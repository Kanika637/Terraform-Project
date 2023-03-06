provider "aws" {
    region = "us-east-1"
    access_key = "AKIAQFSVKXY3P7JUIMWP"
    secret_key = "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"
}

//vpc

resource "aws_vpc" "my_first_vpc" {
  cidr_block = "10.0.0.0/16"
  tags={
    Name: "production"
  }
}

//subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.my_first_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

//internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_first_vpc.id

  tags = {
    Name = "gate"
  }
}

//route table

resource "aws_route_table" "prod-table" {
  vpc_id = aws_vpc.my_first_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-table"
  }
}

//aws route table association

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-table.id
}

// security grp

resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.my_first_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
}
ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
}
ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
}

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_tls"
  }
}

//network interface

resource "aws_network_interface" "network-interface" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}

//eip

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.network-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

//server

resource "aws_instance" "web-server" {
  ami           = "ami-00874d747dde814fa"
  instance_type = "t3.micro"
  key_name = "terraform-key"
  availability_zone = "us-east-1a"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.network-interface.id
  }

user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo your very first web server > /var/www/html/index.html'
            EOF

tags={
    Name= "web-server"
}
}