terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.45.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#### EC2 Security Groups ####

module "dev_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for frontend_server"
  vpc_id      = aws_vpc.main.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
}

module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = aws_vpc.main.id

  # ingress_cidr_blocks = ["0.0.0.0/0"]
  # ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]
  # egress_rules        = ["all-all"]
}


#### IGW ####

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

#### route tables ####
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Route table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

#### EC2 Instances ####

resource "aws_eip" "lb" {
  instance = aws_instance.frontend_server.id
  domain = "vpc"
}

resource "aws_instance" "frontend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "HelloWorld"
  }

    root_block_device {
    volume_size = 8
  }

   user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo apt update && apt upgrade -y
    sudo apt install docker.io -y
    sudo service docker start
    sudo docker pull aive407/frontend:latest
    sudo docker run -p 80:3000 aive407/frontend
  EOF

  vpc_security_group_ids = [
    module.ec2_sg.security_group_id,
    module.dev_ssh_sg.security_group_id
  ]

  key_name                = "terraformKey"
  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

#### Vpc #####

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "projectVPC"
  }
}

#### Subnets ####

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.0/25"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.128/25"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "Private Subnet"
  }
}

