# Define project name and directories
set origin_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP"
set proj_folder "${origin_dir}/QTMP_VCU"
set _xil_proj_name_ "QTMP_VCU"
set proj_file "[file normalize "${proj_folder}/${_xil_proj_name_}.xpr"]"

# Delete existing project files if they exist
if {[file isdirectory $proj_folder]} {
    puts "Deleting existing project folder..."
    if {[catch {file delete -force $proj_folder} err]} {
        puts "ERROR: Failed to delete project folder '$proj_folder'. Error: $err"
        exit 1
    }
} else {
    file mkdir $proj_folder
    puts "Created project folder at '$proj_folder'."
}

# Create the project
cd $proj_folder
create_project ${_xil_proj_name_} -part xc7z020clg484-1 -force
set obj [current_project]

# Set project properties
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
puts "Project '${_xil_proj_name_}' created successfully in '$proj_folder'."

# Define directories for sources and testbenches
set sources_1_dir "${proj_folder}/QTMP_VCU.gen/sources_1"
set testbench_dir "${proj_folder}/QTMP_VCU.gen/testbenches"

# Create directories if they do not exist
if {[file isdirectory $sources_1_dir] == 0} {
    file mkdir $sources_1_dir
    puts "Created sources_1 directory at '$sources_1_dir'."
} else {
    puts "Sources directory already exists at '$sources_1_dir'."
}

if {[file isdirectory $testbench_dir] == 0} {
    file mkdir $testbench_dir
    puts "Created testbenches directory at '$testbench_dir'."
} else {
    puts "Testbenches directory already exists at '$testbench_dir'."
}

# Check files in sources_1_dir
set source_files [glob -nocomplain -directory $sources_1_dir *.vhd]
puts "Files found in sources_1_dir: $source_files"

# Add design files to sources_1
if {[llength $source_files] > 0} {
    add_files -fileset sources_1 $source_files
    puts "Added design files from '$sources_1_dir' to sources_1."
} else {
    puts "ERROR: No VHD files found in '$sources_1_dir'."
}

# Check files in testbench_dir
set testbench_files [glob -nocomplain -directory $testbench_dir *.vhd]
puts "Files found in testbench_dir: $testbench_files"

# Add testbench files to sim_1
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

puts "Project setup completed."
