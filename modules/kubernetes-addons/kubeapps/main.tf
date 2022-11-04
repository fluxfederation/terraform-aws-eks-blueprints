locals {
  name                 = try(var.helm_config.name, "kubeapps")
  service_account_name = "${local.name}-sa"

  argocd_gitops_config = {
    enable             = true
    serviceAccountName = local.service_account_name
  }
}

module "helm_addon" {
  source = "../helm-addon"

  # https://github.com/vmware-tanzu/kubeapps/tree/main/chart/kubeapps
  helm_config = merge(
    {
      name             = "kubeapps"
      chart            = "kubeapps"
      repository       = "https://charts.bitnami.com/bitnami"
      version          = "12.0.0"
      namespace        = "kubeapps"
      values           = [file("${path.module}/values.yaml")]
      create_namespace = true
      description      = "Kubeapps Helm Chart deployment configuration"
    },
    var.helm_config
  )

  addon_context     = var.addon_context

}

resource "kubernetes_service_account_v1" "kubeapps" {
  metadata {
    name = "kubeapps-operator"
    namespace = module.helm_addon.helm_release[0].namespace
  }
}

resource "kubernetes_cluster_role_binding_v1" "kubeapps" {
  metadata {
    name = "kubeapps-operator-cluster-role-binding"
  }
  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account_v1.kubeapps.metadata[0].name
    namespace = module.helm_addon.helm_release[0].namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_secret_v1" "kubeapps-operator-token" {
  metadata {
    name = "kubeapps-operator-token"
    namespace = module.helm_addon.helm_release[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.kubeapps.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}
