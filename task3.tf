#####################
# Declaring  Provider
#####################
provider "aws" {
  region = "ap-south-1"
 // your profile for AWS here.
 profile = "honey"   
}


##############
# Creating VPC
##############
resource "aws_vpc" "MyOwnVPC" {
  cidr_block           = "192.168.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}


################################################
# Creating and attaching internet gateway to VPC
################################################
resource "aws_internet_gateway" "gw" {
  depends_on = [
    aws_vpc.MyOwnVPC,
  ]
  vpc_id = aws_vpc.MyOwnVPC.id

  tags = {
    Name = "MyGateway"
  }
}

################################
# Subnet in 1a Availability zone
################################
resource "aws_subnet" "subnet1-1a" {
  depends_on = [
    aws_vpc.MyOwnVPC,
  ]
  vpc_id = aws_vpc.MyOwnVPC.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "FirstSubnet"
  }
}


#############################
# Route table for FirstSubnet
#############################
resource "aws_route_table" "route" {
  depends_on = [
    aws_vpc.MyOwnVPC,
    aws_internet_gateway.gw,
  ]
  vpc_id = aws_vpc.MyOwnVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "MyRouteTable"
  }
}


#####################################################
# Associating route table created above to subnet1-1a
#####################################################
resource "aws_route_table_association" "a" {
  depends_on = [
    aws_subnet.subnet1-1a,
    aws_route_table.route,
  ]
  subnet_id      = aws_subnet.subnet1-1a.id
  route_table_id = aws_route_table.route.id
}


################################
# Subnet in 1b Availability zone
################################
resource "aws_subnet" "subnet2-1b" {
  depends_on = [
    aws_vpc.MyOwnVPC,
  ]
  vpc_id = aws_vpc.MyOwnVPC.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "SecondSubnet"
  }
}


###################
# Creating Key Pair
###################
resource "tls_private_key" "webserver_key"  {
    algorithm = "RSA"
    rsa_bits =   4096
}


##########################################
# Creating a file for key on local system.
##########################################
resource "local_file" "private_key" {
  depends_on = [
    tls_private_key.webserver_key,
  ]
  content = tls_private_key.webserver_key.private_key_pem
  filename = "Task3-key.pem"
  file_permission = 0777
}


##########################
# Public key saved in AWS 
##########################
resource "aws_key_pair" "webserver_key"{
  key_name = "mynewkey"
  public_key = tls_private_key.webserver_key.public_key_openssh
}


################################
# Creating Security Group for 1a
################################
resource "aws_security_group" "allow_traffic_1" {
  name        = "allowed_traffic_1"
  vpc_id      = aws_vpc.MyOwnVPC.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


################################
# Creating Security Group for 1b
################################
resource "aws_security_group" "allow_traffic_2" {
  name        = "allowed_traffic_2"
  vpc_id      = aws_vpc.MyOwnVPC.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

########################
# Instance for wordpress
########################
resource "aws_instance" "ins1"{
depends_on = [
    aws_key_pair.webserver_key,
    aws_security_group.allow_traffic_1,
    aws_subnet.subnet1-1a,
  ]

  ami                    = "ami-000cbce3e1b899ebd" 
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1-1a.id
  key_name               = aws_key_pair.webserver_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic_1.id]

    tags = {
    Name = "WordpressOS"
 }
}

####################
# Instance for mysql
####################
resource "aws_instance" "ins2"{
depends_on = [
    aws_key_pair.webserver_key,
    aws_security_group.allow_traffic_2,
    aws_subnet.subnet2-1b,
  ]

  ami                    = "ami-0019ac6129392a0f2" 
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet2-1b.id
  key_name               = aws_key_pair.webserver_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic_2.id]

    tags = {
    Name = "MySQL_OS"
 }
}
