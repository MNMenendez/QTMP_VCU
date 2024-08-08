# Define directories and files
set sources_1_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/sources_1"
set testbench_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/testbenches"
set project_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU"
set project_file "$project_dir/ART_QTMP.xpr"
set simulation_log "$project_dir/simulation.log"

# Add design files from sources_1
set source_files [glob -nocomplain -directory $sources_1_dir *.vhd]
if {[llength $source_files] > 0} {
    add_files -fileset sources_1 $source_files
    puts "Added design files from '$sources_1_dir' to sources_1."
} else {
    puts "ERROR: No VHD files found in '$sources_1_dir'."
}

# Add testbench files to the simulation set
set testbench_files [glob -nocomplain -directory $testbench_dir *.vhd]
if {[llength $testbench_files] > 0} {
    add_files -fileset sim_1 $testbench_files
    puts "Added testbench files from '$testbench_dir' to sim_1."
} else {
    puts "ERROR: No VHD files found in '$testbench_dir'."
}

# Update compile order
update_compile_order -fileset sources_1

# Set top module for simulation
set_property top hcmt_cpld_top [get_filesets sim_1]

# Save the project to disk
save_project_as $project_file
puts "Project saved to '$project_file'."

# Clear or create the simulation log
if {[file exists $simulation_log]} {
    file delete $simulation_log
}
file delete $simulation_log

# Open the simulation log for writing
set log_fd [open $simulation_log "a"]

# Launch simulations for each testbench file
foreach tb [glob -nocomplain -directory $testbench_dir *.vhd] {
    set tb_name [file rootname [file tail $tb]]
    puts $log_fd "Launching simulation for testbench: $tb_name..."

    # Set the simulation fileset
    launch_simulation -simset sim_1

    # Check the simulation result
    set result [catch {launch_simulation -simset sim_1} err_msg]
    if {$result == 0} {
        puts $log_fd "Simulation for $tb_name completed successfully."
    } else {
        puts $log_fd "ERROR: Simulation for $tb_name failed. Error: $err_msg"
    }
}

# Close the log file
close $log_fd

puts "All simulations launched."
