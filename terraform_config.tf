# File: terraform_config.tf
# Author: Tim Siwula <tcsiwula@usfca.edu>
# Date: Wed Jul 13th 2016
# This is a terraform script that will bootstrap an autoscaling group on AWS preinstalled with nginx. Access rights restricted to ELB only.
# Update: terraform get
# Complie: terraform plan
# Run: terraform apply
# Stop: terraform destroy
#
#   docs:
#   https://aws.amazon.com/blogs/apn/terraform-beyond-the-basics-with-aws/
#   https://github.com/terraform-community-modules/tf_aws_asg_elb
#   https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html
#   https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html
#   https://github.com/hashicorp/terraform/tree/master/examples


# ------------------------------------------------------------------
# 1.     Define aws as provider
# ------------------------------------------------------------------
provider "aws" {
}

# ------------------------------------------------------------------
# 2.     Define iam access
# ------------------------------------------------------------------
resource "aws_iam_role" "ecs" {
    name = "ecs"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "ecs_for_ec2" {
    name = "ecs-for-ec2"
    roles = ["${aws_iam_role.ecs.id}"]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role" "ecs_elb" {
    name = "ecs-elb"
    assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "ecs_elb" {
    name = "ecs_elb"
    roles = ["${aws_iam_role.ecs_elb.id}"]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}


# ------------------------------------------------------------------
# 2.     define a vpc
# ------------------------------------------------------------------
module "vpc" {
    source = "github.com/terraform-community-modules/tf_aws_vpc"
    name = "my-vpc"
    cidr = "10.0.0.0/16"
    private_subnets = "10.0.1.0/24,10.0.2.0/24,10.0.3.0/24"
    public_subnets  = "10.0.101.0/24,10.0.102.0/24,10.0.103.0/24"
    azs      = "us-east-1d, us-east-1a, us-east-1e, us-east-1c"
}


# ------------------------------------------------------------------
# 3.     define a provisioner for bootstrap configs
# ------------------------------------------------------------------



# ------------------------------------------------------------------
# 3.     elb
# ------------------------------------------------------------------

