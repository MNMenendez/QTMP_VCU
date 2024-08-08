# Path to the Vivado project file
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"

# Check if the project file exists
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Check if the project is read-only
if {[file writable $proj_file] == 0} {
    puts "ERROR: Project '$proj_file' is read-only. Please change the project properties to make it writable."
    exit 1
}

# Define simulation fileset
set sim_fileset "sim_1"

# Check if the simulation fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for the simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Additional simulation setup or commands can be added here
