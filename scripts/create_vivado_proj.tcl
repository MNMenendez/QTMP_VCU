# Define the origin directory and project name
set origin_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP"
if {[info exists ::origin_dir_loc]} {
    set origin_dir $::origin_dir_loc
}
set _xil_proj_name_ "QTMP_VCU"
if {[info exists ::user_project_name]} {
    set _xil_proj_name_ $::user_project_name
}

# Project file path
set proj_file "[file normalize "${origin_dir}/${_xil_proj_name_}.xpr"]"

# Delete the existing project files if they exist
if {[file exists $proj_file]} {
    puts "Deleting existing project files..."
    file delete -force $proj_file
    file delete -force [file join $origin_dir "${_xil_proj_name_}.cache"]
    file delete -force [file join $origin_dir "${_xil_proj_name_}.hw"]
    file delete -force [file join $origin_dir "${_xil_proj_name_}.ip_user_files"]
}

# Create the project, forcing it to overwrite if it already exists
create_project ${_xil_proj_name_} -part xc7z020clg484-1 -force

# Set the default properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
puts "Project '${_xil_proj_name_}' created successfully."

# Create and manage filesets
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}
set obj [get_filesets sources_1]
set source_dir "${origin_dir}/source"
set files [glob -nocomplain -directory $source_dir *.vhd]
if {[llength $files] == 0} {
    puts "WARNING: No VHD files found in the source directory '$source_dir'."
} else {
    add_files -norecurse -fileset $obj $files
    puts "Added VHD files from source directory."
}

if {[string equal [get_filesets -quiet constrs_1] ""]} {
    create_fileset -constrset constrs_1
}
set obj [get_filesets constrs_1]
puts "Constraints fileset 'constrs_1' created."

if {[string equal [get_filesets -quiet sim_1] ""]} {
    create_fileset -simset sim_1
}
set obj [get_filesets sim_1]
set testbench_dir "${origin_dir}/testbenches"
set files [glob -nocomplain -directory $testbench_dir *.vhd]
if {[llength $files] == 0} {
    puts "WARNING: No VHD files found in the testbenches directory '$testbench_dir'."
} else {
    add_files -norecurse -fileset $obj $files
    puts "Added VHD files from testbenches directory."
}

puts "All files added and properties set successfully."
