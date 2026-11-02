output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "availability_zones" {
  value = module.network.availability_zones
}

output "apps" {
  description = "Per-app details."
  value = {
    for name, app in module.apps : name => {
      namespace       = app.namespace
      service_account = app.service_account
      bucket          = app.bucket_name
      role_arn        = app.role_arn
    }
  }
}
