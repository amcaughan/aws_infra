FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Basic tools
RUN apt-get update && \
    apt-get install -y \
      sudo \
      git \
      curl \
      unzip \
      ca-certificates \
      gnupg \
      lsb-release \
      software-properties-common \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user "dev"
RUN useradd -ms /bin/bash dev && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
USER dev
WORKDIR /home/dev

###########################################################
# AWS CLI v2
###########################################################
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
      -o "/tmp/awscliv2.zip" && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    sudo /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

###########################################################
# Terraform
###########################################################
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install -y terraform && \
    sudo rm -rf /var/lib/apt/lists/*

###########################################################
# Terragrunt
###########################################################
RUN TG_VERSION=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest \
        | grep tag_name | cut -d '"' -f 4) && \
    curl -Ls "https://github.com/gruntwork-io/terragrunt/releases/download/${TG_VERSION}/terragrunt_linux_amd64" \
      -o /tmp/terragrunt && \
    chmod +x /tmp/terragrunt && \
    sudo mv /tmp/terragrunt /usr/local/bin/terragrunt

# Default shell
CMD ["/bin/bash"]
