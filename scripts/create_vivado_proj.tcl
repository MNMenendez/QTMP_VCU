# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Use origin directory path location variable, if specified in the tcl shell
if { [info exists ::origin_dir_loc] } {
  set origin_dir $::origin_dir_loc
}

# Set the project name
set _xil_proj_name_ "QTMP_VCU"

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

variable script_file
set script_file "create_vivado_proj.tcl"

# Help information for this script
proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Recreate a Vivado project from this script. The created project will be"
  puts "functionally equivalent to the original project for which this script was"
  puts "generated. The script contains commands for creating a project, filesets,"
  puts "runs, adding/importing sources and setting properties on various objects.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs [--origin_dir <path>]"
  puts "$script_file -tclargs [--project_name <name>]"
  puts "$script_file -tclargs [--help]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "[--origin_dir <path>]  Determine source file paths wrt this path. Default"
  puts "                       origin_dir path value is \".\", otherwise, the value"
  puts "                       that was set with the \"-paths_relative_to\" switch"
  puts "                       when this script was generated.\n"
  puts "[--project_name <name>] Create project with the specified name. Default"
  puts "                       name is the name of the project from where this"
  puts "                       script was generated.\n"
  puts "[--help]               Print help information for this script"
  puts "-------------------------------------------------------------------------\n"
  exit 0
}

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--origin_dir"   { incr i; set origin_dir [lindex $::argv $i] }
      "--project_name" { incr i; set _xil_proj_name_ [lindex $::argv $i] }
      "--help"         { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"

# Create project
create_project ${_xil_proj_name_} -part xc7z020clg484-1

# Check if project creation was successful
if {[catch {get_property directory [current_project]} proj_dir]} {
    puts "ERROR: Unable to get the project directory."
    exit 1
}

# Set project properties
set obj [current_project]

# Ensure only one instance of each property is set
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
puts "Project '${_xil_proj_name_}' created successfully."

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

# Add all VHD files from 'source' folder
set source_dir "${orig_proj_dir}/source"
set files [glob -nocomplain -directory $source_dir *.vhd]
if {[llength $files] == 0} {
    puts "WARNING: No VHD files found in the source directory '$source_dir'."
} else {
    add_files -norecurse -fileset $obj $files
    puts "Added VHD files from source directory."
}

# Debug: Output the list of files and their objects
foreach file $files {
    set file_name [file tail $file]
    puts "Processing file: $file_name"
    set file_obj [get_files -of_objects $obj $file_name]
    if {[llength $file_obj] == 0} {
        puts "WARNING: No file objects found for '$file_name'."
    } else {
        foreach obj $file_obj {
            set_property -name "file_type" -value "VHDL" -objects $obj
            puts "Set property 'file_type' to 'VHDL' for '$file_name'."
        }
    }
}

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]
puts "Constraints fileset 'constrs_1' created."

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]

# Add all VHD files from 'testbenches' folder
set testbench_dir "${orig_proj_dir}/testbenches"
set files [glob -nocomplain -directory $testbench_dir *.vhd]
if {[llength $files] == 0} {
    puts "WARNING: No VHD files found in the testbenches directory '$testbench_dir'."
} else {
    add_files -norecurse -fileset $obj $files
    puts "Added VHD files from testbenches directory."
}

# Debug: Output the list of files and their objects
foreach file $files {
    set file_name [file tail $file]
    puts "Processing file: $file_name"
    set file_obj [get_files -of_objects $obj $file_name]
    if {[llength $file_obj] == 0} {
        puts "WARNING: No file objects found for '$file_name'."
    } else {
        foreach obj $file_obj {
            set_property -name "file_type" -value "VHDL" -objects $obj
            puts "Set property 'file_type' to 'VHDL' for '$file_name'."
        }
    }
}

# Debug message to indicate completion
puts "All files added and properties set successfully."

# End of script
