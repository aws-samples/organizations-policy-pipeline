# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import os
import sys
from  utils import mergeandoptimize
import logging

# Create a logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
logger.propagate = False

# Create handlers
file_handler = logging.FileHandler('rcp.log')
console_handler = logging.StreamHandler()

# Set logging levels for handlers
file_handler.setLevel(logging.INFO)
console_handler.setLevel(logging.INFO)

# Create formatters and add it to handlers
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
file_handler.setFormatter(formatter)
console_handler.setFormatter(formatter)

# Add handlers to the logger
logger.addHandler(file_handler)
logger.addHandler(console_handler)


# Files and folders
RCP_MANAGEMENT_FILE_NAME = "rcp-management.json"
RCP_MANAGEMENT_FILE_PATH = os.getcwd() + "/../../" + "rcp-management/" + RCP_MANAGEMENT_FILE_NAME

ENVIRONMENT_FILE_NAME = "environments.json"
ENVIRONMENT_FILE_PATH = os.getcwd() + "/../../environments/" + ENVIRONMENT_FILE_NAME

GUARDRAIL_FOLDER = os.getcwd() + "/../../" + "rcp-management/guardrails/"
POLICY_FOLDER = os.getcwd() + "/../../" + "rcp-management/policies/"

def main():
    print("#################################")
    print("# Starting RCP Policy Processor #")
    print("#################################\n")
    # Load content from RCP management file
    rcps = []
    with open(RCP_MANAGEMENT_FILE_PATH, 'r') as f:
        data = json.load(f)

    with open(ENVIRONMENT_FILE_PATH, 'r') as g:
        environment_ou_list = json.load(g)


    # Validate if "SID" field are unique
    sid_set = set()
    for item in data:
        sid = item.get("SID")
        if sid in sid_set:
            logger.error(f"[!] SIDs are not unique. Please, review {RCP_MANAGEMENT_FILE_NAME} file.")
            sys.exit(1)
        sid_set.add(sid)
    logger.info("SIDs are unique")


    # Create rcps.json file for import in Terraform
    for statement in data:
        if statement == {}:
            logger.error(f"[!] Empty statement found. Please, review {RCP_MANAGEMENT_FILE_NAME} file.")
            sys.exit(1)
        logger.info("[*] Processing statement ID: " + str(statement['SID']))
        rcp_statement = {}
        
        # Checks if statement is using GUARDRAIL or POLICY
        if statement["Guardrails"] != []:
            logging.info("Guardrails are being used, not policy")
            optmized_policy = mergeandoptimize.mergeguardrails(statement['Guardrails'], GUARDRAIL_FOLDER)
        elif statement["Policy"] != "":
            logging.info("Policy is being used, not guardrails")
            with open(POLICY_FOLDER + str(statement["Policy"]) + ".json", 'r') as h:
                optmized_policy = json.load(h)
        else:
            logging.error("[!] No policy or guardrails found for statement ID: " + str(statement['SID']))
            sys.exit(1)

        # Checks the target Type
        if statement['Target']['Type'] == "Account" or statement['Target']['Type'] == "OU":
            logging.info(f"Target type is {statement['Target']['Type']}")
            rcp_statement['target_id'] = statement['Target']['ID'].split(":")[1]
            rcp_statement['sid'] = statement['SID']
            rcp_statement['policy'] = optmized_policy
            rcps.append(rcp_statement.copy())
        elif statement['Target']['Type'] == "Environment":
            logging.info(f"Target type is {statement['Target']['Type']}")
            targets = []
            for environment in environment_ou_list:
                if environment["ID"] == statement['Target']['ID']:
                    logging.info(f'Environment ID found: {environment["ID"]}')
                    targets = environment["Target"].copy()
                
            if targets == []:
                logging.error(f"Environment ID not found for SID {statement['SID']}: {statement['Target']['ID']}")
                sys.exit(1)
                    
            logging.info(f"The environment {statement['Target']['Type']} has the following targets: {targets}")
            for each_target in targets:
                rcp_statement['target_id'] = each_target.split(":")[1]
                rcp_statement['policy'] = optmized_policy
                rcp_statement['sid'] = statement['SID']
                rcps.append(rcp_statement.copy())
        else:
            logging.error("[!] Invalid Target Type: " + str(statement['Target']['Type']))
            sys.exit(1)
                
        print()
    with open('../terraform/rcps.json', 'w') as o:
        json.dump(rcps, o)
main()