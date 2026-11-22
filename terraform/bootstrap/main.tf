terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 7.0"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-2"
}

variable "github_repo" {
  description = "owner/repo allowed to assume the Actions role"
  type        = string
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "platform-lab"
      ManagedBy = "terraform-bootstrap"
    }
  }
}

data "aws_caller_identity" "me" {}

locals {
  bucket = "tfstate-${data.aws_caller_identity.me.account_id}-${var.region}"
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket
  force_destroy = true # lab only, lets terraform destroy remove a bucket that still holds versions
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# GitHub Actions OIDC (an account can have only one provider for this URL)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "gh_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "gh_actions" {
  name               = "platform-lab-gh-actions"
  assume_role_policy = data.aws_iam_policy_document.gh_trust.json
}

# Lab shortcut. In real life scope this to exactly what the pipeline manages.
resource "aws_iam_role_policy_attachment" "gh_poweruser" {
  role       = aws_iam_role.gh_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Instance profile for the monitoring server (Prometheus EC2 service discovery)
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "platform-lab-monitoring"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy" "monitoring_describe" {
  name = "describe-ec2"
  role = aws_iam_role.monitoring.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "platform-lab-monitoring"
  role = aws_iam_role.monitoring.name
}

# Instance role for the Jenkins server (no access keys stored in Jenkins)
resource "aws_iam_role" "jenkins" {
  name               = "platform-lab-jenkins"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "jenkins_poweruser" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess" # lab shortcut, scope it in real life
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "platform-lab-jenkins"
  role = aws_iam_role.jenkins.name
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "gh_actions_role_arn" {
  value = aws_iam_role.gh_actions.arn
}
