data "aws_caller_identity" "main" {}
data "aws_region" "main" {}

data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_security_group" "main" {
  filter {
    name = "tag:kubernetes.io/cluster/${var.name}"
    values = ["owned"]
  }

  depends_on = [aws_eks_node_group.main]
}