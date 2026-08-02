#include "summon_animation_player.h"

#include "config.h"
#include "fmt.h"
#include "logging.h"
#include "utils.h"

#include <irrlicht.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstring>
#include <mutex>
#include <thread>
#include <vector>

#if EDOPRO_WINDOWS
#define NOMINMAX
#include <windows.h>
#elif EDOPRO_LINUX
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

namespace ygo {
namespace {

constexpr uint32_t FRAME_WIDTH = 640;
constexpr uint32_t FRAME_HEIGHT = 360;
constexpr size_t FRAME_BYTES = FRAME_WIDTH * FRAME_HEIGHT * 4u;
constexpr uint32_t SUMMON_TYPE_MASK = 0xff000000u;
constexpr uint32_t SUMMON_TYPE_FUSION = 0x43000000u;
constexpr uint32_t SUMMON_TYPE_RITUAL = 0x45000000u;
constexpr uint32_t SUMMON_TYPE_SYNCHRO = 0x46000000u;
constexpr uint32_t SUMMON_TYPE_XYZ = 0x49000000u;
constexpr uint32_t SUMMON_TYPE_PENDULUM = 0x4a000000u;
constexpr uint32_t SUMMON_TYPE_LINK = 0x4c000000u;

enum class AnimationKind : uint8_t {
	NONE,
	SYNCHRO,
	XYZ,
	PENDULUM,
	LINK,
	RITUAL,
	FUSION,
};

AnimationKind GetAnimationKind(uint32_t summon_type) {
	switch(summon_type & SUMMON_TYPE_MASK) {
	case SUMMON_TYPE_SYNCHRO: return AnimationKind::SYNCHRO;
	case SUMMON_TYPE_XYZ: return AnimationKind::XYZ;
	case SUMMON_TYPE_PENDULUM: return AnimationKind::PENDULUM;
	case SUMMON_TYPE_LINK: return AnimationKind::LINK;
	case SUMMON_TYPE_RITUAL: return AnimationKind::RITUAL;
	case SUMMON_TYPE_FUSION: return AnimationKind::FUSION;
	default: return AnimationKind::NONE;
	}
}

epro::path_stringview GetBaseName(AnimationKind kind) {
	switch(kind) {
	case AnimationKind::SYNCHRO: return EPRO_TEXT("synchro");
	case AnimationKind::XYZ: return EPRO_TEXT("xyz");
	case AnimationKind::PENDULUM: return EPRO_TEXT("pendulum");
	case AnimationKind::LINK: return EPRO_TEXT("link");
	case AnimationKind::RITUAL: return EPRO_TEXT("ritual");
	case AnimationKind::FUSION: return EPRO_TEXT("fusion");
	default: return EPRO_TEXT("");
	}
}

epro::path_string FindAnimationFile(AnimationKind kind) {
	static constexpr std::array<epro::path_stringview, 10> extensions{
		EPRO_TEXT("gif"), EPRO_TEXT("GIF"),
		EPRO_TEXT("mp4"), EPRO_TEXT("MP4"),
		EPRO_TEXT("webm"), EPRO_TEXT("WebM"), EPRO_TEXT("WEBM"),
		EPRO_TEXT("mkv"), EPRO_TEXT("Mkv"), EPRO_TEXT("MKV")
	};
	const auto base = GetBaseName(kind);
	for(const auto extension : extensions) {
		auto path = epro::format(EPRO_TEXT("{}/Animations/{}.{}"),
			Utils::GetWorkingDirectory(), base, extension);
		if(Utils::FileExists(path))
			return path;
	}
	return {};
}

epro::path_string FindExecutable(epro::path_stringview name) {
	const auto local = epro::format(EPRO_TEXT("{}/{}"), Utils::GetExeFolder(), name);
	if(Utils::FileExists(local))
		return local;
	return epro::path_string{name};
}

#if EDOPRO_WINDOWS
epro::path_string QuoteWindowsArgument(epro::path_stringview argument) {
	epro::path_string quoted{EPRO_TEXT('"')};
	size_t backslashes = 0;
	for(const auto character : argument) {
		if(character == EPRO_TEXT('\\')) {
			++backslashes;
			continue;
		}
		if(character == EPRO_TEXT('"')) {
			quoted.append(backslashes * 2 + 1, EPRO_TEXT('\\'));
			quoted.push_back(EPRO_TEXT('"'));
			backslashes = 0;
			continue;
		}
		quoted.append(backslashes, EPRO_TEXT('\\'));
		backslashes = 0;
		quoted.push_back(character);
	}
	quoted.append(backslashes * 2, EPRO_TEXT('\\'));
	quoted.push_back(EPRO_TEXT('"'));
	return quoted;
}

epro::path_string BuildWindowsCommand(const std::vector<epro::path_string>& arguments) {
	epro::path_string command;
	for(const auto& argument : arguments) {
		if(!command.empty())
			command.push_back(EPRO_TEXT(' '));
		command += QuoteWindowsArgument(argument);
	}
	return command;
}
#endif

} // namespace

struct SummonAnimationPlayer::Impl {
	explicit Impl(irr::video::IVideoDriver* driver) : driver(driver) {}

