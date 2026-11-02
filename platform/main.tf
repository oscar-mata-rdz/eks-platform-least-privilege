locals {
  name_prefix  = "${var.team}-${var.environment}"
  cluster_name = "${local.name_prefix}-${var.region}"

  tags = merge(var.tags, {
    Team        = var.team
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = terraform.workspace == var.region
      error_message = "Workspace is \"${terraform.workspace}\" but region is \"${var.region}\". Run: terraform workspace select -or-create ${var.region}"
    }
  }
}

module "network" {
  source = "../modules/network"

  name               = local.cluster_name
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}

module "eks" {
  source = "../modules/eks-cluster"

  cluster_name           = local.cluster_name
  kubernetes_version     = var.kubernetes_version
  subnet_ids             = module.network.private_subnet_ids
  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  node_groups            = var.node_groups
}

module "apps" {
  source   = "../modules/app-workload"
  for_each = var.apps

  app_name             = each.key
  name_prefix          = local.name_prefix
  namespace            = each.value.namespace
  service_account_name = each.value.service_account
  bucket_access        = each.value.bucket_access
  allow_delete         = each.value.allow_delete

  cluster_name = module.eks.cluster_name
  cluster_arn  = module.eks.cluster_arn
}
