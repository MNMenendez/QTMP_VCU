# Define paths
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"
set sim_fileset "sim_1"

# Open project
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Check if the fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Set environment variable for GCC path
set env(PATH) "C:/MinGW/bin;$env(PATH)"

# Print the environment variable to confirm it's set
puts "Environment PATH: $env(PATH)"

# Launch simulation
puts "Launching simulation..."
launch_simulation -simset $sim_fileset
