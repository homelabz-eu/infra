concurrent: ${concurrent}
checkInterval: ${check_interval}
runnerToken: "${registration_token}"
rbac:
  create: true
runners:
  config: |
    [[runners]]
      tags = ["${runner_tags}"]
      name = "${runner_tags}"
      url = "${gitlab_url}"
      executor = "kubernetes"
      environment = ["FF_USE_ADVANCED_POD_SPEC_CONFIGURATION=true"]
      [runners.kubernetes]
        namespace = "${namespace}"
        privileged = ${privileged}
        poll_timeout = ${poll_timeout}
        service_account = "${service_account_name}"
        [[runners.kubernetes.pod_spec]]
          name = "build envvars"
          patch = '''
            containers:
              - name: build
                env:
                  - name: HARBOR_KEY
                    valueFrom:
                      secretKeyRef:
                        name: cluster-secrets
                        key: HARBOR_KEY
                volumeMounts:
                  - name: cluster-secrets-volume
                    mountPath: "/tmp/kubeconfig"
                    subPath: kubeconfig
            volumes:
              - name: cluster-secrets-volume
                secret:
                  secretName: cluster-secrets
                  optional: true
                  items:
                    - key: KUBECONFIG
                      path: kubeconfig
          '''
          patch_type = "strategic"
