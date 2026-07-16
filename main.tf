terraform {
  required_version = ">=1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 0. Configure the AWS provider

provider "aws" {
  region = "us-east-1"
}

# 1. Create a VPC with CIDR block

resource "aws_vpc" "lab_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terraform-Lab-VPC"
  }
}

# 2. Create a public subnet in the VPC
resource "aws_subnet" "public_subnet" {

  vpc_id = aws_vpc.lab_vpc.id

  cidr_block = "10.0.1.0/24"

  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true

  tags = {
    Name = "Terraform-Public-Subnet"
  }
}

# 3. Create an Internet Gateway and attach it to the VPC
resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Terraform-IGW"
  }
}

# 4. Create a route table and associate it with the public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "Terraform-Public-RT"
  }
}

# 5. Add a route to the Internet Gateway in the route table
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# 6. Create a Association between the route table and the public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# Step 2. create an EC2 instance in the public subnet

# 1. Create a security group for the EC2 instance
resource "aws_security_group" "web_sg" {
  name        = "Terraform-Web-SG"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.lab_vpc.id

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
  tags = {
    Name = "Terraform-Web-SG"
  }
}
# Create a key pair for SSH access to the EC2 instance

# 1. Generate a private key using the TLS provider
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2. Create the AWS Key Pair using the public key from the step above
resource "aws_key_pair" "deployer" {
  key_name   = "lab-key"
  public_key = tls_private_key.example.public_key_openssh
}

# 3. Save the private key locally as a .pem file (chmod 400 is recommended afterward)
resource "local_file" "private_key" {
  content  = tls_private_key.example.private_key_pem
  filename = "{path-to-your-key-file}/my-aws-key.pem"
}

# 4. Output the key name for reference
output "key_name" {
  value       = aws_key_pair.deployer.key_name
  description = "The name of the AWS Key Pair"
}

# Continue with the EC2 instance creation
# 2. Create an EC2 instance in the public subnet
# Ami id from bash = ami-0fd6240f599091088 (bash on 15.07.2026)
resource "aws_instance" "web_instance" {
  ami                    = "ami-0fd6240f599091088"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  associate_public_ip_address = true

  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name = "Terraform-Web-Server"
  }
}

# Output all the resources created in this lab

output "hello_world" {
  value = "Hello, World!"
}

output "vpc_id" {
  value = aws_vpc.lab_vpc.id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id
}

output "route_table_id" {
  value = aws_route_table.public_rt.id
}
output "route_table_association_id" {
  value = aws_route_table_association.public_assoc.id
}

output "subnet_id" {
  value = aws_subnet.public_subnet.id
}
output "security_group_id" {
  value = aws_security_group.web_sg.id
}
output "instance_id" {
  value = aws_instance.web_instance.id
}