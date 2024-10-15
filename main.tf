provider "aws" {
  region = "us-east-1"
}

# VPC creation
resource "aws_vpc" "my_project_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnet creation (two public, two private in two AZs)
resource "aws_subnet" "public_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.my_project_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_project_vpc.cidr_block, 4, count)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnets" {
  count             = 2
  vpc_id            = aws_vpc.my_project_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_project_vpc.cidr_block, 4, count + 2)
  availability_zone = element(var.azs, count.index)
}

# Internet Gateway
resource "aws_internet_gateway" "my_project_igw" {
  vpc_id = aws_vpc.my_project_vpc.id
}

# Route Table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_project_vpc.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_project_igw.id
}

# Bastion Host Configuration
resource "aws_instance" "bastion_host" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = "bastion_key" # SSH key for bastion host access
  subnet_id     = aws_subnet.public_subnets[0].id
}

# Auto Scaling Group and Launch Configuration
resource "aws_launch_configuration" "my_project_launch_config" {
  image_id                    = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type               = "t2.micro"
  associate_public_ip_address = false
  key_name                    = "bastion_key" # SSH key for bastion host access
}

resource "aws_autoscaling_group" "my_project_asg" {
  vpc_zone_identifier  = aws_subnet.private_subnets[*].id
  launch_configuration = aws_launch_configuration.my_project_launch_config.id
  min_size             = 2
  max_size             = 2
  desired_capacity     = 2
}

# Load Balancer in one public subnet
resource "aws_lb" "my_project_lb" {
  name               = "my-project-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [aws_subnet.public_subnets[0].id]
}

# Output private IPs for Ansible inventory
output "private_instance_ips" {
  value = aws_instance.private_instance[*].private_ip
}
