# Azure Resource Management Scripts

PowerShell scripts for managing Microsoft Azure resources.

## 📁 Directory Structure

- **ResourceGroups/** - Resource group creation and management
- **VirtualMachines/** - VM deployment and operations
- **Storage/** - Storage account and blob management
- **Networking/** - VNet, NSG, and network configuration
- **CostManagement/** - Cost analysis and budget management
- **Monitoring/** - Azure Monitor, alerts, and diagnostics

## 🔧 Common Operations

### Virtual Machines
- VM deployment and configuration
- Start/stop automation
- Snapshot management
- VM sizing and scaling

### Storage
- Storage account creation
- Blob container management
- File share operations
- Access key rotation

### Networking
- Virtual network creation
- NSG rule management
- Load balancer configuration
- VPN and ExpressRoute management

### Cost Management
- Cost analysis and reporting
- Budget creation and alerts
- Resource tagging for cost allocation
- Unused resource identification

## Prerequisites

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -AllowClobber

# Connect to Azure
Connect-AzAccount

# Select subscription
Set-AzContext -Subscription "subscription-name"
```

## Best Practices

- Use resource tags for organization and cost tracking
- Implement naming conventions
- Use managed identities when possible
- Enable diagnostic logging
- Regular cost reviews
