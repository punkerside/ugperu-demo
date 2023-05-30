module "vpc" {
  source  = "punkerside/vpc/aws"
  version = "0.0.5"

  name = "${var.project}-${var.env}"
}

module "eks" {
  source  = "punkerside/eks/aws"
  version = "0.0.4"

  name               = "${var.project}-${var.env}"
  instance_types     = [ "c6a.16xlarge" ]
  # instance_types     = [ "c6a.16xlarge", "c6a.24xlarge", "m6a.16xlarge", "m6a.24xlarge", "r6a.16xlarge", "r6a.24xlarge" ]
  max_size           = 20
  disk_size          = 1024
  eks_version        = var.eks_version
  subnet_public_ids  = module.vpc.subnet_public_ids.*.id
  subnet_private_ids = module.vpc.subnet_private_ids.*.id
}