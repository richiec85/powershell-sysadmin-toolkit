<#
.SYNOPSIS
    Advanced PowerShell function template with best practices.

.DESCRIPTION
    This template demonstrates an advanced PowerShell function with proper structure,
    parameter validation, pipeline support, and comprehensive error handling.

.PARAMETER InputObject
    The object(s) to process. Accepts pipeline input.

.PARAMETER Property
    The property to process or modify.

.PARAMETER Force
    Forces the operation without prompting for confirmation.

.EXAMPLE
    Get-Something | Invoke-AdvancedFunction -Property "Name"

    Processes objects from the pipeline.

.EXAMPLE
    Invoke-AdvancedFunction -InputObject $object -Property "Status" -Verbose

    Processes a specific object with verbose output.

.INPUTS
    System.Object

.OUTPUTS
    System.Object

.NOTES
    Author:         Your Name
    Created:        YYYY-MM-DD
    Version:        1.0
#>

function Invoke-AdvancedFunction {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium',
        DefaultParameterSetName = 'Default'
    )]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'Default',
            HelpMessage = 'Enter the object to process'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Object', 'Item')]
        [PSObject[]]$InputObject,

        [Parameter(
            Mandatory = $true,
            Position = 1,
            HelpMessage = 'Enter the property name'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$Property,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PSCmdlet.ParameterSetName)"
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        # Initialize counters and collections
        $processedCount = 0
        $failedCount = 0
        $results = [System.Collections.Generic.List[PSObject]]::new()

        # Validation and setup
        try {
            # Perform any necessary setup or validation here
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Initialization complete"
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        foreach ($item in $InputObject) {
            try {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing item: $($item.ToString())"

                # Check if property exists
                if (-not ($item.PSObject.Properties.Name -contains $Property)) {
                    Write-Warning "Property '$Property' not found on object"
                    $failedCount++
                    continue
                }

                # Confirm action with ShouldProcess
                $target = "Item: $($item.ToString())"
                $action = "Process property '$Property'"

                if ($Force -or $PSCmdlet.ShouldProcess($target, $action)) {
                    # Perform the actual operation
                    $result = [PSCustomObject]@{
                        PSTypeName    = 'AdvancedFunction.Result'
                        OriginalItem  = $item
                        Property      = $Property
                        Value         = $item.$Property
                        ProcessedDate = Get-Date
                        Success       = $true
                    }

                    # Add to results collection
                    $results.Add($result)
                    $processedCount++

                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Successfully processed item"
                }
                else {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Operation cancelled by user"
                }
            }
            catch {
                $failedCount++
                Write-Error "Failed to process item: $_"
                Write-Debug "Error details: $($_.Exception | Format-List -Force | Out-String)"

                # Optionally continue processing other items or stop
                if ($ErrorActionPreference -eq 'Stop') {
                    throw
                }
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function completed"
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processed: $processedCount | Failed: $failedCount"

        # Return results
        if ($results.Count -gt 0) {
            Write-Output $results
        }

        # Cleanup if necessary
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Cleanup complete"
    }
}

# Example usage:
# Get-Process | Select-Object -First 5 | Invoke-AdvancedFunction -Property "Name" -Verbose
