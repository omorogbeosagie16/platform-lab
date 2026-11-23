terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 7.0"
    }
  }
  backend "s3" {}
}

variable "admin_cidrs" {
  description = "Your PC public IP /32 and the ctl public IP /32"
  type        = list(string)
}

variable "webhook_cidrs" {
  description = "GitHub webhook source ranges, IPv4 only"
  type        = list(string)
  default     = []
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      Project   = "platform-lab"
      ManagedBy = "terraform"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "jenkins" {
  name        = "platform-lab-jenkins"
  description = "Jenkins: ssh and web UI from admin, webhooks from GitHub"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.jenkins.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "ui" {
  for_each          = toset(concat(var.admin_cidrs, var.webhook_cidrs))
  security_group_id = aws_security_group.jenkins.id
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.jenkins.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = "t3.medium"
  key_name               = "lab"
  iam_instance_profile   = "platform-lab-jenkins"
  vpc_security_group_ids = [aws_security_group.jenkins.id]

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "jenkins"
    Role = "jenkins"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_private_ip" {
  value = aws_instance.jenkins.private_ip
}
