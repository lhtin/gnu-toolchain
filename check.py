#!python3

import argparse, subprocess, sys

parser = argparse.ArgumentParser(description='Check gcc testsuite result.')
parser.add_argument ("--golden_dir", type=str, required=True)
parser.add_argument ("--test_dir", type=str, required=True)
parser.add_argument ("--tool-list", nargs="+", default=["gcc", "g++", "gfortran", "objc"])

args = parser.parse_args()

cmd = '''
python3 ./check-single.py --golden_file {golden_dir}/{tool}/{tool}.sum --summary_file {test_dir}/{tool}/{tool}.sum
'''

has_fail = False

def run (cmd):
  global has_fail
  try:
    subprocess.run(cmd, check=True, shell=True, stderr=subprocess.STDOUT)
  except Exception:
    has_fail = True

for tool in args.tool_list:
  check_cmd = cmd.format (**{"golden_dir": args.golden_dir, "test_dir": args.test_dir, "tool": tool})
  print(check_cmd)
  run(check_cmd)

if has_fail:
  print("Finish with FAILED.")
  sys.exit (1)
