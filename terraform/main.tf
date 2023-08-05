module "vpc" {
  source  = "punkerside/vpc/aws"
  version = "0.0.6"
  name    = var.name
}

module "eks" {
  source  = "punkerside/eks/aws"
  version = "0.0.5"

  name                   = var.name
  instance_types         = [ "c6a.16xlarge" ]
  max_size               = 20
  desired_size           = 2
  disk_size              = 512
  eks_version            = var.eks_version
  subnet_public_ids      = module.vpc.subnet_public_ids.*.id
  subnet_private_ids     = module.vpc.subnet_private_ids.*.id
  endpoint_public_access = true
}

# resource "aws_eks_node_group" "main" {
#   cluster_name         = module.eks.main.name
#   node_group_name      = "apps"
#   node_role_arn        = data.aws_iam_role.main.arn
#   subnet_ids           = module.vpc.subnet_private_ids.*.id
#   ami_type             = "AL2_x86_64"
#   capacity_type        = "SPOT"
#   disk_size            = 512
#   force_update_version = false
#   instance_types       = [ "c6a.16xlarge" ]

#   scaling_config {
#     desired_size = 1
#     max_size     = 20
#     min_size     = 1
#   }
# }