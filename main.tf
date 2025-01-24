provider "aws" {
  region = "eu-west-1" # Changez selon votre région
}

# VPC
resource "aws_vpc" "nomad_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "nomad-vpc"
  }
}

# Subnet
resource "aws_subnet" "nomad_subnet" {
  vpc_id                  = aws_vpc.nomad_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "nomad-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "nomad_igw" {
  vpc_id = aws_vpc.nomad_vpc.id

  tags = {
    Name = "nomad-igw"
  }
}

# Route Table
resource "aws_route_table" "nomad_rt" {
  vpc_id = aws_vpc.nomad_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nomad_igw.id
  }

  tags = {
    Name = "nomad-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "nomad_rta" {
  subnet_id      = aws_subnet.nomad_subnet.id
  route_table_id = aws_route_table.nomad_rt.id
}

# Security Group
resource "aws_security_group" "nomad_sg" {
  vpc_id = aws_vpc.nomad_vpc.id

  ingress {
    from_port   = 4646
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restrict to the private network
  }

  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restrict to the private network
  }

  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restrict to the private network
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restrict to the private network
  }

  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restrict to the private network
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

  tags = {
    Name = "nomad-sg"
  }
}

# Nomad Server Instance
resource "aws_instance" "nomad_server" {
  ami             = "ami-0fa8eaa89da54d46b" # Amazon Linux 2
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.nomad_subnet.id
  security_groups = [aws_security_group.nomad_sg.id]
  key_name        = "key-nomad"

  tags = {
    Name = "nomad-server"
  }

  user_data = file("${path.module}/scripts/server_install.sh")
}

output "nomad_server_private_ip" {
  value = aws_instance.nomad_server.private_ip
}

output "nomad_server_public_ip" {
  value = aws_instance.nomad_server.public_ip
}



# Nomad Client Instance
resource "aws_instance" "nomad_client" {
  count           = 2
  ami             = "ami-0fa8eaa89da54d46b" # Amazon Linux 2
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.nomad_subnet.id
  security_groups = [aws_security_group.nomad_sg.id]
  key_name        = "key-nomad"
  depends_on = [aws_instance.nomad_server]
  
  tags = {
    Name = "nomad-client"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./key-nomad.pem") 
      host        = self.public_ip
    }

    source      = "./scripts/client_install.sh"
    destination = "/home/ec2-user/client_install.sh"
  }

  user_data = <<-EOF
    #!/bin/bash
    sleep 30
    chmod +x /home/ec2-user/client_install.sh
    bash /home/ec2-user/client_install.sh ${aws_instance.nomad_server.private_ip}
    rm /home/ec2-user/client_install.sh
    exit 0
  EOF
}
