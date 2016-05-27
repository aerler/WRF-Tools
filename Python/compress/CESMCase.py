#!/usr/bin/env python

import os, re, argparse
import os.path as osp
import xml.etree.ElementTree as etree

class CESMCase(object):
    """
    DESCRIPTION
    This class describes the details of a CESM case. Specifically, it
    contains as attributes the contents of the env_case.xml file of a given
    case.
    """
    def __init__(self, case):
        """
        ARGUMENTS
            case - name of the case
        """
        self.CESMHOME = "/home/p/peltier/dchandan/Models/cesm/"
        self.CASE     = case
        self.CASEROOT = osp.join("/project/p/peltier/dchandan/CESM_cases/", self.CASE)
        self.RESERVED = "/reserved1/p/peltier/dchandan/"
        self.SCRATCH  = "/scratch/p/peltier/dchandan"

        self.xmlattribs = []

        self.read_xml("env_case.xml")
        self.read_xml("env_conf.xml")
        self.read_xml("env_build.xml")
        self.read_xml("env_run.xml")
        self.read_xml("env_mach_pes.xml")


    def read_xml(self, xmlfile, verbose=False):
        """
        This function reads the env_case.xml file to populate itself with the
        details of the case.
        """
        if verbose:
            print("CESM_Case --> read_xml [{0}]".format(xmlfile))
            print("    >>>>>>>>>>>>>>>")
        tree  = etree.parse(osp.join(self.CASEROOT, xmlfile))
        root  = tree.getroot()

        for child in root:
            # Iterating over all the child tags under the root tag.
            # Each child tag has a 'id' and a 'value' attribute
            key   = child.attrib['id']
            value = child.attrib['value']

            self.xmlattribs.append(key)

            # Now i serach to see if there are any variables in the value
            # that need to be substituted for. The following re matches variables.
            # The while loop implies that all variables that need to be expanded
            # are expanded before proceeding further.
            b = re.search("[$]{1}[0-9A-Za-z_]*", value)
            while b is not None:
                var = b.group(0)  # Getting the name of the variable e.g. "$CCSMROOT"
                replacement = getattr(self, var.strip("$")) # This is the replacement value
                value = value.replace(var, replacement)
                if verbose: print("    Replacing {0} with {1}".format(var, replacement))
                b = re.search("[$]{1}[0-9A-Za-z_]*", value)
            setattr(self, key, value)
        if verbose: print("    <<<<<<<<<<<<<<<")


    def __str__(self):
        return "CESM_Case object \nConfiguration :: \n" + \
        "\n".join(["    {0} : {1}".format(x, getattr(self, x)) for x in self.xmlattribs])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('case', nargs=1, type=str, help='case name')
    args = parser.parse_args()


    case = CESMCase(args.case[0])
    print(case)
