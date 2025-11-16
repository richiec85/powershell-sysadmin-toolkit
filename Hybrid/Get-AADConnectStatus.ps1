<#
.SYNOPSIS
    Monitors and manages Azure AD Connect (Entra Connect) synchronization
.DESCRIPTION
    This script checks the health of Azure AD Connect sync, identifies sync errors,
    and provides troubleshooting information for hybrid identity scenarios.
.PARAMETER Action
    Action to perform: Status, Errors, Force, Report
.PARAMETER ServerName
    Azure AD Connect server name (optional for remote checks)
.EXAMPLE
    .\Get-AADConnectStatus.ps1 -Action Status
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Status", "Errors", "Force", "Report", "Validate")]
    [string]$Action = "Status",
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "$PSScriptRoot\Reports\AADConnectStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
)

# Import required modules
function Import-RequiredModules {
    $modules = @("ADSync", "ActiveDirectory", "AzureAD")
    
    foreach ($module in $modules) {
        try {
            Import-Module $module -ErrorAction Stop
            Write-Host "✓ Imported module: $module" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to import module $module : $_"
            if ($module -eq "ADSync") {
                Write-Host "Note: ADSync module must be run on the Azure AD Connect server" -ForegroundColor Yellow
            }
        }
    }
}

# Get sync status
function Get-SyncStatus {
    Write-Host "`nChecking Azure AD Connect Sync Status..." -ForegroundColor Cyan
    
    try {
        # Get sync scheduler status
        $scheduler = Get-ADSyncScheduler
        
        # Get connector status
        $connectors = Get-ADSyncConnector
        
        # Get last sync cycle
        $syncCycle = Get-ADSyncSchedulerConnectorOverride
        
        $status = [PSCustomObject]@{
            SyncEnabled = $scheduler.SyncCycleEnabled
            StagingMode = $scheduler.StagingModeEnabled
            NextSyncTime = $scheduler.NextSyncCycleStartTimeInUTC
            SyncInterval = "$($scheduler.CustomizedSyncCycleInterval.TotalMinutes) minutes"
            MaintenanceMode = $scheduler.MaintenanceModeEnabled
            Connectors = $connectors.Count
            AADConnector = ($connectors | Where-Object { $_.Type -eq "Azure Active Directory" }).Name
            ADConnector = ($connectors | Where-Object { $_.Type -like "*Active Directory*" -and $_.Type -ne "Azure Active Directory" }).Name
        }
        
        # Display status
        Write-Host "`n========== SYNC STATUS ==========" -ForegroundColor Yellow
        Write-Host "Sync Enabled: $(if($status.SyncEnabled){'✓ Yes'}else{'✗ No'})" -ForegroundColor $(if($status.SyncEnabled){'Green'}else{'Red'})
        Write-Host "Staging Mode: $(if($status.StagingMode){'Yes (Not syncing)'}else{'No'})" -ForegroundColor $(if($status.StagingMode){'Yellow'}else{'Green'})
        Write-Host "Next Sync: $($status.NextSyncTime)"
        Write-Host "Sync Interval: $($status.SyncInterval)"
        Write-Host "Maintenance Mode: $(if($status.MaintenanceMode){'Yes'}else{'No'})"
        Write-Host "Connectors: $($status.Connectors)"
        
        return $status
    }
    catch {
        Write-Error "Failed to get sync status: $_"
        return $null
    }
}

# Get sync errors
function Get-SyncErrors {
    Write-Host "`nChecking for Synchronization Errors..." -ForegroundColor Cyan
    
    try {
        # Get export errors
        $exportErrors = Get-ADSyncExportError
        
        # Get import errors
        $csObjects = Get-ADSyncCSObject -ErrorType ImportError
        
        $errors = @()
        
        # Process export errors
        foreach ($error in $exportErrors) {
            $errors += [PSCustomObject]@{
                Type = "Export Error"
                Connector = $error.ConnectorName
                Object = $error.DistinguishedName
                ErrorType = $error.ErrorType
                ErrorCode = $error.ErrorCode
                ErrorDescription = $error.ErrorDescription
                TimeOccurred = $error.TimeOccurred
            }
        }
        
        # Process import errors
        foreach ($obj in $csObjects) {
            $errors += [PSCustomObject]@{
                Type = "Import Error"
                Connector = $obj.ConnectorName
                Object = $obj.DistinguishedName
                ErrorType = $obj.ImportErrorType
                ErrorCode = $obj.ImportErrorCode
                ErrorDescription = $obj.ImportErrorDescription
                TimeOccurred = $obj.LastImportTime
            }
        }
        
        if ($errors.Count -eq 0) {
            Write-Host "✓ No synchronization errors found" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Found $($errors.Count) synchronization errors" -ForegroundColor Red
            
            # Group errors by type
            $errorSummary = $errors | Group-Object -Property ErrorType | 
                Select-Object @{N='Error Type';E={$_.Name}}, @{N='Count';E={$_.Count}}
            
            Write-Host "`n========== ERROR SUMMARY ==========" -ForegroundColor Yellow
            $errorSummary | Format-Table -AutoSize
            
            # Show top 10 errors
            Write-Host "`n========== RECENT ERRORS ==========" -ForegroundColor Yellow
            $errors | Select-Object -First 10 | Format-Table -Property Type, Object, ErrorType, TimeOccurred -AutoSize
        }
        
        return $errors
    }
    catch {
        Write-Error "Failed to get sync errors: $_"
        return @()
    }
}

