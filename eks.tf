variable "admin_ipv4_cidr" {
  description = "Public IPv4 address allowed to reach the EKS API, in /32 notation."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_ipv4_cidr)) && endswith(var.admin_ipv4_cidr, "/32")
    error_message = "Use a single IPv4 address in /32 notation."
  }
}

locals {
  eks_private_subnet_ids = [
    aws_subnet.main["private_1"].id,
    aws_subnet.main["private_2"].id,
  ]
}

resource "aws_eks_cluster" "main" {
  name     = "student-platform"
  role_arn = aws_iam_role.eks_cluster.arn

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = local.eks_private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.admin_ipv4_cidr]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "student-platform-workers"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = local.eks_private_subnet_ids

  instance_types = ["c7i-flex.large"]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes,
    aws_route_table_association.private,
    aws_route_table_association.public,
  ]
}
