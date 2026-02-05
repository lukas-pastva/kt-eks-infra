include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "vpc" {
  config_path = "${get_original_terragrunt_dir()}/../vpc"

  mock_outputs = {
    vpc_id         = "vpc-00000000"
    private_subnets = ["subnet-00000000", "subnet-00000001", "subnet-00000002"]
    vpc_cidr_block = "10.0.0.0/16"
  }
}

dependency "encryption_config" {
  config_path = "${get_original_terragrunt_dir()}/../encryption-config"

  mock_outputs = {
    arn = "arn:aws:iam::111122223333:root"
  }
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-efs?ref=v1.6.5"
}

inputs = {
  name = include.root.locals.full_name

  encrypted   = true
  kms_key_arn = dependency.encryption_config.outputs.arn

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  mount_targets = {
    for idx, subnet_id in dependency.vpc.outputs.private_subnets :
    "private-${idx}" => { subnet_id = subnet_id }
  }

  create_security_group      = true
  security_group_name        = "${include.root.locals.full_name}-efs"
  security_group_description = "EFS mount target security group for ${include.root.locals.full_name}"
  security_group_vpc_id      = dependency.vpc.outputs.vpc_id
  security_group_rules = {
    vpc_ingress = {
      description = "NFS ingress from VPC"
      cidr_blocks = [dependency.vpc.outputs.vpc_cidr_block]
    }
  }

  tags = merge(
    include.root.locals.custom_tags
  )
}
