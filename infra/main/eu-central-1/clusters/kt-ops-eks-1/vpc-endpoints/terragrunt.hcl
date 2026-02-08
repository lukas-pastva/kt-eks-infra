include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "vpc" {
  config_path = "${get_original_terragrunt_dir()}/../vpc"

  mock_outputs = {
    vpc_id                   = "vpc-00000000"
    private_subnets          = ["subnet-00000000", "subnet-00000001", "subnet-00000002"]
    private_route_table_ids  = ["rtb-00000000", "rtb-00000001", "rtb-00000002"]
    public_route_table_ids   = ["rtb-00000003"]
    default_security_group_id = "sg-00000000"
  }
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc//modules/vpc-endpoints?ref=v5.17.0"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([dependency.vpc.outputs.private_route_table_ids, dependency.vpc.outputs.public_route_table_ids])
      tags            = { Name = "${include.root.locals.merged.prefix}-${include.root.locals.merged.env}-s3-vpc-endpoint" }
    },
    kms = {
      service             = "kms"
      service_type        = "Interface"
      subnet_ids          = flatten([dependency.vpc.outputs.private_subnets])
      security_group_ids  = [dependency.vpc.outputs.default_security_group_id]
      private_dns_enabled = true
      tags                = { Name = "${include.root.locals.merged.prefix}-${include.root.locals.merged.env}-kms-vpc-endpoint" }
    },
  }
  tags = merge(
    include.root.locals.custom_tags
  )
}
