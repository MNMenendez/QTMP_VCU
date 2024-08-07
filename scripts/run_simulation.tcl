# Define the path to the project file
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"

# Open the Vivado project
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Define the fileset for simulation
set sim_fileset sim_1

# Ensure that the simulation fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for simulation
# Specify the top module name
set_property top hcmt_cpld_top [get_filesets $sim_fileset]
puts "Top module set to hcmt_cpld_top"

# Launch the simulation
launch_simulation -simset [get_filesets $sim_fileset]

# Close the simulation
close_sim

# Look for assertion failures in the simulation log
set log_file [glob -nocomplain *sim/$sim_fileset/behav/xsim/simulate.log]
if {[llength $log_file] == 0} {
    puts "ERROR: Simulation log file not found."
    exit 1
}
set fp [open [lindex $log_file 0] r]
set file_data [read $fp]
close $fp

# Check for assertion failures
if {[regexp "Failure:" $file_data]} {
    puts "ERROR: Assertion failure detected in simulation log."
    exit 1
} else {
    puts "Simulation completed successfully."
    exit 0
}
