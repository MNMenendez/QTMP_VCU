@echo off
echo Running VHDL compilation...

rem Set paths
set MODELSIM_HOME=C:\modeltech64_10.6d\win64

rem Print environment variables for debugging
echo MODELSIM_HOME=%MODELSIM_HOME%

rem Print current directory
echo Current Directory: %CD%

rem Run ModelSim commands
"%MODELSIM_HOME%\vsim.exe" -c -do "vlib work; vcom -2008 -work work \"C:\ProgramData\Jenkins\.jenkins\workspace\ART_QTMP\source\*.vhdl\"; vcom -2008 -work work \"C:\ProgramData\Jenkins\.jenkins\workspace\ART_QTMP\testbenches\*.vhdl\""

rem Check the error level
if %errorlevel% neq 0 (
    echo Compilation failed with error level %errorlevel%
) else (
    echo Compilation succeeded
)

pause
