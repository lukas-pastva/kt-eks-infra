include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-kms.git?ref=v1.5.0"
}

locals {
  component_values   = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  key_administrators = local.component_values["aws_account_admin_role"]
  name               = "${include.root.locals.full_name}-${basename(get_terragrunt_dir())}"
}

inputs = {
  description = local.name
  key_usage   = "ENCRYPT_DECRYPT"
  key_administrators = local.key_administrators
  aliases = [local.name]
  tags    = merge(
    include.root.locals.custom_tags,
    {
      "purpose" = "${basename(get_terragrunt_dir())}Key",
    }
  )

}
