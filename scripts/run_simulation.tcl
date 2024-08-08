# Define the project file path
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"

# Check if the project file exists
if {[file exists $proj_file]} {
    # Open the project
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Check if the project is writable
if {[catch {file writable $proj_file} writable_status] && !$writable_status} {
    puts "ERROR: Project '$proj_file' is read-only. Please change the project properties to make it writable."
    exit 1
}

# Define the simulation fileset name
set sim_fileset "sim_1"

# Check if the simulation fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Run the simulation
launch_simulation -simset $sim_fileset
puts "Simulation launched successfully."

# Exit Vivado
exit
