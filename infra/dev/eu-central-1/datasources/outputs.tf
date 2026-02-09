output "aws_region" {
  value       = data.aws_region.current
  description = "The AWS region where the resources are provisioned"
}

output "aws_availability_zones" {
  value       = data.aws_availability_zones.available
  description = "The list of available AWS availability zones in the region"
}
