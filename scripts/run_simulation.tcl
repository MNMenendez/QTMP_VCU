# Define directories and files
set vivadoPath "C:/Xilinx/Vivado/2024.1/bin"
set testbench_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/testbenches"
set project_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU"
set simulation_log "$project_dir/simulation.log"
set results_xml "$project_dir/simulation_results.xml"

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

# Clear existing results XML or create a new one
if {[file exists $results_xml]} {
    file delete $results_xml
}
file mkdir [file dirname $results_xml]
set xml_fd [open $results_xml "w"]
puts $xml_fd "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
puts $xml_fd "<testsuites>"

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
    puts $xml_fd "</testsuites>"
    close $xml_fd
    exit
}

# Define procedure to run Vivado simulation
proc run_vivado_simulation {tb log_fd vivadoPath project_dir xml_fd} {
    set tb_name [file rootname [file tail $tb]]
    puts $log_fd "Launching simulation for testbench: $tb_name..."

    # Create the Vivado command for simulation
    set cmd "cd $project_dir && $vivadoPath/vivado.bat -mode batch -source $tb"

    # Run simulation and capture output
    set result [catch {
        set output [exec $cmd]
        # Debugging: log the full command and output
        puts $log_fd "Command executed: $cmd"
        puts $log_fd "Simulation output: $output"
        return 0
    } err_msg]

    # Log error message if any
    if {$result != 0} {
        puts $log_fd "Error encountered: $err_msg"
    }

    # Determine result and write to XML
    set status "failed"
    if {$result == 0} {
        # Check if the simulation output contains the string indicating success
        if {[string match "*finished successfully*" $output]} {
            set status "passed"
        } elseif {[string match "*skipped*" $output]} {
            set status "skipped"
        }
    } else {
        # Append the error message to the output
        set output "$err_msg\n$output"
    }

    puts $log_fd "Simulation for $tb_name $status."
    puts $xml_fd "<testcase name=\"$tb_name\" status=\"$status\">"
    puts $xml_fd "    <system-out><![CDATA[$output]]></system-out>"
    puts $xml_fd "</testcase>"
}

# Launch simulations for each testbench
foreach tb $testbenches {
    run_vivado_simulation $tb $log_fd $vivadoPath $project_dir $xml_fd
}

# Close the log file and XML file
puts $log_fd "All simulations launched."
close $log_fd
puts $xml_fd "</testsuites>"
close $xml_fd
