@echo off
echo Running ModelSim
vlib work
vcom -2008 -work work "%WORKSPACE%\\QTMP_VCU\\source\\*.vhdl"
vcom -2008 -work work "%WORKSPACE%\\QTMP_VCU\\testbenches\\*.vhdl"
vsim -c -do "run -all; quit"
