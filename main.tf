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
      max_size        = 2
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

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.8.0"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  #region EKS ADDONS
  enable_amazon_eks_vpc_cni = true
  enable_amazon_eks_coredns = true
  amazon_eks_coredns_config = {
    most_recent        = true
    kubernetes_version = "1.30"
    resolve_conflicts  = "OVERWRITE"
  }
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true
  #endregion

  #region K8s ADDONS
  enable_argocd = false

  

  # ingress
  enable_aws_load_balancer_controller = true
  
  }

  enable_aws_for_fluentbit            = false
  enable_cluster_autoscaler           = false
  enable_metrics_server               = false
  enable_prometheus                   = false
  enable_grafana                      = false
  enable_external_secrets             = false
  enable_aws_efs_csi_driver           = false
  enable_aws_cloudwatch_metrics       = false
  #endregion

  depends_on = [
    time_sleep.wait_for_cluster
  ]
  }
}
#endregion
