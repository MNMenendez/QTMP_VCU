# Define the project file and fileset
set proj_folder "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU"
set proj_file [file normalize "${proj_folder}/QTMP_VCU.xpr"]
set sim_fileset "sim_1"
set testbench_dir "${proj_folder}/testbenches"

# Check if the project file exists and open the project
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Set GCC path and update the PATH environment variable
set gcc_path "C:/Xilinx/Vivado/2024.1/tps/mingw/9.3.0/win64.o/nt/bin"
set env(PATH) "${gcc_path};$env(PATH)"
puts "Updated Environment PATH: $env(PATH)"

# Check if the fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Add all testbenches to the simulation fileset
puts "Adding testbenches..."
set testbenches [glob -nocomplain -directory $testbench_dir *.vhd]
foreach tb $testbenches {
    add_files -fileset $sim_fileset $tb
    puts "Added testbench: $tb"
}

# Update the compile order for the simulation fileset
update_compile_order -fileset $sim_fileset

# Set the top module for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Launch simulation for each testbench and generate reports
foreach tb $testbenches {
    set tb_name [file rootname [file tail $tb]]
    puts "Launching simulation for testbench: $tb_name..."
    
    # Define unique names for the snapshot and log files
    set snapshot_name "${tb_name}_behav"
    set log_file [file join $proj_folder "${tb_name}_simulate.log"]
    
    # Launch simulation
    launch_simulation -simset $sim_fileset -snapshot $snapshot_name

    # Wait for simulation to complete
    wait_on_simulation
    
    # Check the simulation results
    set simulation_status [get_property simulation.status]
    if {$simulation_status == "PASSED"} {
        puts "Simulation for testbench: $tb_name passed."
    } else {
        puts "Simulation for testbench: $tb_name failed. Check the log file for details: $log_file"
        exit 1
    }

    # Generate the test report
    puts "Generating test report for testbench: $tb_name..."
    set report_file [file join $proj_folder "${tb_name}_report.txt"]
    exec xsim -report $report_file -log $log_file
    
    puts "Test report generated at: $report_file"
}

# Close the project
close_project

puts "Simulation complete. Test reports generated."
