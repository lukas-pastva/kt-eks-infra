include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-policy?ref=v5.11.2"
}

dependency "argocd_kms" {
  config_path  = "${get_original_terragrunt_dir()}/../../../kms/${basename(get_terragrunt_dir())}"
  mock_outputs = {
    kms_key_arn = "arn::::::",
    key_arn     = "arn::::::"
  }
}

inputs = {
  name                          = "${include.root.locals.full_name}-${basename(get_terragrunt_dir())}"
  create_iam_user_login_profile = false
  policy                        = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:GenerateDataKey"
          ],
          "Resource" : dependency.argocd_kms.outputs.key_arn
        }
      ]
    })

  tags = merge(
    include.root.locals.custom_tags
  )
}
