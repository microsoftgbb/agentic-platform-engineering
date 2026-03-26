resource "random_password" "argocd_admin" {
  length  = 16
  special = true
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(random_password.argocd_admin.result)
  }

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  # Enable notifications controller for ArgoCD notifications
  set {
    name  = "notifications.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.argocd]
}
