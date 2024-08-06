@echo off
echo Running VHDL compilation...

rem Set paths
set MODELSIM_HOME=C:/modeltech64_10.6d/win64

rem Print environment variables for debugging
echo MODELSIM_HOME=%MODELSIM_HOME%

rem Print current directory
echo Current Directory: %CD%

rem Check if ModelSim executable is accessible
if exist "%MODELSIM_HOME%/vsim.exe" (
    echo ModelSim executable found.
) else (
    echo ModelSim executable not found.
    exit /b 1
)

rem Check if transcript file can be created
echo Testing file creation in current directory...
echo Test > test_file.txt
if exist "test_file.txt" (
    echo Test file created successfully.
    del test_file.txt
) else (
    echo Unable to create test file.
    exit /b 1
)

rem Run ModelSim commands
"%MODELSIM_HOME%/vsim.exe" -c -do "vlib work; vcom -2008 -work work \"C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/source/*.vhdl\"; vcom -2008 -work work \"C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/testbenches/*.vhdl\""

rem Check the error level
if %errorlevel% neq 0 (
    echo Compilation failed with error level %errorlevel%
) else (
    echo Compilation succeeded
)

pause
