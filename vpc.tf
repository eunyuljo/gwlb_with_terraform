# Customer VPC
module "customer_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "customer-vpc"
  cidr            = "10.0.0.0/25"
  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.0.0.0/28", "10.0.0.16/28"]  # For GWLB Endpoint
  private_subnets = ["10.0.0.64/28", "10.0.0.80/28"]  # Application subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Environment = "customer_vpc"
  }
}

# Partner VPC
module "partner_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "partner-vpc"
  cidr            = "192.168.0.0/24"
  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["192.168.0.0/28", "192.168.0.16/28"]  # For GWLB Endpoint
  private_subnets = ["192.168.0.128/28"]  # GWLB placement
  

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Environment = "partner_vpc"
  }
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "partner_to_customer" {
  vpc_id      = module.partner_vpc.vpc_id
  peer_vpc_id = module.customer_vpc.vpc_id
  auto_accept = true

  tags = {
    Name = "Partner-to-Customer"
  }
}

# Route Table Updates for VPC Peering
resource "aws_route" "customer_to_partner" {
  route_table_id         = module.customer_vpc.public_route_table_ids[0]
  destination_cidr_block = "192.168.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.partner_to_customer.id
}

resource "aws_route" "partner_to_customer" {
  route_table_id         = module.partner_vpc.public_route_table_ids[0]
  destination_cidr_block = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.partner_to_customer.id
}