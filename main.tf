# Specify the region in which we would want to deploy our stack
variable "region" {
  default = "ca-central-1"
}

# Specify 3 availability zones from the region
variable "availability_zones" {
  default = ["ca-central-1a", "ca-central-1b"]
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ca-central-1"
}



# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "tf_vpc"
  }
}

# Create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id 

  tags = {
    Name = "tf_igw"
  }
}

# Create Route Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "tf-rt"
  }
}

# Create Public Subnet
resource "aws_subnet" "pub_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ca-central-1b"


  tags = {
    Name = "pub-tf-subnet"
  }
}

resource "aws_route_table_association" "sub_association" {
  subnet_id      = aws_subnet.pub_subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Create Elastic IP for Ngw
resource "aws_eip" "nat_eip" {
  vpc      = true
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "tf-ngw-eip"
  }
}

# Create Ngw
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_subnet.id

  tags = {
    Name = "tf-ngw"
  }
}

# Create Pri Route table
resource "aws_route_table" "pri_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "tf-pri-rt"
  }
}

# Create Private Subnet
resource "aws_subnet" "pri_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ca-central-1b"

  tags = {
    Name = "pri-tf-subnet"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.pri_subnet.id
  route_table_id = aws_route_table.pri_route_table.id
}

# Create Security group with port 22 & 443
resource "aws_security_group" "ssh_https_sg" {
  name        = "allow_https_ssh"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


 ingress {
    description      = "ssh traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_https_ssh"
  }
}

# Create Pri Subnet for Ec2
resource "aws_subnet" "ec2_pri_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/28"
  availability_zone = "ca-central-1a"

  tags = {
    Name = "pri-tf-subnet"
  }
}


# Create EC2 in Public Subnet
resource "aws_instance" "public_instance" {
    ami = "ami-066a5db48807613c7"
    instance_type = "t2.micro"
    vpc_security_group_ids = ["sg-00c154c5eb7d2c57a"]
    subnet_id = "subnet-0e1b214f111639986"
    key_name = "my-demo-key-pair"
    count = 1
    associate_public_ip_address = true 
    availability_zone = "ca-central-1b"
    tags = {
      "Name" = "tf-pub-instance"
    }
  
}

# Create Security Group for rds
resource "aws_security_group" "tcp_sg" {
  name        = "allow_tcp"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "port_5432"
  }
}

# Create DB Subnet Group
resource "aws_db_subnet_group" "db_sub_grp" {
  name       = "dbsub"
  subnet_ids = [aws_subnet.ec2_pri_subnet.id, aws_subnet.pri_subnet.id]

  tags = {
    Name = "tf-sub-grp"
  }
}

# Create RDS MySQL in Pri Subnet
resource "aws_db_instance" "pri_rds" {
    identifier = "mydbcluster"
    engine = "mysql"
    engine_version = "8.0.28"
    instance_class = "db.m5d.xlarge"
    name = "db_rds"
    username = "christinaedube"
    password = "Graceemeh1"
    allocated_storage = "100"
    db_subnet_group_name = "dbsub"
    vpc_security_group_ids = ["sg-0bbf0811de2721de2"]
    parameter_group_name = "default.mysql8.0"
    skip_final_snapshot = true

  
}
