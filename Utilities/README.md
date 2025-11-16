# Utility Scripts & Helper Functions

Reusable PowerShell functions and utilities used across other scripts.

## 📁 Directory Structure

- **Authentication/** - Connection and credential helpers
- **Logging/** - Logging and transcript functions
- **ErrorHandling/** - Error handling and retry logic
- **DataProcessing/** - CSV, JSON, and data manipulation

## 🔧 Common Utilities

### Authentication Helpers
- Secure credential storage
- Multi-service authentication
- Token management
- Service principal authentication

### Logging Functions
- Transcript logging
- Custom log file creation
- Log rotation
- Centralized logging

### Error Handling
- Try-catch wrappers
- Retry logic with exponential backoff
- Error notification
- Graceful degradation

### Data Processing
- CSV import/export with validation
- JSON parsing
- Data transformation
- Bulk operations framework

## Usage Example

```powershell
# Import utility functions
. .\Utilities\Authentication\Connect-Services.ps1
. .\Utilities\Logging\Write-Log.ps1

# Use in your scripts
Connect-Services -Services @('Azure', 'EntraID')
Write-Log -Message "Starting process" -Level INFO
```

## Function Standards

All utility functions should:
- Include comment-based help
- Support -WhatIf where applicable
- Include parameter validation
- Return proper error codes
- Be reusable and modular

## Creating New Utilities

When creating new utility functions:
1. Follow PowerShell verb-noun naming
2. Include comprehensive help
3. Add parameter validation
4. Include usage examples
5. Test thoroughly
6. Document dependencies
