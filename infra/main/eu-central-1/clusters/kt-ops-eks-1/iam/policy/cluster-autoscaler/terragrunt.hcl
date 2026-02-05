include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-policy?ref=v5.11.2"
}

inputs = {
  name                   = "${include.root.locals.full_name}-${basename(get_terragrunt_dir())}"
  create_iam_user_login_profile = false
  policy                        = jsonencode(
    {
      "Statement" : [
        {
          "Action" : [
            "ec2:DescribeLaunchTemplateVersions",
            "ec2:DescribeInstanceTypes",
            "autoscaling:DescribeTags",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeAutoScalingGroups"
          ],
          "Effect" : "Allow",
          "Resource" : "*",
          "Sid" : "clusterAutoscalerAll"
        },
        {
          "Action" : [
            "autoscaling:UpdateAutoScalingGroup",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "autoscaling:SetDesiredCapacity"
          ],
          "Condition" : {
            "StringEquals" : {
              "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled" : "true",
              "autoscaling:ResourceTag/kubernetes.io/cluster/kt-ops-eks-1" : "owned"
            }
          },
          "Effect" : "Allow",
          "Resource" : "*",
          "Sid" : "clusterAutoscalerOwn"
        }
      ],
      "Version" : "2012-10-17"
    }
  )

  tags = merge(
    include.root.locals.custom_tags
  )
}
