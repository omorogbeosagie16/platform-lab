packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-2"
}

locals {
  ts = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "ubuntu" {
  region        = var.region
  instance_type = "t3.micro"
  ssh_username  = "ubuntu"
  ami_name      = "golden-ubuntu-2404-${local.ts}"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  imds_support = "v2.0"

  tags = {
    Project = "platform-lab"
    Role    = "golden"
    Base    = "ubuntu-24.04"
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade",
    ]
  }

  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/golden.yml"
    user          = "ubuntu"
    use_proxy     = false
    # Packer runs from the packer/ folder, so ansible.cfg is not read here.
    ansible_env_vars = ["ANSIBLE_HOST_KEY_CHECKING=False"]
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo apt-get clean",
    ]
  }
}
