# Windows Management Scripts

PowerShell scripts for Windows OS and server management.

## 📁 Directory Structure

- **Services/** - Windows service monitoring and management
- **EventLogs/** - Event log analysis and alerting
- **Updates/** - Patch management and Windows Update
- **Performance/** - Performance monitoring and diagnostics
- **Registry/** - Registry management and configuration
- **ScheduledTasks/** - Scheduled task creation and management

## 🔧 Common Operations

### Service Management
- Service monitoring and alerting
- Automatic service restart
- Service configuration
- Service dependency management

### Event Log Analysis
- Error log collection
- Security event monitoring
- Application log analysis
- Log forwarding and alerting

### Update Management
- Windows Update status checking
- Patch installation automation
- Update reporting
- WSUS integration

### Performance Monitoring
- CPU, memory, disk monitoring
- Performance counter collection
- Baseline creation
- Alert threshold configuration

## Prerequisites

```powershell
# Most scripts require local admin rights
# Run PowerShell as Administrator

# For remote management
Enable-PSRemoting -Force

# WinRM configuration for remote access
```

## Remote Management

```powershell
# Single computer
Invoke-Command -ComputerName SERVER01 -ScriptBlock { Get-Service }

# Multiple computers
Invoke-Command -ComputerName SERVER01, SERVER02 -FilePath .\script.ps1
```

## Security Considerations

- Use least privilege access
- Enable PowerShell logging
- Audit script execution
- Secure credential storage
