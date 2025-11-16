<#
.SYNOPSIS
    Brief description of what the script does.

.DESCRIPTION
    Detailed description of what the script does, its purpose, and any important information
    about its functionality and requirements.

.PARAMETER ParameterName
    Description of what this parameter does and what values it accepts.

.PARAMETER WhatIf
    Shows what would happen if the script runs without actually making changes.

.EXAMPLE
    .\Basic-Script-Template.ps1 -ParameterName "Value"

    Description of what this example does.

.EXAMPLE
    .\Basic-Script-Template.ps1 -ParameterName "Value" -WhatIf

    Shows what would happen without making actual changes.

.NOTES
    Author:         Your Name
    Created:        YYYY-MM-DD
    Last Modified:  YYYY-MM-DD
    Version:        1.0

    Changelog:
    1.0 - Initial release

.LINK
    https://github.com/yourusername/powershell-sysadmin-toolkit
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true,
               HelpMessage = "Enter a description for this parameter")]
    [ValidateNotNullOrEmpty()]
    [string]$ParameterName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$PSScriptRoot\Output"
)

begin {
    #region Initialization
    # Start transcript logging
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $transcriptPath = "$PSScriptRoot\Logs\Transcript-$timestamp.log"

    # Create logs directory if it doesn't exist
    if (-not (Test-Path "$PSScriptRoot\Logs")) {
        New-Item -Path "$PSScriptRoot\Logs" -ItemType Directory -Force | Out-Null
    }

    Start-Transcript -Path $transcriptPath
    Write-Verbose "Script started at $(Get-Date)"
    Write-Verbose "Transcript logging to: $transcriptPath"

    # Initialize variables
    $errorCount = 0
    $successCount = 0
    #endregion
}

process {
    try {
        #region Main Logic
        Write-Verbose "Processing parameter: $ParameterName"

        # Your main script logic here
        if ($PSCmdlet.ShouldProcess($ParameterName, "Perform Action")) {
            # Perform the actual operation
            Write-Host "Processing: $ParameterName" -ForegroundColor Green
            $successCount++
        }
        #endregion
    }
    catch {
        #region Error Handling
        $errorCount++
        Write-Error "Error processing $ParameterName : $_"
        Write-Verbose "Error details: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        #endregion
    }
}

end {
    #region Cleanup and Reporting
    Write-Host "`n=== Script Execution Summary ===" -ForegroundColor Cyan
    Write-Host "Successful operations: $successCount" -ForegroundColor Green
    Write-Host "Failed operations: $errorCount" -ForegroundColor Red
    Write-Host "Script completed at $(Get-Date)" -ForegroundColor Cyan

    # Stop transcript
    Stop-Transcript
    Write-Verbose "Transcript saved to: $transcriptPath"
    #endregion
}
