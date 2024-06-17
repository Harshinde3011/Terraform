provider "aws" {
  region = "ap-south-1"
}

variable "cidr" {
  default = "10.0.0.0/16"
}

resource "aws_key_pair" "example" {
  key_name = "harsh-pub-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_internet_gateway" "MyIGW" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_subnet" "pub_subnet-1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "MyRoute" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MyIGW.id
  }

  tags = {
    Name = "MyRouteTable"
  }
}


resource "aws_route_table_association" "RouteAssociation" {
  subnet_id = aws_subnet.pub_subnet-1.id
  route_table_id = aws_route_table.MyRoute.id
}

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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
    Name = "Web-sg"
  }
}

resource "aws_instance" "MyServer" {
    ami = "ami-0f58b397bc5c1f2e8"
    instance_type = "t2.micro"
    key_name = aws_key_pair.example.key_name
    subnet_id = aws_subnet.pub_subnet-1.id
    vpc_security_group_ids = [ aws_security_group.webSg.id ]

    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.public_ip
    }

    # provisioner which will copy your app.py form local to remote ec2

    provisioner "file" {
      source = "app.py"
      destination = "/home/ubuntu/app.py"
    }

    provisioner "remote-exec" {
      inline = [ 
        "echo 'hello form remote instance'",
        "sudo su",
        "cd /home/ubuntu",
        "sudo apt-get update -y",
        "sudo apt-get install -y python3-pip python3-venv",
        "sudo python3 -m venv /home/ubuntu/venv",
        "sudo source /venv/bin/activate",
        "sudo pip install flask",
        "sudo python3 app.py",
       ]
    }
}

