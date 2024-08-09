import sys
import xml.etree.ElementTree as ET
import re

def parse_simulation_results(xml_file_path):
    """Parse the simulation results XML file to extract test results and architecture information."""
    test_results = []

    try:
        tree = ET.parse(xml_file_path)
        root = tree.getroot()

        for testcase in root.findall('testcase'):
            test_name = testcase.get('name')
            status = testcase.get('status', 'FAILED')
            
            # Extract architecture from the test name or other relevant attributes
            architecture = extract_architecture(test_name)
            
            # Append results with architecture information
            if status == 'PASSED':
                status = 'passed'
            elif status == 'SKIPPED':
                status = 'skipped'
            else:
                status = 'failed'
            test_results.append((test_name, architecture, status))
    except Exception as e:
        print(f"Error parsing XML file: {e}")
    
    return test_results

def extract_architecture(test_name):
    """Extract architecture name from the test name."""
    # Example extraction logic; adjust the regex or logic based on your specific naming convention
    match = re.search(r'OF\s+(\w+)\s+IS', test_name, re.IGNORECASE)
    return match.group(1) if match else 'unknown'

def create_junit_xml(test_results, output_file_path):
    """Create a JUnit XML report from test results, grouping by architecture."""
    # Create the root element for the JUnit XML report
    testsuites = ET.Element('testsuites')

    # Group results by architecture
    architectures = {}
    for test_name, architecture, status in test_results:
        if architecture not in architectures:
            architectures[architecture] = ET.SubElement(testsuites, 'testsuite', name=architecture)
        
        testcase = ET.SubElement(architectures[architecture], 'testcase', name=test_name, module=architecture, status=status)
        if status == 'failed':
            ET.SubElement(testcase, 'failure', message='Test failed')
        elif status == 'skipped':
            ET.SubElement(testcase, 'skipped')
    
    tree = ET.ElementTree(testsuites)
    try:
        with open(output_file_path, 'wb') as file:
            tree.write(file, encoding='utf-8', xml_declaration=True)
    except Exception as e:
        print(f"Error writing JUnit XML file: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_to_junit_xml.py <simulation_results_xml_path> <output_file_path>")
        sys.exit(1)

    xml_file_path = sys.argv[1]
    output_file_path = sys.argv[2]

    test_results = parse_simulation_results(xml_file_path)
    create_junit_xml(test_results, output_file_path)
    print(f"JUnit XML report created at {output_file_path}")
