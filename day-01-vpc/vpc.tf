provider "aws" {
  region = local.region
}

locals {
  region   = "us-east-1"
  vpc_name = "linuxtips-containers-vpc"
  azs      = formatlist("${local.region}%s", ["a", "b", "c"])
  vpc_tags = {
    project     = "linuxtips-containers"
    region      = local.region
    environment = "dev"
    terraform   = "true"
  }
}

terraform {
  backend "s3" {
    bucket         = "vhmanca-linuxtips-terraform-state"
    key            = "dev/us-east-1/network/vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "linuxtips-terraform-state-locks"
    encrypt = true
  }
}

# NGW Elastic IP
resource "aws_eip" "nat_gw_elastic_ip" {

  tags = merge(
    tomap({"Name" = "${local.vpc_name}-nat-eip"}),
    local.vpc_tags
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.12"

  name = local.vpc_name
  cidr = "10.0.0.0/16"

  azs                          = local.azs
  create_database_subnet_group = false
  enable_dns_hostnames         = true
  enable_dns_support           = true
  enable_nat_gateway           = true
  single_nat_gateway           = true
  one_nat_gateway_per_az       = false
  reuse_nat_ips                = true
  external_nat_ip_ids          = [aws_eip.nat_gw_elastic_ip.id]

  #######################################
  # SUBNETS                             #
  #######################################

  private_subnets     = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"] #10.0.0.0/17
  database_subnets    = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"] #10.0.128.0/18
  public_subnets      = ["10.0.196.0/24", "10.0.197.0/24", "10.0.198.0/24"] #10.0.196.0/22

  private_subnet_names     = ["${local.vpc_name}-private-${local.region}a", "${local.vpc_name}-private-${local.region}b", "${local.vpc_name}-private-${local.region}c"]
  public_subnet_names      = ["${local.vpc_name}-public-${local.region}a", "${local.vpc_name}-public-${local.region}b", "${local.vpc_name}-public-${local.region}c"]
  database_subnet_names    = ["${local.vpc_name}-private-data-tier-${local.region}a", "${local.vpc_name}-private-data-tier-${local.region}b", "${local.vpc_name}-private-data-tier-${local.region}c"]


  public_subnet_tags = merge(
    local.vpc_tags
  )

  private_subnet_tags = merge(
    local.vpc_tags
  )

  #######################################
  # NACLs                               #
  #######################################

  # default-vpc nacl
  manage_default_network_acl = true
  default_network_acl_tags   = merge(
    tomap({"Name" = "${local.vpc_name}-default-nacl"}),
    local.vpc_tags
  )

  # public-app-tier nacl
  public_dedicated_network_acl   = true
  public_acl_tags = merge(
    tomap({"Name" = "${local.vpc_name}-public--nacl"}),
    local.vpc_tags
  )

  # private-app-tier nacl
  private_dedicated_network_acl  = true
  private_acl_tags = merge(
    tomap({"Name" = "${local.vpc_name}-private-nacl"}),
    local.vpc_tags
  )

  # data-tier nacl
  database_dedicated_network_acl = true
  database_acl_tags = merge(
    tomap({"Name" = "${local.vpc_name}-private-data-tier-nacl"}),
    local.vpc_tags
  )

  #######################################
  # ROUTE TABLE                         #
  #######################################

  # default-vpc route table
  manage_default_route_table = true
  default_route_table_tags   = merge(
    tomap({"Name" = "${local.vpc_name}-default-rt"}),
    local.vpc_tags
  )

  # public-app-tier route table
  public_route_table_tags = merge(
    tomap({"Name" = "${local.vpc_name}-public-rt"}),
    local.vpc_tags
  )

  # private-app-tier route table
  private_route_table_tags = merge(
    tomap({"Name" = "${local.vpc_name}-private-rt"}),
    local.vpc_tags
  )

  #######################################
  # SECURITY GROUPS                     #
  #######################################

  # default-vpc security group
  manage_default_security_group = true
  default_security_group_tags   = merge(
    tomap({"Name" = "${local.vpc_name}-default-sg"}),
    local.vpc_tags
  )

  tags = local.vpc_tags
}