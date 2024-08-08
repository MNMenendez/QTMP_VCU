# Open the existing project
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Set the simulation fileset
set sim_fileset "sim_1"
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Configure verbose simulation settings
# (Add detailed options as needed)
launch_simulation -simset $sim_fileset

# Run the simulation for a specified duration
run 1000ns

# Optionally, you can capture simulation output
# Redirecting stdout and stderr to log files can be achieved via shell commands.
# For Windows:
exec cmd /c "type C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.sim/sim_1/behav/xsim/sim.log > C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/simulation.log"

# For Unix/Linux:
# exec sh -c "cat C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.sim/sim_1/behav/xsim/sim.log > C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/simulation.log"
