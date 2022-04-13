resource "kubernetes_service_account" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn"               = "${module.cw_agent_pod_role.iam_role_arn}"
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
    labels = {
      "app.kubernetes.io/name"       = "cloudwatch-agent"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_cluster_role" "cloudwatch_agent_role" {
  metadata {
    name = "cloudwatch-agent-role"

    labels = {
      "app.kubernetes.io/name"       = "cloudwatch-agent"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = ["apps"]
    resources  = ["replicasets"]
  }

  rule {
    verbs      = ["list", "watch"]
    api_groups = ["batch"]
    resources  = ["jobs"]
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["nodes/proxy"]
  }

  rule {
    verbs      = ["create"]
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
  }

  rule {
    verbs          = ["get", "update"]
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cwagent-clusterleader"]
  }
}

resource "kubernetes_cluster_role_binding" "cloudwatch_agent_role_binding" {
  metadata {
    name = "cloudwatch-agent-role-binding"

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cloudwatch_agent.metadata[0].name
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cloudwatch_agent_role.metadata[0].name
  }
}

resource "kubernetes_config_map" "cwagentconfig" {
  metadata {
    name      = "cwagentconfig"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "app.kubernetes.io/name"       = "cloudwatch-agent"
    }
  }

  data = {
    "cwagentconfig.json" = <<EOF
      {
        "agent": {
          "region": "${data.aws_region.current.name}"
        },
        "logs": {
          "metrics_collected": {
            "kubernetes": {
              "cluster_name": "${local.cluster_name}",
              "metrics_collection_interval": 60
            }
          },
          "force_flush_interval": 5
        }
      }
    EOF
  }
}


resource "kubernetes_daemonset" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "cloudwatch-agent"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  spec {
    selector {
      match_labels = {
        name = "cloudwatch-agent"
      }
    }

    template {
      metadata {
        labels = {
          name = "cloudwatch-agent"
        }
      }

      spec {
        volume {
          name = "cwagentconfig"
          config_map {
            name = kubernetes_config_map.cwagentconfig.metadata[0].name
          }
        }

        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"
          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"
          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "containerdsock"
          host_path {
            path = "/run/dockershim.sock"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk/"
          }
        }

        termination_grace_period_seconds = 60
        service_account_name             = kubernetes_service_account.cloudwatch_agent.metadata[0].name

        container {
          name  = "cloudwatch-agent"
          image = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:1.247349.0b251399"

          env {
            name = "HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.8"
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            read_only  = true
            mount_path = "/rootfs"
          }

          volume_mount {
            name       = "dockersock"
            read_only  = true
            mount_path = "/var/run/docker.sock"
          }

          volume_mount {
            name       = "varlibdocker"
            read_only  = true
            mount_path = "/var/lib/docker"
          }

          volume_mount {
            name       = "containerdsock"
            read_only  = true
            mount_path = "/run/containerd/containerd.sock"
          }

          volume_mount {
            name       = "sys"
            read_only  = true
            mount_path = "/sys"
          }

          volume_mount {
            name       = "devdisk"
            read_only  = true
            mount_path = "/dev/disk"
          }
        }
      }
    }
  }
}
