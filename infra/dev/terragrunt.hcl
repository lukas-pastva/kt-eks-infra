terragrunt_version_constraint = ">= 0.68"

locals {
  merged = merge(
    try(yamldecode(file(find_in_parent_folders("global_values.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("env_values.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("zone_values.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("region_values.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("component_values.yaml"))), {})
  )
  custom_tags = merge(
    try(yamldecode(file(find_in_parent_folders("global_tags.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("env_tags.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("zone_tags.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("region_tags.yaml"))), {}),
    try(yamldecode(file(find_in_parent_folders("component_tags.yaml"))), {})
  )
  full_name                   = "${local.merged.prefix}-${local.merged.env}-${local.merged.name}"
  public_trusted_access_cidrs = yamldecode(file("${find_in_parent_folders("global_values.yaml")}"))["public_trusted_access_cidrs"]
}

remote_state {
  backend = "s3"

  config = {
    bucket  = "sw-tronic-sk-tg-state-store"
    key     = "${local.merged.provider}/${path_relative_to_include()}/terraform.tfstate"
    region  = local.merged.tf_state_bucket_region
    encrypt = true

    dynamodb_table = "sw-tronic-sk-tg-state-lock"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "versions-override" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = ">= 5.79.0, < 6.0.0"
        }
      }
    }
  EOF
}

generate "provider-aws" {
  path      = "provider-aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "provider_default_tags" {
      type = map
      default = {}
    }
    provider "aws" {
      region = "${local.merged.aws_region}"
      default_tags {
        tags = var.provider_default_tags
      }
    }
  EOF
}

inputs = {
  provider_default_tags = local.custom_tags
}

# Use this to impersonate a role, useful for EKS when you want a role to be
# the "root" use and not a personal AWS account
# iam_role = "arn:aws:iam::${yamldecode(file(find_in_parent_folders("global_values.yaml")))["aws_account_id"]}:role/administrator"
