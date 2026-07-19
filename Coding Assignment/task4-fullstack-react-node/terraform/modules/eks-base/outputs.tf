output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
