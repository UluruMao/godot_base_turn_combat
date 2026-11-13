@echo off
setlocal
cd /d "%~dp0"

rem Prefer an explicitly configured engine; otherwise search PATH.
if not defined GODOT_EXE (
    for %%G in (godot.exe godot4.exe) do (
        for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
    )
)
if not defined GODOT_EXE (
    echo Godot was not found. Add Godot 4.7.2 to PATH or set GODOT_EXE
    echo to your Godot executable. You can also import project.godot
    echo in the Godot editor and press F5.
    pause
    exit /b 1
)
if not exist "%GODOT_EXE%" (
    echo GODOT_EXE does not point to an existing executable.
    pause
    exit /b 1
)

"%GODOT_EXE%" --headless --editor --path "%~dp0." --import --quit
if errorlevel 1 (
    echo Asset import failed. Open the project in Godot to inspect the error.
    pause
    exit /b 1
)
"%GODOT_EXE%" --path "%~dp0." %*
