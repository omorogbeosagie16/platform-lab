output "servers" {
  value = {
    for k, i in aws_instance.this : k => {
      public_ip  = i.public_ip
      private_ip = i.private_ip
      role       = i.tags["Role"]
    }
  }
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}
