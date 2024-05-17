terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
        }
    }
}
provider "aws" {
    region = var.region
    access_key = var.access_key
    secret_key = var.secret_key
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "tf-example"
  }
}

resource "aws_internet_gateway" "test_env_gw" {
vpc_id = aws_vpc.my_vpc.id
}

resource "aws_security_group" "security" {
  name = "allow-all"

  vpc_id = aws_vpc.my_vpc.id

  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}                      

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "us-west-1b"

  tags = {
    Name = "tf-example"
  }
}

resource "aws_route" "internet-route" {
    destination_cidr_block = "0.0.0.0/0"
    route_table_id = aws_route_table.my-route-table.id
    gateway_id = aws_internet_gateway.test_env_gw.id
}

resource "aws_route_table" "my-route-table" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table_association" "name" {
  subnet_id = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my-route-table.id
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter{
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
  
}


resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "tf_key" {
  key_name   = "amit-test-ec2"
  public_key = tls_private_key.rsa.public_key_openssh
}


resource "local_file" "tf_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "keypair"

}

resource "aws_instance" "test_env_ec2" {
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t3.micro"
  security_groups             = ["${aws_security_group.security.id}"]
  associate_public_ip_address = true
  key_name = aws_key_pair.tf_key.key_name
  subnet_id = aws_subnet.my_subnet.id
  tags = {
   Name = "tf-example"
  }
}



resource "null_resource" "install_docker" {
depends_on = [aws_instance.test_env_ec2]
connection {
  type = "ssh"
  user = "ubuntu"
  host = aws_instance.test_env_ec2.public_dns
  private_key = file(local_file.tf_key.filename)
}

provisioner "remote-exec" {
    inline = [  "sudo apt update -y && sudo apt install docker.io -y", 
                "git clone https://github.com/amitgupta7/docker-es-job.git",
                "sudo docker build -t es-job docker-es-job",
                "sudo docker run -i es-job:latest",
                "sleep 1" ]  
}


}

output "hostnames" {
  value = aws_instance.test_env_ec2.public_dns
}