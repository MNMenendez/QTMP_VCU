import sys
import xml.etree.ElementTree as ET

def parse_simulation_results(xml_file_path):
    """Parse the simulation results XML file to extract test results."""
    test_results = []
    try:
        tree = ET.parse(xml_file_path)
        root = tree.getroot()
        for testcase in root.findall('testcase'):
            test_name = testcase.get('name')
            module = testcase.get('module', 'unknown')
            status = testcase.get('status', 'FAILED')
            if status == 'PASSED':
                status = 'passed'
            elif status == 'SKIPPED':
                status = 'skipped'
            else:
                status = 'failed'
            test_results.append((test_name, module, status))
    except Exception as e:
        print(f"Error parsing XML file: {e}")
    return test_results

def create_junit_xml(test_results, output_file_path):
    """Create a JUnit XML report from test results, grouping by module."""
    testsuites = ET.Element('testsuites', name='MyTestSuitesName')  # Change this name to what you want
    modules = {}
    for test_name, module, status in test_results:
        if module not in modules:
            modules[module] = ET.SubElement(testsuites, 'testsuite', name=module)
        testcase = ET.SubElement(modules[module], 'testcase', name=test_name)
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
