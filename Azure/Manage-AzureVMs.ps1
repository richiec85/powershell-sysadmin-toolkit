<#
.SYNOPSIS
    Manages Azure Virtual Machines - Start, Stop, Resize, and Monitor
.DESCRIPTION
    This script provides comprehensive Azure VM management capabilities including
    starting/stopping VMs, resizing, snapshot creation, and cost optimization.
.PARAMETER Action
    Action to perform: Start, Stop, Restart, Resize, Snapshot, Report
.PARAMETER ResourceGroup
    Azure Resource Group name
.PARAMETER VMName
    Virtual Machine name (supports wildcards for bulk operations)
.EXAMPLE
    .\Manage-AzureVMs.ps1 -Action Stop -ResourceGroup "RG-Production" -VMName "VM-*"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start", "Stop", "Restart", "Resize", "Snapshot", "Report", "CostOptimize")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string]$NewSize,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeallocateIfStopped,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "$PSScriptRoot\Reports\AzureVM_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Connect to Azure
function Connect-AzureSubscription {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "Connecting to Azure..." -ForegroundColor Yellow
            Connect-AzAccount
        }
        
        Write-Host "Connected to Azure Subscription: $($context.Subscription.Name)" -ForegroundColor Green
        Write-Host "Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
    }
    catch {
        throw "Failed to connect to Azure: $_"
    }
}

# Get VMs based on criteria
function Get-TargetVMs {
    param(
        [string]$ResourceGroup,
        [string]$VMName
    )
    
    $vms = @()
    
    if ($ResourceGroup -and $VMName) {
        # Specific VMs in a resource group
        if ($VMName -like "*[*?]*") {
            $vms = Get-AzVM -ResourceGroupName $ResourceGroup | Where-Object { $_.Name -like $VMName }
        }
        else {
            $vms = @(Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName -ErrorAction SilentlyContinue)
        }
    }
    elseif ($ResourceGroup) {
        # All VMs in a resource group
        $vms = Get-AzVM -ResourceGroupName $ResourceGroup
    }
    else {
        # All VMs in subscription
        $vms = Get-AzVM
    }
    
    return $vms
}

