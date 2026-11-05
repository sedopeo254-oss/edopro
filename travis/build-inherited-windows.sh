#!/usr/bin/env bash
set -euo pipefail
./premake5 vs2017 --oldwindows=true --sound=miniaudio,sfml --no-joystick=true
python3 - <<'PY'
from pathlib import Path
import re
p=Path('build/Irrlicht.vcxproj')
s=p.read_text()
new,count=re.subn(r'(<ClCompile>)(?!\s*<LanguageStandard>)',r'\1<LanguageStandard>stdcpp17</LanguageStandard>',s)
assert count>0, 'Irrlicht C++17 project compile groups missing'
p.write_text(new)
print('Irrlicht C++17 enabled:',count)
PY
msbuild.exe -m -p:Configuration=release -p:Platform=Win32 ./build/ygo.sln -t:ygopro -verbosity:minimal -p:EchoOff=true
