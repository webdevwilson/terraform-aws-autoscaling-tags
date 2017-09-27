locals {
  name = "asg_tag_instance"
  tags = {
    Name = "${local.name}"
    Foo  = "bar"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "main" {
  name          = "${local.name}"
  image_id      = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "main" {
  availability_zones   = ["us-east-1a"]
  name                 = "${local.name}"
  launch_configuration = "${aws_launch_configuration.main.name}"
  min_size             = 1
  max_size             = 5

  lifecycle {
    create_before_destroy = true
  }
}

module "add_tags" {
  source                  = "../"
  autoscaling_group_arn   = "${aws_autoscaling_group.main.arn}"
  tags                    = "${local.tags}"
}