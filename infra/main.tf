terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

resource "random_string" "random" {
  length           = 16
  special          = true
  override_special = "/@£$"
}

# Create a VPC
resource "aws_vpc" "vpc_devops" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_classiclink   = "false"
  tags = {
    Name = "VPC-${var.environment}"
  }
}



resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_devops.id
  tags = {
    Name = "igw-${var.environment}"
  }
}

resource "aws_subnet" "public_subnet_one" {
  availability_zone       = "us-east-1a"
  vpc_id                  = aws_vpc.vpc_devops.id
  cidr_block              = var.public_subnet_one_cidr
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnetOne-${var.environment}"
  }
}

resource "aws_subnet" "public_subnet_two" {
  availability_zone       = "us-east-1b"
  vpc_id                  = aws_vpc.vpc_devops.id
  cidr_block              = var.public_subnet_two_cidr
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnetTwo-${var.environment}"
  }
}

resource "aws_subnet" "private_subnet_one" {
  availability_zone = "us-east-1c"
  vpc_id            = aws_vpc.vpc_devops.id
  cidr_block        = var.private_subnet_one_cidr
  tags = {
    Name = "PrivateSubnetOne-${var.environment}"
  }
}

resource "aws_subnet" "private_subnet_two" {
  availability_zone = "us-east-1d"
  vpc_id            = aws_vpc.vpc_devops.id
  cidr_block        = var.private_subnet_two_cidr
  tags = {
    Name = "PrivateSubnetTwo-${var.environment}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_devops.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "PublicRouteTable-${var.environment}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc_devops.id
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "PrivateRouteTable-${var.environment}"
  }
}

resource "aws_route_table_association" "public_subnet_one_association" {
  subnet_id      = aws_subnet.public_subnet_one.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_two_association" {
  subnet_id      = aws_subnet.public_subnet_two.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_one_association" {
  subnet_id      = aws_subnet.private_subnet_one.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_two_association" {
  subnet_id      = aws_subnet.private_subnet_two.id
  route_table_id = aws_route_table.private_route_table.id
}

# Launch Configuration
resource "aws_launch_configuration" "launch_configuartion" {
  name_prefix          = "launch_configuration-${var.environment}-${random_string.random.id}"
  image_id             = data.aws_ami.amazon_ami.id
  instance_type        = var.node_type
  security_groups      = [aws_security_group.instance_security_group.id]
  iam_instance_profile = aws_iam_instance_profile.instance_profile.id
  key_name             = "keypair"
  user_data            = file("userdata.sh")
  lifecycle {
    create_before_destroy = true
  }
}


# IAM Role for EC2 Instance
resource "aws_iam_role" "instance_iam_role" {
  name = "${var.environment}-instance_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "instance_iam_role-${var.environment}"
  }
}
# Instance Profile for Role
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.environment}-instance_profile"
  role = aws_iam_role.instance_iam_role.name
}

# Attach AWS Managed policies
resource "aws_iam_role_policy_attachment" "aws_managed_policy_attachment" {
  role       = aws_iam_role.instance_iam_role.name
  policy_arn = data.aws_iam_policy.ReadOnlyAccess.arn
}

# Instance Security Group
resource "aws_security_group" "instance_security_group" {
  name   = "${var.environment}-instance_security_group"
  vpc_id = aws_vpc.vpc_devops.id

  # Inbound SSH
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "5000"
    to_port     = "5000"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound All Protocols
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "instance-security-group-${var.environment}"
  }
}

resource "aws_autoscaling_group" "auto_scaling_group" {
  name_prefix          = "${aws_launch_configuration.launch_configuartion.name}-${var.environment}-auto_scaling_group"
  launch_configuration = aws_launch_configuration.launch_configuartion.name
  min_size             = 1
  max_size             = 2
  vpc_zone_identifier  = [aws_subnet.public_subnet_one.id, aws_subnet.public_subnet_two.id]
  lifecycle {
    create_before_destroy = true
  }
}