# Start VMs
function Start-VMs {
    param([array]$VMs)
    
    $results = @()
    
    foreach ($vm in $VMs) {
        try {
            $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code.Split("/")[1]
            
            if ($powerState -eq "running") {
                Write-Host "⚠ VM $($vm.Name) is already running" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    VMName = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Action = "Start"
                    Status = "Already Running"
                    PreviousState = $powerState
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($vm.Name, "Start VM")) {
                    Write-Host "Starting VM: $($vm.Name)..." -ForegroundColor Cyan
                    Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -NoWait
                    
                    Write-Host "✓ Start command sent for $($vm.Name)" -ForegroundColor Green
                    
                    $results += [PSCustomObject]@{
                        VMName = $vm.Name
                        ResourceGroup = $vm.ResourceGroupName
                        Action = "Start"
                        Status = "Starting"
                        PreviousState = $powerState
                    }
                }
            }
        }
        catch {
            Write-Host "✗ Failed to start VM $($vm.Name): $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                VMName = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Action = "Start"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
    
    return $results
}

# Stop VMs
function Stop-VMs {
    param(
        [array]$VMs,
        [bool]$Deallocate
    )
    
    $results = @()
    
    foreach ($vm in $VMs) {
        try {
            $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code.Split("/")[1]
            
            if ($powerState -eq "stopped" -or $powerState -eq "deallocated") {
                Write-Host "⚠ VM $($vm.Name) is already stopped" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    VMName = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Action = "Stop"
                    Status = "Already Stopped"
                    PreviousState = $powerState
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($vm.Name, "Stop VM")) {
                    Write-Host "Stopping VM: $($vm.Name)..." -ForegroundColor Cyan
                    
                    if ($Deallocate) {
                        Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -NoWait
                        $status = "Deallocating"
                    }
                    else {
                        Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -StayProvisioned -Force -NoWait
                        $status = "Stopping (Provisioned)"
                    }
                    
                    Write-Host "✓ Stop command sent for $($vm.Name)" -ForegroundColor Green
                    
                    $results += [PSCustomObject]@{
                        VMName = $vm.Name
                        ResourceGroup = $vm.ResourceGroupName
                        Action = "Stop"
                        Status = $status
                        PreviousState = $powerState
                    }
                }
            }
        }
        catch {
            Write-Host "✗ Failed to stop VM $($vm.Name): $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                VMName = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Action = "Stop"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
    
    return $results
}

# Resize VMs
function Resize-VMs {
    param(
        [array]$VMs,
        [string]$NewSize
    )
    
    $results = @()
    
    foreach ($vm in $VMs) {
        try {
            $currentSize = $vm.HardwareProfile.VmSize
            
            if ($currentSize -eq $NewSize) {
                Write-Host "⚠ VM $($vm.Name) is already size $NewSize" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    VMName = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Action = "Resize"
                    Status = "No Change"
                    CurrentSize = $currentSize
                }
            }
            else {
                # Check if size is available in the region
                $availableSizes = Get-AzVMSize -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name
                if ($availableSizes.Name -notcontains $NewSize) {
                    throw "Size '$NewSize' not available for VM $($vm.Name)"
                }
                
                if ($PSCmdlet.ShouldProcess($vm.Name, "Resize from $currentSize to $NewSize")) {
                    Write-Host "Resizing VM: $($vm.Name) from $currentSize to $NewSize..." -ForegroundColor Cyan
                    
                    $vm.HardwareProfile.VmSize = $NewSize
                    Update-AzVM -VM $vm -ResourceGroupName $vm.ResourceGroupName
                    
                    Write-Host "✓ Resized $($vm.Name) to $NewSize" -ForegroundColor Green
                    
                    $results += [PSCustomObject]@{
                        VMName = $vm.Name
                        ResourceGroup = $vm.ResourceGroupName
                        Action = "Resize"
                        Status = "Success"
                        PreviousSize = $currentSize
                        NewSize = $NewSize
                    }
                }
            }
        }
        catch {
            Write-Host "✗ Failed to resize VM $($vm.Name): $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                VMName = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Action = "Resize"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
    
    return $results
}

# Create VM snapshots
function Create-VMSnapshots {
    param([array]$VMs)
    
    $results = @()
    
    foreach ($vm in $VMs) {
        try {
            Write-Host "Creating snapshot for VM: $($vm.Name)..." -ForegroundColor Cyan
            
            # Get OS disk
            $osDisk = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
            
            # Create snapshot config
            $snapshotName = "$($vm.Name)-snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            $snapshotConfig = New-AzSnapshotConfig `
                -SourceResourceId $osDisk.Id `
                -Location $vm.Location `
                -CreateOption Copy
            
            if ($PSCmdlet.ShouldProcess($vm.Name, "Create snapshot")) {
                # Create snapshot
                $snapshot = New-AzSnapshot `
                    -ResourceGroupName $vm.ResourceGroupName `
                    -SnapshotName $snapshotName `
                    -Snapshot $snapshotConfig
                
                Write-Host "✓ Created snapshot: $snapshotName" -ForegroundColor Green
                
                $results += [PSCustomObject]@{
                    VMName = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Action = "Snapshot"
                    Status = "Success"
                    SnapshotName = $snapshotName
                    DiskName = $osDisk.Name
                }
                
                # Also snapshot data disks if present
                foreach ($dataDisk in $vm.StorageProfile.DataDisks) {
                    $disk = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $dataDisk.Name
                    $dataSnapshotName = "$($vm.Name)-data$($dataDisk.Lun)-snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    
                    $dataSnapshotConfig = New-AzSnapshotConfig `
                        -SourceResourceId $disk.Id `
                        -Location $vm.Location `
                        -CreateOption Copy
                    
                    $dataSnapshot = New-AzSnapshot `
                        -ResourceGroupName $vm.ResourceGroupName `
                        -SnapshotName $dataSnapshotName `
                        -Snapshot $dataSnapshotConfig
                    
                    Write-Host "  ✓ Created data disk snapshot: $dataSnapshotName" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Host "✗ Failed to create snapshot for VM $($vm.Name): $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                VMName = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Action = "Snapshot"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
    
    return $results
}

# Generate VM report
function Get-VMReport {
    Write-Host "`nGenerating VM report..." -ForegroundColor Cyan
    
    $report = @()
    $allVMs = Get-AzVM
    
    foreach ($vm in $allVMs) {
        try {
            $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code.Split("/")[1]
            
            # Get IP addresses
            $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
            $privateIP = $nic.IpConfigurations[0].PrivateIpAddress
            $publicIP = if ($nic.IpConfigurations[0].PublicIpAddress) {
                (Get-AzPublicIpAddress -ResourceGroupName $vm.ResourceGroupName -Name ($nic.IpConfigurations[0].PublicIpAddress.Id.Split("/")[-1])).IpAddress
            } else { "None" }
            
            # Get tags
            $tags = if ($vm.Tags) {
                ($vm.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
            } else { "None" }
            
            $report += [PSCustomObject]@{
                VMName = $vm.Name
                ResourceGroup = $vm.ResourceGroupName
                Location = $vm.Location
                Size = $vm.HardwareProfile.VmSize
                Status = $powerState
                OSType = $vm.StorageProfile.OsDisk.OsType
                PrivateIP = $privateIP
                PublicIP = $publicIP
                DataDisks = $vm.StorageProfile.DataDisks.Count
                Tags = $tags
            }
        }
        catch {
            Write-Warning "Failed to get details for VM $($vm.Name): $_"
        }
    }
    
    return $report
}

# Cost optimization recommendations
function Get-CostOptimization {
    Write-Host "`nAnalyzing VMs for cost optimization..." -ForegroundColor Cyan
    
    $recommendations = @()
    $allVMs = Get-AzVM
    
    foreach ($vm in $allVMs) {
        try {
            $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code.Split("/")[1]
            
            # Check for stopped but not deallocated VMs
            if ($powerState -eq "stopped") {
                $recommendations += [PSCustomObject]@{
                    VMName = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Recommendation = "Deallocate VM"
                    Reason = "VM is stopped but still incurring compute charges"
                    EstimatedSavings = "100% of compute cost"
                }
            }
            
            # Check for oversized VMs (this is simplified - real analysis would use metrics)
            $size = $vm.HardwareProfile.VmSize
            if ($size -like "*_v3" -or $size -like "*_v4") {
                # Check if older generation exists
                $olderGen = $size -replace "_v[34]", "_v2"
                $availableSizes = Get-AzVMSize -Location $vm.Location
                if ($availableSizes.Name -contains $olderGen) {
                    $recommendations += [PSCustomObject]@{
                        VMName = $vm.Name
                        ResourceGroup = $vm.ResourceGroupName
                        Recommendation = "Consider older VM generation"
                        Reason = "Older generation VMs may be sufficient and cost less"
                        EstimatedSavings = "10-20% of compute cost"
                    }
                }
            }
            
            # Check for VMs without tags
            if (-not $vm.Tags -or $vm.Tags.Count -eq 0) {
                $recommendations += [PSCustomObject]@{
                    VMName = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Recommendation = "Add cost center tags"
                    Reason = "Tags help track and allocate costs"
                    EstimatedSavings = "Better cost visibility"
                }
            }
        }
        catch {
            Write-Warning "Failed to analyze VM $($vm.Name): $_"
        }
    }
    
    return $recommendations
}

# Main execution
try {
    Connect-AzureSubscription
    
    switch ($Action) {
        "Start" {
            $vms = Get-TargetVMs -ResourceGroup $ResourceGroup -VMName $VMName
            if ($vms.Count -eq 0) {
                Write-Warning "No VMs found matching criteria"
                return
            }
            
            Write-Host "Found $($vms.Count) VM(s) to start" -ForegroundColor Yellow
            $results = Start-VMs -VMs $vms
            
            $results | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nResults exported to: $ReportPath" -ForegroundColor Green
        }
        
        "Stop" {
            $vms = Get-TargetVMs -ResourceGroup $ResourceGroup -VMName $VMName
            if ($vms.Count -eq 0) {
                Write-Warning "No VMs found matching criteria"
                return
            }
            
            Write-Host "Found $($vms.Count) VM(s) to stop" -ForegroundColor Yellow
            $results = Stop-VMs -VMs $vms -Deallocate $DeallocateIfStopped
            
            $results | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nResults exported to: $ReportPath" -ForegroundColor Green
        }
        
        "Restart" {
            $vms = Get-TargetVMs -ResourceGroup $ResourceGroup -VMName $VMName
            if ($vms.Count -eq 0) {
                Write-Warning "No VMs found matching criteria"
                return
            }
            
            Write-Host "Found $($vms.Count) VM(s) to restart" -ForegroundColor Yellow
            foreach ($vm in $vms) {
                if ($PSCmdlet.ShouldProcess($vm.Name, "Restart VM")) {
                    Restart-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -NoWait
                    Write-Host "✓ Restart command sent for $($vm.Name)" -ForegroundColor Green
                }
            }
        }
        
        "Resize" {
            if (-not $NewSize) {
                throw "NewSize parameter is required for Resize action"
            }
            
            $vms = Get-TargetVMs -ResourceGroup $ResourceGroup -VMName $VMName
            if ($vms.Count -eq 0) {
                Write-Warning "No VMs found matching criteria"
                return
            }
            
            Write-Host "Found $($vms.Count) VM(s) to resize" -ForegroundColor Yellow
            $results = Resize-VMs -VMs $vms -NewSize $NewSize
            
            $results | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nResults exported to: $ReportPath" -ForegroundColor Green
        }
        
        "Snapshot" {
            $vms = Get-TargetVMs -ResourceGroup $ResourceGroup -VMName $VMName
            if ($vms.Count -eq 0) {
                Write-Warning "No VMs found matching criteria"
                return
            }
            
            Write-Host "Found $($vms.Count) VM(s) to snapshot" -ForegroundColor Yellow
            $results = Create-VMSnapshots -VMs $vms
            
            $results | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nResults exported to: $ReportPath" -ForegroundColor Green
        }
        
        "Report" {
            $report = Get-VMReport
            
            # Display summary
            Write-Host "`n========== VM SUMMARY ==========" -ForegroundColor Yellow
            Write-Host "Total VMs: $($report.Count)" -ForegroundColor Cyan
            Write-Host "Running: $(($report | Where-Object { $_.Status -eq 'running' }).Count)" -ForegroundColor Green
            Write-Host "Stopped: $(($report | Where-Object { $_.Status -eq 'stopped' }).Count)" -ForegroundColor Yellow
            Write-Host "Deallocated: $(($report | Where-Object { $_.Status -eq 'deallocated' }).Count)" -ForegroundColor Red
            
            $report | Export-Csv -Path $ReportPath -NoTypeInformation
            Write-Host "`nFull report exported to: $ReportPath" -ForegroundColor Green
        }
        
        "CostOptimize" {
            $recommendations = Get-CostOptimization
            
            if ($recommendations.Count -gt 0) {
                Write-Host "`n========== COST OPTIMIZATION RECOMMENDATIONS ==========" -ForegroundColor Yellow
                $recommendations | Format-Table -AutoSize -Wrap
                
                $recommendations | Export-Csv -Path $ReportPath -NoTypeInformation
                Write-Host "`nRecommendations exported to: $ReportPath" -ForegroundColor Green
            }
            else {
                Write-Host "`nNo cost optimization recommendations found" -ForegroundColor Green
            }
        }
    }
}
catch {
    Write-Error "Script failed: $_"
}
