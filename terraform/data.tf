data "aws_iam_role" "main" {
  name = var.name

  depends_on = [ module.eks ]
}