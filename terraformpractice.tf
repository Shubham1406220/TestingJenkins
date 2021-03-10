terraform {
  required_version = " >=0.12"
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = ">=2.68.0"
    }
  }
  backend "s3" {
    bucket     = "terraform-shubham-001"
    key   = "practice-001"
    region     = "ap-south-1"
    access_key = "AKIAQQKMOHRBX6CPCYNA"
    secret_key = "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"
  }
}

provider "aws" {
  secret_key = var.secret_key
  access_key = var.access_key
  region     = var.region
}

variable "sg-ports" {
  type    = list(any)
  default = [22, 345, 655]
}

variable "region" {
  default   = "ap-south-1"
  sensitive = true
}
variable "access_key" {
  default   = "AKIAQQKMOHRBX6CPCYNA"
  sensitive = "true"
  type      = string
}
variable "secret_key" {
  default   = "VzqFssXn0BElJl00mLO1x8RMdHYfWzoJWSV8hBp2"
  type      = string
  sensitive = "true"
}

resource "aws_vpc" "testing" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    name = "Testing"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.testing.id
  tags = {
    name = "IGW"
  }
}

resource "aws_eip" "eip-nat" {
  vpc = "true"
  tags = {
    name = "eip-nat"
  }
}
resource "aws_nat_gateway" "NGW" {
  subnet_id     = aws_subnet.Public-subnet.id
  allocation_id = aws_eip.eip-nat.id
  depends_on    = [aws_eip.eip-nat]
  tags = {
    name = "NGW"
  }
}


data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "Public-subnet" {
  vpc_id                  = aws_vpc.testing.id
  map_public_ip_on_launch = true
  cidr_block              = "10.0.1.0/24"
  availability_zone       = element(data.aws_availability_zones.azs.names,0)
  tags = {
    name = "Public-subnet"
  }
}

resource "aws_subnet" "Private-subnet" {
  vpc_id                  = aws_vpc.testing.id
  availability_zone       = element(data.aws_availability_zones.azs.names,1)
  map_public_ip_on_launch = false
  cidr_block              = "10.0.2.0/24"
  tags = {
    name = "Private-subnet"
  }
}
resource "aws_instance" "test-ec2" {
  ami                         = "ami-0a4a70bd98c6d6441"
  instance_type               = "t3.nano"
  key_name                    = "AWS"
  associate_public_ip_address = "true"
  subnet_id                   = aws_subnet.Public-subnet.id
  tenancy                     = "default"
  vpc_security_group_ids      = [aws_security_group.Public-SG.id]
  cpu_core_count              = 1
  cpu_threads_per_core        = 2
  ebs_optimized               = "true"
  root_block_device {
    delete_on_termination = "true"
    encrypted             = "false"
    throughput            = 125
    volume_size           = 8
    volume_type           = "gp3"
    iops                  = 3000
  }
  ebs_block_device {
    delete_on_termination = "true"
    iops                  = 3000
    encrypted             = "false"
    throughput            = 125
    volume_size           = 8
    volume_type           = "gp3"
    device_name           = "/dev/sde"
  }
}

resource "aws_instance" "Private-Ec2" {
  ami                         = "ami-0a4a70bd98c6d6441"
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.Private-subnet.id
  vpc_security_group_ids      = [aws_security_group.Private-SG.id]
  tenancy                     = "default"
  key_name                    = "AWS"
  associate_public_ip_address = "false"
  cpu_core_count              = 1
  cpu_threads_per_core        = 2
  ebs_optimized               = "true"
  root_block_device {
    delete_on_termination = "true"
    iops                  = 3000
    throughput            = 125
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = "false"
  }
  ebs_block_device {
    delete_on_termination = "true"
    iops                  = 3000
    throughput            = 125
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = "false"
    device_name           = "/dev/sde"
  }

}

resource "aws_security_group" "Public-SG" {
  name   = "Public-SG"
  vpc_id = aws_vpc.testing.id
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16"]
    }
  }
  dynamic "egress" {
    for_each = var.sg-ports
    content {
      to_port     = egress.value
      from_port   = egress.value
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16", "0.0.0.0/0"]
    }
  }

}

resource "aws_security_group" "Private-SG" {
  name   = "Private-SG"
  vpc_id = aws_vpc.testing.id

  dynamic "egress" {
    for_each = var.sg-ports
    content {
      to_port     = egress.value
      from_port   = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16"]
    }
  }
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }
}

resource "aws_network_acl" "Public-nacl" {
  vpc_id     = aws_vpc.testing.id
 subnet_ids = [aws_subnet.Public-subnet.id]
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      to_port    = ingress.value
      from_port  = ingress.value
      protocol   = "tcp"
      rule_no    = 3100
      action     = "allow"
      cidr_block = "10.0.0.0/16"
    }
  }
  dynamic "egress" {
    for_each = var.sg-ports
    content {
      to_port    = egress.value
      from_port  = egress.value
      protocol   = "tcp"
      rule_no    = 3100
      action     = "allow"
      cidr_block = "10.0.0.0/16"
    }
  }
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      to_port    = ingress.value
      from_port  = ingress.value
      protocol   = "tcp"
      rule_no    = 3200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  }
  dynamic "egress" {
    for_each = var.sg-ports
    content {
      to_port    = egress.value
      from_port  = egress.value
      protocol   = "tcp"
      rule_no    = 3200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  }
}

resource "aws_network_acl" "Private-nacl" {
  vpc_id     = aws_vpc.testing.id
  subnet_ids = [aws_subnet.Private-subnet.id]
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      to_port    = ingress.value
      from_port  = ingress.value
      protocol   = "tcp"
      rule_no    = 3100
      action     = "allow"
      cidr_block = "10.0.0.0/16"
    }
  }
  dynamic "egress" {
    for_each = var.sg-ports
    content {
      to_port    = egress.value
      from_port  = egress.value
      protocol   = "tcp"
      rule_no    = 3100
      action     = "allow"
      cidr_block = "10.0.0.0/16"
    }
  }
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      to_port    = ingress.value
      from_port  = ingress.value
      protocol   = "tcp"
      rule_no    = 3200
      action     = "deny"
      cidr_block = "0.0.0.0/0"
    }
  }
  dynamic "egress" {
    for_each = var.sg-ports
    content {
      to_port    = egress.value
      from_port  = egress.value
      protocol   = "tcp"
      rule_no    = 3200
      action     = "allow"
      cidr_block = "0.0.0.0/0"
    }
  }
}

resource "aws_route_table" "Private-RT" {
  vpc_id = aws_vpc.testing.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NGW.id
  }
}
resource "aws_route_table_association" "Private-SG-RT" {
  route_table_id = aws_route_table.Private-RT.id
  subnet_id      = aws_subnet.Private-subnet.id
}


resource "aws_route_table" "Public-RT" {
  vpc_id = aws_vpc.testing.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}
resource "aws_main_route_table_association" "Main-public-RT" {
  route_table_id = aws_route_table.Public-RT.id
  vpc_id         = aws_vpc.testing.id
}
resource "aws_route_table_association" "Public-SG-RT" {
  route_table_id = aws_route_table.Public-RT.id
  subnet_id      = aws_subnet.Public-subnet.id
}
