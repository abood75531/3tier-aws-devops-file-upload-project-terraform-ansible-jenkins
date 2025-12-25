terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region = var.region
}

# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "devops-3tier-vpc" }
}

# -----------------------------
# Subnets
# -----------------------------
resource "aws_subnet" "frontend" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = { Name = "frontend-subnet" }
}

resource "aws_subnet" "backend" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "backend-subnet" }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
  tags = { Name = "db-subnet" }
}

# -----------------------------
# Internet Gateway + Public Route
# -----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "frontend_assoc" {
  subnet_id      = aws_subnet.frontend.id
  route_table_id = aws_route_table.public_rt.id
}

# =====================================================
# 🔥 NAT GATEWAY ADDITION (NEW)
# =====================================================

# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT Gateway in Public (Frontend) Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.frontend.id

  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "main-nat-gateway" }
}

# Private Route Table (Backend + DB)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "private-rt" }
}

# Associate Backend Subnet with NAT Route
resource "aws_route_table_association" "backend_assoc" {
  subnet_id      = aws_subnet.backend.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate DB Subnet with NAT Route
resource "aws_route_table_association" "db_assoc" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.private_rt.id
}

# -----------------------------
# Security Groups
# -----------------------------
resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.main.id
  name   = "frontend-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.main.id
  name   = "backend-sg"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id
  name   = "db-sg"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ansible_sg" {
  vpc_id = aws_vpc.main.id
  name   = "ansible-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# EC2 Instances
# -----------------------------
resource "aws_instance" "frontend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.frontend.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  tags = { Name = "frontend-ec2" }
}

resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.backend.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  tags = { Name = "backend-ec2" }
}

resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.db.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  tags = { Name = "db-ec2" }
}

# -----------------------------
# Ansible Server
# -----------------------------
resource "aws_instance" "ansible" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.frontend.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname ansible
    yum update -y
    yum install ansible -y
    mkdir -p /etc/ansible/playbooks
  EOF

  tags = { Name = "ansible-server" }
}

# -----------------------------
# S3 + CloudFront + SNS (UNCHANGED)
# -----------------------------
resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "uploads" {
  bucket = "file-upload-${random_id.rand.hex}"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.uploads.bucket_regional_domain_name
    origin_id   = "s3-origin"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_sns_topic" "upload_topic" {
  name = "file-upload-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.upload_topic.arn
  protocol  = "email"
  endpoint  = var.admin_email
}