	~Impl() {
		Stop();
		if(texture)
			driver->removeTexture(texture);
	}

	void Request(uint32_t summon_type) {
		const auto kind = GetAnimationKind(summon_type);
		if(kind != AnimationKind::NONE)
			pending.store(static_cast<uint8_t>(kind));
	}

	void Tick(bool enabled) {
		if(!enabled) {
			if(visible || worker.joinable())
				Stop();
			pending.store(0);
			return;
		}
		const auto requested = static_cast<AnimationKind>(pending.exchange(0));
		if(requested != AnimationKind::NONE) {
			const auto now = std::chrono::steady_clock::now();
			// A Pendulum Summon produces one core message per summoned card. Treat
			// those messages as one animation instead of restarting the video.
			if(!(visible && requested == active_kind
					&& now - last_start < std::chrono::milliseconds(1500)))
				Start(requested);
		}
		if(decode_finished.exchange(false)) {
			finish_pending = true;
			hide_after = std::chrono::steady_clock::now() + std::chrono::milliseconds(150);
		}

		uint64_t serial = 0;
		std::vector<uint8_t> frame;
		{
			std::lock_guard<std::mutex> lock(frame_mutex);
			if(frame_serial != uploaded_serial) {
				serial = frame_serial;
				frame = latest_frame;
			}
		}
		if(!frame.empty() && !texture) {
			texture = driver->addTexture(
				irr::core::dimension2du(FRAME_WIDTH, FRAME_HEIGHT),
				"SummonAnimationFrame", irr::video::ECF_A8R8G8B8);
			if(!texture) {
				ErrorLog("Could not create the summon animation texture");
				Stop();
				return;
			}
		}
		if(!frame.empty() && texture) {
			auto* destination = static_cast<uint8_t*>(texture->lock());
			if(destination) {
				const auto pitch = texture->getPitch();
				for(uint32_t row = 0; row < FRAME_HEIGHT; ++row) {
					std::memcpy(destination + row * pitch,
						frame.data() + row * FRAME_WIDTH * 4u, FRAME_WIDTH * 4u);
				}
				texture->unlock();
				uploaded_serial = serial;
				has_uploaded_frame = true;
			}
		}
		if(finish_pending && std::chrono::steady_clock::now() >= hide_after) {
			visible = false;
			finish_pending = false;
		}
	}

	void Draw(uint32_t width, uint32_t height) {
		if(!visible || !has_uploaded_frame || !texture || !width || !height)
			return;
		const irr::core::recti screen(0, 0, static_cast<irr::s32>(width), static_cast<irr::s32>(height));
		driver->draw2DRectangle(irr::video::SColor(255, 0, 0, 0), screen);
		const double source_ratio = static_cast<double>(FRAME_WIDTH) / FRAME_HEIGHT;
		const double screen_ratio = static_cast<double>(width) / height;
		uint32_t draw_width = width;
		uint32_t draw_height = height;
		if(screen_ratio > source_ratio)
			draw_width = static_cast<uint32_t>(height * source_ratio);
		else
			draw_height = static_cast<uint32_t>(width / source_ratio);
		const auto left = static_cast<irr::s32>((width - draw_width) / 2u);
		const auto top = static_cast<irr::s32>((height - draw_height) / 2u);
		const irr::core::recti destination(left, top,
			left + static_cast<irr::s32>(draw_width), top + static_cast<irr::s32>(draw_height));
		const irr::core::recti source(0, 0, FRAME_WIDTH, FRAME_HEIGHT);
		driver->draw2DImage(texture, destination, source, nullptr, nullptr, true);
	}

