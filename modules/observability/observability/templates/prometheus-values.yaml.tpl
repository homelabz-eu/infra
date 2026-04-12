prometheusOperator:
  image:
    registry: registry.homelabz.eu/mirror-quay
    repository: prometheus-operator/prometheus-operator
  prometheusConfigReloader:
    image:
      registry: registry.homelabz.eu/mirror-quay
      repository: prometheus-operator/prometheus-config-reloader
  thanosImage:
    registry: registry.homelabz.eu/mirror-quay
    repository: thanos/thanos
  admissionWebhooks:
    deployment:
      image:
        registry: registry.homelabz.eu/mirror-quay
        repository: prometheus-operator/admission-webhook
    patch:
      image:
        registry: registry.homelabz.eu/mirror-k8s
        repository: ingress-nginx/kube-webhook-certgen

alertmanager:
  alertmanagerSpec:
    image:
      registry: registry.homelabz.eu/mirror-quay
      repository: prometheus/alertmanager

kube-state-metrics:
  image:
    registry: registry.homelabz.eu/mirror-k8s
    repository: kube-state-metrics/kube-state-metrics

prometheus-node-exporter:
  image:
    registry: registry.homelabz.eu/mirror-quay
    repository: prometheus/node-exporter

grafana:
  image:
    registry: registry.homelabz.eu/mirror-dockerhub
    repository: grafana/grafana
  sidecar:
    image:
      registry: registry.homelabz.eu/mirror-quay
      repository: kiwigrid/k8s-sidecar
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
      external-dns.alpha.kubernetes.io/hostname: ${grafana_domain}
    hosts:
      - ${grafana_domain}
    path: /
    tls:
    - secretName: prometheus-grafana-tls
      hosts:
      - ${grafana_domain}
  additionalDataSources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-operated:9090
      access: proxy
    - name: Loki
      type: loki
      access: proxy
      url: http://loki-headless:3100
      jsonData:
        tlsSkipVerify: true
        httpHeaderName1: 'X-Scope-OrgID'
      secureJsonData:
        httpHeaderValue1: 'empty'

prometheus:
  prometheusSpec:
    image:
      registry: registry.homelabz.eu/mirror-quay
      repository: prometheus/prometheus
    additionalArgs:
      - name: web.enable-otlp-receiver
        value: ""
    enableRemoteWriteReceiver: true
    remoteWriteDashboards: true
    scrapeClasses:
      - default: true
        name: cluster-relabeling
        relabelings:
          - sourceLabels: [ __name__ ]
            regex: (.*)
            targetLabel: cluster
            replacement: ${cluster_name}
            action: replace
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
      external-dns.alpha.kubernetes.io/hostname: ${prometheus_domain}
    hosts:
      - ${prometheus_domain}
    path: /
    tls:
    - secretName: prometheus-prometheus-tls
      hosts:
      - ${prometheus_domain}
