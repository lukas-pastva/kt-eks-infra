include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/particuleio/terraform-aws-kms.git?ref=v1.2.0"
}

locals {
  component_values       = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  aws_account_admin_role = local.component_values["aws_account_admin_role"]

  env_values     = yamldecode(file("${find_in_parent_folders("env_values.yaml")}"))
  aws_account_id = local.env_values["aws_account_id"]
}

inputs = {
  description = "EKS Secret Encryption Key for ${include.root.locals.full_name}"
  alias       = "${include.root.locals.full_name}_secret_encryption"
  tags        = merge(
    include.root.locals.custom_tags
  )
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : "kms:*",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : local.aws_account_admin_role
        },
        "Resource" : "*",
        "Sid" : "Enable IAM User Permissions"
      },
      {
        "Action" : [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:Decrypt"
        ],
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        "Resource" : "*",
        "Sid" : "Allow service-linked role use of the CMK"
      },
      {
        "Action" : "kms:CreateGrant",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : [
              "true"
            ]
          }
        },
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        "Resource" : "*",
        "Sid" : "Allow attachment of persistent resources"
      }
    ],
    "Version" : "2012-10-17"
  })
}
