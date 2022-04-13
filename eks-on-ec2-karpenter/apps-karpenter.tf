resource "kubernetes_namespace" "karpenter" {
  metadata {
    annotations = {
      name = "karpenter"
    }

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }

    name = "karpenter"
  }
}


module "karpenter_pod_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.8.0"

  create_role      = true
  role_name        = "${local.cluster_name}-irsa-karpenter"
  role_description = "IRSA role for karpenter"

  provider_url                   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns               = [aws_iam_policy.karpenter.arn]
  oidc_fully_qualified_subjects  = ["system:serviceaccount:karpenter:karpenter"]
  oidc_fully_qualified_audiences = ["sts.${data.aws_partition.current.dns_suffix}"]

  tags = local.tags
}

data "aws_iam_policy_document" "karpenter" {
  # Karpenter permissions
  # Copied from https://karpenter.sh/docs/getting-started-with-terraform/
  statement {
    sid = "karpenter"

    effect = "Allow"

    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateTags",
      "iam:PassRole",
      "ec2:TerminateInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ssm:GetParameter",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "karpenter" {
  name   = "${local.cluster_name}-irsa-karpenter"
  policy = data.aws_iam_policy_document.karpenter.json

  tags = local.tags
}

# resource "helm_release" "karpenter" {
#   name             = "karpenter"
#   namespace        = kubernetes_namespace.karpenter.metadata[0].name
#   repository       = "https://charts.karpenter.sh"
#   chart            = "karpenter"
#   version          = "0.5.4"
#   create_namespace = false
#
#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.karpenter_pod_role.iam_role_arn
#   }
#
#   set {
#     name  = "controller.clusterName"
#     value = module.eks.cluster_id
#   }
#
#   set {
#     name  = "controller.clusterEndpoint"
#     value = module.eks.cluster_endpoint
#   }
# }

# resource "helm_release" "karpenter_thingie" {
#   repository = "https://charts.helm.sh/incubator"
#   chart      = "raw"
#
#   namespace = "default"
#   name      = "karpenter-thingie"
#
#   values = [<<YAML
#     resources:
#       - apiVersion: karpenter.sh/v1alpha5
#         kind: Provisioner
#         metadata:
#           name: default
#         spec:
#           ttlSecondsAfterEmpty: 120
#           requirements:
#             - key: karpenter.sh/capacity-type
#               operator: In
#               values: ["spot"]
#             - key: node.kubernetes.io/instance-type
#               operator: In
#               values: ["c6g.4xlarge"]
#             - key: kubernetes.io/arch
#               operator: In
#               values: ["arm64"]
#           provider:
#             instanceProfile: ${aws_iam_instance_profile.karpenter.name}
#             launchTemplate: ${aws_launch_template.karpenter.name}
#             subnetSelector:
#               karpenter-yas: '*'
#             securityGroupSelector:
#               karpenter-yas: '*'
#   YAML
#   ]
# }
