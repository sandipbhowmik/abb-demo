# ACA → AKS Infra with Secure MySQL Credentials + Key Vault CSI

This stack:
- Replaces ACA with **AKS** (AAD RBAC, OIDC, Azure CNI+policy, Insights)
- Provisions **VNet/Subnets/NSGs**, **ACR**, **Key Vault**, **Log Analytics + App Insights**
- Creates **MySQL Flexible Server** with **auto-generated password**
- Stores DB credentials in **Key Vault**
- Configures **Workload Identity** so AKS pods can mount KV secrets via **CSI driver**
- Includes an **Azure Storage** backend bootstrap for remote Terraform state

## Apply
```bash
terraform init
terraform apply -auto-approve   -var subscription_id="00000000-0000-0000-0000-000000000000"   -var tenant_id="00000000-0000-0000-0000-000000000000"   -var location="westeurope"   -var rg_name="rg-java-on-aks-dev"   -var name_prefix="petclinic-dev"
```

## Get kubeconfig
```bash
az aks get-credentials -g rg-java-on-aks-dev -n petclinic-dev-aks
```

## Mount KV secrets in AKS
1. Create namespace + service account:
```bash
kubectl create namespace apps
kubectl create sa petclinic-sa -n apps
```
2. Edit `examples/k8s/secretproviderclass.yaml` and replace `<CLIENT_ID>`, `<VAULT_NAME>`, `<TENANT_ID>`.
3. Apply:
```bash
kubectl apply -f examples/k8s/secretproviderclass.yaml
```

## Remote state backend
Use `backend/bootstrap` to create the storage account/container and then copy `backend.tf.example` → `backend.tf` and re-run `terraform init`.


## Azure OpenAI (optional)
- Module path: `modules/ai/openai` (AzAPI-based scaffold)
- Default: `enable = false`. To deploy:
```hcl
module "ai_openai" {
  source      = "./modules/ai/openai"
  enable      = true
  location    = var.location
  rg_name     = azurerm_resource_group.rg.name
  name_prefix = var.name_prefix
  tags        = var.tags
}
```
> Note: Azure OpenAI requires approved access in your subscription and region.


## Azure OpenAI with Deployment + RBAC
- Module: `modules/ai/openai` now supports **model deployments** and **RBAC grant**.
- Default block is present in `main.tf` (set `enable = true` to provision).
- Variables to tweak:
  - `deployment_name`, `model_name`, `model_version`, `sku_name`, `capacity`
- RBAC:
  - Grants `Cognitive Services OpenAI User` to the **AKS UAMI** (`module.workload_identity.uami_principal_id`).
- Note: Azure OpenAI requires allowed subscription + supported region & model availability.
