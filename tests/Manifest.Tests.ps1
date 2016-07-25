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

Describe "Check $($moduleName) Manifest" {
	Context "Manifest check for $($moduleName)" {
		$manifestPath = ($moduleCall)
		$manifestHash = (Invoke-Expression -Command (Get-Content $manifestPath -Raw))

		It "$($moduleName) have a valid manifest" { { $null = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue } | Should Not Throw
		}

		It "$($moduleName) have a valid Root Module" {
			$manifestHash.RootModule | Should Be "$moduleName.psm1"
		}

		It "$($moduleName) have no more ModuleToProcess entry" {
			$manifestHash.ModuleToProcess | Should BeNullOrEmpty
		}

<#
		It "$($moduleName) have a valid description" {
			$manifestHash.Description | Should Not BeNullOrEmpty
		}

		It "$($moduleName) have a valid PowerShell Version Requirement" {
			$manifestHash.PowerShellVersion | Should Not BeNullOrEmpty
		}

		It "$($moduleName) have a valid PowerShell CLR Version Requirement" {
			$manifestHash.CLRVersion | Should Not BeNullOrEmpty
		}
#>

		It "$($moduleName) have a valid author" {
			$manifestHash.Author | Should Not BeNullOrEmpty
		}

		It "$($moduleName) have a valid Company" {
			$manifestHash.CompanyName | Should Not BeNullOrEmpty
		}

		It "$($moduleName) have a valid guid" { {
				[guid]::Parse($manifestHash.Guid)
			} | Should Not throw
		}

		It "$($moduleName) have a valid copyright" {
			$manifestHash.CopyRight | Should Not BeNullOrEmpty
		}

		It "$($moduleName) have a valid Version" {
			$manifestHash.ModuleVersion | Should Not BeNullOrEmpty
		}

		It "$($moduleName) exports Functions" {
			$manifestHash.FunctionsToExport | Should Not BeNullOrEmpty
		}

		It "$($moduleName) exports Cmdlets" {
			$manifestHash.CmdletsToExport | Should Not BeNullOrEmpty
		}

		It "$($moduleName) exports Variables" {
			$manifestHash.VariablesToExport | Should Not BeNullOrEmpty
		}

		It "$($moduleName) exports Aliases" {
			$manifestHash.AliasesToExport | Should Not BeNullOrEmpty
		}

<#
		It "Online Galleries: $($moduleName) have Categories" {
			$manifestHash.PrivateData.PSData.Category | Should Not BeNullOrEmpty
		}

		It "Online Galleries: $($moduleName) have Tags" {
			$manifestHash.PrivateData.PSData.Tags | Should Not BeNullOrEmpty
		}

		It "Online Galleries: $($moduleName) have a license URL" {
			$manifestHash.PrivateData.PSData.LicenseUri | Should Not BeNullOrEmpty
		}

		It "Online Galleries: $($moduleName) have a Project URL" {
			$manifestHash.PrivateData.PSData.ProjectUri | Should Not BeNullOrEmpty
		}

		It "Online Galleries: $($moduleName) have a Icon URL" {
			$manifestHash.PrivateData.PSData.IconUri | Should Not BeNullOrEmpty
		}

		It "Online Galleries: $($moduleName) have ReleaseNotes" {
			$manifestHash.PrivateData.PSData.ReleaseNotes | Should Not BeNullOrEmpty
		}

		It "NuGet: $($moduleName) have Info for Prerelease" {
			$manifestHash.PrivateData.PSData.IsPrerelease | Should Not BeNullOrEmpty
		}

		It "NuGet: $($moduleName) have Module Title" {
			$manifestHash.PrivateData.PSData.ModuleTitle | Should Not BeNullOrEmpty
		}

		It "NuGet: $($moduleName) have Module Summary" {
			$manifestHash.PrivateData.PSData.ModuleSummary | Should Not BeNullOrEmpty
		}

		It "NuGet: $($moduleName) have Module Language" {
			$manifestHash.PrivateData.PSData.ModuleLanguage | Should Not BeNullOrEmpty
		}

		It "NuGet: $($moduleName) have License Acceptance Info" {
			$manifestHash.PrivateData.PSData.ModuleRequireLicenseAcceptance | Should Not BeNullOrEmpty
		}
#>
	}
}