	void Start(AnimationKind kind) {
		Stop();
		const auto file = FindAnimationFile(kind);
		if(file.empty())
			return;
		active_kind = kind;
		last_start = std::chrono::steady_clock::now();
		stop_requested.store(false);
		decode_finished.store(false);
		finish_pending = false;
		visible = true;
		has_uploaded_frame = false;
		uploaded_serial = 0;
		{
			std::lock_guard<std::mutex> lock(frame_mutex);
			latest_frame.clear();
			frame_serial = 0;
		}
#if EDOPRO_WINDOWS || EDOPRO_LINUX
		worker = std::thread([this, file] { Decode(file); });
#else
		(void)file;
		visible = false;
#endif
	}

	void Stop() {
		stop_requested.store(true);
		TerminateProcesses();
		if(worker.joinable())
			worker.join();
		decode_finished.store(false);
		finish_pending = false;
		visible = false;
		active_kind = AnimationKind::NONE;
	}

	void PublishFrame(std::vector<uint8_t>& frame) {
		std::lock_guard<std::mutex> lock(frame_mutex);
		latest_frame.swap(frame);
		++frame_serial;
		frame.resize(FRAME_BYTES);
	}

#if EDOPRO_WINDOWS
	bool LaunchDecoder(const epro::path_string& file) {
		SECURITY_ATTRIBUTES security{ sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE };
		HANDLE read_pipe = nullptr;
		HANDLE write_pipe = nullptr;
		if(!CreatePipe(&read_pipe, &write_pipe, &security, 0))
			return false;
		SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);
		const auto ffmpeg = FindExecutable(EPRO_TEXT("ffmpeg.exe"));
		std::vector<epro::path_string> arguments{
			ffmpeg, EPRO_TEXT("-v"), EPRO_TEXT("error"), EPRO_TEXT("-nostdin"),
			EPRO_TEXT("-re"), EPRO_TEXT("-i"), file, EPRO_TEXT("-an"),
			EPRO_TEXT("-vf"), EPRO_TEXT("scale=640:360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2:color=black,fps=30"),
			EPRO_TEXT("-t"), EPRO_TEXT("30"), EPRO_TEXT("-f"), EPRO_TEXT("rawvideo"),
			EPRO_TEXT("-pix_fmt"), EPRO_TEXT("bgra"), EPRO_TEXT("pipe:1")
		};
		auto command = BuildWindowsCommand(arguments);
		std::vector<wchar_t> mutable_command(command.begin(), command.end());
		mutable_command.push_back(L'\0');
		HANDLE null_device = CreateFileW(L"NUL", GENERIC_READ | GENERIC_WRITE,
			FILE_SHARE_READ | FILE_SHARE_WRITE, &security, OPEN_EXISTING, 0, nullptr);
		STARTUPINFOW startup{};
		startup.cb = sizeof(startup);
		startup.dwFlags = STARTF_USESTDHANDLES;
		startup.hStdInput = null_device;
		startup.hStdOutput = write_pipe;
		startup.hStdError = null_device;
		PROCESS_INFORMATION process{};
		const bool launched = !!CreateProcessW(nullptr, mutable_command.data(), nullptr, nullptr,
			TRUE, CREATE_NO_WINDOW, nullptr, Utils::GetWorkingDirectory().data(), &startup, &process);
		CloseHandle(write_pipe);
		if(null_device != INVALID_HANDLE_VALUE)
			CloseHandle(null_device);
		if(!launched) {
			CloseHandle(read_pipe);
			return false;
		}
		CloseHandle(process.hThread);
		std::lock_guard<std::mutex> lock(process_mutex);
		decoder_process = process.hProcess;
		decoder_pipe = read_pipe;
		return true;
	}

