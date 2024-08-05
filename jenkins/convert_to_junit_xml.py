import sys
import xml.etree.ElementTree as ET

def convert_to_junit(log_file, output_file):
    # Create a basic JUnit XML structure
    testsuites = ET.Element('testsuites')
    testsuite = ET.SubElement(testsuites, 'testsuite', name='ModelSim Test Suite', tests='1', failures='0')

    with open(log_file, 'r') as f:
        lines = f.readlines()

    # Add test case based on log content (simplified)
    testcase = ET.SubElement(testsuite, 'testcase', name='TestCase', classname='model_sim')
    ET.SubElement(testcase, 'system-out').text = ''.join(lines)

    tree = ET.ElementTree(testsuites)
    tree.write(output_file, encoding='utf-8', xml_declaration=True)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_to_junit_xml.py <log_file> <output_file>")
        sys.exit(1)

    log_file = sys.argv[1]
    output_file = sys.argv[2]
    convert_to_junit(log_file, output_file)
