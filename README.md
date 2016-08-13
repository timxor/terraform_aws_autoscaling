# A terraform script for bootstrapping an AWS autoscaling group.

Instances have nginx installed in them as extra and they are accessible over an ELB.

The example launches a web server, installs nginx, creates an ELB for instance. It also creates security groups for the ELB and EC2 instance. 

To run, configure your AWS provider as described in https://www.terraform.io/docs/providers/aws/index.html

Run this example using:

    terraform apply

Wait a couple of minutes for the EC2 userdata to install nginx, and then type the ELB DNS Name from outputs in your browser and see the nginx welcome page
