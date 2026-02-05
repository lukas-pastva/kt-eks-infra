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
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowReadingMetricsFromCloudWatch",
          "Effect" : "Allow",
          "Action" : [
            "cloudwatch:DescribeAlarmsForMetric",
            "cloudwatch:DescribeAlarmHistory",
            "cloudwatch:DescribeAlarms",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricData",
            "cloudwatch:GetInsightRuleReport",
            "cloudwatch:GetMetricStatistics"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "AllowReadingLogsFromCloudWatch",
          "Effect" : "Allow",
          "Action" : [
            "logs:DescribeLogGroups",
            "logs:GetLogGroupFields",
            "logs:StartQuery",
            "logs:StopQuery",
            "logs:GetQueryResults",
            "logs:GetLogEvents"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "AllowReadingTagsInstancesRegionsFromEC2",
          "Effect" : "Allow",
          "Action" : ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"],
          "Resource" : "*"
        },
        {
          "Sid" : "AllowReadingResourcesForTags",
          "Effect" : "Allow",
          "Action" : "tag:GetResources",
          "Resource" : "*"
        }
      ]
    })

  tags = merge(
    include.root.locals.custom_tags
  )

}