#!/bin/bash
# ============================================================
# inject-portal26-otel.sh
#
# Injects portal26 OTEL environment variables into an already
# deployed AgentCore agent runtime.
#
# Run this from your agent directory — the directory that
# contains your .bedrock_agentcore.yaml file.
#
# What this script does:
#   1. Reads your agent runtime details from .bedrock_agentcore.yaml
#   2. Reads OTEL config from otel_config.py in the same directory
#   3. Fetches current environment variables from your runtime
#   4. Warns if any portal26 OTEL vars already exist (will overwrite)
#   5. Merges portal26 OTEL vars on top of your existing vars
#   6. Updates the runtime with the merged set
#   7. Prints final env vars on runtime to confirm
#
# Your existing environment variables are never removed.
# Only portal26 OTEL keys are added or overwritten.
#
# Usage:
#   cd <your-agent-directory>
#   ./inject-portal26-otel.sh <aws-profile>
#
# Example:
#   cd ~/myproject/agents/myagent
#   ./inject-portal26-otel.sh my-aws-profile
# ============================================================
set -e

# -- Validate arguments ---------------------------------------
if [ -z "$1" ]; then
  echo "ERROR - Missing AWS profile argument."
  echo "Usage: ./inject-portal26-otel.sh <aws-profile>"
  exit 1
fi

AWS_PROFILE="$1"

# -- Validate AWS profile exists ------------------------------
if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
  echo "ERROR - AWS profile '$AWS_PROFILE' not found in ~/.aws/config"
  echo "  Available profiles:"
  aws configure list-profiles 2>/dev/null | sed 's/^/    /'
  exit 1
fi

# -- Validate AWS profile has connectivity --------------------
echo "Validating AWS profile '$AWS_PROFILE'..."
CALLER_IDENTITY=$(AWS_PROFILE="$AWS_PROFILE" aws sts get-caller-identity --output json 2>&1)
if [ $? -ne 0 ]; then
  echo "ERROR - AWS profile '$AWS_PROFILE' failed connectivity check:"
  echo "  $CALLER_IDENTITY"
  echo "  Check your credentials or VPN."
  exit 1
fi
CALLER_ACCOUNT=$(echo "$CALLER_IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])")
CALLER_ARN=$(echo "$CALLER_IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Arn'])")
echo "OK - Account : $CALLER_ACCOUNT"
echo "OK - Identity: $CALLER_ARN"

# -- Validate config file exists ------------------------------
CONFIG_FILE=".bedrock_agentcore.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR - .bedrock_agentcore.yaml not found in current directory."
  echo "  Please run this script from your agent directory."
  echo "  Example: cd ~/myproject/agents/myagent && ./inject-portal26-otel.sh <aws-profile>"
  exit 1
fi

