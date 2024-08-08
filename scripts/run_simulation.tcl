# Set project file and simulation fileset
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"
set sim_fileset "sim_1"

# Open project
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Set simulation fileset
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}
set_property top hcmt_cpld_top [get_filesets $sim_fileset]
puts "Launching simulation..."
launch_simulation -simset $sim_fileset

# Run simulation for 1000ns
puts "Running simulation for 1000ns..."
run 1000ns

# Define source and destination log files
set sim_log "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.sim/sim_1/behav/xsim/simulate.log"
set dest_log "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/simulation.log"

# Check if the simulation log file exists
if {[file exists $sim_log]} {
    puts "Simulation log file found: $sim_log"
    # Copy the log file to the destination
    file copy -force $sim_log $dest_log
    puts "Log file copied to: $dest_log"
} else {
    puts "ERROR: Simulation log file '$sim_log' does not exist."
    exit 1
}

# Exit Vivado
exit
