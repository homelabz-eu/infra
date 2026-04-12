FROM golang:1.25 AS secret-manager-builder
WORKDIR /build
COPY secret-manager/ .
RUN go build -o /secret-manager ./cmd/secret-manager

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    unzip \
    make \
    gettext-base \
    openssh-client \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

RUN curl -fsSL https://get.opentofu.org/opentofu.gpg | gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg \
    && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor -o /usr/share/keyrings/opentofu-repo-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg,/usr/share/keyrings/opentofu-repo-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | tee /etc/apt/sources.list.d/opentofu.list \
    && apt-get update && apt-get install -y tofu --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y vault --no-install-recommends \
    && setcap -r /usr/bin/vault \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

RUN curl -L "https://github.com/mozilla/sops/releases/download/v3.9.4/sops-v3.9.4.linux.amd64" -o /usr/local/bin/sops \
    && chmod +x /usr/local/bin/sops

RUN curl -L "https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-amd64.tar.gz" -o /tmp/age.tar.gz \
    && tar -xzf /tmp/age.tar.gz -C /tmp \
    && mv /tmp/age/age /usr/local/bin/age \
    && mv /tmp/age/age-keygen /usr/local/bin/age-keygen \
    && chmod +x /usr/local/bin/age /usr/local/bin/age-keygen \
    && rm -rf /tmp/age /tmp/age.tar.gz

COPY --from=secret-manager-builder /secret-manager /usr/local/bin/secret-manager

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --no-cache-dir pyyaml hvac requests boto3 kubernetes ansible
