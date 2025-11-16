<#
.SYNOPSIS
    Manages Microsoft 365 license assignments in Entra ID (Azure AD)
.DESCRIPTION
    This script handles bulk license assignments, removals, and reporting for Entra ID users.
    Supports various Microsoft 365 license types and can process users from CSV.
.PARAMETER Action
    Action to perform: Assign, Remove, or Report
.PARAMETER CSVPath
    Path to CSV file with user information
.PARAMETER LicenseType
    Type of license to assign (E3, E5, F1, F3, etc.)
.EXAMPLE
    .\Manage-EntraIDLicenses.ps1 -Action Assign -CSVPath "users.csv" -LicenseType "E3"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Assign", "Remove", "Report")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$CSVPath,
    
    [Parameter(Mandatory=$false)]
    [string]$LicenseType,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "$PSScriptRoot\Reports\LicenseReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# License SKU mapping
$LicenseSKUs = @{
    "E3" = "ENTERPRISEPACK"
    "E5" = "ENTERPRISEPREMIUM"
    "F1" = "DESKLESSPACK"
    "F3" = "SPE_F1"
    "Business Basic" = "O365_BUSINESS_ESSENTIALS"
    "Business Standard" = "O365_BUSINESS_PREMIUM"
    "Business Premium" = "SPB"
    "Exchange" = "EXCHANGESTANDARD"
    "Teams" = "TEAMS_EXPLORATORY"
    "Visio" = "VISIO_PLAN2"
    "Project" = "PROJECTPROFESSIONAL"
    "PowerBI" = "POWER_BI_PRO"
}

# Connect to Microsoft Graph
function Connect-MicrosoftGraph {
    try {
        # Check if already connected
        $context = Get-MgContext
        if (-not $context) {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome
        }
        Write-Host "Connected to Microsoft Graph" -ForegroundColor Green
    }
    catch {
        throw "Failed to connect to Microsoft Graph: $_"
    }
}

# Get license SKU ID
function Get-LicenseSKU {
    param([string]$LicenseType)
    
    $tenant = (Get-MgContext).TenantId
    $skuPartNumber = $LicenseSKUs[$LicenseType]
    
    if (-not $skuPartNumber) {
        throw "Unknown license type: $LicenseType"
    }
    
    $sku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $skuPartNumber }
    
    if (-not $sku) {
        throw "License SKU not found in tenant: $skuPartNumber"
    }
    
    return $sku
}

# Assign licenses
function Assign-Licenses {
    param(
        [array]$Users,
        [string]$LicenseType
    )
    
    $sku = Get-LicenseSKU -LicenseType $LicenseType
    $results = @()
    
    Write-Host "`nAssigning $LicenseType licenses..." -ForegroundColor Cyan
    Write-Host "Available licenses: $($sku.PrepaidUnits.Enabled - $sku.ConsumedUnits)" -ForegroundColor Yellow
    
    foreach ($user in $Users) {
        try {
            $userPrincipalName = if ($user.PSObject.Properties['UserPrincipalName']) {
                $user.UserPrincipalName
            } else {
                $user
            }
            
            # Get user
            $mgUser = Get-MgUser -UserId $userPrincipalName -ErrorAction Stop
            
            # Check current licenses
            $currentLicenses = Get-MgUserLicenseDetail -UserId $mgUser.Id
            $hasLicense = $currentLicenses.SkuId -contains $sku.SkuId
            
            if ($hasLicense) {
                Write-Host "⚠ User $userPrincipalName already has $LicenseType license" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    User = $userPrincipalName
                    Action = "Skipped"
                    License = $LicenseType
                    Status = "Already Licensed"
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($userPrincipalName, "Assign $LicenseType license")) {
                    # Assign license
                    Set-MgUserLicense -UserId $mgUser.Id `
                        -AddLicenses @(@{SkuId = $sku.SkuId}) `
                        -RemoveLicenses @()
                    
                    Write-Host "✓ Assigned $LicenseType to $userPrincipalName" -ForegroundColor Green
                    
                    $results += [PSCustomObject]@{
                        User = $userPrincipalName
                        Action = "Assigned"
                        License = $LicenseType
                        Status = "Success"
                    }
                }
            }
        }
        catch {
            Write-Host "✗ Failed to assign license to $userPrincipalName : $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                User = $userPrincipalName
                Action = "Failed"
                License = $LicenseType
                Status = $_.Exception.Message
            }
        }
    }
    
    return $results
}

