# Define directories and files
set sources_1_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/sources_1"
set testbench_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/testbenches"
set project_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU"
set project_file "$project_dir/QTMP_VCU.xpr"
set simulation_log "$project_dir/simulation.log"

# Add design files
set source_files [glob -nocomplain -directory $sources_1_dir *.vhd]
if {[llength $source_files] > 0} {
    add_files -fileset sources_1 $source_files
    puts "Added design files from '$sources_1_dir' to sources_1."
} else {
    puts "ERROR: No VHD files found in '$sources_1_dir'."
}

# Add testbench files
set testbench_files [glob -nocomplain -directory $testbench_dir *.vhd]
if {[llength $testbench_files] > 0} {
    add_files -fileset sim_1 $testbench_files
    puts "Added testbench files from '$testbench_dir' to sim_1."
} else {
    puts "ERROR: No VHD files found in '$testbench_dir'."
}

# Update compile order and save project
update_compile_order -fileset sources_1
set_property top hcmt_cpld_top [get_filesets sim_1]
save_project_as -force $project_file
puts "Project saved to '$project_file'."

# Clear existing simulation log or create a new one
if {[file exists $simulation_log]} {
    file delete $simulation_log
}
puts "Cleared existing simulation log or created a new one."

# Open log file and start logging
set log_fd [open $simulation_log "a"]
puts $log_fd "Simulation Log Started at [clock seconds]"

# Launch simulations for each testbench
foreach tb [glob -nocomplain -directory $testbench_dir *.vhd] {
    set tb_name [file rootname [file tail $tb]]
    puts $log_fd "Launching simulation for testbench: $tb_name..."

    # Run simulation and capture output
    set result [catch {
        # Explicitly specify the simulation command and testbench file if necessary
        launch_simulation -simset sim_1 -testbench $tb
    } err_msg]

    # Record result in log file
    if {$result == 0} {
        puts $log_fd "Simulation for $tb_name completed successfully."
    } else {
        puts $log_fd "ERROR: Simulation for $tb_name failed. Error: $err_msg"
    }
}

# Close the log file
close $log_fd
puts "All simulations launched."
