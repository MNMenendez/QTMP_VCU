import os
import sys
import xml.etree.ElementTree as ET

def convert_to_junit(testbench_dir, output_file):
    # Create a basic JUnit XML structure
    testsuites = ET.Element('testsuites')
    testsuite = ET.SubElement(testsuites, 'testsuite', name='Vivado Test Suite')

    # List all VHDL test files in the testbench directory
    test_files = [f for f in os.listdir(testbench_dir) if f.endswith('.vhd')]

    for test_file in test_files:
        testcase_name = os.path.splitext(test_file)[0]
        testcase = ET.SubElement(testsuite, 'testcase', name=testcase_name, classname='vivado_sim')

        # Read the log file corresponding to this test case
        log_file = os.path.join(testbench_dir, f"{testcase_name}.log")
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                lines = f.readlines()
            ET.SubElement(testcase, 'system-out').text = ''.join(lines)
        else:
            # If no log file is found, add a failure element
            ET.SubElement(testcase, 'failure', message='Log file not found')

    # Write to output XML file
    tree = ET.ElementTree(testsuites)
    tree.write(output_file, encoding='utf-8', xml_declaration=True)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_to_junit_xml.py <testbench_directory> <output_file>")
        sys.exit(1)

    testbench_dir = sys.argv[1]
    output_file = sys.argv[2]
    convert_to_junit(testbench_dir, output_file)
