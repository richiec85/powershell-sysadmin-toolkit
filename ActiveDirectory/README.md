# Active Directory Scripts

PowerShell scripts for managing on-premises Active Directory environments.

## 📁 Directory Structure

- **Users/** - User account creation, modification, and management
- **Groups/** - Group management and membership operations
- **Computers/** - Computer account management
- **OrganizationalUnits/** - OU structure and management
- **Security/** - Password policies, permissions, and security settings
- **Monitoring/** - AD health checks and monitoring scripts

## 🔧 Common Operations

### User Management
- Bulk user creation from CSV
- Password resets and expiration
- Account enabling/disabling
- User attribute updates

### Group Management
- Group creation and deletion
- Membership management
- Nested group operations
- Group-based access control

### Computer Management
- Computer account cleanup
- Stale computer detection
- Computer attribute updates

### OU Management
- OU structure creation
- GPO application
- Delegation of control

## Prerequisites

```powershell
# Import Active Directory module
Import-Module ActiveDirectory

# Requires RSAT tools on Windows 10/11
# Or run from Domain Controller
```

## Security Notes

- Always test in non-production first
- Use -WhatIf parameter for dry runs
- Ensure proper permissions before execution
- Enable transcript logging
