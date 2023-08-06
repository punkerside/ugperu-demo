module "vpc" {
  source  = "punkerside/vpc/aws"
  version = "0.0.6"
  name    = var.name
}

resource "aws_ec2_tag" "elb_private" {
  count       = length(module.vpc.subnet_private_ids.*.id)
  resource_id = element(module.vpc.subnet_private_ids.*.id, count.index)
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
  depends_on = [aws_eks_node_group.main]
}

resource "aws_ec2_tag" "elb_public" {
  count       = length(module.vpc.subnet_public_ids.*.id)
  resource_id = element(module.vpc.subnet_public_ids.*.id, count.index)
  key         = "kubernetes.io/role/elb"
  value       = "1"
  depends_on = [aws_eks_node_group.main]
}

resource "aws_ec2_tag" "karpenter" {
  count       = length(module.vpc.subnet_private_ids.*.id)
  resource_id = element(module.vpc.subnet_private_ids.*.id, count.index)
  key         = "karpenter.sh/discovery"
  value       = var.name
  depends_on = [aws_eks_node_group.main]
}

resource "aws_iam_role" "main" {
  name               = var.name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["eks.amazonaws.com", "ec2.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = var.name
  }
}

resource "aws_iam_role_policy" "main" {
  name = var.name
  role = aws_iam_role.main.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*",
        "wafv2:*",
        "waf-regional:*",
        "sts:AssumeRoleWithWebIdentity",
        "sts:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "AutoScalingFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  role       = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2RoleforSSM" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.main.name
}

resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.main.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = concat(sort(module.vpc.subnet_public_ids.*.id), sort(module.vpc.subnet_private_ids.*.id), )
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name = var.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy
  ]
}

resource "aws_launch_template" "main" {
  name                    = var.name
  disable_api_termination = false
  ebs_optimized           = true
  user_data               = filebase64("init.sh")

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 500
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = var.name
      "karpenter.sh/discovery" = var.name
    }
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name         = aws_eks_cluster.main.name
  node_group_name      = "default"
  node_role_arn        = aws_iam_role.main.arn
  subnet_ids           = module.vpc.subnet_private_ids.*.id
  ami_type             = "AL2_x86_64"
  capacity_type        = "SPOT"
  force_update_version = false
  instance_types       = ["c6a.16xlarge"]

  launch_template {
    name    = aws_launch_template.main.name
    version = aws_launch_template.main.latest_version
  }

  scaling_config {
    desired_size = 1
    max_size     = 20
    min_size     = 1
  }

  tags = {
    Name = var.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity.0.oidc.0.issuer
}


data "aws_caller_identity" "main" {}
data "aws_region" "main" {}

resource "aws_iam_role" "karpenter" {
  name               = "${var.name}-karpenter"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${data.aws_caller_identity.main.account_id}:oidc-provider/oidc.eks.${data.aws_region.main.name}.amazonaws.com/id/${substr(aws_eks_cluster.main.identity.0.oidc.0.issuer, -32, -1)}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.${data.aws_region.main.name}.amazonaws.com/id/${substr(aws_eks_cluster.main.identity.0.oidc.0.issuer, -32, -1)}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

  tags = {
    Name = "${var.name}-karpenter"
  }
}

resource "aws_iam_role_policy" "karpenter" {
  name = "${var.name}-karpenter"
  role = aws_iam_role.karpenter.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}