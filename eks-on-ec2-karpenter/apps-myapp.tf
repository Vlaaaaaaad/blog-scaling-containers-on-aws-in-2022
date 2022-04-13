module "myapp_pod_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.8.0"

  create_role      = true
  role_name        = "${local.cluster_name}-irsa-myapp"
  role_description = "IRSA role for myapp"

  provider_url                   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns               = [aws_iam_policy.myapp.arn]
  oidc_fully_qualified_subjects  = ["system:serviceaccount:default:myapp"]
  oidc_fully_qualified_audiences = ["sts.${data.aws_partition.current.dns_suffix}"]

  tags = local.tags
}

resource "aws_iam_policy" "myapp" {
  name   = "${local.cluster_name}-irsa-myapp"
  policy = data.aws_iam_policy_document.aws_vpc_cni.json

  tags = local.tags
}

data "aws_iam_policy_document" "myapp" {
  # Nothing cause the application code does not call any AWS APIs
}

resource "kubernetes_service_account" "myapp" {
  metadata {
    name      = "myapp"
    namespace = "default"

    annotations = {
      "eks.amazonaws.com/role-arn"               = "${module.myapp_pod_role.iam_role_arn}"
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
    labels = {
      "app.kubernetes.io/name"       = "myapp"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# resource "helm_release" "myapp_sg" {
#   repository = "https://charts.helm.sh/incubator"
#   chart      = "raw"
#
#   namespace = "default"
#   name      = "myapp-sg"
#
#   # TODO: some of these SGs are definitely not needed
#   values = [<<YAML
#     resources:
#       - apiVersion: vpcresources.k8s.aws/v1beta1
#         kind: SecurityGroupPolicy
#         metadata:
#           name: myap-sg
#         spec:
#           podSelector: {}
#           securityGroups:
#             groupIds:
#               - ${aws_security_group.sg_per_pod_myapp.id}
#               - ${aws_security_group.sg_per_pod_all.id}
#               - ${module.eks.cluster_primary_security_group_id}
#               - ${module.eks.node_security_group_id}
#   YAML
#   ]
# }

resource "aws_security_group" "sg_per_pod_myapp" {
  name = format("%.255s", "${local.cluster_name}_sg_per_pod_myapp")
  description = format(
    "%.255s",
    "Terraform-managed base SG for Fargate tasks in ${local.cluster_name}",
  )
  vpc_id = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_security_group_rule" "sg_per_pod_myapp_to_internet" {
  security_group_id = aws_security_group.sg_per_pod_myapp.id
  description       = "Allow HTTPS traffic out to the Internet"

  type      = "egress"
  protocol  = "tcp"
  from_port = 443
  to_port   = 443

  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "myapp_from_eks_spot" {
  security_group_id = aws_security_group.sg_per_pod_myapp.id
  description       = "Allow traffic from EC2: the Spot EKS Managed Node Group"

  type      = "ingress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = module.eks.eks_managed_node_groups.spot.security_group_id
}

resource "kubernetes_deployment" "myapp" {
  metadata {
    name      = "myapp"
    namespace = "default"

    labels = {
      "app.kubernetes.io/name"       = "myapp"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    # replicas = 3500
    replicas = 0

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "myapp"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"       = "myapp"
          "app.kubernetes.io/managed-by" = "Terraform"
        }
      }

      spec {
        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account.myapp.metadata[0].name

        container {
          name              = "myapp"
          image             = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}/test-app-2022:241ac4b1c44fce7e1754b587a6c589204a7be92a"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5002
          }
          security_context {
            read_only_root_filesystem  = false # Python!
            privileged                 = false
            allow_privilege_escalation = false
          }

          env {
            name  = "VLAAAAAAAD_ORCHESTRATOR_TYPE"
            value = "eks"
          }
          env {
            name  = "VLAAAAAAAD_RUNNER_TYPE"
            value = "ec2"
          }
          env {
            name  = "MY_K8S_SCALER"
            value = "karpenter"
          }
          env {
            name = "MY_POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name = "MY_NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          env {
            name = "MY_POD_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          env {
            name = "MY_POD_UID"
            value_from {
              field_ref {
                field_path = "metadata.uid"
              }
            }
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
            requests = {
              cpu    = "1"
              memory = "2Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/status/alive"
              port = "5002"
            }
          }
          readiness_probe {
            http_get {
              path = "/status/healthy"
              port = "5002"
            }
          }
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "eks.amazonaws.com/capacityType"
                  operator = "In"
                  values   = ["SPOT"]
                }
              }
            }
          }
        }
      }
    }
  }
}
