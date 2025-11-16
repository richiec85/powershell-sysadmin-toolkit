# Contributing to PowerShell SysAdmin Toolkit

Thank you for your interest in contributing to the PowerShell SysAdmin Toolkit! This guide will help you contribute effectively.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Script Standards](#script-standards)
- [Testing Guidelines](#testing-guidelines)
- [Submission Process](#submission-process)

## 🤝 Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what's best for the community
- Show empathy towards other contributors

## 🚀 Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/powershell-sysadmin-toolkit.git
   cd powershell-sysadmin-toolkit
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the script standards below
   - Test thoroughly
   - Document your code

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add: Brief description of changes"
   ```

## 📝 How to Contribute

### Types of Contributions

- **New Scripts**: Add new functionality to existing categories
- **Bug Fixes**: Fix issues in existing scripts
- **Documentation**: Improve README files, comments, or examples
- **Templates**: Enhance or add new script templates
- **Testing**: Add or improve test cases

### Where to Add Your Scripts

Place scripts in the appropriate directory:

```
ActiveDirectory/    - On-premises AD scripts
├── Users/         - User management scripts
├── Groups/        - Group management scripts
└── ...

EntraID/           - Azure AD/Entra ID scripts
├── Users/         - User management scripts
├── Licenses/      - License management scripts
└── ...

Azure/             - Azure resource management
Windows/           - Windows OS management
Hybrid/            - Hybrid cloud scenarios
Reporting/         - Reporting and auditing
Utilities/         - Helper functions and utilities
Templates/         - Script templates
```

## 📐 Script Standards

### Required Elements

Every script must include:

1. **Comment-Based Help**
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
       Created: YYYY-MM-DD
       Version: 1.0
   #>
   ```

2. **Parameter Validation**
   ```powershell
   param(
       [Parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]$ParameterName
   )
   ```

3. **Error Handling**
   ```powershell
   try {
       # Your code
   }
   catch {
       Write-Error "Error message: $_"
   }
   ```

4. **Logging**
   ```powershell
   Start-Transcript -Path ".\Logs\ScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
   # Script content
   Stop-Transcript
   ```

5. **WhatIf Support** (when applicable)
   ```powershell
   [CmdletBinding(SupportsShouldProcess = $true)]
   param()

   if ($PSCmdlet.ShouldProcess($target, $action)) {
       # Perform action
   }
   ```

### Coding Standards

- Use **approved PowerShell verbs**: `Get-Verb` for list
- Follow **PascalCase** for function names: `Get-UserReport`
- Use **camelCase** for variables: `$userName`
- Use **4 spaces** for indentation (no tabs)
- Maximum line length: **120 characters**
- Include **verbose output** for debugging: `Write-Verbose`

### Security Requirements

- **Never hardcode credentials**
  ```powershell
  # Good
  $credential = Get-Credential

  # Bad
  $password = "MyPassword123"
  ```

- **Use secure string for passwords**
  ```powershell
  $securePassword = Read-Host "Enter password" -AsSecureString
  ```

- **Validate input parameters**
  ```powershell
  [ValidatePattern('^[a-zA-Z0-9]+$')]
  [string]$Username
  ```

- **Include warning for destructive operations**
  ```powershell
  Write-Warning "This will delete all users in the specified OU"
  ```

### Documentation Standards

1. **Clear Comments**
   - Explain *why*, not just *what*
   - Comment complex logic
   - Update comments when code changes

2. **Examples**
   - Include at least 2 examples in help
   - Show common use cases
   - Include expected output

3. **Prerequisites**
   - List required modules
   - Document permissions needed
   - Note version requirements

## 🧪 Testing Guidelines

### Before Submitting

1. **Test in Non-Production**
   - Use test environment
   - Test with various inputs
   - Test error conditions

2. **Run PSScriptAnalyzer**
   ```powershell
   Install-Module -Name PSScriptAnalyzer
   Invoke-ScriptAnalyzer -Path .\YourScript.ps1
   ```

3. **Test with Different PowerShell Versions**
   - PowerShell 5.1 (Windows PowerShell)
   - PowerShell 7+ (PowerShell Core)

4. **Verify Help Documentation**
   ```powershell
   Get-Help .\YourScript.ps1 -Full
   ```

### Test Cases to Consider

- Valid inputs
- Invalid inputs
- Edge cases (empty strings, null values)
- Large datasets
- Missing prerequisites
- Insufficient permissions

## 📤 Submission Process

1. **Ensure Code Quality**
   - Passes PSScriptAnalyzer with no errors
   - Follows all script standards
   - Includes comprehensive help

2. **Update Documentation**
   - Add script description to relevant README
   - Update main README if adding new category
   - Include usage examples

3. **Create Pull Request**
   - Use descriptive title
   - Explain what your script does
   - List any dependencies
   - Reference related issues

4. **Pull Request Template**
   ```markdown
   ## Description
   Brief description of the script and its purpose

   ## Type of Change
   - [ ] New script
   - [ ] Bug fix
   - [ ] Enhancement
   - [ ] Documentation

   ## Testing
   - [ ] Tested in PowerShell 5.1
   - [ ] Tested in PowerShell 7+
   - [ ] Passed PSScriptAnalyzer
   - [ ] Tested in non-production environment

   ## Checklist
   - [ ] Comment-based help included
   - [ ] Parameters are validated
   - [ ] Error handling implemented
   - [ ] WhatIf support added (if applicable)
   - [ ] Examples provided
   - [ ] Documentation updated
   ```

## 🎯 Script Categories

### Difficulty Levels

Label your scripts with difficulty:

- **Beginner**: Basic cmdlet usage, simple operations
- **Intermediate**: Multiple operations, error handling, parameter sets
- **Advanced**: Complex logic, pipeline support, module creation

### Priority Areas

We especially welcome contributions in:

- Entra ID (Microsoft Graph) scripts
- Azure cost optimization
- Security and compliance reporting
- Automation and scheduled tasks
- Cross-platform PowerShell 7+ scripts

## 💡 Tips for Success

1. **Start Small**: Begin with simple scripts to understand the structure
2. **Use Templates**: Copy from `/Templates` directory
3. **Ask Questions**: Open an issue if you need clarification
4. **Review Others**: Learn from existing scripts in the repository
5. **Stay Updated**: Keep up with PowerShell best practices

## 📞 Getting Help

- **Issues**: Open an issue for bugs or questions
- **Discussions**: Use GitHub Discussions for general questions
- **Documentation**: Check existing scripts for examples

## 🏆 Recognition

Contributors will be:
- Listed in the repository contributors
- Credited in script headers
- Acknowledged in release notes

Thank you for helping make this toolkit better for the entire community!
