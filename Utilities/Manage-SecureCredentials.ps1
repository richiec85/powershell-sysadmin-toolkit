<#
.SYNOPSIS
    Secure credential management utility for PowerShell scripts
.DESCRIPTION
    This script provides functions to securely store and retrieve credentials,
    manage service accounts, and handle multi-factor authentication tokens.
.PARAMETER Action
    Action to perform: Store, Retrieve, List, Remove, Test
.PARAMETER CredentialName
    Name/identifier for the credential
.EXAMPLE
    .\Manage-SecureCredentials.ps1 -Action Store -CredentialName "AzureAdmin"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Store", "Retrieve", "List", "Remove", "Test", "Export", "Import")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$CredentialName,
    
    [Parameter(Mandatory=$false)]
    [string]$CredentialPath = "$env:USERPROFILE\.powershell\credentials",
    
    [Parameter(Mandatory=$false)]
    [string]$ExportPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseWindowsVault
)

# Ensure credential directory exists
if (-not (Test-Path $CredentialPath)) {
    New-Item -ItemType Directory -Path $CredentialPath -Force | Out-Null
}

# Function to store credentials
function Store-SecureCredential {
    param(
        [string]$Name,
        [string]$Path,
        [bool]$UseVault
    )
    
    Write-Host "`nStoring credential: $Name" -ForegroundColor Cyan
    
    # Prompt for credentials
    $credential = Get-Credential -Message "Enter credentials for: $Name"
    
    if (-not $credential) {
        Write-Warning "No credentials provided"
        return
    }
    
    try {
        if ($UseVault) {
            # Store in Windows Credential Manager
            Write-Host "Storing in Windows Credential Manager..." -ForegroundColor Yellow
            
            # Install required module if needed
            if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
                Install-Module -Name CredentialManager -Force -Scope CurrentUser
            }
            
            Import-Module CredentialManager
            
            # Store credential
            New-StoredCredential -Target $Name `
                -UserName $credential.UserName `
                -SecurePassword $credential.Password `
                -Type Generic `
                -Persist LocalMachine
            
            Write-Host "✓ Credential stored in Windows Vault" -ForegroundColor Green
        }
        else {
            # Store as encrypted file
            Write-Host "Storing as encrypted file..." -ForegroundColor Yellow
            
            $credFile = Join-Path $Path "$Name.xml"
            
            # Export credential to file (encrypted with DPAPI)
            $credential | Export-Clixml -Path $credFile
            
            # Set restrictive permissions
            $acl = Get-Acl $credFile
            $acl.SetAccessRuleProtection($true, $false)
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $env:USERNAME, "FullControl", "Allow"
            )
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $credFile -AclObject $acl
            
            Write-Host "✓ Credential stored at: $credFile" -ForegroundColor Green
        }
        
        # Store metadata
        $metadata = @{
            Name = $Name
            UserName = $credential.UserName
            StoredDate = Get-Date
            StorageType = if($UseVault){"WindowsVault"}else{"EncryptedFile"}
            LastAccessed = Get-Date
        }
        
        $metadataFile = Join-Path $Path "$Name.meta.json"
        $metadata | ConvertTo-Json | Out-File -FilePath $metadataFile
        
        Write-Host "✓ Credential '$Name' stored successfully" -ForegroundColor Green
        
    }
    catch {
        Write-Error "Failed to store credential: $_"
    }
}

