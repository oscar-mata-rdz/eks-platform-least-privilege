region              = "us-west-2"
allowed_account_ids = ["000000000000"]

team        = "payments"
environment = "prod"
tags = {
  CostCenter = "payments"
}

vpc_cidr           = "10.20.0.0/16"
az_count           = 2
single_nat_gateway = true

kubernetes_version     = "1.34"
endpoint_public_access = false

node_groups = {
  general = {
    instance_types = ["m6i.large", "m6a.large"]
    min_size       = 1
    max_size       = 4
    desired_size   = 2
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
