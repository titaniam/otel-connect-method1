# ============================================================
# otel_config.py
# ============================================================

OTEL_MODE = "cloud"

CLOUD_OTEL = {
    # --- Traces (working) ---
    "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT":   "https://otel-tenant1.portal26.in:4318/v1/traces",
    "OTEL_EXPORTER_OTLP_TRACES_HEADERS":    "Authorization=Basic dGl0YW5pYW06aGVsbG93b3JsZA==",
    "OTEL_EXPORTER_OTLP_TRACES_PROTOCOL":   "http/protobuf",
    "OTEL_TRACES_EXPORTER":                 "otlp",

    # --- Logs (endpoint ready, agent-side setup pending) ---
    "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT":     "https://otel-tenant1.portal26.in:4318/v1/logs",
    "OTEL_EXPORTER_OTLP_LOGS_HEADERS":      "Authorization=Basic dGl0YW5pYW06aGVsbG93b3JsZA==",
    "OTEL_EXPORTER_OTLP_LOGS_PROTOCOL":     "http/protobuf",
    "OTEL_LOGS_EXPORTER":                   "otlp",

    # --- Metrics (disabled until portal26.in enables /v1/metrics) ---
    # To enable: curl -X POST -H "Content-Type: application/x-protobuf"
    #            -H "Authorization: Basic dGl..." 
    #            https://otel-tenant1.portal26.in:4318/v1/metrics
    # If 200 → change "none" to "otlp" and add endpoint/headers/protocol keys
    "OTEL_METRICS_EXPORTER":                "none",

    # --- Metrics (enabled) ---

    #"OTEL_EXPORTER_OTLP_METRICS_ENDPOINT":  "https://otel-tenant1.portal26.in:4318/v1/metrics",
    #"OTEL_EXPORTER_OTLP_METRICS_HEADERS":   "Authorization=Basic dGl0YW5pYW06aGVsbG93b3JsZA==",
    #"OTEL_EXPORTER_OTLP_METRICS_PROTOCOL":  "http/protobuf",
    #"OTEL_METRICS_EXPORTER":                "otlp",   # ← flip from "none"




    # --- portal26 resource attributes ---
    "OTEL_RESOURCE_ATTRIBUTES":             "portal26.user.id=relusys,portal26.tenant_id=tenant1",
    "OTEL_LOG_USER_PROMPTS":                "1",
    "OTEL_METRIC_EXPORT_INTERVAL":          "1000",
    "OTEL_LOGS_EXPORT_INTERVAL":            "500",
}