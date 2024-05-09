import subprocess

import boto3
import sys, getopt
import os
import json

def init(upgrade=''):
  subprocess.run(f"terraform init {upgrade}", check=True, shell=True)

def get_accounts():
  organizations = boto3.client('organizations')
  paginator = organizations.get_paginator("list_accounts")

  return [
        account["Id"]
        for page in paginator.paginate()
        for account in page["Accounts"]
  ]

def get_master_account_id():
  organizations = boto3.client('organizations')
  orgInfo = organizations.describe_organization()
  return orgInfo['Organization']['MasterAccountId']

def workspace_exists(workspace_name):
  completed_process = subprocess.run(f"terraform workspace list | grep {workspace_name}", shell=True)
  return completed_process.returncode == 0

def create_workspace(workspace_name):
  subprocess.run(f"terraform workspace new {workspace_name}", check=True, shell=True)

def switch_to_workspace(workspace_name):
  subprocess.run(f"terraform workspace select {workspace_name}", check=True, shell=True)

def plan(account, plan_file, tfvarsfile, opttfvars='', region=''):
  optional_var_file = f"-var-file={opttfvars}" if opttfvars != '' else ''
  optional_region = f"-var target_aws_account_region={region}" if region != '' else ''
  print("Going to execute plan")
  runcmd = f"terraform plan -var target_account_id={account} {optional_region} -var-file={tfvarsfile} {optional_var_file} -out={plan_file}"
  print(runcmd)
  subprocess.run(runcmd, check=True, shell=True)

def apply(plan_file):
  subprocess.run(f"terraform apply {plan_file}", check=True, shell=True)

def save_output(filename, filenamejson):
  subprocess.run(f"terraform output > {filename}", check=True, shell=True)
  subprocess.run(f"terraform output -json> {filenamejson}", check=True, shell=True)

def get_scope_regions(filename):
  f = open(filename)
  data = json.load(f)
  scope_regions = data['scope_regions']["value"].split(',')
  f.close()
  return scope_regions

def run(argv):
  opts, args = getopt.getopt(argv,"hi:o:c:u",["core-var-file=",'org-var-file=',"upgrade"])
  corepath = './core-deployment'
  corevarsfile = ''
  coreoutputfile = 'core-deployment-output.tfvars'
  coreoutputfilejson = 'core-deployment-output.json'
  orgvarsfile = ''
  upgrade = ''

  for opt, arg in opts:
      if opt == '-h':
         print ('tfstacks.py --var-file=<tfvars-file>')
         sys.exit()
      elif opt in ("-c", "--core-var-file"):
         print ("Looking for core vars file")
         corevarsfile = arg
         print (corevarsfile)
      elif opt in ("-o", "--org-var-file"):
         orgvarsfile = arg
      elif opt in ("-u", "--upgrade"):
         upgrade = '--upgrade'
  

  os.chdir('./core-deployment')
  if not workspace_exists("core-deployment"):
    create_workspace("core-deployment")
  switch_to_workspace("core-deployment")
  init(upgrade)
  primaryAccountId = get_master_account_id()
  plan_file = f"{primaryAccountId}.plan"
  plan(primaryAccountId, plan_file, corevarsfile)
  apply(plan_file)
  save_output(coreoutputfile, coreoutputfilejson)

  os.chdir('..')
  os.chdir('./organizational-deployment')

  for account in get_accounts():
    scope_regions = get_scope_regions(os.path.normpath(f"../{corepath}/{coreoutputfilejson}"))
    for region in scope_regions:
      print(f"Working on workspace {account}-{region}")
      workspace_name = f"{account}-{region}"
      if not workspace_exists(workspace_name):
        create_workspace(workspace_name)
      switch_to_workspace(workspace_name)
      init(upgrade)
      plan_file = f"{account}-{region}.plan"
      plan(account, plan_file, orgvarsfile, os.path.normpath(f"../{corepath}/{coreoutputfile}"), region)
      apply(plan_file)

if __name__ == "__main__":
  run(sys.argv[1:])