# Remove licenses
function Remove-Licenses {
    param(
        [array]$Users,
        [string]$LicenseType
    )
    
    $sku = Get-LicenseSKU -LicenseType $LicenseType
    $results = @()
    
    Write-Host "`nRemoving $LicenseType licenses..." -ForegroundColor Cyan
    
    foreach ($user in $Users) {
        try {
            $userPrincipalName = if ($user.PSObject.Properties['UserPrincipalName']) {
                $user.UserPrincipalName
            } else {
                $user
            }
            
            # Get user
            $mgUser = Get-MgUser -UserId $userPrincipalName -ErrorAction Stop
            
            # Check current licenses
            $currentLicenses = Get-MgUserLicenseDetail -UserId $mgUser.Id
            $hasLicense = $currentLicenses.SkuId -contains $sku.SkuId
            
            if (-not $hasLicense) {
                Write-Host "⚠ User $userPrincipalName doesn't have $LicenseType license" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    User = $userPrincipalName
                    Action = "Skipped"
                    License = $LicenseType
                    Status = "No License"
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($userPrincipalName, "Remove $LicenseType license")) {
                    # Remove license
                    Set-MgUserLicense -UserId $mgUser.Id `
                        -AddLicenses @() `
                        -RemoveLicenses @($sku.SkuId)
                    
                    Write-Host "✓ Removed $LicenseType from $userPrincipalName" -ForegroundColor Green
                    
                    $results += [PSCustomObject]@{
                        User = $userPrincipalName
                        Action = "Removed"
                        License = $LicenseType
                        Status = "Success"
                    }
                }
            }
        }
        catch {
            Write-Host "✗ Failed to remove license from $userPrincipalName : $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                User = $userPrincipalName
                Action = "Failed"
                License = $LicenseType
                Status = $_.Exception.Message
            }
        }
    }
    
    return $results
}

# Generate license report
function Get-LicenseReport {
    Write-Host "`nGenerating license report..." -ForegroundColor Cyan
    
    $report = @()
    $allUsers = Get-MgUser -All -Property UserPrincipalName,DisplayName,AccountEnabled,AssignedLicenses
    
    foreach ($user in $allUsers) {
        $licenses = Get-MgUserLicenseDetail -UserId $user.Id
        
        if ($licenses) {
            $licenseNames = $licenses | ForEach-Object {
                $skuName = (Get-MgSubscribedSku | Where-Object { $_.SkuId -eq $_.SkuId }).SkuPartNumber
                $skuName
            }
            
            $report += [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName = $user.DisplayName
                AccountEnabled = $user.AccountEnabled
                Licenses = ($licenseNames -join "; ")
                LicenseCount = $licenses.Count
            }
        }
        else {
            $report += [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName = $user.DisplayName
                AccountEnabled = $user.AccountEnabled
                Licenses = "None"
                LicenseCount = 0
            }
        }
    }
    
    return $report
}

# Main execution
try {
    Connect-MicrosoftGraph
    
    switch ($Action) {
        "Assign" {
            if (-not $CSVPath -or -not $LicenseType) {
                throw "CSVPath and LicenseType are required for Assign action"
            }
            
            $users = Import-Csv $CSVPath
            $results = Assign-Licenses -Users $users -LicenseType $LicenseType
            
            # Export results
            $results | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nResults exported to: $ReportPath" -ForegroundColor Green
        }
        
        "Remove" {
            if (-not $CSVPath -or -not $LicenseType) {
                throw "CSVPath and LicenseType are required for Remove action"
            }
            
            $users = Import-Csv $CSVPath
            $results = Remove-Licenses -Users $users -LicenseType $LicenseType
            
            # Export results
            $results | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nResults exported to: $ReportPath" -ForegroundColor Green
        }
        
        "Report" {
            $report = Get-LicenseReport
            
            # Display summary
            $licenseSummary = $report | Group-Object -Property Licenses | 
                Select-Object @{N='License';E={$_.Name}}, @{N='Count';E={$_.Count}} |
                Sort-Object Count -Descending
            
            Write-Host "`n========== LICENSE SUMMARY ==========" -ForegroundColor Yellow
            $licenseSummary | Format-Table -AutoSize
            
            # Export full report
            $report | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nFull report exported to: $ReportPath" -ForegroundColor Green
        }
    }
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    # Disconnect from Microsoft Graph
    if (Get-MgContext) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    }
}

<# CSV Template for Assign/Remove:
UserPrincipalName
jdoe@contoso.com
jsmith@contoso.com
#>
