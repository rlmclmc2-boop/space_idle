# Isolated native test provenance

The direct native scale test used an isolated Windows x86_64 build under `test/native-build/` on D:. That directory and its DLL are intentionally Git-ignored. The source at build time was branch commit `dd4377e1d7d18fd6670a304fc6642e5fde5ea84c`, after the unsafe relative health clamps were removed. Its combat header is unchanged by the subsequent authored Excel edits.

Inputs verified before building:

| Input | SHA-256 or commit |
|---|---|
| godot-cpp 10.0.0 stable checkout | `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` |
| Godot 4.7.2 single-precision API (`D:/CodexBuild/space_idle/api/extension_api.json`) | `d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986` |
| Godot 4.7.2 console executable | `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643` |
| `combat_execution_kernel.h` | `12bc744e6fd064415e1be88914c5174a3b43856adf97dfaa77248007764d4734` |
| `space_native.cpp` | `041e61cee4e8e0417a0952694385d56ffe2ba88838e46af600dd04f5ce939118` |
| `SConstruct` | `9d060ef9e7a0c61533865ce9d93c17cea9a61eb55071aa5789c6c247f8441147` |
| resulting `space_native.dll` | `62176b7a7e1ab372004356ec42db06b8e5c321eb325f591021dac9b62d14fd4b` |

Executed from the task branch root in PowerShell, with all generated files under D::

```powershell
$env:TEMP='D:\CodexTools\tmp'
$env:TMP=$env:TEMP
$env:PYTHONPYCACHEPREFIX='D:\CodexTools\cache\pycache'
$env:PATH='D:\CodexTools\llvm-mingw\llvm-mingw-20261006-ucrt-x86_64\bin;'+$env:PATH
Copy-Item -LiteralPath space-battleship/addons/native_battle/SConstruct -Destination test/native-build/project/SConstruct
Copy-Item -LiteralPath space-battleship/addons/native_battle/src/space_native.cpp -Destination test/native-build/project/src/space_native.cpp
Copy-Item -LiteralPath space-battleship/addons/native_battle/src/combat_execution_kernel.h -Destination test/native-build/project/src/combat_execution_kernel.h
Copy-Item -LiteralPath space-battleship/addons/native_battle/src/combat_presentation.h -Destination test/native-build/project/src/combat_presentation.h
Copy-Item -LiteralPath space-battleship/addons/native_battle/src/combat_retained_presentation.h -Destination test/native-build/project/src/combat_retained_presentation.h
Push-Location test/native-build/project
& D:\CodexTools\venv\godot-native\Scripts\python.exe -m SCons bindings=D:/CodexBuild/space_idle/balance-recovery-progression-20261015/test/native-build/godot-cpp platform=windows arch=x86_64 use_mingw=yes use_llvm=yes mingw_prefix=D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64 use_static_cpp=yes custom_api_file=D:/CodexBuild/space_idle/api/extension_api.json target=template_release lto=none -j 1
Pop-Location
python test/run.py test_native_weapon_scale.gd --godot D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --headless --timeout 120
```

The project, SConstruct, presentation headers, and `space_native.cpp` were copied from the branch into `test/native-build/project` before the incremental rebuild; only the combat header changed from the previous build. `raw/native-rebuild.txt` is the original incremental SCons output. `raw/test_native_weapon_scale.txt` is the later isolated Godot direct-contract output under the user-approved relation-stability criterion. It records the known nonzero 1e40 boundary but exits zero when the other checks pass. The native firing-chain and five-scale role results are separate in `native-roles120.jsonl` and `candidate120-scales-native.jsonl`.
