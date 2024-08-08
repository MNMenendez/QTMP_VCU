import sys
import os
import xml.etree.ElementTree as ET

def convert_to_junit(log_file, output_file):
    # Create a basic JUnit XML structure
    testsuites = ET.Element('testsuites')
    testsuite = ET.SubElement(testsuites, 'testsuite', name='Vivado Test Suite', tests='0', failures='0')

    if not os.path.isfile(log_file):
        raise FileNotFoundError(f"Log file {log_file} does not exist.")

    with open(log_file, 'r') as f:
        lines = f.readlines()

    # Simple parsing logic to count failures and tests
    num_failures = sum(1 for line in lines if 'Failure' in line)
    num_tests = sum(1 for line in lines if 'Test' in line)  # Update this based on log content

    # Update testsuite attributes
    testsuite.set('tests', str(num_tests))
    testsuite.set('failures', str(num_failures))

    # Create a single test case
    testcase = ET.SubElement(testsuite, 'testcase', name='TestCase', classname='vivado_simulation')

    if num_failures > 0:
        # If there are failures, add a failure element
        ET.SubElement(testcase, 'failure', message='Test failed').text = ''.join(lines)
    else:
        # If there are no failures, add a system-out element
        ET.SubElement(testcase, 'system-out').text = ''.join(lines)

    # Write the XML to the output file
    tree = ET.ElementTree(testsuites)
    tree.write(output_file, encoding='utf-8', xml_declaration=True)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_to_junit_xml.py <log_file> <output_file>")
        sys.exit(1)

    log_file = sys.argv[1]
    output_file = sys.argv[2]
    convert_to_junit(log_file, output_file)
