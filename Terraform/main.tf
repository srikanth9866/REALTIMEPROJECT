terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Creating a New Key
resource "aws_key_pair" "Key-Pair" {

  # Name of the Key
  key_name = "MyKey"

  # Adding the SSH authorized key !
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDf+Z45qTZWlOzt4BasMulLwZEeBuP7W9WIQxifaQDTKSESf2v+jYTS+nE+xYkxAF8rwMKIbyTcreg9TjPah0O/3FfxRwkCEcAQYrP3DLQK5h2Tv56k3FmsX8gmmLrPFThDeYFKbai6JIcptA/s+z+5udTUDa+Ud6tnMesh5dLVSqqH0LjxsJ6wz+fLwPQDAy92AyzEHpgBJDQYNNMfoc2bl6yU8t4kPly1LSzzEjC92SsZU7UCt6dCiA1QE3ZlmblKSmoTTfX6wv+t/zbyTh8rbKmkFzRlq0yR6xZrgZGZ4lkw1WP/Q/aZoDBmSdTry85MTYZptPgly1vp94FCw6fa8/TaEZuhGgg0/ylmDVkDrZIho6YeIINM8WLN5RkDkvSWuNIxsk2eSPnkyIBcOH0+bc3cjmBJvr4gQIn0UPR+jh//gOx5h3jb1Layw8nxCUtyIHR1u8pGX3xpieTqyjjbWdFk/0yEM/s1dGqBkCMan8+rMVOkj7AupbBhO/FuUYM= Madhu Kiran@DESKTOP-I148625"

}


# Creating a VPC!
resource "aws_vpc" "demo" {

  # IP Range for the VPC
  cidr_block = "172.20.0.0/16"

  # Enabling automatic hostname assigning
  enable_dns_hostnames = true
  tags = {
    Name = "demo"
  }
}


# Creating Public subnet!
resource "aws_subnet" "subnet1" {
  depends_on = [
    aws_vpc.demo
  ]

  # VPC in which subnet has to be created!
  vpc_id = aws_vpc.demo.id

  # IP Range of this subnet
  cidr_block = "172.20.10.0/24"

  # Data Center of this subnet.
  availability_zone = "us-east-1a"

  # Enabling automatic public IP assignment on instance launch!
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}



# Creating an Internet Gateway for the VPC
resource "aws_internet_gateway" "Internet_Gateway" {
  depends_on = [
    aws_vpc.demo,
    aws_subnet.subnet1,
  ]

  # VPC in which it has to be created!
  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "IG-Public-&-Private-VPC"
  }
}

# Creating an Route Table for the public subnet!
resource "aws_route_table" "Public-Subnet-RT" {
  depends_on = [
    aws_vpc.demo,
    aws_internet_gateway.Internet_Gateway
  ]

  # VPC ID
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet_Gateway.id
  }

  tags = {
    Name = "Route Table for Internet Gateway"
  }
}

# Creating a resource for the Route Table Association!
resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.demo,
    aws_subnet.subnet1,
    aws_route_table.Public-Subnet-RT
  ]

  # Public Subnet ID
  subnet_id = aws_subnet.subnet1.id

  #  Route Table ID
  route_table_id = aws_route_table.Public-Subnet-RT.id
}

# Creating a Security Group for Jenkins
resource "aws_security_group" "JENKINS-SG" {

  depends_on = [
    aws_vpc.demo,
    aws_subnet.subnet1,
  ]

  description = "HTTP, PING, SSH"

  # Name of the security Group!
  name = "jenkins-sg"

  # VPC ID in which Security group has to be created!
  vpc_id = aws_vpc.demo.id

  # Created an inbound rule for webserver access!
  ingress {
    description = "HTTP for webserver"
    from_port   = 80
    to_port     = 8080

    # Here adding tcp instead of http, because http in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for ping
  ingress {
    description = "Ping"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22

    # Here adding tcp instead of ssh, because ssh in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outward Network Traffic for the WordPress
  egress {
    description = "output from webserver"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating security group for MyApp, this will allow access only from the instances having the security group created above.
resource "aws_security_group" "MYAPP-SG" {

  depends_on = [
    aws_vpc.demo,
    aws_subnet.subnet1,
    aws_security_group.JENKINS-SG
  ]

  description = "MyApp Access only from the Webserver Instances!"
  name        = "myapp-sg"
  vpc_id      = aws_vpc.demo.id

  # Created an inbound rule for MyApp
  ingress {
    description     = "MyApp Access"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.JENKINS-SG.id]
  }

  # Created an inbound rule for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22

    # Here adding tcp instead of ssh, because ssh in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "output from MyApp"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating an AWS instance for the Jenkins!
resource "aws_instance" "jenkins" {

  depends_on = [
    aws_vpc.demo,
    aws_subnet.subnet1,
    aws_security_group.JENKINS-SG
  ]

  ami           = "ami-09d3b3274b6c5d4aa" 
  # amazoon-linux
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet1.id

  # Keyname and security group are obtained from the reference of their instances created above!
  # Here I am providing the name of the key which is already uploaded on the AWS console.
  key_name = "MyKey"

  # Security groups to use!
  vpc_security_group_ids = [aws_security_group.JENKINS-SG.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y epel",
      "sudo yum install wget ",
 #    "sudo yum update -y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key",
      "sudo yum update -y",
      "sudo amazon-linux-extras install java-openjdk11 -y",	  
      "sudo yum install jenkins -y",
 	    "sudo systemctl start jenkins",	 
	    "sudo yum install git maven -y",
#     "sudo yum install git python3 python3-pip maven -y",
#     "python3 -m pip install --upgrade pip",
      "sudo systemctl daemon-reload",
      "sudo yum install ansible -y",
#      "yes | sudo pip3 install ansible",
      "sudo amazon-linux-extras install docker -y",
      "sudo service docker start",
      "sudo usermod -aG docker $USER",
      "sudo usermod -aG docker jenkins",
      "sudo systemctl enable docker.service",
      "sudo systemctl enable containerd.service",
      "sudo service docker restart",
    ]
  }
  tags = {
    Name = "Jenkins_From_Terraform"
  }

}

# Creating an AWS instance for the MyApp! It should be launched in the private subnet!
resource "aws_instance" "MyApp" {
  depends_on = [
    aws_instance.jenkins,
  ]

  # i.e. MyApp Installed!
  ami           = "ami-09d3b3274b6c5d4aa"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet1.id

  # Keyname and security group are obtained from the reference of their instances created above!
  key_name = "MyKey"


  # Attaching 2 security groups here, 1 for the MyApp Database access by the Web-servers,
  vpc_security_group_ids = [aws_security_group.MYAPP-SG.id]

  tags = {
    Name = "MyApp_From_Terraform"
  }
}
