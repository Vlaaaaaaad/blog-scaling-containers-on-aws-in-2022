# module "cluster_autoscaler_pod_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
#   version = "4.8.0"
#
#   create_role      = true
#   role_name        = "${local.cluster_name}-irsa-cluster-autoscaler"
#   role_description = "IRSA role for cluster autoscaler"
#
#   provider_url                   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
#   role_policy_arns               = [aws_iam_policy.cluster_autoscaler.arn]
#   oidc_fully_qualified_subjects  = ["system:serviceaccount:kube-system:cluster-autoscaler-aws"]
#   oidc_fully_qualified_audiences = ["sts.${data.aws_partition.current.dns_suffix}"]
#
#   tags = local.tags
# }
#
# data "aws_iam_policy_document" "cluster_autoscaler" {
#   # Cluster-autoscaler permissions
#   # Copied from https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws
#   statement {
#     sid = "clusterautoscaler"
#
#     effect = "Allow"
#
#     actions = [
#       "autoscaling:DescribeAutoScalingGroups",
#       "autoscaling:DescribeAutoScalingInstances",
#       "autoscaling:DescribeLaunchConfigurations",
#       "autoscaling:DescribeTags",
#       "autoscaling:DescribeLaunchConfigurations",
#       "autoscaling:SetDesiredCapacity",
#       "autoscaling:TerminateInstanceInAutoScalingGroup",
#       "autoscaling:UpdateAutoScalingGroup",
#       "ec2:DescribeLaunchTemplateVersions",
#     ]
#
#     resources = ["*"]
#   }
# }
#
# resource "aws_iam_policy" "cluster_autoscaler" {
#   name   = "${local.cluster_name}-irsa-cluster-autoscaler"
#   policy = data.aws_iam_policy_document.cluster_autoscaler.json
#
#   tags = local.tags
# }
#
# resource "kubernetes_service_account" "cluster_autoscaler" {
#   metadata {
#     name      = "cluster-autoscaler"
#     namespace = "kube-system"
#
#     annotations = {
#       "eks.amazonaws.com/role-arn"               = "${module.cluster_autoscaler_pod_role.iam_role_arn}"
#       "eks.amazonaws.com/sts-regional-endpoints" = "true"
#     }
#     labels = {
#       "app.kubernetes.io/name"       = "cluster-autoscaler"
#       "app.kubernetes.io/managed-by" = "Terraform"
#     }
#   }
# }
#
# resource "helm_release" "cluster_autoscaler" {
#   name             = "cluster-autoscaler"
#   namespace        = "kube-system"
#   repository       = "https://kubernetes.github.io/autoscaler"
#   chart            = "cluster-autoscaler"
#   version          = "9.13.0"
#   create_namespace = false
#
#   set {
#     name  = "awsRegion"
#     value = data.aws_region.current.name
#   }
#
#   set {
#     name  = "rbac.serviceAccount.name"
#     value = "cluster-autoscaler-aws"
#   }
#
#   set {
#     name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.cluster_autoscaler_pod_role.iam_role_arn
#     type  = "string"
#   }
#
#   set {
#     name  = "autoDiscovery.clusterName"
#     value = module.eks.cluster_id
#   }
#
#   set {
#     name  = "autoDiscovery.enabled"
#     value = "true"
#   }
#
#   set {
#     name  = "rbac.create"
#     value = "true"
#   }
# }
