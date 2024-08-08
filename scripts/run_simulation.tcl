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

# Define the path to the simulation log directory
set sim_log_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.sim/sim_1/behav/xsim"

# Ensure the directory exists
if {[file isdirectory $sim_log_dir]} {
    # Get a list of all log files in the directory
    set log_files [glob -nocomplain $sim_log_dir/*.log]
    if {[llength $log_files] == 0} {
        puts "ERROR: No log files found in '$sim_log_dir'."
        exit 1
    }

    # Open and read each log file
    foreach log_file $log_files {
        set fp [open $log_file r]
        set file_data [read $fp]
        close $fp

        # Check for assertion failures and output results
        if {[regexp "Failure:" $file_data]} {
            puts "ERROR: Assertion failure detected in log file $log_file."
            # Optionally, you could add more specific details here
        } else {
            puts "Simulation completed successfully for log file $log_file."
        }
    }

    # Optionally, you might want to create a consolidated report
    # Here we just print the names of the log files
    puts "Simulation log files processed."
} else {
    puts "ERROR: Simulation log directory '$sim_log_dir' does not exist."
    exit 1
}
