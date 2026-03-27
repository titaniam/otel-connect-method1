# Portal26 OTEL Integration Guide

## Overview

This guide describes how to connect an Amazon Bedrock AgentCore agent to Portal26 for governance and observability. Portal26 collects telemetry signals — traces, logs, and metrics — from the agent runtime and makes them available to the security and governance team in real time.

Portal26 uses the OpenTelemetry (OTEL) standard to collect these signals. Integration requires a small set of environment variables to be configured on the agent runtime. These variables tell the runtime where to route telemetry. No agent business logic is modified.

---

## Prerequisites

The following are required before proceeding:

- An AWS CLI profile with permission to manage the agent runtime
- The `otel_config.py` or `portal26-otel.tfvars` file provided by the Portal26 administrator
- Python 3.8 or later (Method 1 only)

Contact the Portal26 administrator if either file has not been received.

---

## Choosing an Integration Method

The integration method depends on how the team manages infrastructure.

| | Method 1 — Script | Method 2 — Terraform |
|---|---|---|
| **When to use** | Infrastructure is managed via CLI or any non-Terraform tooling | Infrastructure is managed as code using Terraform |
| **What it does** | Injects OTEL vars directly into the live agent runtime via AWS API | Adds OTEL vars into the Terraform configuration, applied on every `terraform apply` |
| **Drift risk** | Low — vars are set once on the live runtime | None — vars are part of Terraform state |
| **Time to complete** | ~5 minutes | ~15 minutes |

---

## Method 1 — Script Injection

### How It Works

The injection script fetches the current environment variables from the live agent runtime, merges the Portal26 OTEL variables on top, and pushes the merged set back. Existing environment variables on the runtime are preserved — only Portal26 OTEL keys are added or updated.

### Step 1 — Place the files in the agent directory

The Portal26 administrator will provide two files:

- `inject-portal26-otel.sh` — the injection script
- `otel_config.py` — tenant-specific OTEL configuration

Place both files in the agent directory — the directory containing `.bedrock_agentcore.yaml`. The structure should be:

```
myagent/
  .bedrock_agentcore.yaml       ← present from deployment
  otel_config.py                ← provided by Portal26
  inject-portal26-otel.sh       ← provided by Portal26
  agent.py                      ← agent code
```

### Step 2 — Make the script executable

```bash
chmod +x inject-portal26-otel.sh
```

### Step 3 — Run the script

Navigate to the agent directory and run:

```bash
cd /path/to/agent
./inject-portal26-otel.sh <aws-profile>
```

The AWS profile must have `bedrock-agentcore:UpdateAgentRuntime` permission on the agent runtime. To list available profiles:

```bash
aws configure list-profiles
```

**Example:**

```bash
./inject-portal26-otel.sh my-company-profile
```

### Step 4 — Verify the output

A successful run produces output similar to the following:

```
Validating AWS profile 'my-company-profile'...
OK - Account : 123456789012
OK - Identity: arn:aws:iam::123456789012:role/MyDeployRole

================================================
Agent name  : myagent
Runtime ID  : myagent-aBcD1234eF
Region      : us-east-1
AWS profile : my-company-profile
================================================

Reading portal26 OTEL config...
OK - Traces  : https://otel-tenant1.portal26.in:4318/v1/traces
OK - Logs    : https://otel-tenant1.portal26.in:4318/v1/logs
OK - Metrics : disabled

Fetching current runtime details...
OK - Runtime details fetched

Checking for conflicts with existing env vars...

Updating runtime with merged environment variables...
OK - Runtime updated successfully

Verifying — final environment variables on runtime:
  MY_EXISTING_VAR = my-value
  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = https://otel-tenant1.portal26.in:4318/v1/logs  <- portal26
  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = https://otel-tenant1.portal26.in:4318/v1/traces  <- portal26
  OVERRIDE_AGENTCORE_ADOT_ENV_VARS = true  <- portal26
  ...

================================================
Done. portal26 OTEL vars injected successfully.

Signals will appear at: portal26.in
  Traces  : https://otel-tenant1.portal26.in:4318/v1/traces
  Logs    : https://otel-tenant1.portal26.in:4318/v1/logs
  Metrics : disabled
================================================
```

Variables marked with `<- portal26` are the ones added or updated by the script. All other variables remain unchanged.

### Overwrite Behaviour

If a Portal26 OTEL variable already exists on the runtime (for example, from a previous injection), the script will warn before overwriting:

```
WARNING - OTEL_EXPORTER_OTLP_TRACES_ENDPOINT will be overwritten
  old: https://old-endpoint.example.com/v1/traces
  new: https://otel-tenant1.portal26.in:4318/v1/traces
```

The script will proceed and apply the updated values. This is expected behaviour when refreshing a Portal26 configuration.

### Troubleshooting

**"AWS profile not found"**
Run `aws configure list-profiles` to confirm the profile name. Ensure the profile has `bedrock-agentcore:UpdateAgentRuntime` permission. If permission is missing, contact the AWS administrator to have it granted on the relevant agent runtime resource.

