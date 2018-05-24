provider "aws" {
  region     = "us-east-1"
}

resource "aws_key_pair" "CompanyNewsKey" {
  key_name   = "companynews-key"
  public_key = "${file("../.ssh/id_rsa.pub")}"
}

resource "aws_vpc" "CompanyNewsVPC" {
  cidr_block = "10.0.0.0/16"
  
  tags {
    Name = "companyNews-vpc"
  }
  
}

resource "aws_subnet" "CompanyNewsPublic" {
  vpc_id = "${aws_vpc.CompanyNewsVPC.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags {
    Name = "companyNews-public"
  }
}

resource "aws_internet_gateway" "CompanyNewsIGW" {
    vpc_id = "${aws_vpc.CompanyNewsVPC.id}"

    tags {
        Name = "companyNews-igw"
    }
}

resource "aws_route_table" "CompanyNewsRT" {
    vpc_id = "${aws_vpc.CompanyNewsVPC.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.CompanyNewsIGW.id}"
    }

    tags {
        Name = "CompanyNews-rt"
    }
}

resource "aws_route_table_association" "CompanyNewsRTAssoc" {
  subnet_id      = "${aws_subnet.CompanyNewsPublic.id}"
  route_table_id = "${aws_route_table.CompanyNewsRT.id}"
}

resource "aws_security_group" "CompanyNewsSGAppl" {
  name        = "SG for Application"
  description = "Allow 8080 & 22 traffic"
  vpc_id      = "${aws_vpc.CompanyNewsVPC.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8009
    to_port     = 8009
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

resource "aws_security_group" "CompanyNewsSGWeb" {
  name        = "SG for Web"
  description = "Allow 8080 & 22 traffic"
  vpc_id      = "${aws_vpc.CompanyNewsVPC.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_instance" "CompanyNewsWeb" {
  ami = "${var.ubuntu_image}"
  instance_type = "t2.micro"
  key_name="${aws_key_pair.CompanyNewsKey.key_name}"
  subnet_id = "${aws_subnet.CompanyNewsPublic.id}"
  security_groups=["${aws_security_group.CompanyNewsSGWeb.id}"]
  associate_public_ip_address = true
  tags {
    Name = "CompanyNewsWeb"
  }
}

resource "aws_instance" "CompanyNewsAppl" {
  ami = "${var.ubuntu_image}"
  instance_type = "t2.micro"
  key_name="${aws_key_pair.CompanyNewsKey.key_name}"
  subnet_id = "${aws_subnet.CompanyNewsPublic.id}"
  security_groups=["${aws_security_group.CompanyNewsSGAppl.id}"]
  associate_public_ip_address = true
  tags {
    Name = "CompanyNewsAppl"
  }
    
}