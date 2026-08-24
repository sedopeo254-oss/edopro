using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;
using YgoMaster;

namespace YgoMasterClient
{
    // Read-only Ai Duel bridge. It never sends commands back to Master Duel.
    // Add the small call-sites from AiDuelBridgeHooks.patch to DuelDll.cs.
    public static class AiDuelBridge
    {
        const string Host = "127.0.0.1";
        const int Port = 17384;
        static readonly object Sync = new object();
        static TcpClient Client;
        static NetworkStream Stream;
        static string SessionId;
        static bool Enabled = true;
        static DateTime LastConnectTry = DateTime.MinValue;

        public static string StatusText
        {
            get { return IsConnected ? "Ai Duel Bridge: CONNECTED" : "Ai Duel Bridge: waiting for Ai Duel.exe"; }
        }

        public static bool IsConnected
        {
            get { return Client != null && Client.Connected && Stream != null; }
        }

        static bool EnsureConnected()
        {
            if (!Enabled) return false;
            if (IsConnected) return true;
            if ((DateTime.UtcNow - LastConnectTry).TotalSeconds < 2) return false;
            LastConnectTry = DateTime.UtcNow;
            try
            {
                Close();
                Client = new TcpClient();
                Client.NoDelay = true;
                Client.Connect(Host, Port);
                Stream = Client.GetStream();
                Send(new Dictionary<string, object>
                {
                    { "type", "HELLO" },
                    { "source", "Master Duel / YgoMasterClient" },
                    { "bridgeVersion", 3 },
                    { "at", DateTime.UtcNow.ToString("o") }
                });
                return true;
            }
            catch
            {
                Close();
                return false;
            }
        }

        static void Close()
        {
            try { if (Stream != null) Stream.Dispose(); } catch { }
            try { if (Client != null) Client.Close(); } catch { }
            Stream = null;
            Client = null;
        }

        static void Send(Dictionary<string, object> obj)
        {
            lock (Sync)
            {
                if (!EnsureConnected()) return;
                try
                {
                    if (!obj.ContainsKey("at")) obj["at"] = DateTime.UtcNow.ToString("o");
                    if (!string.IsNullOrEmpty(SessionId) && !obj.ContainsKey("session")) obj["session"] = SessionId;
                    string json = MiniJSON.Json.Serialize(obj) + "\n";
                    byte[] bytes = Encoding.UTF8.GetBytes(json);
                    Stream.Write(bytes, 0, bytes.Length);
                    Stream.Flush();
                }
                catch { Close(); }
            }
        }

        public static void OnDuelBegin(object gameMode, int myId)
        {
            SessionId = "md_" + DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fff");
            Send(new Dictionary<string, object>
            {
                { "type", "DUEL_BEGIN" },
                { "session", SessionId },
                { "gameMode", gameMode == null ? "" : gameMode.ToString() },
                { "myId", myId },
                { "readOnly", true }
            });
        }

        public static void OnDuelEnd(int result, int finish, int finishCardId)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "DUEL_END" },
                { "result", result },
                { "finish", finish },
                { "finishCardId", finishCardId }
            });
            SessionId = null;
        }

        public static void OnPhase(ulong seq, int phase)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "PHASE" }, { "seq", seq }, { "phase", phase }
            });
        }

        public static void OnCommand(ulong seq, int player, int position, int index, int commandId)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "COMMAND" }, { "seq", seq }, { "player", player },
                { "position", position }, { "index", index }, { "commandId", commandId }
            });
        }

        public static void OnRunEffect(ulong seq, int id, int p1, int p2, int p3)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "RUN_EFFECT" }, { "seq", seq }, { "id", id },
                { "param1", p1 }, { "param2", p2 }, { "param3", p3 }
            });
        }

        public static void OnDialogResult(ulong seq, uint result)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "DIALOG_RESULT" }, { "seq", seq }, { "result", result }
            });
        }

        public static void OnListCardExData(ulong seq, int index, int data)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "LIST_CARD_EX_DATA" }, { "seq", seq }, { "index", index }, { "data", data }
            });
        }

        public static void OnListIndex(ulong seq, int index)
        {
            Send(new Dictionary<string, object>
            {
                { "type", "LIST_SELECT" }, { "seq", seq }, { "index", index }
            });
        }

        public static void OnReplayRecord(byte[] data)
        {
            if (data == null || data.Length == 0) return;
            Send(new Dictionary<string, object>
            {
                { "type", "REPLAY_RECORD" },
                { "size", data.Length },
                { "payloadBase64", Convert.ToBase64String(data) }
            });
        }
    }
}
