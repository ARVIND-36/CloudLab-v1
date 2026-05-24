# =============================================================================
# CloudLab: On-Demand DevOps Lab Platform
# Terraform Variables — Parameterized Infrastructure Inputs
# =============================================================================
# These variables allow the infrastructure to be customized at deploy time
# without modifying the core Terraform configuration. Values are injected via
# the GitHub Actions workflow using TF_VAR_ environment variables.
# =============================================================================

# ---------------------------------------------------------------------------
# Azure Region — Where to deploy the lab resources
# ---------------------------------------------------------------------------
variable "azure_region" {
  description = "The Azure region where all lab resources will be provisioned."
  type        = string
  default     = "East US"

  validation {
    condition     = length(var.azure_region) > 0
    error_message = "Azure region must not be empty."
  }
}

# ---------------------------------------------------------------------------
# VM Size — Controls the compute capacity of the lab VM
# ---------------------------------------------------------------------------
variable "vm_size" {
  description = "The size (SKU) of the Azure Virtual Machine. Default is a burstable B1s instance suitable for lightweight lab work."
  type        = string
  default     = "Standard_B1s"

  validation {
    condition     = can(regex("^Standard_", var.vm_size))
    error_message = "VM size must be a valid Azure SKU starting with 'Standard_'."
  }
}

# ---------------------------------------------------------------------------
# SSH Public Key — Used for passwordless authentication to the VM
# ---------------------------------------------------------------------------
variable "ssh_public_key" {
  description = "The SSH public key to be injected into the VM for secure, passwordless authentication. This should be stored as a GitHub Actions secret."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Lab Name — Dynamic prefix for resources (e.g., java or docker)
# ---------------------------------------------------------------------------
variable "lab_name" {
  description = "The prefix name for the lab environment (e.g. 'java', 'docker') to isolate different environments."
  type        = string
  default     = "cloudlab"
}
