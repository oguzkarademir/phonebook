resource "aws_security_group" "pb_alb_sec-gr" {
  name = "pb-alb-sec-group"
  vpc_id = data.aws_vpc.selected.id
  tags = {
      Name = "pb_alb_sec_gr_tag"
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "pb_webservers_sec_gr" {
  name = "pb-webservers-sec-group"
  vpc_id = data.aws_vpc.selected.id
  tags = {
      Name = "pb_webserver_sec_gr_tag"
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    security_groups =[aws_security_group.pb_alb_sec-gr.id]
  }
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "pb_rds_sec_gr" {
  name = "rpb-rds-sec-group"
  vpc_id = data.aws_vpc.selected.id
  tags = {
      Name = "pb_rds_sec_gr_tag"
  }

  ingress {
    from_port   = 3306
    protocol    = "tcp"
    to_port     = 3306
    security_groups = [aws_security_group.pb_webservers_sec_gr.id]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}