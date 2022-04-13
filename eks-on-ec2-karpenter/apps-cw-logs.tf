resource "kubernetes_config_map" "fluent_bit_cluster_info" {
  metadata {
    name      = "fluent-bit-cluster-info"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  data = {
    "cluster.name" = "${local.cluster_name}"
    "http.port"    = "2020"
    "http.server"  = "On"
    "logs.region"  = "${data.aws_region.current.name}"
    "read.head"    = "Off"
    "read.tail"    = "On"
  }
}

resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn"               = "${module.cw_agent_pod_role.iam_role_arn}"
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "kubernetes_cluster_role" "fluent_bit_role" {
  metadata {
    name = "fluent-bit-role"
  }

  rule {
    verbs             = ["get"]
    non_resource_urls = ["/metrics"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["namespaces", "pods", "pods/logs"]
  }
}

resource "kubernetes_cluster_role_binding" "fluent_bit_role_binding" {
  metadata {
    name = "fluent-bit-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluent_bit.metadata[0].name
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluent_bit_role.metadata[0].name
  }
}

resource "kubernetes_config_map" "fluent_bit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    labels = {
      k8s-app = "fluent-bit"
    }
  }

  data = {
    "application-log.conf" = <<-YAML
      [INPUT]
          Name                tail
          Tag                 application.*
          Exclude_Path        /var/log/containers/cloudwatch-agent*, /var/log/containers/fluent-bit*, /var/log/containers/aws-node*, /var/log/containers/kube-proxy*
          Path                /var/log/containers/*.log
          Docker_Mode         On
          Docker_Mode_Flush   5
          Docker_Mode_Parser  container_firstline
          Parser              regex
          DB                  /var/fluent-bit/state/flb_container.db
          Mem_Buf_Limit       50MB
          Skip_Long_Lines     Off
          Refresh_Interval    10
          Rotate_Wait         30
          storage.type        filesystem
          Read_from_Head      $${READ_FROM_HEAD}

      [INPUT]
          Name                tail
          Tag                 application.*
          Path                /var/log/containers/fluent-bit*
          Parser              docker
          DB                  /var/fluent-bit/state/flb_log.db
          Mem_Buf_Limit       5MB
          Skip_Long_Lines     On
          Refresh_Interval    10
          Read_from_Head      $${READ_FROM_HEAD}

      [INPUT]
          Name                tail
          Tag                 application.*
          Path                /var/log/containers/cloudwatch-agent*
          Docker_Mode         On
          Docker_Mode_Flush   5
          Docker_Mode_Parser  cwagent_firstline
          Parser              docker
          DB                  /var/fluent-bit/state/flb_cwagent.db
          Mem_Buf_Limit       5MB
          Skip_Long_Lines     On
          Refresh_Interval    10
          Read_from_Head      $${READ_FROM_HEAD}

      [FILTER]
          Name                kubernetes
          Match               application.*
          Kube_URL            https://kubernetes.default.svc:443
          Kube_Tag_Prefix     application.var.log.containers.
          Merge_Log           On
          Merge_Log_Key       log_processed
          K8S-Logging.Parser  On
          K8S-Logging.Exclude Off
          Labels              Off
          Annotations         Off

      [FILTER]
          Name parser
          Match *
          Key_Name log
          Parser regex
          Reserve_Data On

      [OUTPUT]
          Name                cloudwatch_logs
          Match               application.*
          region              $${AWS_REGION}
          log_group_name      /aws/containerinsights/$${CLUSTER_NAME}/application
          log_stream_prefix   $${HOST_NAME}-
          auto_create_group   true
          extra_user_agent    container-insights
    YAML

    "dataplane-log.conf" = <<-YAML
      [INPUT]
          Name                systemd
          Tag                 dataplane.systemd.*
          Systemd_Filter      _SYSTEMD_UNIT=docker.service
          Systemd_Filter      _SYSTEMD_UNIT=kubelet.service
          DB                  /var/fluent-bit/state/systemd.db
          Path                /var/log/journal
          Read_From_Tail      $${READ_FROM_TAIL}

      [INPUT]
          Name                tail
          Tag                 dataplane.tail.*
          Path                /var/log/containers/aws-node*, /var/log/containers/kube-proxy*
          Docker_Mode         On
          Docker_Mode_Flush   5
          Docker_Mode_Parser  container_firstline
          Parser              docker
          DB                  /var/fluent-bit/state/flb_dataplane_tail.db
          Mem_Buf_Limit       50MB
          Skip_Long_Lines     On
          Refresh_Interval    10
          Rotate_Wait         30
          storage.type        filesystem
          Read_from_Head      $${READ_FROM_HEAD}

      [FILTER]
          Name                modify
          Match               dataplane.systemd.*
          Rename              _HOSTNAME                   hostname
          Rename              _SYSTEMD_UNIT               systemd_unit
          Rename              MESSAGE                     message
          Remove_regex        ^((?!hostname|systemd_unit|message).)*$

      [FILTER]
          Name                aws
          Match               dataplane.*
          imds_version        v2

      [OUTPUT]
          Name                cloudwatch_logs
          Match               dataplane.*
          region              $${AWS_REGION}
          log_group_name      /aws/containerinsights/$${CLUSTER_NAME}/dataplane
          log_stream_prefix   $${HOST_NAME}-
          auto_create_group   true
          extra_user_agent    container-insights
    YAML

    "fluent-bit.conf" = <<-YAML
      [SERVICE]
          Flush                     5
          Log_Level                 error
          Daemon                    off
          Parsers_File              parsers.conf
          HTTP_Server               $${HTTP_SERVER}
          HTTP_Listen               0.0.0.0
          HTTP_Port                 $${HTTP_PORT}
          storage.path              /var/fluent-bit/state/flb-storage/
          storage.sync              normal
          storage.checksum          off
          storage.backlog.mem_limit 5M

      @INCLUDE application-log.conf
      @INCLUDE dataplane-log.conf
      @INCLUDE host-log.conf
    YAML

    "host-log.conf" = <<-YAML
      [INPUT]
          Name                tail
          Tag                 host.dmesg
          Path                /var/log/dmesg
          Parser              syslog
          DB                  /var/fluent-bit/state/flb_dmesg.db
          Mem_Buf_Limit       5MB
          Skip_Long_Lines     On
          Refresh_Interval    10
          Read_from_Head      $${READ_FROM_HEAD}

      [INPUT]
          Name                tail
          Tag                 host.messages
          Path                /var/log/messages
          Parser              syslog
          DB                  /var/fluent-bit/state/flb_messages.db
          Mem_Buf_Limit       5MB
          Skip_Long_Lines     On
          Refresh_Interval    10
          Read_from_Head      $${READ_FROM_HEAD}

      [INPUT]
          Name                tail
          Tag                 host.secure
          Path                /var/log/secure
          Parser              syslog
          DB                  /var/fluent-bit/state/flb_secure.db
          Mem_Buf_Limit       5MB
          Skip_Long_Lines     On
          Refresh_Interval    10
          Read_from_Head      $${READ_FROM_HEAD}

      [FILTER]
          Name                aws
          Match               host.*
          imds_version        v2

      [OUTPUT]
          Name                cloudwatch_logs
          Match               host.*
          region              $${AWS_REGION}
          log_group_name      /aws/containerinsights/$${CLUSTER_NAME}/host
          log_stream_prefix   $${HOST_NAME}.
          auto_create_group   true
          extra_user_agent    container-insights
      YAML

    "parsers.conf" = <<-YAML
      [PARSER]
          Name                docker
          Format              json
          Time_Key            time
          Time_Format         %Y-%m-%dT%H:%M:%S.%LZ

      [PARSER]
          Name                syslog
          Format              regex
          Regex               ^(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
          Time_Key            time
          Time_Format         %b %d %H:%M:%S

      [PARSER]
          Name                container_firstline
          Format              regex
          Regex               (?<log>(?<="log":")\S(?!\.).*?)(?<!\\)".*(?<stream>(?<="stream":").*?)".*(?<time>\d{4}-\d{1,2}-\d{1,2}T\d{2}:\d{2}:\d{2}\.\w*).*(?=})
          Time_Key            time
          Time_Format         %Y-%m-%dT%H:%M:%S.%LZ

      [PARSER]
          Name                cwagent_firstline
          Format              regex
          Regex               (?<log>(?<="log":")\d{4}[\/-]\d{1,2}[\/-]\d{1,2}[ T]\d{2}:\d{2}:\d{2}(?!\.).*?)(?<!\\)".*(?<stream>(?<="stream":").*?)".*(?<time>\d{4}-\d{1,2}-\d{1,2}T\d{2}:\d{2}:\d{2}\.\w*).*(?=})
          Time_Key            time
          Time_Format         %Y-%m-%dT%H:%M:%S.%LZ
      [PARSER]
          Name regex
          Format regex
          Regex ^(?<time>[^ ]+) (?<stream>[^ ]+) (?<logtag>[^ ]+) (?<message>.+)$
          Time_Key time
          Time_Format %Y-%m-%dT%H:%M:%S.%L%z
          Time_Keep On
          Decode_Field_As json message
    YAML
  }
}

resource "kubernetes_daemonset" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

    labels = {
      k8s-app                         = "fluent-bit"
      "kubernetes.io/cluster-service" = "true"
      version                         = "v1"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app                         = "fluent-bit"
          "kubernetes.io/cluster-service" = "true"
          version                         = "v1"
        }
      }

      spec {
        volume {
          name = "fluentbitstate"
          host_path {
            path = "/var/fluent-bit/state"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = "fluent-bit-config"
          config_map {
            name = kubernetes_config_map.fluent_bit_config.metadata[0].name
          }
        }

        volume {
          name = "runlogjournal"
          host_path {
            path = "/run/log/journal"
          }
        }

        volume {
          name = "dmesg"
          host_path {
            path = "/var/log/dmesg"
          }
        }

        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:2.21.4"

          env {
            name = "AWS_REGION"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "logs.region"
              }
            }
          }

          env {
            name = "CLUSTER_NAME"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "cluster.name"
              }
            }
          }

          env {
            name = "HTTP_SERVER"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "http.server"
              }
            }
          }

          env {
            name = "HTTP_PORT"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "http.port"
              }
            }
          }

          env {
            name = "READ_FROM_HEAD"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "read.head"
              }
            }
          }

          env {
            name = "READ_FROM_TAIL"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "read.tail"
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
            name  = "CI_VERSION"
            value = "k8s/1.3.8"
          }

          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              cpu    = "500m"
              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "fluentbitstate"
            mount_path = "/var/fluent-bit/state"
          }

          volume_mount {
            name       = "varlog"
            read_only  = true
            mount_path = "/var/log"
          }

          volume_mount {
            name       = "varlibdockercontainers"
            read_only  = true
            mount_path = "/var/lib/docker/containers"
          }

          volume_mount {
            name       = "fluent-bit-config"
            mount_path = "/fluent-bit/etc/"
          }

          volume_mount {
            name       = "runlogjournal"
            read_only  = true
            mount_path = "/run/log/journal"
          }

          volume_mount {
            name       = "dmesg"
            read_only  = true
            mount_path = "/var/log/dmesg"
          }

          image_pull_policy = "Always"
        }

        termination_grace_period_seconds = 10
        service_account_name             = kubernetes_service_account.fluent_bit.metadata[0].name

        toleration {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        toleration {
          operator = "Exists"
          effect   = "NoExecute"
        }

        toleration {
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }
}