# Force sync
function Start-ForcedSync {
    param([string]$SyncType = "Delta")
    
    Write-Host "`nInitiating $SyncType Sync..." -ForegroundColor Cyan
    
    try {
        # Check if sync is already running
        $scheduler = Get-ADSyncScheduler
        if ($scheduler.SyncCycleInProgress) {
            Write-Warning "A sync cycle is already in progress. Please wait for it to complete."
            return
        }
        
        # Start sync based on type
        if ($SyncType -eq "Delta") {
            Start-ADSyncSyncCycle -PolicyType Delta
            Write-Host "✓ Delta sync initiated" -ForegroundColor Green
        }
        else {
            Write-Warning "Full sync will resync all objects. This may take a long time."
            $confirm = Read-Host "Are you sure you want to start a full sync? (Y/N)"
            if ($confirm -eq "Y") {
                Start-ADSyncSyncCycle -PolicyType Initial
                Write-Host "✓ Full sync initiated" -ForegroundColor Green
            }
        }
        
        # Monitor sync progress
        Write-Host "`nMonitoring sync progress..." -ForegroundColor Yellow
        $syncInProgress = $true
        $checkCount = 0
        
        while ($syncInProgress -and $checkCount -lt 60) {
            Start-Sleep -Seconds 10
            $scheduler = Get-ADSyncScheduler
            $syncInProgress = $scheduler.SyncCycleInProgress
            
            if ($syncInProgress) {
                Write-Host "." -NoNewline
                $checkCount++
            }
        }
        
        if (-not $syncInProgress) {
            Write-Host "`n✓ Sync completed" -ForegroundColor Green
            
            # Check for errors
            $errors = Get-SyncErrors
            if ($errors.Count -gt 0) {
                Write-Warning "Sync completed with $($errors.Count) errors"
            }
        }
        else {
            Write-Host "`nSync is still running after 10 minutes. Check status later." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Failed to start sync: $_"
    }
}

# Validate hybrid configuration
function Test-HybridConfiguration {
    Write-Host "`nValidating Hybrid Configuration..." -ForegroundColor Cyan
    
    $validationResults = @()
    
    # Test 1: Check AD connectivity
    Write-Host "  Testing Active Directory connectivity..." -ForegroundColor Gray
    try {
        $adDomain = Get-ADDomain
        $validationResults += [PSCustomObject]@{
            Test = "AD Connectivity"
            Result = "Pass"
            Details = "Connected to $($adDomain.DNSRoot)"
        }
    }
    catch {
        $validationResults += [PSCustomObject]@{
            Test = "AD Connectivity"
            Result = "Fail"
            Details = $_.Exception.Message
        }
    }
    
    # Test 2: Check Azure AD connectivity
    Write-Host "  Testing Azure AD connectivity..." -ForegroundColor Gray
    try {
        Connect-AzureAD -ErrorAction Stop | Out-Null
        $aadTenant = Get-AzureADTenantDetail
        $validationResults += [PSCustomObject]@{
            Test = "Azure AD Connectivity"
            Result = "Pass"
            Details = "Connected to $($aadTenant.DisplayName)"
        }
    }
    catch {
        $validationResults += [PSCustomObject]@{
            Test = "Azure AD Connectivity"
            Result = "Fail"
            Details = $_.Exception.Message
        }
    }
    
    # Test 3: Check service account
    Write-Host "  Checking AD Connect service account..." -ForegroundColor Gray
    try {
        $connector = Get-ADSyncConnector | Where-Object { $_.Type -like "*Active Directory*" -and $_.Type -ne "Azure Active Directory" }
        $serviceAccount = $connector.ConnectivityParameters | Where-Object { $_.Name -eq "forest-login-user" }
        
        if ($serviceAccount) {
            $validationResults += [PSCustomObject]@{
                Test = "Service Account"
                Result = "Pass"
                Details = "Account: $($serviceAccount.Value)"
            }
        }
    }
    catch {
        $validationResults += [PSCustomObject]@{
            Test = "Service Account"
            Result = "Warning"
            Details = "Could not verify service account"
        }
    }
    
    # Test 4: Check password hash sync
    Write-Host "  Checking password hash synchronization..." -ForegroundColor Gray
    try {
        $passwordSync = Get-ADSyncAADPasswordSyncConfiguration
        $validationResults += [PSCustomObject]@{
            Test = "Password Hash Sync"
            Result = if($passwordSync.PasswordSyncEnabled){"Pass"}else{"Info"}
            Details = if($passwordSync.PasswordSyncEnabled){"Enabled"}else{"Disabled"}
        }
    }
    catch {
        $validationResults += [PSCustomObject]@{
            Test = "Password Hash Sync"
            Result = "Warning"
            Details = "Could not determine status"
        }
    }
    
    # Test 5: Check UPN suffix matching
    Write-Host "  Checking UPN suffix configuration..." -ForegroundColor Gray
    try {
        $adForest = Get-ADForest
        $aadDomains = Get-AzureADDomain
        
        $adUPNs = $adForest.UPNSuffixes + $adForest.RootDomain
        $aadVerified = $aadDomains | Where-Object { $_.IsVerified } | Select-Object -ExpandProperty Name
        
        $matchingUPNs = $adUPNs | Where-Object { $_ -in $aadVerified }
        
        if ($matchingUPNs.Count -gt 0) {
            $validationResults += [PSCustomObject]@{
                Test = "UPN Suffix Matching"
                Result = "Pass"
                Details = "Matching suffixes: $($matchingUPNs -join ', ')"
            }
        }
        else {
            $validationResults += [PSCustomObject]@{
                Test = "UPN Suffix Matching"
                Result = "Warning"
                Details = "No matching UPN suffixes found"
            }
        }
    }
    catch {
        $validationResults += [PSCustomObject]@{
            Test = "UPN Suffix Matching"
            Result = "Warning"
            Details = "Could not verify UPN suffixes"
        }
    }
    
    # Display results
    Write-Host "`n========== VALIDATION RESULTS ==========" -ForegroundColor Yellow
    foreach ($result in $validationResults) {
        $color = switch ($result.Result) {
            "Pass" { "Green" }
            "Warning" { "Yellow" }
            "Fail" { "Red" }
            default { "Gray" }
        }
        
        Write-Host "$($result.Test): $($result.Result)" -ForegroundColor $color
        Write-Host "  $($result.Details)" -ForegroundColor Gray
    }
    
    return $validationResults
}

# Generate comprehensive report
function New-SyncReport {
    param(
        [object]$Status,
        [array]$Errors,
        [array]$Validation
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure AD Connect Sync Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f0f2f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #323130; margin-top: 30px; background-color: #e1e1e1; padding: 10px; }
        .card { background: white; border-radius: 8px; padding: 20px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th { background-color: #0078d4; color: white; padding: 12px; text-align: left; }
        td { border: 1px solid #e1e1e1; padding: 10px; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        .status-active { color: #107c10; font-weight: bold; }
        .status-inactive { color: #a80000; font-weight: bold; }
        .status-warning { color: #ff8c00; font-weight: bold; }
        .metric { display: inline-block; margin: 10px 20px; }
        .metric-value { font-size: 2em; font-weight: bold; color: #0078d4; }
        .metric-label { color: #605e5c; margin-top: 5px; }
        .error { background-color: #fde7e9; border-left: 4px solid #a80000; padding: 10px; margin: 10px 0; }
        .success { background-color: #dff6dd; border-left: 4px solid #107c10; padding: 10px; margin: 10px 0; }
        .warning { background-color: #fff4ce; border-left: 4px solid #ff8c00; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Azure AD Connect Synchronization Report</h1>
        <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p>Server: $ServerName</p>
"@
    
    # Add status section
    if ($Status) {
        $syncStatus = if($Status.SyncEnabled -and -not $Status.StagingMode){"Active"}else{"Inactive"}
        $statusClass = if($syncStatus -eq "Active"){"status-active"}else{"status-inactive"}
        
        $html += @"
        <div class="card">
            <h2>Synchronization Status</h2>
            <div class="metric">
                <div class="metric-value"><span class="$statusClass">$syncStatus</span></div>
                <div class="metric-label">Sync Status</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($Status.SyncInterval)</div>
                <div class="metric-label">Sync Interval</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($Status.Connectors)</div>
                <div class="metric-label">Connectors</div>
            </div>
            <table>
                <tr><th>Configuration</th><th>Value</th></tr>
                <tr><td>Sync Enabled</td><td>$($Status.SyncEnabled)</td></tr>
                <tr><td>Staging Mode</td><td>$($Status.StagingMode)</td></tr>
                <tr><td>Next Sync Time</td><td>$($Status.NextSyncTime)</td></tr>
                <tr><td>Maintenance Mode</td><td>$($Status.MaintenanceMode)</td></tr>
                <tr><td>Azure AD Connector</td><td>$($Status.AADConnector)</td></tr>
                <tr><td>AD Connector</td><td>$($Status.ADConnector)</td></tr>
            </table>
        </div>
"@
    }
    
    # Add validation section
    if ($Validation) {
        $html += @"
        <div class="card">
            <h2>Configuration Validation</h2>
"@
        foreach ($test in $Validation) {
            $class = switch ($test.Result) {
                "Pass" { "success" }
                "Warning" { "warning" }
                "Fail" { "error" }
                default { "warning" }
            }
            
            $html += @"
            <div class="$class">
                <strong>$($test.Test):</strong> $($test.Result)<br/>
                $($test.Details)
            </div>
"@
        }
        $html += "</div>"
    }
    
    # Add errors section
    if ($Errors -and $Errors.Count -gt 0) {
        $html += @"
        <div class="card">
            <h2>Synchronization Errors ($($Errors.Count))</h2>
            <table>
                <tr><th>Type</th><th>Object</th><th>Error</th><th>Time</th></tr>
"@
        foreach ($error in $Errors | Select-Object -First 50) {
            $html += @"
                <tr>
                    <td>$($error.Type)</td>
                    <td>$($error.Object)</td>
                    <td>$($error.ErrorType)</td>
                    <td>$($error.TimeOccurred)</td>
                </tr>
"@
        }
        
        if ($Errors.Count -gt 50) {
            $html += "<tr><td colspan='4'>... and $($Errors.Count - 50) more errors</td></tr>"
        }
        
        $html += @"
            </table>
        </div>
"@
    }
    else {
        $html += @"
        <div class="card">
            <div class="success">
                <strong>No synchronization errors found</strong>
            </div>
        </div>
"@
    }
    
    $html += @"
    </div>
</body>
</html>
"@
    
    return $html
}

# Main execution
Write-Host "`n========== Azure AD Connect Monitor ==========" -ForegroundColor Cyan

try {
    # Import modules
    Import-RequiredModules
    
    $status = $null
    $errors = @()
    $validation = @()
    
    switch ($Action) {
        "Status" {
            $status = Get-SyncStatus
        }
        
        "Errors" {
            $errors = Get-SyncErrors
        }
        
        "Force" {
            Write-Host "`nSelect sync type:" -ForegroundColor Yellow
            Write-Host "1. Delta Sync (recommended)"
            Write-Host "2. Full Sync"
            $choice = Read-Host "Enter choice (1 or 2)"
            
            if ($choice -eq "2") {
                Start-ForcedSync -SyncType "Full"
            }
            else {
                Start-ForcedSync -SyncType "Delta"
            }
        }
        
        "Validate" {
            $validation = Test-HybridConfiguration
        }
        
        "Report" {
            $status = Get-SyncStatus
            $errors = Get-SyncErrors
            $validation = Test-HybridConfiguration
            
            # Generate HTML report
            $html = New-SyncReport -Status $status -Errors $errors -Validation $validation
            
            # Ensure directory exists
            $reportDir = Split-Path $ReportPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
            }
            
            # Save report
            $html | Out-File -FilePath $ReportPath -Encoding UTF8
            Write-Host "`n✓ Report saved to: $ReportPath" -ForegroundColor Green
            
            # Open report
            Start-Process $ReportPath
        }
    }
}
catch {
    Write-Error "Script failed: $_"
    Write-Host "`nNote: This script must be run on the Azure AD Connect server with appropriate permissions" -ForegroundColor Yellow
}

Write-Host "`n========== Script Complete ==========" -ForegroundColor Green
