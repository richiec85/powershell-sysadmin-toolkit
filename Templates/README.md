# PowerShell Script Templates

Standard templates for creating new PowerShell scripts with best practices built-in.

## Available Templates

### Basic Script Template
- Parameter definition
- Comment-based help
- Error handling
- Logging setup

### Advanced Function Template
- Advanced function structure
- Pipeline support
- WhatIf/Confirm support
- Verbose and Debug output

### Module Template
- Module manifest
- Public/private functions
- Export configuration
- Module help

### Reporting Script Template
- Data collection
- Report generation
- Email delivery
- Multiple output formats

## Using Templates

1. Copy the appropriate template
2. Rename to your script name
3. Update the help section
4. Modify parameters as needed
5. Implement your logic in the Process block
6. Test thoroughly

## Template Standards

All templates include:
- Proper parameter validation
- Comment-based help with examples
- Error handling
- Transcript logging
- WhatIf support (where applicable)
- Verbose output
- Standard header with metadata

## Script Header Format

```powershell
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.PARAMETER ParameterName
    Parameter description

.EXAMPLE
    Example usage

.NOTES
    Author: Your Name
    Date: YYYY-MM-DD
    Version: 1.0
#>
```