	void LaunchAudio(const epro::path_string& file) {
		const auto ffplay = FindExecutable(EPRO_TEXT("ffplay.exe"));
		std::vector<epro::path_string> arguments{
			ffplay, EPRO_TEXT("-v"), EPRO_TEXT("quiet"), EPRO_TEXT("-nostdin"),
			EPRO_TEXT("-nodisp"), EPRO_TEXT("-autoexit"), EPRO_TEXT("-t"), EPRO_TEXT("30"), file
		};
		auto command = BuildWindowsCommand(arguments);
		std::vector<wchar_t> mutable_command(command.begin(), command.end());
		mutable_command.push_back(L'\0');
		STARTUPINFOW startup{};
		startup.cb = sizeof(startup);
		PROCESS_INFORMATION process{};
		if(CreateProcessW(nullptr, mutable_command.data(), nullptr, nullptr, FALSE,
				CREATE_NO_WINDOW, nullptr, Utils::GetWorkingDirectory().data(), &startup, &process)) {
			CloseHandle(process.hThread);
			std::lock_guard<std::mutex> lock(process_mutex);
			audio_process = process.hProcess;
		}
	}

	size_t ReadDecoder(uint8_t* output, size_t amount) {
		HANDLE pipe = nullptr;
		{
			std::lock_guard<std::mutex> lock(process_mutex);
			pipe = decoder_pipe;
		}
		if(!pipe)
			return 0;
		DWORD read = 0;
		if(!ReadFile(pipe, output, static_cast<DWORD>(amount), &read, nullptr))
			return 0;
		return read;
	}

	void CleanupProcesses() {
		HANDLE pipe = nullptr;
		HANDLE video = nullptr;
		HANDLE audio = nullptr;
		{
			std::lock_guard<std::mutex> lock(process_mutex);
			pipe = decoder_pipe;
			video = decoder_process;
			audio = audio_process;
			decoder_pipe = nullptr;
			decoder_process = nullptr;
			audio_process = nullptr;
		}
		if(pipe)
			CloseHandle(pipe);
		if(video) {
			WaitForSingleObject(video, INFINITE);
			CloseHandle(video);
		}
		if(audio) {
			if(WaitForSingleObject(audio, 0) == WAIT_TIMEOUT)
				TerminateProcess(audio, 0);
			WaitForSingleObject(audio, INFINITE);
			CloseHandle(audio);
		}
	}

	void TerminateProcesses() {
		std::lock_guard<std::mutex> lock(process_mutex);
		if(decoder_process)
			TerminateProcess(decoder_process, 0);
		if(audio_process)
			TerminateProcess(audio_process, 0);
	}
#elif EDOPRO_LINUX
	static pid_t Spawn(const std::vector<epro::path_string>& arguments, int output_fd = -1) {
		const auto pid = fork();
		if(pid != 0)
			return pid;
		const auto null_fd = open("/dev/null", O_RDWR);
		if(null_fd >= 0) {
			dup2(null_fd, STDIN_FILENO);
			dup2(null_fd, STDERR_FILENO);
		}
		if(output_fd >= 0)
			dup2(output_fd, STDOUT_FILENO);
		else if(null_fd >= 0)
			dup2(null_fd, STDOUT_FILENO);
		if(null_fd > STDERR_FILENO)
			close(null_fd);
		std::vector<char*> argv;
		argv.reserve(arguments.size() + 1);
		for(const auto& argument : arguments)
			argv.push_back(const_cast<char*>(argument.c_str()));
		argv.push_back(nullptr);
		execvp(argv[0], argv.data());
		_exit(127);
	}

	bool LaunchDecoder(const epro::path_string& file) {
		int descriptors[2];
		if(pipe(descriptors) != 0)
			return false;
		const auto ffmpeg = FindExecutable(EPRO_TEXT("ffmpeg"));
		std::vector<epro::path_string> arguments{
			ffmpeg, "-v", "error", "-nostdin", "-re", "-i", file, "-an",
			"-vf", "scale=640:360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2:color=black,fps=30",
			"-t", "30", "-f", "rawvideo", "-pix_fmt", "bgra", "pipe:1"
		};
		const auto pid = Spawn(arguments, descriptors[1]);
		close(descriptors[1]);
		if(pid < 0) {
			close(descriptors[0]);
			return false;
		}
		std::lock_guard<std::mutex> lock(process_mutex);
		decoder_pid = pid;
		decoder_fd = descriptors[0];
		return true;
	}

	void LaunchAudio(const epro::path_string& file) {
		const auto ffplay = FindExecutable(EPRO_TEXT("ffplay"));
		std::vector<epro::path_string> arguments{
			ffplay, "-v", "quiet", "-nostdin", "-nodisp", "-autoexit", "-t", "30", file
		};
		const auto pid = Spawn(arguments);
		if(pid > 0) {
			std::lock_guard<std::mutex> lock(process_mutex);
			audio_pid = pid;
		}
	}

