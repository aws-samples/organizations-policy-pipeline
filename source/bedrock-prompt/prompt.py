# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import os
import boto3
import json
import sys
from botocore.config import Config

inference_profile = os.getenv(
    "INFERENCE_PROFILE", "global.anthropic.claude-sonnet-4-5-20250929-v1:0"
)

try:
    model_id = json.loads(inference_profile)
except json.JSONDecodeError:
    model_id = inference_profile

# Newer Claude models (Sonnet 5, Opus 5 and later) think by default, and maxTokens
# caps thinking + answer together. Keep headroom so the summary isn't cut off.
MAX_TOKENS = 16000

# AWS recommends a read timeout of at least 60 minutes for Claude inference calls
# (the botocore default is 60 seconds, which long thinking can exceed).
READ_TIMEOUT_SECONDS = 3600


def load_prompt():
    with open("../bedrock-prompt/prompt.txt", "r") as file:
        return file.read()


def concatenate_logs():
    parent_dir = "."
    concatenated_logs = ""
    log_files = ["scp.log", "rcp.log", "tf.log"]

    for log_file in log_files:
        file_path = os.path.join(parent_dir, log_file)
        if os.path.exists(file_path):
            with open(file_path, "r") as file:
                concatenated_logs += file.read() + "\n\n"
        else:
            print(f"Warning: {log_file} not found in the parent directory.")
            sys.exit(1)

    return concatenated_logs


def query_bedrock(prompt):
    bedrock = boto3.client(
        service_name="bedrock-runtime",
        config=Config(read_timeout=READ_TIMEOUT_SECONDS),
    )

    # Converse API: one request/response format for every Bedrock model.
    # Sampling parameters (temperature, top_p, top_k) are intentionally omitted:
    # Claude Opus 4.7 and newer models reject them with
    # "ValidationException: `temperature` is deprecated for this model."
    response = bedrock.converse_stream(
        modelId=model_id,
        messages=[{"role": "user", "content": [{"text": prompt}]}],
        inferenceConfig={"maxTokens": MAX_TOKENS},
    )

    full_response = ""
    stop_reason = None
    for event in response["stream"]:
        if "contentBlockDelta" in event:
            # Keep only the answer text; reasoning (thinking) deltas are skipped.
            full_response += event["contentBlockDelta"]["delta"].get("text", "")
        elif "messageStop" in event:
            stop_reason = event["messageStop"].get("stopReason")

    if stop_reason not in ("end_turn", "stop_sequence"):
        print(
            f"Warning: model stopped with reason '{stop_reason}'. The summary may be incomplete."
        )

    return full_response


# Main execution
prompt = load_prompt()
pipeline_logs = concatenate_logs()
prompt += pipeline_logs
prompt += "\n</Pipeline Logs>"

response = query_bedrock(prompt)

print("####################################")
print("######## Gen AI Log Summary #######")
print("####################################")
print()
print()
print(response)

with open("summary.txt", "w") as file:
    file.write(response)
