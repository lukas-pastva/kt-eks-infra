include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-route53.git//modules/zones?ref=v2.10.2"

}

inputs = {
  zones = {
    "${basename(get_terragrunt_dir())}" = {
      comment = "${basename(get_terragrunt_dir())}"
    }
  }

  tags = merge(
    include.root.locals.custom_tags
  )

}