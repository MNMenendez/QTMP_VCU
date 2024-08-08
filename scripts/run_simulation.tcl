# Define directories
set sources_1_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/sources_1"
set testbench_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU/QTMP_VCU.gen/testbenches"

# Ensure the directories exist
if {[file isdirectory $sources_1_dir] == 0} {
    file mkdir $sources_1_dir
    puts "Created sources_1 directory at '$sources_1_dir'."
} else {
    puts "Sources_1 directory already exists at '$sources_1_dir'."
}

if {[file isdirectory $testbench_dir] == 0} {
    file mkdir $testbench_dir
    puts "Created testbenches directory at '$testbench_dir'."
} else {
    puts "Testbenches directory already exists at '$testbench_dir'."
}

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

# Launch simulation
foreach tb [glob -nocomplain -directory $testbench_dir *.vhd] {
    set tb_name [file rootname [file tail $tb]]
    puts "Launching simulation for testbench: $tb_name..."

    # Set the simulation fileset
    launch_simulation -simset sim_1
}

puts "Project setup completed."
