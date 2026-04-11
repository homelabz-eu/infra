FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LIBGUESTFS_BACKEND=direct

RUN apt-get update && apt-get install -y --no-install-recommends \
    libguestfs-tools \
    linux-image-generic \
    qemu-utils \
    curl \
    wget \
    jq \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

ARG KUBECTL_VERSION=v1.33.0
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x kubectl && mv kubectl /usr/local/bin/

ARG VIRTCTL_VERSION=v1.5.0
RUN curl -L -o /usr/local/bin/virtctl \
    "https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-${VIRTCTL_VERSION}-linux-amd64" \
    && chmod +x /usr/local/bin/virtctl
