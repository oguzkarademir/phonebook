terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.8.0"
    } 
    github = {
      source = "integrations/github"
      version = "4.23.0"
    }
  }
}

# Configure the AWS Provider

provider "aws" {
  region = "us-east-1"
}

provider "github" {
  token = "xxxxxxxxxxxxxxxxxxxxxxxxxxx"   # write your github token here
}

data "aws_vpc" "selected" {
  default = true
}

data "aws_subnets" "pb-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

data "aws_ami" "amazon-linux-2" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10*"]
  }
}

# Launch Template Resource

resource "aws_launch_template" "pb_lt" {
  name = "pb-launch-template"
  image_id = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  key_name = "firstkey"
  vpc_security_group_ids = [aws_security_group.pb_webservers_sec_gr.id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "pb-webserver"
    }
  }
  user_data = filebase64("user-data.sh")
  depends_on = [github_repository_file.dbendpoint]
}

# Target Group Resource

resource "aws_alb_target_group" "pb-tg" {
  name = "phonebook-lb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.selected.id
  target_type = "instance"

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 3
  }
}

# Load Balancer

resource "aws_alb" "pb-alb" {
  name = "phonebook-lb-tf"
  ip_address_type = "ipv4"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.pb_alb_sec-gr.id]
  subnets = data.aws_subnets.pb-subnets.ids
}

resource "aws_alb_listener" "pb_alb_listener" {
  load_balancer_arn = aws_alb.pb-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.pb-tg.arn
  }
}

# Auto Scaling Resource

resource "aws_autoscaling_group" "pb-asg" {
  name = "phonebook-asg"
  desired_capacity   = 2
  max_size           = 3
  min_size           = 1
  health_check_grace_period = 300
  health_check_type = "ELB"
  target_group_arns = [aws_alb_target_group.pb-tg.arn]
  vpc_zone_identifier = aws_alb.pb-alb.subnets

  launch_template {
    id      = aws_launch_template.pb_lt.id
    version = aws_launch_template.pb_lt.latest_version
  }
}

# RDS Resource

resource "aws_db_instance" "pb_rds" {
  allocated_storage    = 20
  allow_major_version_upgrade = false
  auto_minor_version_upgrade = true
  instance_class       = "db.t2.micro"
  backup_retention_period = 0
  identifier = "phonebook-app-db"
  db_name = "phonebook"
  vpc_security_group_ids = [aws_security_group.pb_rds_sec_gr.id]
  engine               = "mysql"
  engine_version       = "8.0.28"
  username             = "admin"       # username and password should be the same with in .py file
  password             = "oguz_12345"  # fill in your password
  port = 3306
  monitoring_interval = 0
  multi_az = false
  publicly_accessible = false
  skip_final_snapshot = true
}

resource "github_repository_file" "dbendpoint" {
  content = aws_db_instance.pb_rds.address
  file = "dbserver.endpoint"
  repository = "phonebook"
  overwrite_on_create = true
  branch = "main"
}