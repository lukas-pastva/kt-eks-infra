include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v5.17.0"

}

dependency "datasources" {
  config_path = "../../../datasources"
}

locals {
  vpc_cidr = yamldecode(file("${find_in_parent_folders("global_values.yaml")}"))["ip_addressing_plan"]["${include.root.locals.full_name}"]["vpc_cidr"]
}

inputs = {

  tags = merge(
    include.root.locals.custom_tags,
    {
      "kubernetes.io/cluster/${include.root.locals.full_name}" = "shared",
    }
  )

  name = include.root.locals.full_name
  cidr = local.vpc_cidr
  azs  = dependency.datasources.outputs.aws_availability_zones.names

  private_subnets = [for k, v in slice(dependency.datasources.outputs.aws_availability_zones.names, 0, 3) : cidrsubnet(local.vpc_cidr, 2, k + 0)]
  public_subnets  = [for k, v in slice(dependency.datasources.outputs.aws_availability_zones.names, 0, 3) : cidrsubnet(local.vpc_cidr, 4, k + 12)]

  enable_ipv6                     = false
  assign_ipv6_address_on_creation = false

  enable_nat_gateway = true
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  manage_default_security_group = true

  default_security_group_egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
    }
  ]
  default_security_group_ingress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
    }
  ]

  public_subnet_tags = {
    "kubernetes.io/cluster/${include.root.locals.full_name}" = "shared"
    "kubernetes.io/role/elb"                                 = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${include.root.locals.full_name}" = "shared"
    "kubernetes.io/role/internal-elb"                        = "1"
    "karpenter.sh/discovery"                                 = include.root.locals.full_name
  }

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = 365
  flow_log_traffic_type                           = "REJECT"
}
