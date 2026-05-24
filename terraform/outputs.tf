# =============================================================================
# CloudLab: On-Demand DevOps Lab Platform
# Terraform Outputs — Exported Values for Downstream Consumption
# =============================================================================
# These outputs expose key resource attributes (like the VM's public IP)
# so they can be captured by the GitHub Actions workflow and passed to Ansible.
# =============================================================================

# ---------------------------------------------------------------------------
# VM Public IP — Used by Ansible to connect and configure the lab VM
# ---------------------------------------------------------------------------
output "vm_public_ip" {
  description = "The public IP address of the provisioned CloudLab VM. Used to generate the Ansible inventory and for SSH access."
  value       = azurerm_public_ip.cloudlab_pip.ip_address
}