	size_t ReadDecoder(uint8_t* output, size_t amount) {
		int fd = -1;
		{
			std::lock_guard<std::mutex> lock(process_mutex);
			fd = decoder_fd;
		}
		if(fd < 0)
			return 0;
		const auto read_count = read(fd, output, amount);
		return read_count > 0 ? static_cast<size_t>(read_count) : 0;
	}

	void CleanupProcesses() {
		pid_t video = -1;
		pid_t audio = -1;
		int fd = -1;
		{
			std::lock_guard<std::mutex> lock(process_mutex);
			video = decoder_pid;
			audio = audio_pid;
			fd = decoder_fd;
			decoder_pid = -1;
			audio_pid = -1;
			decoder_fd = -1;
		}
		if(fd >= 0)
			close(fd);
		if(video > 0)
			waitpid(video, nullptr, 0);
		if(audio > 0) {
			kill(audio, SIGTERM);
			waitpid(audio, nullptr, 0);
		}
	}

	void TerminateProcesses() {
		std::lock_guard<std::mutex> lock(process_mutex);
		if(decoder_pid > 0)
			kill(decoder_pid, SIGTERM);
		if(audio_pid > 0)
			kill(audio_pid, SIGTERM);
	}
#else
	void TerminateProcesses() {}
#endif

#if EDOPRO_WINDOWS || EDOPRO_LINUX
	void Decode(const epro::path_string& file) {
		if(stop_requested.load())
			return;
		if(!LaunchDecoder(file)) {
			ErrorLog("Could not start FFmpeg for summon animation: {}", Utils::ToUTF8IfNeeded(file));
			visible = false;
			return;
		}
		LaunchAudio(file);
		if(stop_requested.load())
			TerminateProcesses();
		std::vector<uint8_t> frame(FRAME_BYTES);
		size_t offset = 0;
		bool received_frame = false;
		while(!stop_requested.load()) {
			const auto amount = ReadDecoder(frame.data() + offset, FRAME_BYTES - offset);
			if(!amount)
				break;
			offset += amount;
			if(offset == FRAME_BYTES) {
				received_frame = true;
				PublishFrame(frame);
				offset = 0;
			}
		}
		if(stop_requested.load())
			TerminateProcesses();
		CleanupProcesses();
		if(!received_frame && !stop_requested.load())
			ErrorLog("FFmpeg produced no frames for summon animation: {}", Utils::ToUTF8IfNeeded(file));
		if(received_frame && !stop_requested.load())
			decode_finished.store(true);
		else
			visible = false;
	}
#endif

	irr::video::IVideoDriver* driver{};
	irr::video::ITexture* texture{};
	std::atomic<uint8_t> pending{ 0 };
	std::atomic_bool stop_requested{ false };
	std::atomic_bool decode_finished{ false };
	std::atomic_bool visible{ false };
	bool finish_pending{};
	std::chrono::steady_clock::time_point hide_after{};
	AnimationKind active_kind{ AnimationKind::NONE };
	std::chrono::steady_clock::time_point last_start{};
	std::thread worker;
	std::mutex frame_mutex;
	std::vector<uint8_t> latest_frame;
	uint64_t frame_serial{};
	uint64_t uploaded_serial{};
	bool has_uploaded_frame{};
	std::mutex process_mutex;
#if EDOPRO_WINDOWS
	HANDLE decoder_process{};
	HANDLE audio_process{};
	HANDLE decoder_pipe{};
#elif EDOPRO_LINUX
	pid_t decoder_pid{ -1 };
	pid_t audio_pid{ -1 };
	int decoder_fd{ -1 };
#endif
};

SummonAnimationPlayer::SummonAnimationPlayer(irr::video::IVideoDriver* driver) :
	impl(std::make_unique<Impl>(driver)) {}

SummonAnimationPlayer::~SummonAnimationPlayer() = default;

void SummonAnimationPlayer::Play(uint32_t summon_type) {
	impl->Request(summon_type);
}

void SummonAnimationPlayer::Tick(bool enabled) {
	impl->Tick(enabled);
}

void SummonAnimationPlayer::Draw(uint32_t width, uint32_t height) {
	impl->Draw(width, height);
}

void SummonAnimationPlayer::Stop() {
	impl->Stop();
}

} // namespace ygo
