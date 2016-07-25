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

# Cleanup
$result = $null
$HelpFile = $null

Describe "Check if XML Help exists for  $($moduleName)" {
	Context 'Must pass' {
		It "Check if $($moduleName) XML Help exists" {
			$HelpFile = (Test-Path -Path $modulePath\en-US\$moduleName.psm1-Help.xml)

			if ($HelpFile -eq $True) {
				$result = 'Passed'
			} else {
				$result = 'Failed'
			}

			$result | Should Be Passed

			# Cleanup
			$result = $null
			$HelpFile = $null
		}
	}
}
