import sys
import xml.etree.ElementTree as ET

def parse_log_file(log_file_path):
    """Parse the simulation log file to extract test results."""
    test_results = []
    
    with open(log_file_path, 'r') as file:
        lines = file.readlines()
    
    for line in lines:
        if 'TEST' in line:
            parts = line.split()
            test_name = parts[1].strip("'")
            test_status = parts[2]
            test_results.append((test_name, test_status))
    
    return test_results

def create_junit_xml(test_results, output_file_path):
    """Create a JUnit XML report from test results."""
    testsuite = ET.Element('testsuite', name='Simulation Results', tests=str(len(test_results)))
    
    for test_name, status in test_results:
        testcase = ET.SubElement(testsuite, 'testcase', name=test_name)
        if status == 'FAILED':
            ET.SubElement(testcase, 'failure', message='Test failed')
    
    tree = ET.ElementTree(testsuite)
    with open(output_file_path, 'wb') as file:
        tree.write(file)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_to_junit_xml.py <log_file_path> <output_file_path>")
        sys.exit(1)

    log_file_path = sys.argv[1]
    output_file_path = sys.argv[2]

    test_results = parse_log_file(log_file_path)
    create_junit_xml(test_results, output_file_path)
    print(f"JUnit XML report created at {output_file_path}")
