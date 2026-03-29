apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: RKE2ConfigTemplate
metadata:
  name: ${worker_rke2_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      preRKE2Commands:
      - 'INSTANCE_ID=$(cloud-init query instance-id) && mkdir -p /etc/rancher/rke2/config.yaml.d && echo "kubelet-arg:" > /etc/rancher/rke2/config.yaml.d/provider-id.yaml && echo "- provider-id=proxmox://$INSTANCE_ID" >> /etc/rancher/rke2/config.yaml.d/provider-id.yaml'
      - 'echo "system-default-registry: registry.homelabz.eu/mirror-dockerhub" > /etc/rancher/rke2/config.yaml.d/registry.yaml'
      agentConfig:
        additionalUserData:
          data:
            users: "\n- name: suporte\n  ssh_authorized_keys:\n${ssh_authorized_keys}\n  sudo: ALL=(ALL) NOPASSWD:ALL\n"
${node_taints_yaml}
${node_labels_yaml}
