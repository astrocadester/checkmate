@echo off
setlocal
cd /d "%~dp0"
rem Checkmate original Intel 8080 ROM build - zmac v1.3; no Python.
if defined ZMAC (
    set "ZMAC_BIN=%ZMAC%"
) else if exist "tools\zmac.exe" (
    set "ZMAC_BIN=tools\zmac.exe"
) else (
    set "ZMAC_BIN=zmac"
)
where "%ZMAC_BIN%" >nul 2>&1
if errorlevel 1 if not exist "%ZMAC_BIN%" (
    echo ERROR: zmac v1.3 not found. Set ZMAC or use tools\zmac.exe.
    exit /b 1
)
if not exist "src\checkmate.asm" (
    echo ERROR: Missing src\checkmate.asm
    exit /b 1
)
if not exist "roms\original\checkmat.zip" (
    echo ERROR: Missing reference roms\original\checkmat.zip
    exit /b 1
)
echo Checkmate original ROM build
echo [1/4] Prepare output
if not exist "build" mkdir "build"
if not exist "roms" mkdir "roms"
del /q "build\checkmate.bin" "build\checkmate.lst" "roms\checkmat.zip" >nul 2>&1
for %%F in (checkmat.h checkmat.g checkmat.f checkmat.e) do if exist "build\%%F" del /q "build\%%F"
echo [2/4] Assemble native Intel 8080 source (zmac v1.3)
"%ZMAC_BIN%" -c -o "build\checkmate.bin" -x "build\checkmate.lst" "src\checkmate.asm"
if errorlevel 1 (echo ERROR: Assembly failed.& exit /b 1)
if not exist "build\checkmate.bin" (echo ERROR: Binary image missing.& exit /b 1)
echo [3/4] Split and verify four 1 KB ROMs
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$bytes=[IO.File]::ReadAllBytes('build\checkmate.bin');" ^
    "if($bytes.Length -ne 4096){throw 'Binary image must contain exactly 4096 bytes'};" ^
    "$names=@('checkmat.h','checkmat.g','checkmat.f','checkmat.e');" ^
    "$sha=@('f758599d6393398a6a8e6e7399dc1a3862604f65','484ff9bfb95166ba09f34c753a7908a73de3cc7d','39e0cf502735819a7e1d933e3686945fcfae21af','453f95dd31968d439339c41e625481170437eb0f');" ^
    "for($i=0;$i -lt 4;$i++){ $part=[byte[]]::new(1024);[Array]::Copy($bytes,$i*1024,$part,0,1024);$file=Join-Path 'build' $names[$i];[IO.File]::WriteAllBytes($file,$part);$actual=(Get-FileHash $file -Algorithm SHA1).Hash.ToLowerInvariant();if($actual -ne $sha[$i]){throw ($names[$i]+' SHA1 mismatch: '+$actual)};Write-Host ($names[$i]+' OK '+$actual) }"
if errorlevel 1 (echo ERROR: ROM splitting or verification failed.& exit /b 1)
echo [4/4] Package roms\checkmat.zip
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "Compress-Archive -LiteralPath @('build\checkmat.h','build\checkmat.g','build\checkmat.f','build\checkmat.e') -DestinationPath 'roms\checkmat.zip' -Force"
if errorlevel 1 (echo ERROR: ROM packaging failed.& exit /b 1)
if not exist "roms\checkmat.zip" (echo ERROR: ROM ZIP missing.& exit /b 1)
echo Build complete: roms\checkmat.zip
exit /b 0
