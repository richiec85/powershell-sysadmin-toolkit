<#
.SYNOPSIS
    Comprehensive Windows System Health Check and Monitoring
.DESCRIPTION
    This script performs various health checks on Windows systems including disk space,
    services, event logs, updates, performance metrics, and security settings.
.PARAMETER ComputerName
    Target computer(s) to check. Defaults to local computer.
.PARAMETER HealthCheckType
    Type of health check: Quick, Standard, or Comprehensive
.PARAMETER ExportReport
    Export detailed HTML report
.EXAMPLE
    .\Get-WindowsHealth.ps1 -ComputerName "Server01","Server02" -HealthCheckType Comprehensive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Quick", "Standard", "Comprehensive")]
    [string]$HealthCheckType = "Standard",
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportReport,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "$PSScriptRoot\Reports\SystemHealth_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
)

# Health check configuration
$Config = @{
    DiskSpaceWarningPercent = 20
    DiskSpaceCriticalPercent = 10
    CPUWarningPercent = 80
    CPUCriticalPercent = 90
    MemoryWarningPercent = 80
    MemoryCriticalPercent = 90
    EventLogDays = 7
    UptimeDaysWarning = 30
    CriticalServices = @(
        "W32Time",
        "DNS",
        "DFS",
        "DFSR",
        "Netlogon",
        "Spooler",
        "Server",
        "LanmanWorkstation",
        "EventLog",
        "Schedule"
    )
}

# Initialize results
$Results = @()

# Function to test connectivity
function Test-ComputerConnectivity {
    param([string]$Computer)
    
    $result = Test-Connection -ComputerName $Computer -Count 1 -Quiet
    if (-not $result) {
        Write-Warning "Cannot connect to $Computer"
    }
    return $result
}

# Check disk space
function Get-DiskSpaceHealth {
    param([string]$Computer)
    
    Write-Host "  Checking disk space on $Computer..." -ForegroundColor Gray
    $diskInfo = @()
    
    try {
        $disks = Get-WmiObject -ComputerName $Computer -Class Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        
        foreach ($disk in $disks) {
            $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            
            $status = if ($freePercent -lt $Config.DiskSpaceCriticalPercent) {
                "Critical"
            } elseif ($freePercent -lt $Config.DiskSpaceWarningPercent) {
                "Warning"
            } else {
                "Healthy"
            }
            
            $diskInfo += [PSCustomObject]@{
                Drive = $disk.DeviceID
                SizeGB = $sizeGB
                FreeGB = $freeGB
                FreePercent = $freePercent
                Status = $status
            }
        }
    }
    catch {
        Write-Warning "Failed to get disk info for $Computer : $_"
    }
    
    return $diskInfo
}

