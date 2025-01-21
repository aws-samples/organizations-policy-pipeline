# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import os
import boto3
import json
import sys

def load_prompt():
    with open('../bedrock-prompt/prompt.txt', 'r') as file:
        return file.read()

def concatenate_logs():
    parent_dir = "."
    concatenated_logs = ""
    log_files = ["scp.log", "tf.log"]
    
    for log_file in log_files:
        file_path = os.path.join(parent_dir, log_file)
        if os.path.exists(file_path):
            with open(file_path, 'r') as file:
                concatenated_logs += file.read() + "\n\n"
        else:
            print(f"Warning: {log_file} not found in the parent directory.")
            sys.exit(1)
    
    return concatenated_logs
def query_bedrock(prompt):
    bedrock = boto3.client(service_name='bedrock-runtime')
    
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4096,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
        "temperature": 0
    })
    
    modelId = 'anthropic.claude-3-5-sonnet-20240620-v1:0'
    accept = 'application/json'
    contentType = 'application/json'

    response = bedrock.invoke_model(body=body, modelId=modelId, accept=accept, contentType=contentType)
    response_body = json.loads(response.get('body').read())
    
    return response_body['content'][0]['text']


# Main execution
prompt = load_prompt()
pipeline_logs = concatenate_logs()
prompt += pipeline_logs
prompt += "\n</Pipeline Logs>"
prompt += "Assistant:"

response = query_bedrock(prompt)

print("####################################")
print("######## Gen IA Log Summary  #######")
print("####################################")
print()
print()
print(response)

with open('summary.txt', 'w') as file:
    file.write(response)