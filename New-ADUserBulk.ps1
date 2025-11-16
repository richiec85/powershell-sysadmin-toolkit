<#
.SYNOPSIS
    Creates multiple Active Directory users from a CSV file
.DESCRIPTION
    This script reads user information from a CSV file and creates AD users in bulk.
    Supports setting various user attributes and initial passwords.
.PARAMETER CSVPath
    Path to the CSV file containing user information
.PARAMETER OUPath
    Target OU where users will be created
.PARAMETER DefaultPassword
    Default password for new users (they will be required to change on first login)
.EXAMPLE
    .\New-ADUserBulk.ps1 -CSVPath "C:\users.csv" -OUPath "OU=Users,DC=contoso,DC=com"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$CSVPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OUPath,
    
    [Parameter(Mandatory=$false)]
    [string]$DefaultPassword = "P@ssw0rd123!",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$PSScriptRoot\Logs\NewUsers_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# Import required module
Import-Module ActiveDirectory -ErrorAction Stop

# Start transcript
Start-Transcript -Path $LogPath

try {
    # Verify CSV exists
    if (-not (Test-Path $CSVPath)) {
        throw "CSV file not found: $CSVPath"
    }
    
    # Verify OU exists
    try {
        Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop | Out-Null
    }
    catch {
        throw "OU not found or accessible: $OUPath"
    }
    
    # Import CSV
    $users = Import-Csv $CSVPath
    Write-Host "Found $($users.Count) users to create" -ForegroundColor Cyan
    
    # Counter variables
    $successCount = 0
    $errorCount = 0
    $errors = @()
    
    foreach ($user in $users) {
        try {
            # Build user parameters
            $userParams = @{
                Name = "$($user.FirstName) $($user.LastName)"
                GivenName = $user.FirstName
                Surname = $user.LastName
                SamAccountName = $user.SamAccountName
                UserPrincipalName = "$($user.SamAccountName)@$((Get-ADDomain).DNSRoot)"
                EmailAddress = $user.EmailAddress
                DisplayName = "$($user.FirstName) $($user.LastName)"
                Path = $OUPath
                AccountPassword = (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force)
                ChangePasswordAtLogon = $true
                Enabled = $true
            }
            
            # Add optional parameters if present in CSV
            if ($user.Title) { $userParams.Title = $user.Title }
            if ($user.Department) { $userParams.Department = $user.Department }
            if ($user.Company) { $userParams.Company = $user.Company }
            if ($user.Office) { $userParams.Office = $user.Office }
            if ($user.StreetAddress) { $userParams.StreetAddress = $user.StreetAddress }
            if ($user.City) { $userParams.City = $user.City }
            if ($user.State) { $userParams.State = $user.State }
            if ($user.PostalCode) { $userParams.PostalCode = $user.PostalCode }
            if ($user.Country) { $userParams.Country = $user.Country }
            if ($user.OfficePhone) { $userParams.OfficePhone = $user.OfficePhone }
            if ($user.MobilePhone) { $userParams.MobilePhone = $user.MobilePhone }
            if ($user.Manager) { 
                # Verify manager exists
                try {
                    $managerDN = (Get-ADUser $user.Manager).DistinguishedName
                    $userParams.Manager = $managerDN
                }
                catch {
                    Write-Warning "Manager '$($user.Manager)' not found for user $($user.SamAccountName)"
                }
            }
            
            # Create the user
            if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Create AD User")) {
                New-ADUser @userParams
                Write-Host "✓ Created user: $($user.SamAccountName)" -ForegroundColor Green
                
                # Add to groups if specified
                if ($user.Groups) {
                    $groups = $user.Groups -split ';'
                    foreach ($group in $groups) {
                        try {
                            Add-ADGroupMember -Identity $group.Trim() -Members $user.SamAccountName
                            Write-Host "  Added to group: $group" -ForegroundColor Gray
                        }
                        catch {
                            Write-Warning "  Failed to add to group '$group': $_"
                        }
                    }
                }
                
                $successCount++
            }
        }
        catch {
            Write-Host "✗ Failed to create user: $($user.SamAccountName) - $_" -ForegroundColor Red
            $errors += [PSCustomObject]@{
                User = $user.SamAccountName
                Error = $_.Exception.Message
            }
            $errorCount++
        }
    }
    
    # Summary
    Write-Host "`n========== SUMMARY ==========" -ForegroundColor Yellow
    Write-Host "Successfully created: $successCount users" -ForegroundColor Green
    Write-Host "Failed: $errorCount users" -ForegroundColor Red
    
    if ($errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        $errors | Format-Table -AutoSize
        
        # Export errors to CSV
        $errorFile = Join-Path (Split-Path $LogPath -Parent) "Errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $errors | Export-Csv -Path $errorFile -NoTypeInformation
        Write-Host "Error details exported to: $errorFile" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Stop-Transcript
}

<# CSV Template:
FirstName,LastName,SamAccountName,EmailAddress,Title,Department,Company,Office,Manager,Groups
John,Doe,jdoe,jdoe@contoso.com,Developer,IT,Contoso,Building A,mjones,IT-Staff;Developers
Jane,Smith,jsmith,jsmith@contoso.com,Manager,HR,Contoso,Building B,,HR-Staff;Managers
#>
