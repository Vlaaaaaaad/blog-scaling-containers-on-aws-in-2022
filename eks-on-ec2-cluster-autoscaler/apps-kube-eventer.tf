resource "kubernetes_deployment" "kube_eventer" {
  metadata {
    name      = "kube-eventer"
    namespace = "kube-system"

    labels = {
      name = "kube-eventer"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kube-eventer"
      }
    }

    template {
      metadata {
        labels = {
          app = "kube-eventer"
        }
      }

      spec {
        dns_policy           = "ClusterFirstWithHostNet"
        service_account_name = kubernetes_service_account.kube_eventer.metadata[0].name

        container {
          name  = "kube-eventer"
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}/kube-eventer:latest"
          command = [
            "/kube-eventer",
            "--source=kubernetes:https://kubernetes.default",
            "--sink=honeycomb:?dataset=k8s-${local.cluster_name}&writekey=haha",
          ]

          env {
            name  = "TZ"
            value = "UTC"
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "500Mi"
            }
            requests = {
              cpu    = "1"
              memory = "500Mi"
            }
          }

          volume_mount {
            name       = "localtime"
            read_only  = true
            mount_path = "/etc/localtime"
          }
        }

        volume {
          name = "localtime"

          host_path {
            path = "/etc/localtime"
          }
        }
      }
    }
  }
}

resource "kubernetes_cluster_role" "kube_eventer" {
  metadata {
    name = "kube-eventer"
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["configmaps", "events"]
  }
}

resource "kubernetes_cluster_role_binding" "kube_eventer" {
  metadata {
    name = "kube-eventer"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kube_eventer.metadata[0].name
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kube_eventer.metadata[0].name
  }
}

resource "kubernetes_service_account" "kube_eventer" {
  metadata {
    name      = "kube-eventer"
    namespace = "kube-system"
  }
}
