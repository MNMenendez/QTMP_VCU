# Define the project file and fileset
set proj_folder "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU"
set proj_file [file normalize "${proj_folder}/QTMP_VCU.xpr"]
set sim_fileset "sim_1"

# Check if the project file exists and open the project
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Set GCC path and update the PATH environment variable
set gcc_path "C:/Xilinx/Vivado/2024.1/tps/mingw/9.3.0/win64.o/nt/bin"
set env(PATH) "${gcc_path};$env(PATH)"
puts "Updated Environment PATH: $env(PATH)"

# Check if the fileset exists
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Launch the simulation
puts "Launching simulation..."
launch_simulation -simset $sim_fileset
