output "name" { value = azurerm_kubernetes_cluster.aks.name }
output "id" { value = azurerm_kubernetes_cluster.aks.id }
output "kubelet_object_id" { value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.aks.oidc_issuer_url }
