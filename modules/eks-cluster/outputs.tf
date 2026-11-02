output "cluster_name" {
  value = aws_eks_cluster.this.name

  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.pod_identity_agent,
  ]
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_group_names" {
  value = keys(aws_eks_node_group.this)
}
