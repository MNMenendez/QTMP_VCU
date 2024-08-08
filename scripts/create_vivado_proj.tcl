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

# Attempt to delete the existing project files
if {[file exists $proj_file]} {
    puts "Deleting existing project files..."
    if {[catch {file delete -force $proj_file} err]} {
        puts "ERROR: Failed to delete project file '$proj_file'. Error: $err"
        exit 1
    }
    if {[catch {file delete -force [file join $origin_dir "${_xil_proj_name_}.cache"]} err]} {
        puts "ERROR: Failed to delete cache file. Error: $err"
    }
    if {[catch {file delete -force [file join $origin_dir "${_xil_proj_name_}.hw"]} err]} {
        puts "ERROR: Failed to delete hardware file. Error: $err"
    }
    if {[catch {file delete -force [file join $origin_dir "${_xil_proj_name_}.ip_user_files"]} err]} {
        puts "ERROR: Failed to delete IP user files. Error: $err"
    }
}

# Create the project, forcing it to overwrite if it already exists
create_project ${_xil_proj_name_} -part xc7z020clg484-1 -force

# Set the default properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
puts "Project '${_xil_proj_name_}' created successfully."

# Create and manage filesets
# Check and create sources_1 directory if it does not exist
set sources_1_dir "${origin_dir}/QTMP_VCU.gen/sources_1"
if {[file isdirectory $sources_1_dir] == 0} {
    file mkdir $sources_1_dir
    puts "Created sources_1 directory at '$sources_1_dir'."
}

if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}
set obj [get_filesets sources_1]

# Add VHD files from source directory to sources_1
set source_dir "${origin_dir}/source"
set files [glob -nocomplain -directory $source_dir *.vhd]
if {[llength $files] == 0} {
    puts "WARNING: No VHD files found in the source directory '$source_dir'."
} else {
    # Copy files to sources_1 directory before adding them
    foreach file $files {
        file copy -force $file [file join $sources_1_dir [file tail $file]]
    }
    add_files -norecurse -fileset $obj [glob -nocomplain -directory $sources_1_dir *.vhd]
    puts "Added VHD files from source directory to sources_1."
}

# Add VHD files from testbenches directory to sources_1
set testbench_dir "${origin_dir}/testbenches"
set files [glob -nocomplain -directory $testbench_dir *.vhd]
if {[llength $files] == 0} {
    puts "WARNING: No VHD files found in the testbenches directory '$testbench_dir'."
} else {
    # Copy files to sources_1 directory before adding them
    foreach file $files {
        file copy -force $file [file join $sources_1_dir [file tail $file]]
    }
    add_files -norecurse -fileset $obj [glob -nocomplain -directory $sources_1_dir *.vhd]
    puts "Added VHD files from testbenches directory to sources_1."
}

# Optional: Set GCC path check (requires Vivado to be correctly set up to use this)
# This part will only print a message since Vivado Tcl doesn't support setting GCC paths directly
set gcc_path "C:/MinGW/bin/gcc.exe"
if {[file exists $gcc_path]} {
    puts "GCC found at: $gcc_path"
} else {
    puts "WARNING: GCC not found at the specified path: $gcc_path"
}

puts "All files added and properties set successfully."