**"Could not read agent_arn from .bedrock_agentcore.yaml"**
The agent runtime ARN is not present in the configuration file. Confirm with the agent developer that the deployment completed successfully and the config file is up to date.

**"Failed to update runtime"**
The AWS profile does not have sufficient permission to update the agent runtime. The required IAM action is `bedrock-agentcore:UpdateAgentRuntime`. Contact the AWS administrator to have it added to the profile's policy.

---

## Method 2 — Terraform Integration

### How It Works

Portal26 provides a `portal26-otel.tfvars` file containing the OTEL variable values for the tenant. These are declared as a Terraform variable and merged into the `aws_bedrockagentcore_agent_runtime` resource. Once integrated, the Portal26 variables are applied on every `terraform apply` as part of the standard deployment — no separate injection step is needed.

### Step 1 — Place the tfvars file

The Portal26 administrator will provide:

- `portal26-otel.tfvars` — tenant-specific OTEL variable values

Place this file in the same directory as the Terraform configuration.

### Step 2 — Declare the variable

Add the following declaration to the Terraform configuration (typically `variables.tf` or `main.tf`):

```hcl
variable "portal26_otel_environment_variables" {
  description = "Portal26 OTEL environment variables for agent observability"
  type        = map(string)
  default     = {}
}
```

### Step 3 — Add to the agent runtime resource

Locate the `aws_bedrockagentcore_agent_runtime` resource in the Terraform configuration.

**If the resource has existing environment variables:**

```hcl
resource "aws_bedrockagentcore_agent_runtime" "my_agent" {
  agent_runtime_name = "myagent"

  environment_variables = merge(
    {
      MY_EXISTING_VAR = "my-value"
    },
    var.portal26_otel_environment_variables
  )
}
```

**If the resource has no existing environment variables:**

```hcl
resource "aws_bedrockagentcore_agent_runtime" "my_agent" {
  agent_runtime_name = "myagent"

  environment_variables = var.portal26_otel_environment_variables
}
```

The `merge()` function combines both maps without affecting any other resource configuration. If a key exists in both maps, the Portal26 value takes precedence.

### Step 4 — Apply

Include the Portal26 tfvars file in the `terraform apply` command:

```bash
terraform apply -var-file="portal26-otel.tfvars"
```

If other var files are already in use:

```bash
terraform apply \
  -var-file="terraform.tfvars" \
  -var-file="portal26-otel.tfvars"
```

### Step 5 — Verify

After apply completes, confirm the environment variables on the runtime:

```bash
aws bedrock-agentcore-control get-agent-runtime \
  --agent-runtime-id <runtime-id> \
  --region <region> \
  --query 'environmentVariables' \
  --output json
```

Portal26 OTEL variables should appear alongside any existing ones.

### Keeping the Configuration Active

The `portal26-otel.tfvars` file must be included in every future `terraform apply` for the Portal26 configuration to persist across deployments. Recommended approaches:

- Store it as a secure file or secret in the CI/CD pipeline
- Retrieve it from a secrets manager at deploy time

**Do not commit this file to version control** if it contains authentication tokens.

To update the Portal26 configuration (for example, after a token rotation), replace the `portal26-otel.tfvars` file and run `terraform apply -var-file="portal26-otel.tfvars"`.

### Troubleshooting

**"Variable not declared"**
Ensure the variable declaration from Step 2 has been added to the Terraform configuration before running apply.

**"Error merging environment variables"**
Confirm that the existing `environment_variables` block uses map syntax `{}`. The `merge()` function requires both inputs to be maps.

**Terraform state drift**
If the script injection method (Method 1) was used on the same agent after a Terraform apply, the live runtime state may differ from Terraform state. Running `terraform apply -var-file="portal26-otel.tfvars"` will reconcile the state.

---

## Verifying Signals in Portal26

After completing either integration method and verifying the environment variables are set correctly, invoke the agent using agents invocation method.

Then log in to **portal26.in** and navigate to your tenant dashboard. The following signals should appear within 1–2 minutes of agent invocation:

- **Traces** — step-by-step execution path of the agent
- **Logs** — prompts, responses, and decisions made by the agent
- **Metrics** — only if the metrics endpoint was configured by the Portal26 administrator

If signals do not appear within 5 minutes, contact Portal26 support with the agent runtime ID and region.

---

## Summary

| | Method 1 — Script | Method 2 — Terraform |
|---|---|---|
| Files needed | `inject-portal26-otel.sh`, `otel_config.py` | `portal26-otel.tfvars` |
| One-time setup | `chmod +x` the script | Declare variable, update resource block |
| Apply | `./inject-portal26-otel.sh <aws-profile>` | `terraform apply -var-file="portal26-otel.tfvars"` |
| Future deploys | Re-run script if runtime is recreated | Automatic — included in every apply |
| Drift risk | Low | None |
