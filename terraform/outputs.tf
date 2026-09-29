output "cluster_name" {
  value = aws_eks_cluster.lab.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.lab.endpoint
}

output "node_group_name" {
  value = aws_eks_node_group.workers.node_group_name
}

output "image_repository" {
  value = aws_ecr_repository.app.repository_url
}

output "app_log_group" {
  value = aws_cloudwatch_log_group.app.name
}

output "security_group" {
  value = aws_security_group.sg
}
