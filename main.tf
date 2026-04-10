resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"  
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

}


resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"  
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true    
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id

}

resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }      
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "web-sg" {
    name = "allow_tls"
    description = "Allow TLS traffic"
    vpc_id = aws_vpc.myvpc.id

    ingress {
        description = "HTTP from VPC"
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

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "web-sg"
    }
}

resource "aws_s3_bucket" "web" {
    bucket = "devops-terraform-project-bucket"
    tags = {
        Name = "web-bucket"
    }
}


resource "aws_s3_bucket_acl" "web" {
    bucket = aws_s3_bucket.web.id
    acl = "public-read"
}

resource "aws_instance" "web-server1" {
    ami = "ami-04680790a315cd58d"
    instance_type = "t3.micro"
    subnet_id = aws_subnet.sub1.id
    security_groups = [aws_security_group.web-sg.id]
    user_data = base64encode(file("userdata.sh"))

    tags = {
        Name = "web-server"
    }
}

resource "aws_instance" "web-server2" {
    ami = "ami-04680790a315cd58d"
    instance_type = "t3.micro"
    subnet_id = aws_subnet.sub2.id
    security_groups = [aws_security_group.web-sg.id]
    user_data = base64encode(file("userdata1.sh"))

    tags = {
        Name = "web-server2"
    }
}

resource "aws_lb" "web-alb" {
    name = "web-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.web-sg.id]
    subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

    tags = {
        Name = "web-alb"
    }
} 

resource "aws_lb_target_group" "web-alb-target-group" {
    name = "web-alb-target-group"
    port = 80
    protocol = "HTTP"
    target_type = "instance"
    vpc_id = aws_vpc.myvpc.id

    health_check {
        path = "/"
        port = 80
        protocol = "HTTP"
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 5
        interval = 30
    }

    tags = {
        Name = "web-alb-target-group"
    }
}

resource "aws_lb_target_group_attachment" "web-alb-target-group-attachment1" {
  
  target_group_arn = aws_lb_target_group.web-alb-target-group.arn
  target_id = aws_instance.web-server1.id
  port = 80
  
}

resource "aws_lb_target_group_attachment" "web-alb-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.web-alb-target-group.arn
  target_id = aws_instance.web-server2.id
  port = 80
}

resource "aws_lb_listener" "web-alb-listener" {
  load_balancer_arn = aws_lb.web-alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-alb-target-group.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.web-alb.dns_name
}