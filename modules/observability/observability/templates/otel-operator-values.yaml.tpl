manager:
  image:
    repository: registry.homelabz.eu/mirror-ghcr/open-telemetry/opentelemetry-operator/opentelemetry-operator
  collectorImage:
    repository: registry.homelabz.eu/mirror-dockerhub/otel/opentelemetry-collector-contrib
admissionWebhooks:
  enabled: ${admission_webhooks_enabled}
certManager:
  enabled: ${cert_manager_enabled}
