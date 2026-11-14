data "aws_caller_identity" "current" {}

data "aws_iam_roles" "eks_cluster" {
  name_regex = ".*LabEksClusterRole.*"
}

data "aws_iam_role" "eks_cluster" {
  name = one(data.aws_iam_roles.eks_cluster.names)
}

data "aws_iam_roles" "eks_node" {
  name_regex = ".*LabEksNodeRole.*"
}

data "aws_iam_role" "eks_node" {
  name = one(data.aws_iam_roles.eks_node.names)
}

locals {
  caller_session_parts = regex(
    "^arn:([^:]+):sts::([0-9]+):assumed-role/([^/]+)/[^/]+$",
    data.aws_caller_identity.current.arn
  )

  terraform_principal_arn = "arn:${local.caller_session_parts[0]}:iam::${local.caller_session_parts[1]}:role/${local.caller_session_parts[2]}"
}

resource "aws_eks_cluster" "main" {
  name = "main"

  access_config {
    authentication_mode = "API"
  }

  role_arn = data.aws_iam_role.eks_cluster.arn
  version  = "1.35"

  vpc_config {
    subnet_ids = [
      aws_subnet.sub_a.id,
      aws_subnet.sub_b.id
    ]
  }

}

resource "aws_eks_access_entry" "terraform_user" {
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = local.terraform_principal_arn
  type              = "STANDARD"
  kubernetes_groups = []
}

resource "aws_eks_access_policy_association" "terraform_user_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.terraform_user.principal_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main-ng"
  node_role_arn   = data.aws_iam_role.eks_node.arn
  subnet_ids      = [aws_subnet.sub_a.id, aws_subnet.sub_b.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

}