# -- Read agent name from yaml --------------------------------
AGENT_NAME=$(python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    config = yaml.safe_load(f)
print(config.get('default_agent', ''))
")

if [ -z "$AGENT_NAME" ]; then
  echo "ERROR - Could not read agent name from $CONFIG_FILE"
  exit 1
fi

# -- Read region from yaml ------------------------------------
REGION=$(python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    config = yaml.safe_load(f)
agents = config.get('agents', {})
agent = agents.get('$AGENT_NAME', {})
print(agent.get('aws', {}).get('region', 'us-east-1'))
")

# -- Read runtime ID from yaml --------------------------------
AGENT_ARN=$(python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    config = yaml.safe_load(f)
agents = config.get('agents', {})
agent = agents.get('$AGENT_NAME', {})
arn = agent.get('agent_arn', '') or agent.get('bedrock_agentcore', {}).get('agent_arn', '')
print(arn)
")

if [ -z "$AGENT_ARN" ]; then
  echo "ERROR - Could not read agent_arn from $CONFIG_FILE"
  echo "  Make sure your agent has been deployed at least once."
  exit 1
fi

RUNTIME_ID="${AGENT_ARN##*/}"

echo ""
echo "================================================"
echo "Agent name  : $AGENT_NAME"
echo "Runtime ID  : $RUNTIME_ID"
echo "Region      : $REGION"
echo "AWS profile : $AWS_PROFILE"
echo "================================================"
echo ""

# -- Validate otel_config.py exists and is cloud mode ---------
OTEL_CONFIG_FILE="otel_config.py"
if [ ! -f "$OTEL_CONFIG_FILE" ]; then
  echo "ERROR - otel_config.py not found in current directory."
  echo "  This file should have been provided by portal26."
  exit 1
fi

OTEL_MODE=$(python3 -c "
import sys
sys.path.insert(0, '.')
from otel_config import OTEL_MODE
print(OTEL_MODE)
")

if [ "$OTEL_MODE" != "cloud" ]; then
  echo "ERROR - otel_config.py has OTEL_MODE = \"$OTEL_MODE\""
  echo "  Only OTEL_MODE = \"cloud\" is supported."
  exit 1
fi

# -- Read OTEL vars from otel_config.py -----------------------
echo "Reading portal26 OTEL config..."

read_otel_key() {
  python3 -c "
import sys; sys.path.insert(0, '.')
from otel_config import CLOUD_OTEL as C
print(C.get('$1', ''))"
}

OTLP_TRACES_ENDPOINT=$(read_otel_key OTEL_EXPORTER_OTLP_TRACES_ENDPOINT)
OTLP_TRACES_HEADERS=$(read_otel_key OTEL_EXPORTER_OTLP_TRACES_HEADERS)
OTLP_TRACES_PROTOCOL=$(read_otel_key OTEL_EXPORTER_OTLP_TRACES_PROTOCOL)
OTEL_TRACES_EXP=$(read_otel_key OTEL_TRACES_EXPORTER)
OTLP_LOGS_ENDPOINT=$(read_otel_key OTEL_EXPORTER_OTLP_LOGS_ENDPOINT)
OTLP_LOGS_HEADERS=$(read_otel_key OTEL_EXPORTER_OTLP_LOGS_HEADERS)
OTLP_LOGS_PROTOCOL=$(read_otel_key OTEL_EXPORTER_OTLP_LOGS_PROTOCOL)
OTEL_LOGS_EXP=$(read_otel_key OTEL_LOGS_EXPORTER)
OTLP_METRICS_ENDPOINT=$(read_otel_key OTEL_EXPORTER_OTLP_METRICS_ENDPOINT)
OTLP_METRICS_HEADERS=$(read_otel_key OTEL_EXPORTER_OTLP_METRICS_HEADERS)
OTLP_METRICS_PROTOCOL=$(read_otel_key OTEL_EXPORTER_OTLP_METRICS_PROTOCOL)
OTEL_METRICS_EXP=$(read_otel_key OTEL_METRICS_EXPORTER)
OTEL_RESOURCE_ATTRS=$(read_otel_key OTEL_RESOURCE_ATTRIBUTES)
OTEL_LOG_PROMPTS=$(read_otel_key OTEL_LOG_USER_PROMPTS)
OTEL_METRIC_INTERVAL=$(read_otel_key OTEL_METRIC_EXPORT_INTERVAL)
OTEL_LOGS_INTERVAL=$(read_otel_key OTEL_LOGS_EXPORT_INTERVAL)

# -- Validate required endpoints ------------------------------
if [ -z "$OTLP_TRACES_ENDPOINT" ] || [ -z "$OTLP_LOGS_ENDPOINT" ]; then
  echo "ERROR - otel_config.py is missing required keys:"
  echo "  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT : ${OTLP_TRACES_ENDPOINT:-<missing>}"
  echo "  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT   : ${OTLP_LOGS_ENDPOINT:-<missing>}"
  exit 1
fi

echo "OK - Traces  : $OTLP_TRACES_ENDPOINT"
echo "OK - Logs    : $OTLP_LOGS_ENDPOINT"
echo "OK - Metrics : ${OTLP_METRICS_ENDPOINT:-disabled}"

# -- Fetch full runtime details -------------------------------
echo ""
echo "Fetching current runtime details..."

RUNTIME_FULL_JSON=$(AWS_PROFILE="$AWS_PROFILE" aws bedrock-agentcore-control get-agent-runtime \
  --agent-runtime-id "$RUNTIME_ID" \
  --region "$REGION" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
  echo "ERROR - Could not fetch runtime details:"
  echo "  $RUNTIME_FULL_JSON"
  exit 1
fi

echo "OK - Runtime details fetched"

# -- Extract required fields for update call ------------------
ROLE_ARN=$(echo "$RUNTIME_FULL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['roleArn'])")
NETWORK_CONFIG=$(echo "$RUNTIME_FULL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['networkConfiguration']; print(json.dumps(d))")
AGENT_ARTIFACT=$(echo "$RUNTIME_FULL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['agentRuntimeArtifact']; print(json.dumps(d))")
CURRENT_ENV_JSON=$(echo "$RUNTIME_FULL_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(json.dumps(d.get('environmentVariables') or {}))
")

echo "OK - Current env vars extracted"

# -- Build portal26 OTEL vars map -----------------------------
declare -A OTEL_VARS
OTEL_VARS[OVERRIDE_AGENTCORE_ADOT_ENV_VARS]="true"
OTEL_VARS[OTEL_SERVICE_NAME]="$AGENT_NAME"
[ -n "$OTLP_TRACES_ENDPOINT" ]  && OTEL_VARS[OTEL_EXPORTER_OTLP_TRACES_ENDPOINT]="$OTLP_TRACES_ENDPOINT"
[ -n "$OTLP_TRACES_HEADERS" ]   && OTEL_VARS[OTEL_EXPORTER_OTLP_TRACES_HEADERS]="$OTLP_TRACES_HEADERS"
[ -n "$OTLP_TRACES_PROTOCOL" ]  && OTEL_VARS[OTEL_EXPORTER_OTLP_TRACES_PROTOCOL]="$OTLP_TRACES_PROTOCOL"
[ -n "$OTEL_TRACES_EXP" ]       && OTEL_VARS[OTEL_TRACES_EXPORTER]="$OTEL_TRACES_EXP"
[ -n "$OTLP_LOGS_ENDPOINT" ]    && OTEL_VARS[OTEL_EXPORTER_OTLP_LOGS_ENDPOINT]="$OTLP_LOGS_ENDPOINT"
[ -n "$OTLP_LOGS_HEADERS" ]     && OTEL_VARS[OTEL_EXPORTER_OTLP_LOGS_HEADERS]="$OTLP_LOGS_HEADERS"
[ -n "$OTLP_LOGS_PROTOCOL" ]    && OTEL_VARS[OTEL_EXPORTER_OTLP_LOGS_PROTOCOL]="$OTLP_LOGS_PROTOCOL"
[ -n "$OTEL_LOGS_EXP" ]         && OTEL_VARS[OTEL_LOGS_EXPORTER]="$OTEL_LOGS_EXP"
[ -n "$OTLP_METRICS_ENDPOINT" ] && OTEL_VARS[OTEL_EXPORTER_OTLP_METRICS_ENDPOINT]="$OTLP_METRICS_ENDPOINT"
[ -n "$OTLP_METRICS_HEADERS" ]  && OTEL_VARS[OTEL_EXPORTER_OTLP_METRICS_HEADERS]="$OTLP_METRICS_HEADERS"
[ -n "$OTLP_METRICS_PROTOCOL" ] && OTEL_VARS[OTEL_EXPORTER_OTLP_METRICS_PROTOCOL]="$OTLP_METRICS_PROTOCOL"
[ -n "$OTEL_METRICS_EXP" ]      && OTEL_VARS[OTEL_METRICS_EXPORTER]="$OTEL_METRICS_EXP"
[ -n "$OTEL_RESOURCE_ATTRS" ]   && OTEL_VARS[OTEL_RESOURCE_ATTRIBUTES]="$OTEL_RESOURCE_ATTRS"
[ -n "$OTEL_LOG_PROMPTS" ]      && OTEL_VARS[OTEL_LOG_USER_PROMPTS]="$OTEL_LOG_PROMPTS"
[ -n "$OTEL_METRIC_INTERVAL" ]  && OTEL_VARS[OTEL_METRIC_EXPORT_INTERVAL]="$OTEL_METRIC_INTERVAL"
[ -n "$OTEL_LOGS_INTERVAL" ]    && OTEL_VARS[OTEL_LOGS_EXPORT_INTERVAL]="$OTEL_LOGS_INTERVAL"

# -- Warn on overwrites and merge -----------------------------
echo ""
echo "Checking for conflicts with existing env vars..."

MERGED_JSON=$(python3 -c "
import json, sys

current = json.loads('$CURRENT_ENV_JSON') or {}

otel_keys = json.loads('$(
  python3 -c "
import json
keys = {
  'OVERRIDE_AGENTCORE_ADOT_ENV_VARS': 'true',
  'OTEL_SERVICE_NAME': '$AGENT_NAME',
  'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': '$OTLP_TRACES_ENDPOINT',
  'OTEL_EXPORTER_OTLP_TRACES_HEADERS': '$OTLP_TRACES_HEADERS',
  'OTEL_EXPORTER_OTLP_TRACES_PROTOCOL': '$OTLP_TRACES_PROTOCOL',
  'OTEL_TRACES_EXPORTER': '$OTEL_TRACES_EXP',
  'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT': '$OTLP_LOGS_ENDPOINT',
  'OTEL_EXPORTER_OTLP_LOGS_HEADERS': '$OTLP_LOGS_HEADERS',
  'OTEL_EXPORTER_OTLP_LOGS_PROTOCOL': '$OTLP_LOGS_PROTOCOL',
  'OTEL_LOGS_EXPORTER': '$OTEL_LOGS_EXP',
  'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT': '$OTLP_METRICS_ENDPOINT',
  'OTEL_EXPORTER_OTLP_METRICS_HEADERS': '$OTLP_METRICS_HEADERS',
  'OTEL_EXPORTER_OTLP_METRICS_PROTOCOL': '$OTLP_METRICS_PROTOCOL',
  'OTEL_METRICS_EXPORTER': '$OTEL_METRICS_EXP',
  'OTEL_RESOURCE_ATTRIBUTES': '$OTEL_RESOURCE_ATTRS',
  'OTEL_LOG_USER_PROMPTS': '$OTEL_LOG_PROMPTS',
  'OTEL_METRIC_EXPORT_INTERVAL': '$OTEL_METRIC_INTERVAL',
  'OTEL_LOGS_EXPORT_INTERVAL': '$OTEL_LOGS_INTERVAL',
}
# remove empty values
keys = {k: v for k, v in keys.items() if v}
print(json.dumps(keys))
"
)')

warnings = []
for k, v in otel_keys.items():
    if k in current and current[k] != v:
        warnings.append(f'  WARNING - {k} will be overwritten')
        warnings.append(f'    old: {current[k]}')
        warnings.append(f'    new: {v}')

if warnings:
    print('\n'.join(warnings), file=sys.stderr)

merged = {**current, **otel_keys}
print(json.dumps(merged))
")

if [ $? -ne 0 ]; then
  echo "ERROR - Failed to merge environment variables"
  exit 1
fi

# -- Update runtime with all required fields ------------------
echo ""
echo "Updating runtime with merged environment variables..."

UPDATE_RESULT=$(AWS_PROFILE="$AWS_PROFILE" aws bedrock-agentcore-control update-agent-runtime \
  --agent-runtime-id "$RUNTIME_ID" \
  --region "$REGION" \
  --role-arn "$ROLE_ARN" \
  --network-configuration "$NETWORK_CONFIG" \
  --agent-runtime-artifact "$AGENT_ARTIFACT" \
  --environment-variables "$MERGED_JSON" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
  echo "ERROR - Failed to update runtime:"
  echo "  $UPDATE_RESULT"
  exit 1
fi

echo "OK - Runtime updated successfully"

# -- Print final env vars on runtime --------------------------
echo ""
echo "Verifying — final environment variables on runtime:"

AWS_PROFILE="$AWS_PROFILE" aws bedrock-agentcore-control get-agent-runtime \
  --agent-runtime-id "$RUNTIME_ID" \
  --region "$REGION" \
  --query 'environmentVariables' \
  --output json \
  | python3 -c "
import sys, json
vars = json.load(sys.stdin)
if not vars:
    print('  (none)')
else:
    for k, v in sorted(vars.items()):
        marker = ' <- portal26' if k.startswith('OTEL') or k == 'OVERRIDE_AGENTCORE_ADOT_ENV_VARS' else ''
        print(f'  {k} = {v}{marker}')
"

echo ""
echo "================================================"
echo "Done. portal26 OTEL vars injected successfully."
echo ""
echo "Signals will appear at: portal26.in"
echo "  Traces  : $OTLP_TRACES_ENDPOINT"
echo "  Logs    : $OTLP_LOGS_ENDPOINT"
echo "  Metrics : ${OTLP_METRICS_ENDPOINT:-disabled}"
echo "================================================"