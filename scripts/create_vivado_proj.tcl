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

# Define source directories
set sources_1_dir "${proj_folder}/sources_1"
set sim_1_dir "${proj_folder}/sim_1"

# Create directories if they don't exist
if {[file isdirectory $sources_1_dir] == 0} {
    file mkdir $sources_1_dir
    puts "Created sources_1 directory at '$sources_1_dir'."
}

if {[file isdirectory $sim_1_dir] == 0} {
    file mkdir $sim_1_dir
    puts "Created sim_1 directory at '$sim_1_dir'."
}

# Helper procedure to check if a file is already in the project
proc is_file_in_project {filename} {
    # Get a list of all files in the project
    set all_files [get_files]
    foreach file $all_files {
        if {[file tail $file] eq $filename} {
            return 1
        }
    }
    return 0
}

# Add design files to sources_1
set source_dir "${origin_dir}/source"
set files [glob -nocomplain -directory $source_dir *.vhd]
foreach file $files {
    set filename [file tail $file]
    if {[is_file_in_project $filename] == 0} {
        file copy -force $file [file join $sources_1_dir $filename]
        add_files -fileset sources_1 [file join $sources_1_dir $filename]
        puts "Added VHD file '$file' to sources_1."
    } else {
        puts "File '$file' already exists in the project, skipping addition."
    }
}

# Add testbench files to sim_1
set testbench_dir "${origin_dir}/testbenches"
set files [glob -nocomplain -directory $testbench_dir *.vhd]
foreach file $files {
    set filename [file tail $file]
    if {[is_file_in_project $filename] == 0} {
        file copy -force $file [file join $sim_1_dir $filename]
        add_files -fileset sim_1 [file join $sim_1_dir $filename]
        puts "Added VHD file '$file' from testbenches to sim_1."
    } else {
        puts "File '$file' from testbenches already exists in the project, skipping addition."
    }
}

puts "Project setup completed."
