expose:
  type: ingress
  tls:
    enabled: ${tls_enabled}
    certSource: secret
    secret:
      secretName: ${tls_cert_secret_name}
  ingress:
%{if !ingress_enabled }
    enabled: false
%{endif}
    hosts:
      core: ${harbor_domain}
    className: ${ingress_class_name}
    annotations:
%{for key, value in ingress_annotations}
      ${key}: "${value}"
%{endfor}

externalURL: https://${harbor_domain}

harborAdminPassword: "${admin_password}"

# Persistence configuration
persistence:
  enabled: ${persistence_enabled}
  resourcePolicy: "keep"
%{if persistence_enabled && (storage_class != "" || registry_existing_claim != "")}
  persistentVolumeClaim:
    registry:
%{if registry_existing_claim != ""}
      existingClaim: ${registry_existing_claim}
%{else}
      storageClass: ${storage_class}
      size: ${registry_storage_size}
%{endif}
    chartmuseum:
      storageClass: ${storage_class}
    jobservice:
      jobLog:
        storageClass: ${storage_class}
    database:
      storageClass: ${storage_class}
    redis:
      storageClass: ${storage_class}
    trivy:
      storageClass: ${storage_class}
%{endif}

# External database configuration
database:
  type: external
  external:
    host: "${external_database_host}"
    port: ${external_database_port}
    username: "${external_database_username}"
    password: "${external_database_password}"
    sslmode: "${external_database_sslmode}"
    database: "${external_database_database}"

redis:
  type: external
  external:
    addr: "${external_redis_host}:${external_redis_port}"
    password: "${external_redis_password}"
    databaseIndex: ${external_redis_database_index}
nginx:
  image:
    repository: registry.homelabz.eu/mirror-dockerhub/goharbor/nginx-photon
core:
  image:
    repository: registry.homelabz.eu/mirror-dockerhub/goharbor/harbor-core
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.core.cpu}
      memory: ${resources_limits.core.memory}
    requests:
      cpu: ${resources_requests.core.cpu}
      memory: ${resources_requests.core.memory}
  extraEnvVars:
    - name: REGISTRY_HTTP_CLIENT_TIMEOUT
      value: "600"
jobservice:
  image:
    repository: registry.homelabz.eu/mirror-dockerhub/goharbor/harbor-jobservice
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.jobservice.cpu}
      memory: ${resources_limits.jobservice.memory}
    requests:
      cpu: ${resources_requests.jobservice.cpu}
      memory: ${resources_requests.jobservice.memory}
  extraEnvVars:
    - name: REGISTRY_HTTP_CLIENT_TIMEOUT
      value: "600"

registry:
  registry:
    image:
      repository: registry.homelabz.eu/mirror-dockerhub/goharbor/registry-photon
  controller:
    image:
      repository: registry.homelabz.eu/mirror-dockerhub/goharbor/harbor-registryctl
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.registry.cpu}
      memory: ${resources_limits.registry.memory}
    requests:
      cpu: ${resources_requests.registry.cpu}
      memory: ${resources_requests.registry.memory}

portal:
  image:
    repository: registry.homelabz.eu/mirror-dockerhub/goharbor/harbor-portal
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.portal.cpu}
      memory: ${resources_limits.portal.memory}
    requests:
      cpu: ${resources_requests.portal.cpu}
      memory: ${resources_requests.portal.memory}
notary:
  enabled: false
chartmuseum:
  enabled: false
trivy:
  image:
    repository: registry.homelabz.eu/mirror-dockerhub/goharbor/trivy-adapter-photon
  enabled: true
  resources:
    limits:
      cpu: ${resources_limits.portal.cpu}
      memory: ${resources_limits.portal.memory}
    requests:
      cpu: ${resources_requests.portal.cpu}
      memory: ${resources_requests.portal.memory}
exporter:
  image:
    repository: registry.homelabz.eu/mirror-dockerhub/goharbor/harbor-exporter
log:
  level: info
  audit:
    enabled: true
