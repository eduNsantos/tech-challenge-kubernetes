
# ============================================================
# DATA SOURCES
# ============================================================

data "aws_caller_identity" "current" {}

locals {
  terraform_principal_arn = data.aws_caller_identity.current.arn
}

# ============================================================
# IAM ROLE - EKS CLUSTER
# ============================================================

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ============================================================
# IAM ROLE - EKS WORKER NODES
# ============================================================

resource "aws_iam_role" "eks_node" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ============================================================
# EKS CLUSTER
# ============================================================

resource "aws_eks_cluster" "main" {
  name     = "main"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.35"

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.sub_a.id,
      aws_subnet.sub_b.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ============================================================
# EKS ACCESS ENTRY
# ============================================================

resource "aws_eks_access_entry" "terraform_user" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.terraform_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_user_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.terraform_user.principal_arn

  access_scope {
    type = "cluster"
  }
}

# ============================================================
# EKS NODE GROUP
# ============================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main-ng"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.sub_a.id,
    aws_subnet.sub_b.id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_ecr
  ]
}
