region              = "us-east-1"
allowed_account_ids = ["000000000000"]

team        = "payments"
environment = "prod"
tags = {
  CostCenter = "payments"
}

vpc_cidr           = "10.10.0.0/16"
az_count           = 3
single_nat_gateway = false

kubernetes_version     = "1.34"
endpoint_public_access = true
public_access_cidrs    = ["203.0.113.0/24"]

node_groups = {
  general = {
    instance_types = ["m6i.large", "m6a.large"]
    min_size       = 2
    max_size       = 6
    desired_size   = 3
    labels = {
      workload = "general"
    }
  }
}

apps = {
  payments-service = {
    namespace     = "payments"
    bucket_access = "read-write"
  }
}
