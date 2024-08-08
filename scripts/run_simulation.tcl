# Open the existing project
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Set the simulation fileset
set sim_fileset "sim_1"
if {[llength [get_filesets $sim_fileset]] == 0} {
    puts "ERROR: Fileset '$sim_fileset' does not exist."
    exit 1
}

# Set the top module for simulation
set_property top hcmt_cpld_top [get_filesets $sim_fileset]

# Configure simulation settings to generate detailed logs
# (Use verbose flags and additional options as needed)
launch_simulation -simset $sim_fileset -verbose -log "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/simulation.log"

# Run the simulation with specific duration
run 1000ns

# Optionally, you can specify further configuration or additional scripts here
