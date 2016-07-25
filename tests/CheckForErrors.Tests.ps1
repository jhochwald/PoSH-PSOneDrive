#requires -Version 3 -Modules Pester

<#
		.SYNOPSIS
		Pester Unit Test

		.DESCRIPTION
		Pester is a BDD based test runner for PowerShell.

		.EXAMPLE
		PS C:\> Invoke-Pester

		.NOTES
		PESTER PowerShell Module must be installed!

		modified by     : Joerg Hochwald
		last modified   : 2016-07-25

		.LINK
		Pester https://github.com/pester/Pester
#>

# Where are we?
$modulePath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path | Split-Path -Parent)
$moduleName = 'OneDrive'
$moduleCall = ($modulePath + '\' + $moduleName + '.psd1')

# Reload the Module
Remove-Module $moduleName -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module $moduleCall -DisableNameChecking -Force -Scope Global -ErrorAction Stop -WarningAction SilentlyContinue

Describe "Check $($moduleName) for errors" {
	It "$($moduleName) is valid PowerShell (has no script errors)" {
		# Cleanup
		$errors = $null
		$content = $null

		# Read the File
		$content = (Get-Content -Path $moduleCall -ErrorAction Stop)

		# Check the File
		$null = [System.Management.Automation.PSParser]::Tokenize($content,[ref]$errors)

		# Should have no errors!
		$errors.Count | Should Be 0
	}
}
