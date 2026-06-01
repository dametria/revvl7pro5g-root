@echo off
REM Build cheese for REVVL 7 Pro 5G (SM6450 / Pinehurst)
REM Requires Android NDK 27

set NDK=C:\Users\%USERNAME%\Android\ndk\27.0.12077973
set CC=%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android34-clang.cmd

echo Building cheese for REVVL 7 Pro 5G...
%CC% -o cheese cheese.c -static

if %ERRORLEVEL% EQU 0 (
    echo SUCCESS: cheese built
    dir cheese
) else (
    echo FAILED
)
