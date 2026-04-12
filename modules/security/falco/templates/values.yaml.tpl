image:
  registry: registry.homelabz.eu/mirror-dockerhub
  repository: falcosecurity/falco
falcoctl:
  image:
    registry: registry.homelabz.eu/mirror-dockerhub
    repository: falcosecurity/falcoctl
driver:
  kind: ${driver_kind}
  loader:
    initContainer:
      image:
        registry: registry.homelabz.eu/mirror-dockerhub
        repository: falcosecurity/falco-driver-loader

tty: true

falco:
  json_output: true
  json_include_output_property: true

metrics:
  enabled: ${metrics_enabled}
  interval: 15m
  outputRule: false
  rulesCountersEnabled: true
  resourceUtilizationEnabled: true
  service:
    create: true
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8765"

resources:
  requests:
    cpu: ${cpu_request}
    memory: ${memory_request}
  limits:
    cpu: ${cpu_limit}
    memory: ${memory_limit}
