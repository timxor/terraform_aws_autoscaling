#  --------------------------------------------------------------------------------------------------------------------
#  1. declare infrastructure provider
#  --------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = "${var.aws_region}"
}

#  --------------------------------------------------------------------------------------------------------------------
#  2. declare load balancer
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_elb" "web-elb" {
  name = "terraform-example-elb"

  subnets         = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }

}

#  --------------------------------------------------------------------------------------------------------------------
#  3. declare autoscaling group
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_autoscaling_group" "web-asg" {
  availability_zones = ["${split(",", var.availability_zones)}"]
  name = "terraform-example-asg"
  max_size = "${var.asg_max}"
  min_size = "${var.asg_min}"
  desired_capacity = "${var.asg_desired}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.web-lc.name}"
  load_balancers = ["${aws_elb.web-elb.name}"]
  #vpc_zone_identifier = ["${split(",", var.availability_zones)}"]
  tag {
    key = "Name"
    value = "web-asg"
    propagate_at_launch = "true"
  }
}

#  --------------------------------------------------------------------------------------------------------------------
#  4. declare bootstrap configurations
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_launch_configuration" "web-lc" {
  name = "terraform-example-lc"
  image_id = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "${var.instance_type}"
  # Security group
  security_groups = ["${aws_security_group.elb.id}"]
  user_data = "${file("userdata.sh")}"
  key_name = "${var.key_name}"
}


#  --------------------------------------------------------------------------------------------------------------------
#  5. declare security group for load balancers -- access: http
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "elb" {
  name        = "terraform_example_elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#  --------------------------------------------------------------------------------------------------------------------
#  6. declare key pair
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_key_pair" "auth" {
  key_name = "github_rsa_key"
  public_key = "${file("~/.ssh/github_rsa_key.pub")}"
}

#  --------------------------------------------------------------------------------------------------------------------
#  7. create a virtual private computer (VPC) for the servers to live within
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

#  --------------------------------------------------------------------------------------------------------------------
#  8. create an internet gateway to act as a firewall between internet and back-end services
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}


#  --------------------------------------------------------------------------------------------------------------------
#  1. declare infrastructure provider
#  --------------------------------------------------------------------------------------------------------------------
# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}


#  --------------------------------------------------------------------------------------------------------------------
#  1. declare infrastructure provider
#  --------------------------------------------------------------------------------------------------------------------
# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}



#  --------------------------------------------------------------------------------------------------------------------
#  1. declare infrastructure provider
#  --------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "web" {
  connection {
    type = "ssh"
    user = "ubuntu"
    timeout = "2m"
    agent = false
  }

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.elb.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.default.id}"

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start"
    ]
  }
}
