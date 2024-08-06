@echo off
setlocal

:: Define paths
set MODELSIM_HOME=C:\modeltech64_10.6d\win64
set SOURCE_DIR=C:\ProgramData\Jenkins\.jenkins\workspace\ART_QTMP\source
set TESTBENCHES_DIR=C:\ProgramData\Jenkins\.jenkins\workspace\ART_QTMP\testbenches

:: Create work library
"%MODELSIM_HOME%\vsim.exe" -c -do "vlib work"

:: Compile source files
for %%f in ("%SOURCE_DIR%\*.vhdl") do (
    "%MODELSIM_HOME%\vsim.exe" -c -do "vcom -2008 -work work \"%%f\""
)

:: Compile testbenches
for %%f in ("%TESTBENCHES_DIR%\*.vhdl") do (
    "%MODELSIM_HOME%\vsim.exe" -c -do "vcom -2008 -work work \"%%f\""
)

endlocal
