import sys
import xml.etree.ElementTree as ET

def parse_simulation_results(xml_file_path):
    """Parse the simulation results XML file to extract test results."""
    test_results = []

    try:
        tree = ET.parse(xml_file_path)
        root = tree.getroot()

        # Ensure the root element is 'testsuites'
        if root.tag != 'testsuites':
            raise ValueError("Root element must be 'testsuites'")

        for testcase in root.findall('testcase'):
            test_name = testcase.get('name')
            status = testcase.get('status', 'FAILED')
            if status == 'FAILED':
                status = 'failed'
            elif status == 'PASSED':
                status = 'passed'
            else:
                status = 'skipped'
            test_results.append((test_name, status))
    except Exception as e:
        print(f"Error parsing XML file: {e}")
    
    return test_results

def create_junit_xml(test_results, output_file_path):
    """Create a JUnit XML report from test results."""
    testsuite = ET.Element('testsuite', name='Simulation Results', tests=str(len(test_results)))
    
    for test_name, status in test_results:
        testcase = ET.SubElement(testsuite, 'testcase', name=test_name)
        if status == 'failed':
            ET.SubElement(testcase, 'failure', message='Test failed')
        elif status == 'skipped':
            ET.SubElement(testcase, 'skipped')
    
    tree = ET.ElementTree(testsuite)
    with open(output_file_path, 'wb') as file:
        tree.write(file)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_to_junit_xml.py <xml_file_path> <output_file_path>")
        sys.exit(1)

    xml_file_path = sys.argv[1]
    output_file_path = sys.argv[2]

    test_results = parse_simulation_results(xml_file_path)
    create_junit_xml(test_results, output_file_path)
    print(f"JUnit XML report created at {output_file_path}")
