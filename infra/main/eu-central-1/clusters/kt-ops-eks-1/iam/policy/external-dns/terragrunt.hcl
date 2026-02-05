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
          "Action" : "route53:ChangeResourceRecordSets",
          "Effect" : "Allow",
          "Resource" : "arn:aws:route53:::hostedzone/*"
        },
        {
          "Action" : [
            "route53:ListResourceRecordSets",
            "route53:ListHostedZones"
          ],
          "Effect" : "Allow",
          "Resource" : "*"
        }
      ],
      "Version" : "2012-10-17"
    })

  tags = merge(
    include.root.locals.custom_tags
  )
}
