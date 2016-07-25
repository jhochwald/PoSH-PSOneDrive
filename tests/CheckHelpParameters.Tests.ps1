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

Describe "Check $($moduleName) function" {
	InModuleScope $moduleName {
		$ModuleCommandList = ((Get-Command -Module enatec.OpenSource -CommandType Function).Name)

		foreach ($ModuleCommand in $ModuleCommandList) {
			# Cleanup
			$help = $null

			# Get the Help
			$help = (Get-Help -Name $ModuleCommand -Detailed)

			Context "Check $ModuleCommand Help" {
				It "Check $ModuleCommand Name" {
					$help.NAME | Should Not BeNullOrEmpty
				}

				It "Check $ModuleCommand Synopsis" {
					$help.SYNOPSIS | Should Not BeNullOrEmpty
				}

				It "Check $ModuleCommand Syntax" {
					$help.SYNTAX | Should Not BeNullOrEmpty
				}

				It "Check $ModuleCommand Description" {
					$help.description | Should Not BeNullOrEmpty
				}

				<#
						# No Function is an Island!
						It "Check $ModuleCommand Links" {
						$help.relatedLinks | Should Not BeNullOrEmpty
						}

						# For future usage
						It "Check $ModuleCommand has Values set" {
						$help.returnValues | Should Not BeNullOrEmpty
						}

						# Not all functions need that!
						It "Check $ModuleCommand has parameters set" {
						$help.parameters | Should Not BeNullOrEmpty
						}

						# Do the function have a note field?
						It "Check $ModuleCommand has a Note" {
						$help.alertSet | Should Not BeNullOrEmpty
						}
				#>

				It "Check $ModuleCommand Examples" {
					$help.examples | Should Not BeNullOrEmpty
				}

				It "Check that $ModuleCommand does not use default Synopsis" {
					$help.Synopsis.ToString() | Should not BeLike 'A brief description of the*'
				}

				It "Check that $ModuleCommand does not use default DESCRIPTION" {
					$help.DESCRIPTION.text | Should not BeLike "A detailed description of the*"
				}

				It "Check that $ModuleCommand does not use default NOTES" {
					$help.alertSet.alert.text | Should not BeLike "Additional information about the function."
				}
			}
		}
	}
}
