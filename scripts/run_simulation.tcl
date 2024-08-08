# Define the project file and simulation fileset
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"
set sim_fileset "sim_1"

# Open the project if it exists
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Check if the simulation fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top-level entity for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Launch the simulation
puts "Launching simulation..."
launch_simulation -simset $sim_fileset

# Run the simulation for 1000ns
puts "Running simulation for 1000ns..."
run 1000ns

# Check if the simulation log file exists and report status
set sim_log "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.sim/sim_1/behav/xsim/simulate.log"
if {[file exists $sim_log]} {
    puts "Simulation log file found: $sim_log"
    # Optionally copy the log file to a more accessible location or manage it as needed
    exec cmd /c "type $sim_log > C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/simulation.log"
} else {
    puts "ERROR: Simulation log file '$sim_log' does not exist."
    exit 1
}

# Optionally, print a message indicating that the script has completed
puts "Simulation completed. Check the log file for details."

# Exit Vivado
exit
