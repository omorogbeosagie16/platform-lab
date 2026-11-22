variable "env" {
  description = "Environment name, used in resource names and tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "admin_user" {
  description = "Admin user created by cloud-init on each server"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the public key installed on the servers"
  type        = string
}

variable "admin_cidrs" {
  description = "Source IPs allowed to SSH and reach the k8s API, e.g. your public IP /32"
  type        = list(string)
}

variable "servers" {
  description = "Servers to create, keyed by name"
  type = map(object({
    instance_type = string
    os            = string
    role          = string
    disk_gb       = number
  }))
}
