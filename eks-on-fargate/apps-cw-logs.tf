resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"

    annotations = {
      name = " aws-observability"
    }

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "aws-observability"            = "enabled"
      "app.kubernetes.io/name"       = "aws-logging"
    }
  }
}

resource "kubernetes_config_map" "aws_observability_config" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability.metadata[0].name

    annotations = {
      name = "aws-logging"
    }

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "app.kubernetes.io/name"       = "aws-logging"
    }
  }


  data = {
    "parsers.conf" = <<-EOT
    [PARSER]
      Name regex
      Format regex
      Regex ^(?<time>[^ ]+) (?<stream>[^ ]+) (?<logtag>[^ ]+) (?<message>.+)$
      Time_Key time
      Time_Format %Y-%m-%dT%H:%M:%S.%L%z
      Time_Keep On
      Decode_Field_As json message
    EOT
    "filters.conf" = <<-EOT
    [FILTER]
      Name parser
      Match *
      Key_Name log
      Parser regex
      Reserve_Data On
    EOT
    "output.conf"  = <<-EOT
    [OUTPUT]
      Name cloudwatch_logs
      Match *
      region ${data.aws_region.current.name}
      sts_endpoint https://sts.${data.aws_region.current.name}.amazonaws.com
      endpoint https://logs.${data.aws_region.current.name}.amazonaws.com
      log_group_name /aws/eks/${local.cluster_name}/myapp
      log_stream_prefix fargate-
      auto_create_group true
    EOT
  }
}
