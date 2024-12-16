########################################################################################################################

# Security Group for EC2 - Customer
resource "aws_security_group" "customer_ec2_sg" {
  name        = "customer_ec2_sg"
  vpc_id      = module.customer_vpc.vpc_id
  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "customer_ec2_sg"
  }
}

resource "aws_instance" "customer_instance" {
  ami           = "ami-0023481579962abd4"
  instance_type = "t3.micro"
  subnet_id     = module.customer_vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.customer_ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "Customer-Instance"
  }
}



