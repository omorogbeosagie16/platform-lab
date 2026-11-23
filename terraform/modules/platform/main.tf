data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Rocky Linux 9 official images (owner id from the Rocky project)
data "aws_ami" "rocky" {
  most_recent = true
  owners      = ["792107900819"]
  filter {
    name   = "name"
    values = ["Rocky-9-EC2-Base-9.*x86_64*"]
  }
}

# Our own golden image baked by Packer (packer/ubuntu.pkr.hcl), found by tag.
data "aws_ami" "golden" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "tag:Role"
    values = ["golden"]
  }
}

locals {
  amis = {
    ubuntu = data.aws_ssm_parameter.ubuntu.value
    rocky  = data.aws_ami.rocky.id
    golden = data.aws_ami.golden.id
  }
}

resource "aws_key_pair" "lab" {
  key_name   = "${var.env}-lab"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "this" {
  for_each = var.servers

  ami                         = local.amis[each.value.os]
  instance_type               = each.value.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.base.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true
  iam_instance_profile        = each.value.role == "monitoring" ? "platform-lab-monitoring" : null

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    admin_user = var.admin_user
    ssh_key    = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = each.value.disk_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.env}-${each.key}"
    Role = each.value.role
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
