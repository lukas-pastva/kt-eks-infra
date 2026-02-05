include "root" {
  path           = find_in_parent_folders()
  expose         = true
  merge_strategy = "deep"
}

dependency "vpc" {
  config_path = "${get_original_terragrunt_dir()}/../vpc"

  mock_outputs = {
    private_subnet_ids = [
      "subnet-00000000",
      "subnet-00000001",
      "subnet-00000002"
    ]
  }
}

locals {
  component_values   = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  cluster_admin_role = local.component_values["cluster_admin_role"]

}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-ecs?ref=v5.7.4"
}

inputs = {

  cluster_name = include.root.locals.full_name

  cluster_configuration = {
    execute_command_configuration = {
      logging           = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  services = {
    ecsdemo-frontend = {
      cpu    = 1024
      memory = 4096

      # Container definition(s)
      container_definitions = {

#        fluent-bit = {
#          cpu                    = 512
#          memory                 = 1024
#          essential              = true
#          image                  = "906394416424.dkr.ecr.us-west-2.amazonaws.com/aws-for-fluent-bit:stable"
#          firelens_configuration = {
#            type = "fluentbit"
#          }
#          memory_reservation = 50
#        }

        ecs-sample = {
          cpu           = 512
          memory        = 1024
          essential     = true
          image         = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
          port_mappings = [
            {
              name          = "ecs-sample"
              containerPort = 80
              protocol      = "tcp"
            }
          ]

          # Example image used requires access to write to root filesystem
          readonly_root_filesystem = false

#          dependencies = [
#            {
#              containerName = "fluent-bit"
#              condition     = "START"
#            }
#          ]

          enable_cloudwatch_logging = true
#          log_configuration         = {
#            logDriver = "awsfirelens"
#            options   = {
#              Name                    = "firehose"
#              region                  = "eu-central-1"
#              delivery_stream         = "my-stream"
#              log-driver-buffer-limit = "2097152"
#            }
#          }
#          memory_reservation = 100
        }
      }

#      load_balancer = {
#        service = {
#          target_group_arn = "arn:aws:elasticloadbalancing:eu-central-1:400528358945:targetgroup/k8s-ingressn-ingressn-e182be57b4/5c5dd4c72d34d7b0"
#          container_name   = "ecs-sample"
#          container_port   = 80
#        }
#      }

      subnet_ids           = dependency.vpc.outputs.private_subnets
      security_group_rules = {
        alb_ingress_3000 = {
          type                     = "ingress"
          from_port                = 80
          to_port                  = 80
          protocol                 = "tcp"
          description              = "Service port"
          cidr_blocks = ["0.0.0.0/0"]
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  tags = merge(
    include.root.locals.custom_tags
  )

}
