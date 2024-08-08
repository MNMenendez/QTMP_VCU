# Define project name and directories
set origin_dir "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP"
set _xil_proj_name_ "QTMP_VCU"
set proj_file "[file normalize "${origin_dir}/${_xil_proj_name_}.xpr"]"

# Delete existing project files if they exist
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

# Create the project
create_project ${_xil_proj_name_} -part xc7z020clg484-1 -force
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
puts "Project '${_xil_proj_name_}' created successfully."

# Define source directories
set sources_1_dir "${origin_dir}/QTMP_VCU.gen/sources_1"
if {[file isdirectory $sources_1_dir] == 0} {
    file mkdir $sources_1_dir
    puts "Created sources_1 directory at '$sources_1_dir'."
}

# Add files to sources_1
set source_dir "${origin_dir}/source"
set files [glob -nocomplain -directory $source_dir *.vhd]
foreach file $files {
    set filename [file tail $file]
    if {[llength [get_files -file $filename]] == 0} {
        file copy -force $file [file join $sources_1_dir $filename]
        add_files -norecurse [file join $sources_1_dir $filename]
        puts "Added VHD file '$file' to sources_1."
    } else {
        puts "File '$file' already exists in the project, skipping addition."
    }
}

# Add testbench files similarly
set testbench_dir "${origin_dir}/testbenches"
set files [glob -nocomplain -directory $testbench_dir *.vhd]
foreach file $files {
    set filename [file tail $file]
    if {[llength [get_files -file $filename]] == 0} {
        file copy -force $file [file join $sources_1_dir $filename]
        add_files -norecurse [file join $sources_1_dir $filename]
        puts "Added VHD file '$file' from testbenches to sources_1."
    } else {
        puts "File '$file' from testbenches already exists in the project, skipping addition."
    }
}
