provider "aws" {
region = "ap-south-1"
profile = "shailly"
}
resource "aws_vpc" "shaillyvpc1" {
cidr_block = "192.168.0.0/16"
instance_tenancy = "default"
tags = {
Name = "shaillyvpc1"
}
}
resource "aws_subnet" "shaillyvpc1_subnet-1a" {
vpc_id = "${aws_vpc.shaillyvpc1.id}"
cidr_block = "192.168.0.0/24"
availability_zone = "ap-south-1a"
map_public_ip_on_launch = true
}
resource "aws_subnet" "shaillyvpc1_subnet-1b" {
vpc_id = "${aws_vpc.shaillyvpc1.id}"
cidr_block = "192.168.1.0/24"
availability_zone = "ap-south-1b"
}
resource "aws_internet_gateway" "shaillyvpc1_internet_gateway" {
vpc_id = "${aws_vpc.shaillyvpc1.id}"
tags = {
Name = "shaillyvpc1_internet_gateway"
}
}
resource "aws_route_table" "shaillyvpc1_route_table" {
vpc_id = "${aws_vpc.shaillyvpc1.id}"
route {
cidr_block = "0.0.0.0/0"
gateway_id = "${aws_internet_gateway.shaillyvpc1_internet_gateway.id}"
}
tags = {
Name = "shaillyvpc1_route_table"
}
}
resource "aws_route_table_association" "a" {
subnet_id = aws_subnet.shaillyvpc1_subnet-1a.id
route_table_id = "${aws_route_table.shaillyvpc1_route_table.id}"
}
resource "aws_security_group" "shaillyweb" {
name = "shaillyweb"
description = "Allow ssh http and icmp"
vpc_id = "${aws_vpc.shaillyvpc1.id}"
ingress {
description = "http"
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
description = "ssh"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
description = "ICMP-IPv4"
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "shaillyweb"
}
}
resource "aws_security_group" "mysql" {
name = "shaillysql"
description = "Allow sql"
vpc_id = "${aws_vpc.shaillyvpc1.id}"
ingress {
description = "MYSQL"
security_groups=[ "${aws_security_group.shaillyweb.id}" ]
from_port = 3306
to_port = 3306
protocol = "tcp"
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "shaillysql"
}
}
resource "aws_security_group" "shahbastion" {
name = "shahbastion"
description = "Allow ssh for bastion"
vpc_id = "${aws_vpc.shaillyvpc1.id}"
ingress {
description = "ssh"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "shahbastion"
}
}
resource "aws_security_group" "shahsqlallow" {
name = "shahsqlallow"
description = "ssh allow to the mysql"
vpc_id = "${aws_vpc.shaillyvpc1.id}"
ingress {
description = "ssh"
security_groups=[ "${aws_security_group.shahbastion.id}" ]
from_port = 22
to_port = 22
protocol = "tcp"
}
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "shahsqlallow"
}
}
resource "aws_instance" "shahwordpress" {
ami = "ami-0cb39c5da8e2fa515"
instance_type = "t2.micro"
key_name = "shailly"
availability_zone = "ap-south-1a"
subnet_id = "${aws_subnet.shaillyvpc1_subnet-1a.id}"
security_groups = [ "${aws_security_group.shaillyweb.id}" ]
user_data = <<-EOF
#! /bin/bash
sudo yum install dnf install php-mysqlnd php-fpm httpd tar curl php-json -y
systemctl start httpd
systemctl enable httpd
curl https://wordpress.org/latest.tar.gz --output wordpress.tar.gz
tar xf wordpress.tar.gz
cp -r wordpress /var/www/html
chown -R apache:apache /var/www/html/wordpress
chcon -t httpd_sys_rw_content_t /var/www/html/wordpress -R
EOF
tags = {
Name = "shahwordpress"
}
}
resource "aws_instance" "shahsqlsecure" {
ami = "ami-02c9b9770f41dc7de"
instance_type = "t2.micro"
key_name = "shailly"
availability_zone = "ap-south-1b"
subnet_id = "${aws_subnet.shaillyvpc1_subnet-1b.id}"
security_groups = [ "${aws_security_group.mysql.id}" ,
"${aws_security_group.shahsqlallow.id}"]
user_data = <<-EOF
#! /bin/bash
sudo yum install @shaillysql -y
systemctl start shaillysqld
systemctl enable shaillysqld
EOF
tags = {
Name = "shahsqlsecure"
}
}
resource "aws_instance" "shahbastion" {
ami = "ami-073a8ab1b15e272e5"
instance_type = "t2.micro"
key_name = "shailly"
availability_zone = "ap-south-1a"
subnet_id = "${aws_subnet.shaillyvpc1_subnet-1a.id}"
security_groups = [ "${aws_security_group.shahbastion.id}" ]
tags = {
Name = "shahbastion"
}
}
resource "aws_eip" "shaillyvpc1_eip" {
vpc = true
}
resource "aws_nat_gateway" "shaillyvpc1_nat_gateway" {
allocation_id = "${aws_eip.shaillyvpc1_eip.id}"
subnet_id = "${aws_subnet.shaillyvpc1_subnet-1b.id}"
tags = {
Name = "shaillyvpc1_nat_gateway"
}
}
resource "aws_route_table" "shaillyvpc1_route_table2" {
vpc_id = "${aws_vpc.shaillyvpc1.id}"
route {
cidr_block = "0.0.0.0/0"
nat_gateway_id = "${aws_nat_gateway.shaillyvpc1_nat_gateway.id}"
}
}
