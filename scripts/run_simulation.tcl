# Define directories and files
set testbench_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/testbenches"
set project_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU"
set simulation_log "$project_dir/simulation.log"

# Function to log directory contents
proc log_directory_contents {log_fd dir} {
    puts $log_fd "Contents of directory '$dir':"
    foreach file [glob -nocomplain -directory $dir *] {
        puts $log_fd [file tail $file]
    }
}

# Clear existing simulation log or create a new one
if {[file exists $simulation_log]} {
    file delete $simulation_log
}
puts "Cleared existing simulation log or created a new one."

# Open log file and start logging
set log_fd [open $simulation_log "a"]

# Function to get current time in a human-readable format
proc get_current_time {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

# Log the start of the simulation
puts $log_fd "Simulation Log Started at [get_current_time]"

# Log the contents of the testbench directory before simulation
log_directory_contents $log_fd $testbench_dir

# Get the list of testbenches
set testbenches [glob -nocomplain -directory $testbench_dir *.vhd]

# Check if any testbenches are found
if {[llength $testbenches] == 0} {
    puts $log_fd "ERROR: No testbench files found in '$testbench_dir'."
    close $log_fd
    exit
}

# Define Vivado simulation command
proc run_vivado_simulation {tb log_fd} {
    set tb_name [file rootname [file tail $tb]]
    puts $log_fd "Launching simulation for testbench: $tb_name..."
    
    # Run simulation and capture output
    set result [catch {
        # Use Vivado command to run simulation
        set cmd "vivado -mode batch -source $tb"
        set output [exec $cmd]
        puts $log_fd "Simulation output: $output"
        return 0
    } err_msg]

    # Record result in log file
    if {$result == 0} {
        puts $log_fd "Simulation for $tb_name completed successfully."
    } else {
        puts $log_fd "ERROR: Simulation for $tb_name failed. Error: $err_msg"
    }
}

# Launch simulations for each testbench
foreach tb $testbenches {
    run_vivado_simulation $tb $log_fd
}

# Log the contents of the testbench directory after simulation
log_directory_contents $log_fd $testbench_dir

# Close the log file
close $log_fd
puts "All simulations launched."