# Check critical services
function Get-ServiceHealth {
    param([string]$Computer)
    
    Write-Host "  Checking services on $Computer..." -ForegroundColor Gray
    $serviceInfo = @()
    
    try {
        foreach ($serviceName in $Config.CriticalServices) {
            $service = Get-Service -ComputerName $Computer -Name $serviceName -ErrorAction SilentlyContinue
            
            if ($service) {
                $status = if ($service.Status -eq "Running") {
                    "Healthy"
                } elseif ($service.Status -eq "Stopped") {
                    "Critical"
                } else {
                    "Warning"
                }
                
                $serviceInfo += [PSCustomObject]@{
                    ServiceName = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $service.Status
                    StartType = $service.StartType
                    HealthStatus = $status
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to get service info for $Computer : $_"
    }
    
    return $serviceInfo
}

# Check event logs
function Get-EventLogHealth {
    param([string]$Computer)
    
    Write-Host "  Checking event logs on $Computer..." -ForegroundColor Gray
    $eventInfo = @()
    
    try {
        $startDate = (Get-Date).AddDays(-$Config.EventLogDays)
        
        # System log errors
        $systemErrors = Get-EventLog -ComputerName $Computer -LogName System -EntryType Error -After $startDate -ErrorAction SilentlyContinue
        
        # Application log errors  
        $appErrors = Get-EventLog -ComputerName $Computer -LogName Application -EntryType Error -After $startDate -ErrorAction SilentlyContinue
        
        $eventInfo = [PSCustomObject]@{
            SystemErrors = $systemErrors.Count
            ApplicationErrors = $appErrors.Count
            TopSystemErrors = ($systemErrors | Group-Object -Property Source | Sort-Object Count -Descending | Select-Object -First 5)
            TopAppErrors = ($appErrors | Group-Object -Property Source | Sort-Object Count -Descending | Select-Object -First 5)
            Status = if (($systemErrors.Count + $appErrors.Count) -gt 100) { "Warning" } else { "Healthy" }
        }
    }
    catch {
        Write-Warning "Failed to get event log info for $Computer : $_"
    }
    
    return $eventInfo
}

# Check system uptime
function Get-UptimeHealth {
    param([string]$Computer)
    
    Write-Host "  Checking uptime on $Computer..." -ForegroundColor Gray
    
    try {
        $os = Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem -ErrorAction Stop
        $uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        
        $status = if ($uptime.TotalDays -gt $Config.UptimeDaysWarning) {
            "Warning"
        } else {
            "Healthy"
        }
        
        return [PSCustomObject]@{
            LastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
            Uptime = "$($uptime.Days) days, $($uptime.Hours) hours"
            UptimeDays = [math]::Round($uptime.TotalDays, 2)
            Status = $status
        }
    }
    catch {
        Write-Warning "Failed to get uptime for $Computer : $_"
        return $null
    }
}

# Check Windows Updates
function Get-UpdateHealth {
    param([string]$Computer)
    
    Write-Host "  Checking Windows Updates on $Computer..." -ForegroundColor Gray
    
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        
        # Search for pending updates
        $searchResult = $searcher.Search("IsInstalled=0")
        
        $critical = ($searchResult.Updates | Where-Object { $_.MsrcSeverity -eq "Critical" }).Count
        $important = ($searchResult.Updates | Where-Object { $_.MsrcSeverity -eq "Important" }).Count
        $optional = $searchResult.Updates.Count - $critical - $important
        
        $status = if ($critical -gt 0) {
            "Critical"
        } elseif ($important -gt 0) {
            "Warning"
        } else {
            "Healthy"
        }
        
        return [PSCustomObject]@{
            CriticalUpdates = $critical
            ImportantUpdates = $important
            OptionalUpdates = $optional
            TotalPending = $searchResult.Updates.Count
            Status = $status
        }
    }
    catch {
        Write-Warning "Failed to get update info for $Computer : $_"
        return $null
    }
}

# Check performance metrics
function Get-PerformanceHealth {
    param([string]$Computer)
    
    Write-Host "  Checking performance metrics on $Computer..." -ForegroundColor Gray
    
    try {
        # CPU Usage
        $cpu = Get-WmiObject -ComputerName $Computer -Class Win32_Processor -ErrorAction Stop
        $cpuUsage = ($cpu | Measure-Object -Property LoadPercentage -Average).Average
        
        # Memory Usage
        $os = Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem -ErrorAction Stop
        $memoryUsed = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)
        
        # Page File Usage
        $pageFile = Get-WmiObject -ComputerName $Computer -Class Win32_PageFileUsage -ErrorAction Stop
        $pageFileUsage = if ($pageFile) {
            [math]::Round(($pageFile.CurrentUsage / $pageFile.AllocatedBaseSize) * 100, 2)
        } else { 0 }
        
        $cpuStatus = if ($cpuUsage -gt $Config.CPUCriticalPercent) {
            "Critical"
        } elseif ($cpuUsage -gt $Config.CPUWarningPercent) {
            "Warning"
        } else {
            "Healthy"
        }
        
        $memStatus = if ($memoryUsed -gt $Config.MemoryCriticalPercent) {
            "Critical"
        } elseif ($memoryUsed -gt $Config.MemoryWarningPercent) {
            "Warning"
        } else {
            "Healthy"
        }
        
        return [PSCustomObject]@{
            CPUUsage = $cpuUsage
            CPUStatus = $cpuStatus
            MemoryUsage = $memoryUsed
            MemoryStatus = $memStatus
            PageFileUsage = $pageFileUsage
            TotalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            FreeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        }
    }
    catch {
        Write-Warning "Failed to get performance info for $Computer : $_"
        return $null
    }
}

# Check network configuration
function Get-NetworkHealth {
    param([string]$Computer)
    
    Write-Host "  Checking network configuration on $Computer..." -ForegroundColor Gray
    
    try {
        $adapters = Get-WmiObject -ComputerName $Computer -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction Stop
        
        $networkInfo = @()
        foreach ($adapter in $adapters) {
            $networkInfo += [PSCustomObject]@{
                Description = $adapter.Description
                IPAddress = $adapter.IPAddress -join ", "
                SubnetMask = $adapter.IPSubnet -join ", "
                DefaultGateway = $adapter.DefaultIPGateway -join ", "
                DNSServers = $adapter.DNSServerSearchOrder -join ", "
                DHCPEnabled = $adapter.DHCPEnabled
                MACAddress = $adapter.MACAddress
            }
        }
        
        return $networkInfo
    }
    catch {
        Write-Warning "Failed to get network info for $Computer : $_"
        return @()
    }
}

# Generate HTML report
function New-HTMLReport {
    param($Results)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows System Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        h3 { color: #666; margin-top: 20px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background-color: #007bff; color: white; padding: 12px; text-align: left; }
        td { border: 1px solid #ddd; padding: 10px; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .healthy { color: green; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .critical { color: red; font-weight: bold; }
        .summary { background-color: #e9ecef; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px; }
        .metric-label { font-weight: bold; color: #666; }
        .metric-value { font-size: 1.2em; margin-left: 5px; }
    </style>
</head>
<body>
    <h1>Windows System Health Report</h1>
    <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
"@
    
    foreach ($result in $Results) {
        $overallStatus = "Healthy"
        if ($result.DiskSpace | Where-Object { $_.Status -eq "Critical" }) { $overallStatus = "Critical" }
        elseif ($result.DiskSpace | Where-Object { $_.Status -eq "Warning" }) { $overallStatus = "Warning" }
        elseif ($result.Services | Where-Object { $_.HealthStatus -eq "Critical" }) { $overallStatus = "Critical" }
        
        $statusClass = $overallStatus.ToLower()
        
        $html += @"
    <h2>$($result.ComputerName) - <span class="$statusClass">$overallStatus</span></h2>
    
    <div class="summary">
        <div class="metric">
            <span class="metric-label">Uptime:</span>
            <span class="metric-value">$($result.Uptime.Uptime)</span>
        </div>
        <div class="metric">
            <span class="metric-label">CPU Usage:</span>
            <span class="metric-value">$($result.Performance.CPUUsage)%</span>
        </div>
        <div class="metric">
            <span class="metric-label">Memory Usage:</span>
            <span class="metric-value">$($result.Performance.MemoryUsage)%</span>
        </div>
    </div>
    
    <h3>Disk Space</h3>
    <table>
        <tr><th>Drive</th><th>Size (GB)</th><th>Free (GB)</th><th>Free %</th><th>Status</th></tr>
"@
        foreach ($disk in $result.DiskSpace) {
            $statusClass = $disk.Status.ToLower()
            $html += "<tr><td>$($disk.Drive)</td><td>$($disk.SizeGB)</td><td>$($disk.FreeGB)</td><td>$($disk.FreePercent)</td><td class='$statusClass'>$($disk.Status)</td></tr>"
        }
        
        $html += @"
    </table>
    
    <h3>Services</h3>
    <table>
        <tr><th>Service</th><th>Display Name</th><th>Status</th><th>Start Type</th><th>Health</th></tr>
"@
        foreach ($service in $result.Services) {
            $statusClass = $service.HealthStatus.ToLower()
            $html += "<tr><td>$($service.ServiceName)</td><td>$($service.DisplayName)</td><td>$($service.Status)</td><td>$($service.StartType)</td><td class='$statusClass'>$($service.HealthStatus)</td></tr>"
        }
        
        $html += "</table>"
    }
    
    $html += @"
</body>
</html>
"@
    
    return $html
}

# Main execution
Write-Host "`n========== Windows System Health Check ==========" -ForegroundColor Cyan
Write-Host "Check Type: $HealthCheckType" -ForegroundColor Yellow

foreach ($computer in $ComputerName) {
    Write-Host "`nChecking: $computer" -ForegroundColor Green
    
    if (-not (Test-ComputerConnectivity -Computer $computer)) {
        continue
    }
    
    $computerResult = [PSCustomObject]@{
        ComputerName = $computer
        CheckTime = Get-Date
        CheckType = $HealthCheckType
    }
    
    # Perform checks based on type
    switch ($HealthCheckType) {
        "Quick" {
            $computerResult | Add-Member -MemberType NoteProperty -Name DiskSpace -Value (Get-DiskSpaceHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Services -Value (Get-ServiceHealth -Computer $computer)
        }
        "Standard" {
            $computerResult | Add-Member -MemberType NoteProperty -Name DiskSpace -Value (Get-DiskSpaceHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Services -Value (Get-ServiceHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name EventLogs -Value (Get-EventLogHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Uptime -Value (Get-UptimeHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Performance -Value (Get-PerformanceHealth -Computer $computer)
        }
        "Comprehensive" {
            $computerResult | Add-Member -MemberType NoteProperty -Name DiskSpace -Value (Get-DiskSpaceHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Services -Value (Get-ServiceHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name EventLogs -Value (Get-EventLogHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Uptime -Value (Get-UptimeHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Updates -Value (Get-UpdateHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Performance -Value (Get-PerformanceHealth -Computer $computer)
            $computerResult | Add-Member -MemberType NoteProperty -Name Network -Value (Get-NetworkHealth -Computer $computer)
        }
    }
    
    $Results += $computerResult
    
    # Display summary
    Write-Host "`n  Summary for $computer :" -ForegroundColor Cyan
    
    if ($computerResult.DiskSpace) {
        $criticalDisks = $computerResult.DiskSpace | Where-Object { $_.Status -eq "Critical" }
        if ($criticalDisks) {
            Write-Host "  ⚠ CRITICAL: Low disk space on drives: $($criticalDisks.Drive -join ', ')" -ForegroundColor Red
        }
    }
    
    if ($computerResult.Services) {
        $stoppedServices = $computerResult.Services | Where-Object { $_.Status -ne "Running" }
        if ($stoppedServices) {
            Write-Host "  ⚠ Services not running: $($stoppedServices.ServiceName -join ', ')" -ForegroundColor Yellow
        }
    }
    
    if ($computerResult.Performance) {
        if ($computerResult.Performance.CPUUsage -gt $Config.CPUWarningPercent) {
            Write-Host "  ⚠ High CPU usage: $($computerResult.Performance.CPUUsage)%" -ForegroundColor Yellow
        }
        if ($computerResult.Performance.MemoryUsage -gt $Config.MemoryWarningPercent) {
            Write-Host "  ⚠ High memory usage: $($computerResult.Performance.MemoryUsage)%" -ForegroundColor Yellow
        }
    }
}

# Export report if requested
if ($ExportReport) {
    $html = New-HTMLReport -Results $Results
    
    # Ensure directory exists
    $reportDir = Split-Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $html | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "`n✓ HTML report exported to: $ReportPath" -ForegroundColor Green
    
    # Open report in browser
    Start-Process $ReportPath
}

Write-Host "`n========== Health Check Complete ==========" -ForegroundColor Green
