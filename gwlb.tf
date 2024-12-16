# Partner VPC에 GWLB를 생성한다

# Security Group for Gateway Load Balancer
resource "aws_security_group" "gwlb_sg" {
  name_prefix = "gwlb-sg"
  vpc_id      = module.partner_vpc.vpc_id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gwlb-sg "
  }
}


# Gateway Load Balancer in Partner VPC
resource "aws_lb" "gwlb" {
  name               = "gwlb"
  load_balancer_type = "gateway"
  subnets            = module.partner_vpc.public_subnets
  enable_deletion_protection = false

  tags = {
    Name = "gateway-load-balancer"
  }
}

resource "aws_lb_listener" "gwlb_listener" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb_target_group.arn
  }
}


resource "aws_lb_target_group" "gwlb_target_group" {
  name        = "gwlb-target-group"
  protocol    = "GENEVE"  # GWLB는 GENEVE 프로토콜 사용
  port        = 6081  # GENEVE 고정 포트
  vpc_id      = module.partner_vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = {
    Name = "gwlb-target-group"
  }
}

resource "aws_lb_target_group_attachment" "nginx_attachment" {
  target_group_arn = aws_lb_target_group.gwlb_target_group.arn
  target_id        = aws_instance.nginx_appliance.id
  port             = 6081
}

# Customer VPC에 GWLB Endpoint를 생성한다

# Gateway Load Balancer Endpoint in Customer VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
# Gateway Load Balancer Endpoint Type

resource "aws_vpc_endpoint_service" "gwlb_service" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = {
    Name = "gwlb-endpoint-service"
  }
}

resource "aws_vpc_endpoint" "gwlb_endpoint" {
  service_name      = aws_vpc_endpoint_service.gwlb_service.service_name
  vpc_id            = module.customer_vpc.vpc_id
  subnet_ids        = [module.customer_vpc.public_subnets[0]]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb_service.service_type
  
  tags = {
    Name = "gwlb-endpoint"
  }
}



# Route Table Update for Customer VPC to Route Traffic Through GWLB Endpoint
resource "aws_route" "gwlb_route" {
  route_table_id         = module.customer_vpc.public_route_table_ids[0]
  destination_cidr_block = "192.168.0.0/24" # Partner VPC CIDR
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb_endpoint.id
}



