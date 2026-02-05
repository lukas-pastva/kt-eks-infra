include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-route53.git//modules/zones?ref=v4.1.0"

  after_hook "show_nameservers" {
    commands = ["apply"]
    execute  = ["bash", "-c", "echo '\n========================================\nNAMESERVERS - Add these to your domain registrar:\n========================================' && tofu output -json route53_zone_name_servers 2>/dev/null || terraform output -json route53_zone_name_servers"]
  }
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