#requires -Version 3 -Modules Pester, PSScriptAnalyzer

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

<#
		The 3rd party Module must be here!

		Install it:
		PS> Save-Module -Name PSScriptAnalyzer -Path <path>
		PS> Install-Module -Name PSScriptAnalyzer
#>

# Where are we?
$modulePath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path | Split-Path -Parent)
$moduleName = 'OneDrive'
$moduleCall = ($modulePath + '\' + $moduleName + '.psd1')

# Reload the Module
Remove-Module $moduleName -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Import-Module $moduleCall -DisableNameChecking -Force -Scope Global -ErrorAction Stop -WarningAction SilentlyContinue

Describe "Check $($moduleName) with ScriptAnalyzer" {
	It "$($moduleName) should pass the basic ScriptAnalyzer tests" {
		# Check the Module
		# We disable a few rules until all modules are re-factored...
		(Invoke-ScriptAnalyzer -Path $moduleCall -ExcludeRule 'PSAvoidGlobalVars', 'PSAvoidUsingCmdletAliases', 'PSAvoidUsingUserNameAndPassWordParams', 'PSUseBOMForUnicodeEncodedFile', 'PSAvoidUsingInvokeExpression', 'PSAvoidUsingWriteHost', 'PSUseApprovedVerbs', 'PSAvoidUsingWMICmdlet', 'PSAvoidDefaultValueSwitchParameter', 'PSUseSingularNouns', 'PSShouldProcess', 'PSAvoidUsingPlainTextForPassword')
	}
}
