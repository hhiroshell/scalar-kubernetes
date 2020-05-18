# Create network for kubernetes cluster
resource "azurerm_subnet" "subnet" {
  for_each = local.kubernetes_cluster_network

  name                 = each.key
  virtual_network_name = local.network_name
  resource_group_name  = local.network_name
  address_prefixes     = [each.value]

  lifecycle {
    ignore_changes = [
      enforce_private_link_endpoint_network_policies
    ]
  }
}

# Create a random sp name
resource "random_id" "id" {
  byte_length = 5
}

# Create application for Service Principals
resource "azuread_application" "aks_application_name" {
  name                       = "aks-${local.network_name}-${random_id.id.b64_url}"
  homepage                   = "https://aks-${local.network_name}-${random_id.id.b64_url}"
  identifier_uris            = ["https://aks-${local.network_name}-${random_id.id.b64_url}"]
  reply_urls                 = ["https://aks-${local.network_name}-${random_id.id.b64_url}"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = false

  # Waiting for AAD global replication - see https://github.com/Azure/AKS/issues/1206#issue-493516902
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

# Create Service Principal
resource "azuread_service_principal" "aks_service_principal" {
  application_id = azuread_application.aks_application_name.application_id
}

# Create password for Service Principal
resource "random_password" "aks_service_principal_password" {
  length  = 24
  special = false
}

# Assign Service Principal password (activation)
resource "azuread_service_principal_password" "aks_assign_service_principal_password" {
  service_principal_id = azuread_service_principal.aks_service_principal.id
  value                = random_password.aks_service_principal_password.result
  end_date             = timeadd(timestamp(), "87600h") # 10 years

  lifecycle {
    ignore_changes = [
      end_date,
      value
    ]
  }
}

# Retrieve scope id for assignment 
data "azurerm_subscription" "current" {
}

# Set assignment Contributor to Service Principal
resource "azurerm_role_assignment" "aks_service_principal_role_assignment" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.aks_service_principal.id

  # Waiting for AAD global replication - see https://github.com/Azure/AKS/issues/1206#issue-493516902
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [
    azuread_service_principal_password.aks_assign_service_principal_password
  ]
}

# AKS kubernetes cluster
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                    = local.kubernetes_cluster.name
  resource_group_name     = local.kubernetes_cluster.resource_group_name
  location                = local.kubernetes_cluster.location
  dns_prefix              = local.kubernetes_cluster.dns_prefix
  kubernetes_version      = local.kubernetes_cluster.kubernetes_version
  node_resource_group     = "${local.kubernetes_cluster.resource_group_name}_MC"
  private_cluster_enabled = true

  linux_profile {
    admin_username = local.kubernetes_cluster.admin_username
    ssh_key {
      key_data = file(local.kubernetes_cluster.public_ssh_key_path)
    }
  }

  default_node_pool {
    name                  = substr(local.kubernetes_default_node_pool.name, 0, 12)
    node_count            = local.kubernetes_default_node_pool.node_count
    vm_size               = local.kubernetes_default_node_pool.vm_size
    availability_zones    = var.kubernetes_cluster_availability_zones
    max_pods              = local.kubernetes_default_node_pool.max_pods
    os_disk_size_gb       = local.kubernetes_default_node_pool.os_disk_size_gb
    vnet_subnet_id        = azurerm_subnet.subnet["k8s_node_pod"].id
    enable_node_public_ip = "false"
    enable_auto_scaling   = local.kubernetes_default_node_pool.cluster_auto_scaling
    min_count             = local.kubernetes_default_node_pool.cluster_auto_scaling_min_count
    max_count             = local.kubernetes_default_node_pool.cluster_auto_scaling_max_count
  }

  role_based_access_control {
    enabled = local.kubernetes_cluster.role_based_access_control
  }

  addon_profile {
    kube_dashboard {
      enabled = local.kubernetes_cluster.kube_dashboard
    }
  }

  service_principal {
    client_id     = azuread_service_principal.aks_service_principal.application_id
    client_secret = azuread_service_principal_password.aks_assign_service_principal_password.value
  }

  network_profile {
    network_plugin     = local.kubernetes_cluster.network_plugin
    load_balancer_sku  = local.kubernetes_cluster.load_balancer_sku
    service_cidr       = local.kubernetes_cluster.service_cidr
    docker_bridge_cidr = local.kubernetes_cluster.docker_bridge_cidr
    dns_service_ip     = local.kubernetes_cluster.dns_service_ip
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      windows_profile
    ]
  }

  depends_on = [
    azurerm_role_assignment.aks_service_principal_role_assignment,
    azuread_service_principal_password.aks_assign_service_principal_password
  ]
}

# Add one more kubernetes node pool
resource "azurerm_kubernetes_cluster_node_pool" "aks_cluster_node_pool" {
  lifecycle {
    ignore_changes = [
      node_count
    ]
  }

  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  name                  = substr(local.kubernetes_additional_node_pools.name, 0, 12)
  node_count            = local.kubernetes_additional_node_pools.node_count
  vm_size               = local.kubernetes_additional_node_pools.vm_size
  availability_zones    = var.kubernetes_cluster_availability_zones
  max_pods              = local.kubernetes_additional_node_pools.max_pods
  os_disk_size_gb       = local.kubernetes_additional_node_pools.os_disk_size_gb
  os_type               = local.kubernetes_additional_node_pools.node_os
  vnet_subnet_id        = azurerm_subnet.subnet["k8s_node_pod"].id
  node_taints           = [local.kubernetes_additional_node_pools.taints]
  enable_node_public_ip = "false"
  enable_auto_scaling   = local.kubernetes_additional_node_pools.cluster_auto_scaling
  min_count             = local.kubernetes_additional_node_pools.cluster_auto_scaling_min_count
  max_count             = local.kubernetes_additional_node_pools.cluster_auto_scaling_max_count

  depends_on = [
    azurerm_subnet.subnet,
  ]
}
