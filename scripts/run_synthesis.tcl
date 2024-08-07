# Define the path to the project file
set proj_file "C:/ProgramData/Jenkins/.jenkins/workspace/ART_QTMP/QTMP_VCU.xpr"

# Open the Vivado project
if {[file exists $proj_file]} {
    open_project $proj_file
    puts "Opened project: $proj_file"
} else {
    puts "ERROR: Project file '$proj_file' does not exist."
    exit 1
}

# Define the run name and CPU count
set run_name synth_1
set cpu_count 4

# Reset previous runs
reset_runs $run_name

# Launch synthesis run with specified CPU count
launch_runs $run_name -jobs $cpu_count
puts "Synthesis run launched with $cpu_count jobs."

# Wait for the synthesis run to complete
wait_on_run $run_name

# Check the status of the synthesis run
set status [get_property STATUS [get_runs $run_name]]
if {$status != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed with status '$status'."
    exit 1
}

# Exit successfully if synthesis completed
puts "Synthesis completed successfully."
exit 0
