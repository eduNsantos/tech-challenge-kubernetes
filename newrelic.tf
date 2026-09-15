resource "helm_release" "newrelic" {
  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"

  namespace        = "postech"
  create_namespace = true

  values = [
    file("${path.module}/newrelic-values.yaml")
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_eks_access_policy_association.terraform_user_admin
  ]
}