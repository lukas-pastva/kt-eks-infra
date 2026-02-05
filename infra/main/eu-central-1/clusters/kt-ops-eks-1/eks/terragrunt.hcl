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

dependency "encryption_config" {
  config_path = "${get_original_terragrunt_dir()}/../encryption-config"

  mock_outputs = {
    arn = "arn:aws:iam::111122223333:root"
  }
}

locals {
  component_values                       = yamldecode(file("${find_in_parent_folders("component_values.yaml")}"))
  aws_account_admin_user                 = local.component_values["aws_account_admin_user"]
  cluster_version                        = local.component_values["cluster_version"]
  cluster_logs                           = local.component_values["cluster_logs"]
  cloudwatch_log_group_retention_in_days = local.component_values["cloudwatch_log_group_retention_in_days"]
  cluster_admin_user                     = local.component_values["cluster_admin_user"]

  mng_tags = merge(
    include.root.locals.custom_tags,
  )
}

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-eks?ref=v20.31.0"

  after_hook "kubeconfig" {
    commands = ["apply"]
    execute  = [
      "bash", "-c",
      "aws eks update-kubeconfig --name ${include.root.locals.full_name} --kubeconfig ${get_terragrunt_dir()}/kubeconfig 2>/dev/null"
    ]
  }

  after_hook "kube-system-label" {
    commands = ["apply"]
    execute  = [
      "bash", "-c",
      "kubectl --kubeconfig ${get_terragrunt_dir()}/kubeconfig label ns kube-system name=kube-system --overwrite"
    ]
  }

  after_hook "undefault-gp2" {
    commands = ["apply"]
    execute  = [
      "bash", "-c",
      "kubectl --kubeconfig ${get_terragrunt_dir()}/kubeconfig patch storageclass gp2 -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"false\"}}}'"
    ]
  }

  after_hook "vpc-cni-prefix-delegation" {
    commands = ["apply"]
    execute  = [
      "bash", "-c",
      "kubectl --kubeconfig ${get_terragrunt_dir()}/kubeconfig set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true"
    ]
  }

  after_hook "vpc-cni-prefix-warm-prefix" {
    commands = ["apply"]
    execute  = [
      "bash", "-c",
      "kubectl --kubeconfig ${get_terragrunt_dir()}/kubeconfig set env daemonset aws-node -n kube-system WARM_PREFIX_TARGET=1"
    ]
  }
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite"
  contents  = file("../../../../../../provider-config/eks/eks.tf")
}


inputs = {

  aws = {
    "region" = include.root.locals.merged.aws_region
  }

  tags = merge(
    include.root.locals.custom_tags
  )

  # EKS v20: Use access entries instead of aws_auth configmap
  enable_cluster_creator_admin_permissions = true
  authentication_mode = "API_AND_CONFIG_MAP"

  cluster_name                    = include.root.locals.full_name
  cluster_version                 = local.cluster_version
  cluster_enabled_log_types       = local.cluster_logs
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_endpoint_public_access_cidrs = concat(include.root.locals.public_trusted_access_cidrs)

  kms_key_administrators = local.aws_account_admin_user

  cluster_encryption_config = {
    provider_key_arn = dependency.encryption_config.outputs.arn
    resources        = ["secrets"]
  }
  cluster_addons = {
    coredns = {
      addon_version               = "v1.10.1-eksbuild.11"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      addon_version               = "v1.28.12-eksbuild.5"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      addon_version               = "v1.19.0-eksbuild.1"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  vpc_id                   = dependency.vpc.outputs.vpc_id
  #todo review contorl plane subnet
  control_plane_subnet_ids = dependency.vpc.outputs.private_subnets
  subnet_ids               = dependency.vpc.outputs.private_subnets
  enable_irsa              = true

  cloudwatch_log_group_retention_in_days = local.cloudwatch_log_group_retention_in_days


  access_entries = {
    admin = {
      principal_arn = local.cluster_admin_user
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }



  node_security_group_additional_rules = {
    ingress_self_all = {
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      type      = "ingress"
      self      = true
    }
    ingress_cluster_all = {
      from_port                     = 0
      to_port                       = 0
      protocol                      = "-1"
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_node_port_tcp_1 = {
      from_port        = 1025
      to_port          = 5472 # Exclude calico-typha port 5473
      protocol         = "tcp"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_node_port_tcp_2 = {
      from_port        = 5474
      to_port          = 10249 # Exclude kubelet port 10250
      protocol         = "tcp"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_node_port_tcp_3 = {
      from_port        = 10251
      to_port          = 10255 # Exclude kube-proxy HCHK port 10256
      protocol         = "tcp"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_node_port_tcp_4 = {
      from_port        = 10257
      to_port          = 61677 # Exclude aws-node port 61678
      protocol         = "tcp"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_node_port_tcp_5 = {
      from_port        = 61679
      to_port          = 65535
      protocol         = "tcp"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_node_port_udp = {
      from_port        = 1025
      to_port          = 65535
      protocol         = "udp"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    egress_all = {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = include.root.locals.full_name
  }

  eks_managed_node_group_defaults = {
    tags                         = local.mng_tags
    desired_size                 = 1
    min_size                     = 1
    max_size                     = 1
    capacity_type                = "SPOT"
    platform                     = "bottlerocket"
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
    taints = [
      {
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    ]
    labels = {
      network  = "private"
      nodetype = "asg"
    }
    ebs_optimized = true
    update_config = {
      max_unavailable_percentage = 33
    }
    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs         = {
          volume_size           = 2
          volume_type           = "gp3"
          delete_on_termination = true
          encrypted             = true
          kms_key_id            = dependency.encryption_config.outputs.arn
        }
      }
      containers = {
        device_name = "/dev/xvdb"
        ebs         = {
          volume_size           = 15
          volume_type           = "gp3"
          delete_on_termination = true
          encrypted             = true
          kms_key_id            = dependency.encryption_config.outputs.arn
        }
      }
    }
  }

  eks_managed_node_groups = {

    "default-a" = {
      ami_type                   = "BOTTLEROCKET_x86_64"
      instance_types             = ["t3a.large"]
      capacity_type              = "ON_DEMAND"
      subnet_ids                 = [dependency.vpc.outputs.private_subnets[0]]
      enable_bootstrap_user_data = true
      # bootstrap_extra_args       = <<-EOT
      #   "max-pods" = ${run_cmd("/bin/sh", "-c", "../../../../../../../tools/max-pods-calculator.sh --instance-type t3a.large --cni-version 1.11.2 --cni-prefix-delegation-enabled")}
      #   EOT
      bootstrap_extra_args       = <<-EOT
         "max-pods" = 24
         EOT
    }

    "default-b" = {
      ami_type                   = "BOTTLEROCKET_x86_64"
      instance_types             = ["t3a.large"]
      capacity_type              = "ON_DEMAND"
      subnet_ids                 = [dependency.vpc.outputs.private_subnets[1]]
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = <<-EOT
        "max-pods" = 24
        EOT
    }

    "default-c" = {
      ami_type                   = "BOTTLEROCKET_x86_64"
      platform                   = "bottlerocket"
      instance_types             = ["t3a.medium"]
      subnet_ids                 = [dependency.vpc.outputs.private_subnets[2]]
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = <<-EOT
        "max-pods" = 16
        EOT
    }
  }
}