# Function to retrieve credentials
function Get-SecureCredential {
    param(
        [string]$Name,
        [string]$Path,
        [bool]$UseVault
    )
    
    Write-Host "`nRetrieving credential: $Name" -ForegroundColor Cyan
    
    try {
        # Check metadata
        $metadataFile = Join-Path $Path "$Name.meta.json"
        if (Test-Path $metadataFile) {
            $metadata = Get-Content $metadataFile | ConvertFrom-Json
            Write-Host "  Last accessed: $($metadata.LastAccessed)" -ForegroundColor Gray
            Write-Host "  Storage type: $($metadata.StorageType)" -ForegroundColor Gray
            
            # Update last accessed
            $metadata.LastAccessed = Get-Date
            $metadata | ConvertTo-Json | Out-File -FilePath $metadataFile
        }
        
        if ($UseVault) {
            # Retrieve from Windows Credential Manager
            Import-Module CredentialManager -ErrorAction SilentlyContinue
            
            $storedCred = Get-StoredCredential -Target $Name
            
            if ($storedCred) {
                $credential = New-Object System.Management.Automation.PSCredential(
                    $storedCred.UserName, 
                    $storedCred.Password
                )
                
                Write-Host "✓ Credential retrieved from Windows Vault" -ForegroundColor Green
                return $credential
            }
            else {
                Write-Warning "Credential not found in Windows Vault"
                return $null
            }
        }
        else {
            # Retrieve from encrypted file
            $credFile = Join-Path $Path "$Name.xml"
            
            if (Test-Path $credFile) {
                $credential = Import-Clixml -Path $credFile
                Write-Host "✓ Credential retrieved from encrypted file" -ForegroundColor Green
                return $credential
            }
            else {
                Write-Warning "Credential file not found: $credFile"
                return $null
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve credential: $_"
        return $null
    }
}

# Function to list stored credentials
function Get-StoredCredentialList {
    param([string]$Path)
    
    Write-Host "`nListing stored credentials..." -ForegroundColor Cyan
    
    $credentials = @()
    
    # Get file-based credentials
    $credFiles = Get-ChildItem -Path $Path -Filter "*.meta.json" -ErrorAction SilentlyContinue
    
    foreach ($file in $credFiles) {
        $metadata = Get-Content $file.FullName | ConvertFrom-Json
        $credentials += $metadata
    }
    
    # Try to get Windows Vault credentials
    try {
        Import-Module CredentialManager -ErrorAction SilentlyContinue
        $vaultCreds = Get-StoredCredential -AsCredentialObject
        
        foreach ($cred in $vaultCreds) {
            if ($cred.Type -eq "Generic") {
                $credentials += [PSCustomObject]@{
                    Name = $cred.TargetName
                    UserName = $cred.UserName
                    StorageType = "WindowsVault"
                    StoredDate = "N/A"
                    LastAccessed = "N/A"
                }
            }
        }
    }
    catch {
        Write-Verbose "Could not access Windows Vault"
    }
    
    if ($credentials.Count -gt 0) {
        Write-Host "`n========== STORED CREDENTIALS ==========" -ForegroundColor Yellow
        $credentials | Format-Table -Property Name, UserName, StorageType, StoredDate, LastAccessed -AutoSize
    }
    else {
        Write-Host "No stored credentials found" -ForegroundColor Yellow
    }
    
    return $credentials
}

# Function to remove credentials
function Remove-SecureCredential {
    param(
        [string]$Name,
        [string]$Path,
        [bool]$UseVault
    )
    
    Write-Host "`nRemoving credential: $Name" -ForegroundColor Cyan
    
    $confirm = Read-Host "Are you sure you want to remove this credential? (Y/N)"
    if ($confirm -ne "Y") {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    try {
        # Remove from Windows Vault if exists
        if ($UseVault) {
            Import-Module CredentialManager -ErrorAction SilentlyContinue
            Remove-StoredCredential -Target $Name -ErrorAction SilentlyContinue
            Write-Host "✓ Removed from Windows Vault" -ForegroundColor Green
        }
        
        # Remove files
        $credFile = Join-Path $Path "$Name.xml"
        $metadataFile = Join-Path $Path "$Name.meta.json"
        
        if (Test-Path $credFile) {
            Remove-Item -Path $credFile -Force
            Write-Host "✓ Removed credential file" -ForegroundColor Green
        }
        
        if (Test-Path $metadataFile) {
            Remove-Item -Path $metadataFile -Force
            Write-Host "✓ Removed metadata file" -ForegroundColor Green
        }
        
        Write-Host "✓ Credential '$Name' removed successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to remove credential: $_"
    }
}

# Function to test credentials
function Test-SecureCredential {
    param(
        [string]$Name,
        [string]$Path,
        [bool]$UseVault
    )
    
    Write-Host "`nTesting credential: $Name" -ForegroundColor Cyan
    
    # Retrieve credential
    $credential = Get-SecureCredential -Name $Name -Path $Path -UseVault $UseVault
    
    if (-not $credential) {
        Write-Warning "Could not retrieve credential for testing"
        return
    }
    
    Write-Host "`nSelect test type:" -ForegroundColor Yellow
    Write-Host "1. Test Active Directory authentication"
    Write-Host "2. Test Azure authentication"
    Write-Host "3. Test SQL Server authentication"
    Write-Host "4. Test Remote PowerShell"
    Write-Host "5. Display credential info only"
    
    $choice = Read-Host "Enter choice (1-5)"
    
    switch ($choice) {
        "1" {
            # Test AD authentication
            Write-Host "Testing Active Directory authentication..." -ForegroundColor Yellow
            try {
                Add-Type -AssemblyName System.DirectoryServices.AccountManagement
                $domain = $env:USERDNSDOMAIN
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
                    [System.DirectoryServices.AccountManagement.ContextType]::Domain,
                    $domain
                )
                
                $valid = $context.ValidateCredentials(
                    $credential.UserName,
                    $credential.GetNetworkCredential().Password
                )
                
                if ($valid) {
                    Write-Host "✓ AD authentication successful" -ForegroundColor Green
                }
                else {
                    Write-Host "✗ AD authentication failed" -ForegroundColor Red
                }
            }
            catch {
                Write-Error "Failed to test AD authentication: $_"
            }
        }
        
        "2" {
            # Test Azure authentication
            Write-Host "Testing Azure authentication..." -ForegroundColor Yellow
            try {
                Connect-AzAccount -Credential $credential -ErrorAction Stop | Out-Null
                Write-Host "✓ Azure authentication successful" -ForegroundColor Green
                
                $context = Get-AzContext
                Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
                Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
                
                Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Host "✗ Azure authentication failed: $_" -ForegroundColor Red
            }
        }
        
        "3" {
            # Test SQL Server authentication
            Write-Host "Testing SQL Server authentication..." -ForegroundColor Yellow
            $server = Read-Host "Enter SQL Server name"
            $database = Read-Host "Enter database name (or master)"
            
            try {
                $connectionString = "Server=$server;Database=$database;User Id=$($credential.UserName);Password=$($credential.GetNetworkCredential().Password);"
                $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                $connection.Open()
                
                Write-Host "✓ SQL Server authentication successful" -ForegroundColor Green
                Write-Host "  Server: $($connection.DataSource)" -ForegroundColor Gray
                Write-Host "  Database: $($connection.Database)" -ForegroundColor Gray
                
                $connection.Close()
            }
            catch {
                Write-Host "✗ SQL Server authentication failed: $_" -ForegroundColor Red
            }
        }
        
        "4" {
            # Test Remote PowerShell
            Write-Host "Testing Remote PowerShell..." -ForegroundColor Yellow
            $computer = Read-Host "Enter computer name"
            
            try {
                $session = New-PSSession -ComputerName $computer -Credential $credential -ErrorAction Stop
                
                Write-Host "✓ Remote PowerShell connection successful" -ForegroundColor Green
                
                $remoteInfo = Invoke-Command -Session $session -ScriptBlock { 
                    @{
                        ComputerName = $env:COMPUTERNAME
                        UserName = $env:USERNAME
                        OS = (Get-WmiObject Win32_OperatingSystem).Caption
                    }
                }
                
                Write-Host "  Connected to: $($remoteInfo.ComputerName)" -ForegroundColor Gray
                Write-Host "  Running as: $($remoteInfo.UserName)" -ForegroundColor Gray
                Write-Host "  OS: $($remoteInfo.OS)" -ForegroundColor Gray
                
                Remove-PSSession $session
            }
            catch {
                Write-Host "✗ Remote PowerShell connection failed: $_" -ForegroundColor Red
            }
        }
        
        "5" {
            # Display info only
            Write-Host "`nCredential Information:" -ForegroundColor Yellow
            Write-Host "  Username: $($credential.UserName)" -ForegroundColor Gray
            Write-Host "  Password: [PROTECTED]" -ForegroundColor Gray
            Write-Host "  Password Length: $($credential.GetNetworkCredential().Password.Length) characters" -ForegroundColor Gray
        }
    }
}

# Function to export credentials
function Export-SecureCredentials {
    param(
        [string]$Path,
        [string]$ExportPath
    )
    
    Write-Host "`nExporting credentials..." -ForegroundColor Cyan
    Write-Warning "Exported credentials will be encrypted with the current user's key and can only be imported by the same user on the same machine"
    
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne "Y") {
        Write-Host "Export cancelled" -ForegroundColor Yellow
        return
    }
    
    try {
        # Create export directory
        $exportDir = Split-Path $ExportPath -Parent
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        
        # Compress credential directory
        $tempZip = Join-Path $env:TEMP "credentials_export.zip"
        Compress-Archive -Path "$Path\*" -DestinationPath $tempZip -Force
        
        # Encrypt the zip file
        $bytes = [System.IO.File]::ReadAllBytes($tempZip)
        $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
            $bytes, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        [System.IO.File]::WriteAllBytes($ExportPath, $encrypted)
        
        # Clean up temp file
        Remove-Item $tempZip -Force
        
        Write-Host "✓ Credentials exported to: $ExportPath" -ForegroundColor Green
        Write-Host "  File size: $([math]::Round((Get-Item $ExportPath).Length / 1KB, 2)) KB" -ForegroundColor Gray
    }
    catch {
        Write-Error "Failed to export credentials: $_"
    }
}

# Function to import credentials
function Import-SecureCredentials {
    param(
        [string]$Path,
        [string]$ImportPath
    )
    
    Write-Host "`nImporting credentials..." -ForegroundColor Cyan
    
    if (-not (Test-Path $ImportPath)) {
        Write-Error "Import file not found: $ImportPath"
        return
    }
    
    Write-Warning "This will overwrite existing credentials with the same names"
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne "Y") {
        Write-Host "Import cancelled" -ForegroundColor Yellow
        return
    }
    
    try {
        # Decrypt the file
        $encrypted = [System.IO.File]::ReadAllBytes($ImportPath)
        $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encrypted, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        # Save as temp zip
        $tempZip = Join-Path $env:TEMP "credentials_import.zip"
        [System.IO.File]::WriteAllBytes($tempZip, $decrypted)
        
        # Extract to credential directory
        Expand-Archive -Path $tempZip -DestinationPath $Path -Force
        
        # Clean up temp file
        Remove-Item $tempZip -Force
        
        Write-Host "✓ Credentials imported successfully" -ForegroundColor Green
        
        # List imported credentials
        Get-StoredCredentialList -Path $Path
    }
    catch {
        Write-Error "Failed to import credentials: $_"
        Write-Host "Note: Credentials can only be imported by the same user on the same machine" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "`n========== Secure Credential Manager ==========" -ForegroundColor Cyan

switch ($Action) {
    "Store" {
        if (-not $CredentialName) {
            $CredentialName = Read-Host "Enter credential name"
        }
        Store-SecureCredential -Name $CredentialName -Path $CredentialPath -UseVault $UseWindowsVault
    }
    
    "Retrieve" {
        if (-not $CredentialName) {
            # List available and let user choose
            $creds = Get-StoredCredentialList -Path $CredentialPath
            $CredentialName = Read-Host "`nEnter credential name to retrieve"
        }
        
        $credential = Get-SecureCredential -Name $CredentialName -Path $CredentialPath -UseVault $UseWindowsVault
        if ($credential) {
            Write-Host "✓ Credential retrieved successfully" -ForegroundColor Green
            Write-Host "  Username: $($credential.UserName)" -ForegroundColor Gray
        }
    }
    
    "List" {
        Get-StoredCredentialList -Path $CredentialPath
    }
    
    "Remove" {
        if (-not $CredentialName) {
            # List available and let user choose
            $creds = Get-StoredCredentialList -Path $CredentialPath
            $CredentialName = Read-Host "`nEnter credential name to remove"
        }
        Remove-SecureCredential -Name $CredentialName -Path $CredentialPath -UseVault $UseWindowsVault
    }
    
    "Test" {
        if (-not $CredentialName) {
            # List available and let user choose
            $creds = Get-StoredCredentialList -Path $CredentialPath
            $CredentialName = Read-Host "`nEnter credential name to test"
        }
        Test-SecureCredential -Name $CredentialName -Path $CredentialPath -UseVault $UseWindowsVault
    }
    
    "Export" {
        if (-not $ExportPath) {
            $ExportPath = "$env:USERPROFILE\Desktop\credentials_backup_$(Get-Date -Format 'yyyyMMdd').enc"
        }
        Export-SecureCredentials -Path $CredentialPath -ExportPath $ExportPath
    }
    
    "Import" {
        if (-not $ExportPath) {
            $ExportPath = Read-Host "Enter path to import file"
        }
        Import-SecureCredentials -Path $CredentialPath -ImportPath $ExportPath
    }
}

Write-Host "`n========== Operation Complete ==========" -ForegroundColor Green
