# Extracts AWS AMI ID from AWS which is type linux-2 with provided filters
data "aws_ami" "amazon-linux-2" {
  owners      = ["amazon"]
  most_recent = true

  # you can find filters in terraform docs aws ec2 instance iam, more filters give you the best extracted results
  #  Take a look and reference in aws console to decide which filters are required.

  filter {
    name   = "root-device-type" # you can find the info from aws console, in iam catalog. same as below.
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "owner-alias" # additional filter on topf of the aws console reference. 
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm*"] #in aws consol, go to ami catalog, select amz-linux2 and click launch, then you can see the ami image: e.g., amzn2-ami-kernel-5.10
  }
}

#in order to render the userdata.sh file, userdata.sh file will be used in ec2 instance as user-data
data "template_file" "userdata" {
  template = file("${abspath(path.module)}/userdata.sh") #with path.module, you can be flexible and elastic compared to absolute path.
  vars = {
    server-name = var.server-name #"Docker-Instance" but flexible with var. 
  }
}

#this block creates EC2 with provided userdata.sh script file.
resource "aws_instance" "tfmyec2" {
  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = var.instance_type #t2.micro is default
  count                  = var.num_of_instance
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]    #security group name should be reflected here.
  user_data              = data.template_file.userdata.rendered #user_data = file("./userdata.sh") or give the specific (absolute) path, /home/ec2-user/clarusway-modules/userdata.sh
  tags = {
    Name = var.tag
  }
}

## security group ports 3x, 22, 80, 8080. if more ports, "dynamic block" docs googled,  take for ports variables.    
resource "aws_security_group" "tf-sec-gr" {
  name = "${var.tag}-terraform-sec-grp"
  tags = {
    Name = var.tag
  }

  # dynamic block for multiple ports. inbound-ingress. 
  dynamic "ingress" {
    for_each = var.docker-instance-ports
    iterator = port # iterator arguments 
    content {
      from_port   = port.value # in variables.tf, ports are only 3x. 
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    protocol    = "-1" #-1 echos to every ports. 
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}