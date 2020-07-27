provider "aws" {
  region  = "ap-south-1"
  profile = "jaggu"
}

resource "tls_private_key" "task-3-pri-key" { 
  algorithm   = "RSA"
  rsa_bits = 2048
}

resource "aws_key_pair" "task-3-key" {
  depends_on = [ tls_private_key.task-3-pri-key, ]
  key_name   = "task-3-key"
  public_key = tls_private_key.task-3-pri-key.public_key_openssh
}

# Create a VPC
resource "aws_vpc" "task-3-vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
 enable_dns_support = true

  tags = {
    Name = "task-3-vpc"
  }
}

resource "aws_subnet" "public" {
  depends_on = [aws_vpc.task-3-vpc, ]
  vpc_id     = aws_vpc.task-3-vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch  =  true
  tags = {
    Name = "Public"
  }
}
resource "aws_subnet" "private" {
  depends_on = [ aws_vpc.task-3-vpc,
                  aws_subnet.public, ]
  vpc_id     = aws_vpc.task-3-vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
    tags = {
    Name = "Private"
  }
}
resource "aws_internet_gateway" "task-3-gw" {
  depends_on = [ aws_vpc.task-3-vpc,
                   aws_subnet.public, ]
  vpc_id = aws_vpc.task-3-vpc.id

  tags = {
    Name = "task-3-gw"
  }
}
resource "aws_route_table" "task-3-rt" {
  depends_on = [aws_internet_gateway.task-3-gw, ]
  vpc_id = aws_vpc.task-3-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task-3-gw.id
  }
  
  tags = {
    Name = "task-3-rt"
  }
}
resource "aws_route_table_association" "a" {
   depends_on = [ aws_route_table.task-3-rt, ]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.task-3-rt.id
}

resource "aws_security_group" "sg_wp" {
 depends_on = [ aws_vpc.task-3-vpc, ]
  name        = "sg_wp"
  description = "All HTTP inbound traffic"
  vpc_id      = aws_vpc.task-3-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
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
    Name = "sg_wp"
  }
}
resource "aws_security_group" "mysql_sg" {
  depends_on = [ aws_vpc.task-3-vpc,
                   aws_security_group.sg_wp, ]
  name        = "mysql_sg"
  description = "Allow MYSQL inbound traffic"
  vpc_id      = aws_vpc.task-3-vpc.id

  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_wp.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MYSQL_SG"
  }
}
resource "aws_security_group" "basetion_sg" {
  depends_on = [ aws_vpc.task-3-vpc, ] 
  name        = "basetion_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.task-3-vpc.id

  ingress {
    description = "SSH from VPC"
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
    Name = "BASTION_SG"
  }
}
resource "aws_security_group" "basetion_sg2" {
  depends_on = [ aws_vpc.task-3-vpc,
                   aws_security_group.basetion_sg, ] 
  name        = "basetion_sg2"
  description = "Allow SSH from bastion inlyinbound traffic"
  vpc_id      = aws_vpc.task-3-vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.basetion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BASTION_SG2"
  }
}

resource "aws_instance" "wordpress" {
 depends_on = [ aws_vpc.task-3-vpc,
                  aws_key_pair.task-3-key,
                  aws_subnet.public,
                  aws_security_group.sg_wp, ]
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  key_name = "task-3-key"
  vpc_security_group_ids = [ aws_security_group.sg_wp.id]
  subnet_id = aws_subnet.public.id
 tags = {
    Name = "WordPress"
  }
}


resource "aws_instance" "baston" {
 depends_on = [ aws_vpc.task-3-vpc,
                  aws_key_pair.task-3-key,
                  aws_subnet.public,
                  aws_security_group.basetion_sg, ]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name = "task-3-key"
  vpc_security_group_ids = [ aws_security_group.basetion_sg.id]
  subnet_id = aws_subnet.public.id
 tags = {
    Name = "Baseton_OS"
  }
}
resource "aws_instance" "mysql" {
depends_on = [ aws_vpc.task-3-vpc,
                  aws_key_pair.task-3-key,
                  aws_subnet.private,
                  aws_security_group.basetion_sg2,
                  aws_security_group.mysql_sg, ]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name = "task-3-key"
  vpc_security_group_ids = [ aws_security_group.basetion_sg2.id , aws_security_group.mysql_sg.id]
  subnet_id = aws_subnet.private.id
 tags = {
    Name = "Baseton_OS"
  }
}
