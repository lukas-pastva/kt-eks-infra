include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-policy?ref=v5.52.0"
}

inputs = {
  name                          = "${include.root.locals.full_name}-${basename(get_terragrunt_dir())}"
  create_iam_user_login_profile = false
  policy                        = jsonencode(
    {
      "Statement" : [
        {
          "Action" : [
            "elasticfilesystem:DescribeAccessPoints",
            "elasticfilesystem:DescribeFileSystems",
            "elasticfilesystem:DescribeMountTargets",
            "ec2:DescribeAvailabilityZones"
          ],
          "Effect" : "Allow",
          "Resource" : "*"
        },
        {
          "Action" : [
            "elasticfilesystem:CreateAccessPoint"
          ],
          "Effect" : "Allow",
          "Resource" : "*",
          "Condition" : {
            "StringLike" : {
              "aws:RequestTag/efs.csi.aws.com/cluster" : "true"
            }
          }
        },
        {
          "Action" : [
            "elasticfilesystem:TagResource"
          ],
          "Effect" : "Allow",
          "Resource" : "*",
          "Condition" : {
            "StringLike" : {
              "aws:ResourceTag/efs.csi.aws.com/cluster" : "true"
            }
          }
        },
        {
          "Action" : [
            "elasticfilesystem:DeleteAccessPoint"
          ],
          "Effect" : "Allow",
          "Resource" : "*",
          "Condition" : {
            "StringEquals" : {
              "aws:ResourceTag/efs.csi.aws.com/cluster" : "true"
            }
          }
        }
      ],
      "Version" : "2012-10-17"
    })

  tags = merge(
    include.root.locals.custom_tags
  )
}
