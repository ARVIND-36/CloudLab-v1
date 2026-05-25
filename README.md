# ☁️ CloudLab: On-Demand DevOps Lab Platform

An automated, multi-tenant cloud platform that provisions secure, pre-configured development lab environments in **Microsoft Azure** on-demand — triggered entirely from a **GitHub Actions** UI.

Built with **Terraform** (Infrastructure as Code), **Ansible** (Configuration Management), and **GitHub Actions** (CI/CD Orchestration).

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Setup Guide](#setup-guide)
  - [1. Azure Service Principal](#1-create-an-azure-service-principal)
  - [2. SSH Key Pair](#2-generate-an-ssh-key-pair)
  - [3. GitHub Secrets](#3-configure-github-secrets)
- [Usage](#usage)
  - [Deploying a Lab](#deploying-a-lab)
  - [Connecting via SSH](#connecting-via-ssh)
- [Lab Environments](#lab-environments)
- [Multi-Tenancy](#multi-tenancy)
- [Troubleshooting](#troubleshooting)
- [Future Scope](#future-scope)

---

## Overview

**CloudLab** solves the classic _"it works on my machine"_ problem in university DevOps courses. Instead of spending hours installing tools locally, students click a button on GitHub and receive a fully configured cloud VM in under 3 minutes.

### Key Features

- **One-Click Deployment** — Trigger lab creation from a simple GitHub Actions dropdown UI.
- **Conditional Configuration** — Choose between a Java (JDK 17 + Maven) or Docker (Engine + Compose) development environment.
- **Multi-Tenant Isolation** — Each user gets their own isolated Azure Resource Group, networking, and VM based on their GitHub username.
- **Secure by Default** — SSH key-based authentication only; password login is disabled. NSG rules restrict all traffic to Port 22.
- **Hardware Independent** — Students can connect from any device (Windows, macOS, Linux, Chromebook) using a standard SSH client.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions (CI/CD)                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  workflow_dispatch UI                                      │  │
│  │  ├── lab_type:     [java | docker]                        │  │
│  │  ├── vm_size:      [Standard_B1s | Standard_B2s | ...]    │  │
│  │  └── azure_region: [South India | Central India | ...]    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│              ┌───────────────┴───────────────┐                  │
│              ▼                               ▼                  │
│  ┌──────────────────────┐      ┌──────────────────────────┐    │
│  │  Job 1: Provision    │      │  Job 2: Configure        │    │
│  │  (Terraform)         │─────▶│  (Ansible)               │    │
│  │                      │ IP   │                          │    │
│  │  • Resource Group    │      │  • common role           │    │
│  │  • Virtual Network   │      │  • java-lab role (if)    │    │
│  │  • Subnet            │      │  • docker-lab role (if)  │    │
│  │  • NSG (Port 22)     │      │                          │    │
│  │  • Public IP         │      │  inventory.ini ◄── IP    │    │
│  │  • Ubuntu 22.04 VM   │      │                          │    │
│  └──────────────────────┘      └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                 ┌──────────────────────┐
                 │  Azure Cloud VM      │
                 │  ┌────────────────┐  │
                 │  │ common tools   │  │
                 │  │ git, curl, zip │  │
                 │  ├────────────────┤  │
                 │  │ java-lab OR    │  │
                 │  │ docker-lab     │  │
                 │  └────────────────┘  │
                 │                      │
                 │  ssh azureuser@IP    │
                 └──────────────────────┘
```

---

## Tech Stack

| Component            | Technology                  | Purpose                                      |
| :------------------- | :-------------------------- | :------------------------------------------- |
| **CI/CD**            | GitHub Actions              | Workflow orchestration and user interface     |
| **Infrastructure**   | Terraform (azurerm ~> 3.80) | Declarative Azure resource provisioning       |
| **Configuration**    | Ansible                     | Automated software installation via SSH       |
| **Cloud Provider**   | Microsoft Azure             | Virtual Machines, Networking, Security Groups |
| **Operating System** | Ubuntu 22.04 LTS            | Base image for all lab VMs                    |

---

## Directory Structure

```
cloudlab-platform/
├── .github/
│   └── workflows/
│       └── deploy-lab.yml          # GitHub Actions workflow (CI/CD engine)
├── terraform/
│   ├── main.tf                     # Azure provider, VNet, NSG, VM definitions
│   ├── variables.tf                # Input variables (region, VM size, SSH key)
│   └── outputs.tf                  # Output: VM public IP address
├── ansible/
│   ├── playbook.yml                # Main playbook with conditional role execution
│   └── roles/
│       ├── common/
│       │   └── tasks/
│       │       └── main.yml        # Baseline tools (git, curl, zip, vim, htop)
│       ├── java-lab/
│       │   └── tasks/
│       │       └── main.yml        # OpenJDK 17, Maven, JAVA_HOME configuration
│       └── docker-lab/
│           └── tasks/
│               └── main.yml        # Docker Engine, Compose, user group setup
└── README.md                       # This file
```

---

## Prerequisites

Before setting up CloudLab, ensure you have:

- A **GitHub account** with a repository for this project.
- An **Azure account** (Free tier, Student, or Pay-As-You-Go subscription).
- The **Azure CLI** installed locally — [Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).
- An **SSH client** on your local machine (built-in on macOS/Linux; OpenSSH on Windows 10+).

---

## Setup Guide

### 1. Create an Azure Service Principal

The GitHub Actions runner needs credentials to provision resources in your Azure account.

```bash
# Log in to Azure
az login

# Get your Subscription and Tenant IDs
az account show --query "{subscriptionId:id, tenantId:tenantId}" --output json

# Create a Service Principal with Contributor access
az ad sp create-for-rbac \
  --name "github-actions-cloudlab" \
  --role contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
  --json-auth
```

Save the output — you will need `clientId`, `clientSecret`, `subscriptionId`, and `tenantId`.

---

### 2. Generate an SSH Key Pair

This key pair allows Terraform to inject the public key into the VM and Ansible/users to authenticate via the private key.

```bash
ssh-keygen -t rsa -b 4096 -f ./cloudlab_key -N ""
```

This generates two files:
- `cloudlab_key` — **Private key** (used to SSH into the VM)
- `cloudlab_key.pub` — **Public key** (injected into the VM by Terraform)

> ⚠️ **Important:** Never commit the private key to your repository.

---

### 3. Configure GitHub Secrets

Navigate to your GitHub repository: **Settings → Secrets and variables → Actions → New repository secret**.

Add the following **6 secrets**:

| Secret Name              | Value                                                      |
| :----------------------- | :--------------------------------------------------------- |
| `ARM_CLIENT_ID`          | `clientId` from the Service Principal output               |
| `ARM_CLIENT_SECRET`      | `clientSecret` from the Service Principal output           |
| `ARM_SUBSCRIPTION_ID`    | `subscriptionId` from the Service Principal output         |
| `ARM_TENANT_ID`          | `tenantId` from the Service Principal output               |
| `SSH_PRIVATE_KEY`        | Full contents of `cloudlab_key` (including BEGIN/END lines) |
| `TF_VAR_ssh_public_key`  | Full contents of `cloudlab_key.pub`                        |

---

## Usage

### Deploying a Lab

1. Go to your repository on GitHub.
2. Click the **Actions** tab.
3. Select **☁️ Deploy CloudLab Environment** from the left sidebar.
4. Click the **Run workflow** dropdown.
5. Fill in the input fields:
   - **Lab Environment Type:** `java` or `docker`
   - **Azure VM Size:** `Standard_B1s` (default), `Standard_B1ms`, or `Standard_B2s`
   - **Azure Region:** `South India`, `Central India`, `West India`, etc.
6. Click the green **Run workflow** button.
7. Wait approximately **2–3 minutes** for the workflow to complete (all green checks).

---

### Connecting via SSH

Once the workflow completes:

1. Open the completed workflow run on GitHub.
2. Expand the **⚙️ Configure Lab Environment** job.
3. Click on the **📊 Deployment Summary** step to find the VM's **Public IP** and **SSH command**.

#### On macOS / Linux:
```bash
ssh -i ./cloudlab_key azureuser@<VM_PUBLIC_IP>
```

#### On Windows (PowerShell):
```powershell
# Fix key file permissions (run once)
icacls .\cloudlab_key /inheritance:r /grant:r "${env:USERNAME}:F"

# Connect
ssh -i .\cloudlab_key azureuser@<VM_PUBLIC_IP>
```

#### On Windows (Command Prompt):
```cmd
# Fix key file permissions (run once)
icacls .\cloudlab_key /inheritance:r /grant:r %USERNAME%:F

# Connect
ssh -i .\cloudlab_key azureuser@<VM_PUBLIC_IP>
```

---

## Lab Environments

### ☕ Java Lab (`lab_type: java`)

Pre-installed software:
- **OpenJDK 17** (LTS) with `JAVA_HOME` configured system-wide
- **Apache Maven** for build automation
- Dedicated workspace at `~/java-lab-workspace`

Quick verification after connecting:
```bash
java -version          # Verify JDK 17
mvn -version           # Verify Maven
cd ~/java-lab-workspace
```

### 🐳 Docker Lab (`lab_type: docker`)

Pre-installed software:
- **Docker Engine** (Community Edition)
- **Docker Compose V2** (plugin)
- `azureuser` added to `docker` group (no `sudo` required)
- Dedicated workspace at `~/docker-lab-workspace`

Quick verification after connecting:
```bash
docker --version           # Verify Docker Engine
docker compose version     # Verify Compose
cd ~/docker-lab-workspace
docker run --rm hello-world
```

---

## Multi-Tenancy

CloudLab supports **concurrent multi-user deployments**. Each deployment is automatically isolated using the triggering user's GitHub username (`github.actor`).

**How it works:**

The workflow dynamically constructs a unique prefix for all Azure resources:

```yaml
TF_VAR_lab_name: ${{ github.event.inputs.lab_type }}-${{ github.actor }}
```

**Example — 3 students deploying simultaneously:**

| Student        | Lab Type | Resource Group Created                |
| :------------- | :------- | :------------------------------------ |
| `alice`        | java     | `rg-java-alice-south-india`           |
| `bob`          | docker   | `rg-docker-bob-south-india`           |
| `charlie`      | java     | `rg-java-charlie-south-india`         |

Each student gets their own isolated Virtual Network, Security Group, Public IP, and VM. No collisions, no shared state.

---

## Troubleshooting

### Common Errors and Solutions

| Error | Cause | Solution |
| :--- | :--- | :--- |
| `A resource with the ID ... already exists` | A previous failed run left an orphan Resource Group in Azure. | Delete the leftover group: `az group delete --name <RG_NAME> --yes --no-wait` |
| `SkuNotAvailable` | The selected VM size has no available hardware in the chosen Azure region. | Change the **Azure Region** input to `South India` or `West India`, or try a different VM size like `Standard_B2s`. |
| `RequestDisallowedByAzure` | Your Azure subscription policy restricts deployment to certain regions only. | Use an allowed region (typically Indian regions for student subscriptions). Check allowed regions: `az policy assignment list` |
| `PublicIPCountLimitReached` | Azure caps free/student subscriptions at 3 Public IPs per region. | Delete unused Resource Groups to free up IPs, or deploy to a different region. |
| `Permission denied (publickey)` | SSH is not using the correct private key file. | Use the `-i` flag: `ssh -i ./cloudlab_key azureuser@<IP>` |
| `Load key: invalid format` | The private key file has incorrect encoding (UTF-8 BOM or CRLF line endings). | Transfer the original key file directly instead of copy-pasting text. Or fix encoding: `[System.IO.File]::WriteAllLines(".\cloudlab_key", (Get-Content ".\cloudlab_key"))` |

---

## Future Scope

- **Remote State Backend:** Store Terraform state in Azure Blob Storage instead of ephemeral GitHub runners to prevent orphan resource conflicts.
- **Auto-Teardown Schedules:** Add a scheduled GitHub Actions cron job to automatically run `terraform destroy` after a set time, preventing cloud cost leaks.
- **Web-Based SSH Terminal:** Integrate an in-browser terminal (e.g., Apache Guacamole or Xterm.js) so students don't need a local SSH client.
- **Additional Lab Types:** Extend the platform to support Python, Node.js, Kubernetes, and other environments as additional Ansible roles.
- **Usage Dashboard:** Build a lightweight web dashboard to track active labs, costs, and uptime per student.

---

## License

This project was built as a university course project for DevOps Mastery.

---

> Built with ❤️ using GitHub Actions, Terraform, Ansible, and Microsoft Azure.
