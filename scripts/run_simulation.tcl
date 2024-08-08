# Define the path to the GCC directory
set gcc_path "C:/Xilinx/Vivado/2024.1/tps/mingw/9.3.0/win64.o/nt/bin"

# Update the PATH environment variable to include the GCC directory
set env(PATH) "${gcc_path};$env(PATH)"

# Print the updated PATH for debugging
puts "Updated Environment PATH: $env(PATH)"

# Path to the Vivado project file
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"

# Simulation fileset
set sim_fileset "sim_1"

# Check if the project file exists and open it
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Check if the simulation fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top level for the simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Print a message indicating the simulation is starting
puts "Launching simulation..."

# Launch the simulation
launch_simulation -simset $sim_fileset
