variable "region" {
  type    = string
  default = "us-east-2"
}

variable "env" {
  type    = string
  default = "uat"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/lab_ed25519.pub"
}

variable "admin_user" {
  type    = string
  default = "ops"
}

variable "admin_cidrs" {
  description = "Source IPs allowed to SSH and reach the k8s API, e.g. your public IP /32"
  type        = list(string)
}

variable "servers" {
  type = map(object({
    instance_type = string
    os            = string
    role          = string
    disk_gb       = number
  }))
}
