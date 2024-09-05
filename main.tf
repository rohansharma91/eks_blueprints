#regions LOCALS
locals {
  name         = "eks-bp-demo"
  cluster_name = "eks-bp-demo"
}
#endregion

#region EKS BLUEPRINTS
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.8.0"

  # EKS CLUSTER
  cluster_name       = local.cluster_name
  cluster_version    = "1.30"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_m5 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["t2.small"]
      min_size        = 1
      max_size        = 1
      subnet_ids      = module.vpc.private_subnets
    }
  }

  #region Teams
  platform_teams = {
    admin = {
      users = [data.aws_caller_identity.current.arn]
    }
  }

  application_teams = {
    team-blue-dev = {
      "labels" = {
        "appName"     = "blue-team-app",
        "projectName" = "project-blue",
        "environment" = "dev"
      }
      "quota" = {
        "requests.cpu"    = "250m",
        "requests.memory" = "1Gi",
        "limits.cpu"      = "500m",
        "limits.memory"   = "2Gi",
        "pods"            = "10",
        "secrets"         = "10",
        "services"        = "10"
      }

      #manifests_dir = "./manifests-team-blue"
      users         = [data.aws_caller_identity.current.arn]
    }
  }
  #endregion Team
}
#endregion

resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks_blueprints]

  create_duration = "180s"

  triggers = {
    "always_run" = timestamp()
  }
}

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name      = module.eks_blueprints.cluster_name
  cluster_endpoint  = module.eks_blueprints.cluster_endpoint
  cluster_version   = module.eks_blueprints.cluster_version
  oidc_provider_arn = module.eks_blueprints.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = false
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  enable_aws_load_balancer_controller    = true
  enable_cluster_proportional_autoscaler = false
  enable_karpenter                       = false
  enable_kube_prometheus_stack           = false
  enable_metrics_server                  = false
  enable_external_dns                    = true
  enable_cert_manager                    = false
  

  tags = {
    Environment = "dev"
  }
}
