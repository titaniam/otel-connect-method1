# =============================================================
# portal26-otel.tfvars
#
# Source of truth: otel_config.py (CLOUD_OTEL dict)
# Generated for agent: p26maseqsrossresearcher
#
# HOW TO USE:
#   terraform apply \
#     -var-file="terraform.tfvars" \
#     -var-file="portal26-otel.tfvars"
#
# DO NOT commit to version control — contains auth credentials.
# =============================================================

portal26_otel_environment_variables = {
  # --- Traces ---
  OTEL_TRACES_EXPORTER                        = "otlp"
  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT          = "https://otel-tenant1.portal26.in:4318/v1/traces"
  OTEL_EXPORTER_OTLP_TRACES_HEADERS           = "Authorization=Basic <YOUR_BASE64_CREDENTIALS>"
  OTEL_EXPORTER_OTLP_TRACES_PROTOCOL          = "http/protobuf"

  # --- Logs ---
  OTEL_LOGS_EXPORTER                          = "otlp"
  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT            = "https://otel-tenant1.portal26.in:4318/v1/logs"
  OTEL_EXPORTER_OTLP_LOGS_HEADERS             = "Authorization=Basic <YOUR_BASE64_CREDENTIALS>"
  OTEL_EXPORTER_OTLP_LOGS_PROTOCOL            = "http/protobuf"

  # --- Metrics (disabled until portal26.in enables /v1/metrics) ---
  OTEL_METRICS_EXPORTER                       = "none"

  # --- portal26 resource attributes ---
  OTEL_RESOURCE_ATTRIBUTES                    = "portal26.user.id=relusys,portal26.tenant_id=tenant1"
  OTEL_LOG_USER_PROMPTS                       = "1"
  OTEL_METRIC_EXPORT_INTERVAL                 = "1000"
  OTEL_LOGS_EXPORT_INTERVAL                   = "500"

  # --- AgentCore ADOT override (required for custom OTEL config to take effect) ---
  OVERRIDE_AGENTCORE_ADOT_ENV_VARS            = "true"
}
