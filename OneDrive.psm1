#requires -Version 3

function Get-ODAuthentication {
	<#
			.SYNOPSIS
			Connect to OneDrive for authentication with a given client id

			.DESCRIPTION
			Connect to OneDrive for authentication with a given client id
			(get your free client id on https://dev.onedrive.com/app-registration.htm#register-your-app-for-onedrive)

			.PARAMETER ClientID
			ClientID of your "app" from https://dev.onedrive.com/app-registration.htm#register-your-app-for-onedrive)

			.PARAMETER Scope
			Comma seperated string defining the authentication scope (https://dev.onedrive.com/auth/msa_oauth.htm). Default: "onedrive.readwrite"

			.PARAMETER RedirectURI
			Don't use this parameter. You only need this to write your own web based app for OneDrive. Default is https://login.live.com/oauth20_desktop.srf

			.EXAMPLE
			PS C:\> $Authentication = (Get-ODAuthentication -ClientID "0000000012345678")
			PS C:\> $AuthToken = $Authentication.access_token

			Description
			-----------
			Connect to OneDrive for authentication and save the token to $AuthToken

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'The ClientID of the APP')]
		[ValidateNotNullOrEmpty()]
		[string]$ClientID,
		[string]$Scope = 'onedrive.readwrite',
		[string]$RedirectURI = 'https://login.live.com/oauth20_desktop.srf'
	)

	BEGIN {
		$null = Add-Type -AssemblyName System.Windows.Forms
		$null = Add-Type -AssemblyName System.Drawing
		$null = Add-Type -AssemblyName System.Web

		$URIGetAccessTokenRedirect = $RedirectURI
		$URIGetAccessToken = 'https://login.live.com/oauth20_authorize.srf?client_id=' + $ClientID + '&scope=' + $Scope + '&response_type=token&redirect_uri=' + $URIGetAccessTokenRedirect
		$form = (New-Object -TypeName Windows.Forms.Form)
		$form.text = 'Authenticate to OneDrive'
		$form.size = (New-Object -TypeName Drawing.size -ArgumentList @(700, 600))
		$form.Width = 675
		$form.Height = 750
		$web = (New-Object -TypeName System.Windows.Forms.WebBrowser)
		$web.IsWebBrowserContextMenuEnabled = $true
		$web.Width = 600
		$web.Height = 700
		$web.Location = '25, 25'
		$web.navigate($URIGetAccessToken)
	}

	PROCESS {
		$DocComplete = {
			$Global:uri = $web.Url.AbsoluteUri
			if ($web.Url.AbsoluteUri -match 'access_token=|error') { $form.Close() }
		}

		$web.Add_DocumentCompleted($DocComplete)
		$form.Controls.Add($web)

		$null = $form.showdialog()

		# Build object from last URI (which should contains the token)
		$ReturnURI = ($web.Url).ToString().Replace('#', '&')
		$Authentication = (New-Object -TypeName PSObject)
		ForEach ($element in $ReturnURI.Split('?')[1].Split('&')) {
			$Authentication | Add-Member -MemberType Noteproperty -Name $element.split('=')[0] -Value $element.split('=')[1]
		}

		if ($Authentication.PSobject.Properties.name -match 'expires_in') {
			$Authentication | Add-Member -MemberType Noteproperty -Name 'expires' -Value ([datetime]::Now.AddSeconds($Authentication.expires_in))
		}

		if (!($Authentication.PSobject.Properties.name -match 'expires_in')) {
			Write-Warning -Message ('There is maybe an errror, because there is no access_token!')
		}
	}

	END {
		Write-Output -InputObject $Authentication
	}
}

function Get-ODWebContent {
	<#
			.SYNOPSIS
			Internal function to interact with the OneDrive API

			.DESCRIPTION
			Internal function to interact with the OneDrive API

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER rURI
			Relative path to the API

			.PARAMETER Method
			Web request method like PUT, GET, ...

			.PARAMETER Body
			Payload of a web request

			.PARAMETER BinaryMode
			Do not convert response to JSON

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[string]$rURI = '',
		[ValidateSet('PUT', 'GET', 'POST', 'PATCH', 'DELETE')]
		[string]$Method = 'GET',
		[string]$Body,
		[switch]$BinaryMode
	)

	BEGIN {
		if ($Body -eq '') {
			$xBody = $null
		} else {
			$xBody = $Body
		}

		$ODRootURI = 'https://api.onedrive.com/v1.0'
	}

	PROCESS {
		try {
			$webRequest = Invoke-WebRequest -Method $Method -Uri ($ODRootURI + $rURI) -Headers @{
				Authorization = 'BEARER ' + $AccessToken
			} -ContentType 'application/json' -Body $xBody -ErrorAction SilentlyContinue
		} catch {
			Write-Error -Message ('Cannot access the API. Web request return code is: ' + $_.Exception.Response.StatusCode + "`n" + $_.Exception.Response.StatusDescription)
			break
		}

		switch ($webRequest.StatusCode) {
			200
			{
				if (!$BinaryMode) {
					$responseObject = (ConvertFrom-Json -InputObject $webRequest.Content)
				}

				return $responseObject
			}
			201
			{
				Write-Debug -Message ('Success: ' + $webRequest.StatusCode + ' - ' + $webRequest.StatusDescription)

				if (!$BinaryMode) {
					$responseObject = (ConvertFrom-Json -InputObject $webRequest.Content)
				}

				return $responseObject
			}
			204
			{
				Write-Debug -Message ('Success: ' + $webRequest.StatusCode + ' - ' + $webRequest.StatusDescription + ' (item deleted)')

				$responseObject = '0'
				return $responseObject
			}
			default {
				Write-Warning -Message ('Cannot access the API. Web request return code is: ' + $webRequest.StatusCode + "`n" + $webRequest.StatusDescription)
			}
		}
	}
}

function Get-ODDrives {
	<#
			.SYNOPSIS
			Get user's drives

			.DESCRIPTION
			Get user's drives

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.EXAMPLE
			PS C:\> Get-ODDrives -AccessToken $AuthToken

			Description
			-----------
			List all OneDrives available for your account (there is normally only one)

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken
	)

	PROCESS {
		$responseObject = (Get-ODWebContent -AccessToken $AccessToken -Method GET -rURI '/drives')
	}

	END {
		Write-Output -InputObject $responseObject.Value
	}
}

function Format-ODPathorIDString {
	<#
			.SYNOPSIS
			Formats a given path into an expected uri format

			.DESCRIPTION
			Formats a given path like '/myFolder/mySubfolder/myFile' into an expected uri format

			.PARAMETER Path
			Specifies the path of an element. If it is not given, the path is "/"

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.PARAMETER ElementID
			Specifies the id of an element. If Path and ElementID are given, the ElementID is used with a warning

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[string]$Path = '',
		[string]$DriveID = '',
		[string]$ElementID = ''
	)

	PROCESS {
		if (!$ElementID -eq '') {
			# Use ElementID parameters
			if (!$Path -eq '') { Write-Debug -Message ('Warning: Path and ElementID parameters are set. Only ElementID is used!') }
			return '/drive/items/' + $ElementID
		} else {
			# Use Path parameter
			# remove substring starts with "?"
			if ($Path.Contains('?')) { $Path = $Path.Substring(1, $Path.indexof('?') - 1) }

			# replace "\" with "/"
			$Path = $Path.Replace('\', '/')

			# filter possible string at the end "/children" (case insensitive)
			$Path = $Path + '/'
			$Path = $Path -replace '/children/', ''

			# encoding of URL parts
			$tmpString = ''
			foreach ($Sub in $Path.Split('/')) { $tmpString += [Web.HttpUtility]::UrlEncode($Sub) + '/' }
			$Path = $tmpString

			# remove last "/" if exist
			$Path = $Path.TrimEnd('/')

			# insert drive part of URL
			if ($DriveID -eq '') {
				# Default drive
				$Path = '/drive/root:' + $Path + ':'
			} else {
				# Named drive
				$Path = '/drives/' + $DriveID + '/root:' + $Path + ':'
			}

			return $Path
		}
	}
}

function Get-ODItemProperty {
	<#
			.SYNOPSIS
			Get the properties of an item

			.DESCRIPTION
			Get the properties of an item (file or folder)

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER Path
			Specifies the path to the element/item. If not given, the properties of your default root drive are listed

			.PARAMETER ElementID
			Specifies the id of the element/item. If Path and ElementID are given, the ElementID is used with a warning

			.PARAMETER SelectProperties
			Specifies a comma separated list of the properties to be returned for file and folder objects (case sensitive). If not set, name, size, lastModifiedDateTime and id are used. (See https://dev.onedrive.com/odata/optional-query-parameters.htm).
			If you use -SelectProperties "", all properties are listed. Warning: A complex "content.downloadUrl" is listed/generated for download files without authentication for several hours

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.EXAMPLE
			PS C:\> Get-ODItemProperty -AccessToken $AuthToken -Path "/Data/documents/2016/AzureML with PowerShell.docx"

			Description
			-----------
			Get the default set of metadata for a file or folder (name, size, lastModifiedDateTime, id)

			.EXAMPLE
			PS C:\> Get-ODItemProperty -AccessToken $AuthToken -ElementID 8BADCFF017EAA324!12169 -SelectProperties ""

			Description
			-----------
			Get all metadata of a file or folder by element id ("" select all properties)

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[string]$AccessToken,
		[string]$Path = '/',
		[string]$ElementID = '',
		[string]$SelectProperties = 'name,size,lastModifiedDateTime,id',
		[string]$DriveID = ''
	)

	PROCESS {
		$GetODItemProperty = (Get-ODChildItems -AccessToken $AccessToken -Path $Path -ElementID $ElementID -SelectProperties $SelectProperties -DriveID $DriveID -ItemPropertyMode)
	}

	END {
		Write-Output -InputObject $GetODItemProperty
	}
}

function Get-ODChildItems {
	<#
			.SYNOPSIS
			Get child items of a path. Return count is not limited.

			.DESCRIPTION
			Get child items of a path. Return count is not limited.

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER Path
			Specifies the path of elements to be listed. If not given, the path is "/"

			.PARAMETER ElementID
			Specifies the id of an element. If Path and ElementID are given, the ElementID is used with a warning

			.PARAMETER SelectProperties
			Specifies a comma separated list of the properties to be returned for file and folder objects (case sensitive). If not set, name, size, lastModifiedDateTime and id are used. (See https://dev.onedrive.com/odata/optional-query-parameters.htm).
			If you use -SelectProperties "", all properties are listed. Warning: A complex "content.downloadUrl" is listed/generated for download files without authentication for several hours

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.PARAMETER ItemPropertyMode
			A description of the ItemPropertyMode parameter.

			.PARAMETER SearchText
			A description of the SearchText parameter.

			.EXAMPLE
			PS C:\> Get-ODChildItems -AccessToken $AuthToken -Path "/" | ft

			Description
			-----------
			Lists files and folders in your OneDrives root folder and displays name, size, lastModifiedDateTime, id and folder property as a table

			.EXAMPLE
			PS C:\> Get-ODChildItems -AccessToken $AuthToken -Path "/" -SelectProperties ""

			Description
			-----------
			Lists files and folders in your OneDrives root folder and displays all properties

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[string]$AccessToken,
		[string]$Path = '/',
		[string]$ElementID = '',
		[string]$SelectProperties = 'name,size,lastModifiedDateTime,id',
		[string]$DriveID = '',
		[switch]$ItemPropertyMode,
		[string]$SearchText
	)

	BEGIN {
		$ODRootURI = 'https://api.onedrive.com/v1.0'
	}

	PROCESS {
		if ($Path.Contains("$skiptoken=")) {
			# Recurse mode of odata.nextLink detection
			Write-Debug -Message ('Recurce call')
			$rURI = $Path
		} else {
			$rURI = (Format-ODPathorIDString -path $Path -ElementID $ElementID -DriveID $DriveID)
			$SelectProperties = $SelectProperties.Replace(' ', '')
			if ($SelectProperties -eq '') {
				$opt = ''
			} else {
				$SelectProperties = $SelectProperties.Replace(' ', '') + ',folder'
				$opt = '?select=' + $SelectProperties
			}
			if ($ItemPropertyMode) {
				# item property mode
				$rURI = $rURI + $opt
			} else {
				if (!$SearchText -eq '') {
					# Search mode
					$opt = '/view.search?q=' + $SearchText + '&select=' + $SelectProperties
					$rURI = $rURI + $opt
				} else {
					# child item mode
					$rURI = $rURI + '/children' + $opt
				}
			}
		}

		Write-Debug -Message ('Accessing API with GET to ' + $rURI)

		$responseObject = (Get-ODWebContent -AccessToken $AccessToken -Method GET -rURI $rURI)

		if ($responseObject.PSobject.Properties.name -match '@odata.nextLink') {
			Write-Debug -Message ('Getting more elements form service (@odata.nextLink is present)')

			Get-ODChildItems -AccessToken $AccessToken -SelectProperties $SelectProperties -Path $responseObject.'@odata.nextLink'.Replace($ODRootURI, '')
		}

		if ($ItemPropertyMode) {
			# item property mode
			return $responseObject
		} else {
			# child item mode
			return $responseObject.value
		}
	}
}

function Search-ODItems {
	<#
			.SYNOPSIS
			Search for items starting from Path or ElementID

			.DESCRIPTION
			Search for items starting from Path or ElementID

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER SearchText
			Specifies search string

			.PARAMETER Path
			Specifies the path of the folder to start the search. If not given, the path is "/"

			.PARAMETER ElementID
			Specifies the element id of the folder to start the search. If Path and ElementID are given, the ElementID is used with a warning

			.PARAMETER SelectProperties
			Specifies a comma separated list of the properties to be returned for file and folder objects (case sensitive). If not set, name, size, lastModifiedDateTime and id are used. (See https://dev.onedrive.com/odata/optional-query-parameters.htm).
			If you use -SelectProperties "", all properties are listed. Warning: A complex "content.downloadUrl" is listed/generated for download files without authentication for several hours

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.EXAMPLE
			PS C:\> Search-ODItems -AccessToken $AuthToken -Path "/My pictures" -SearchText "FolderA"

			Description
			-----------
			Search for items in a sub folder recursively. Take a look at OneDrives API documentation to see how search (preview) works (file and folder names, in files, …)

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[Parameter(Mandatory,
		HelpMessage = 'Specifies search string')]
		[ValidateNotNullOrEmpty()]
		[string]$SearchText,
		[string]$Path = '/',
		[string]$ElementID = '',
		[string]$SelectProperties = 'name,size,lastModifiedDateTime,id',
		[string]$DriveID = ''
	)

	PROCESS {
		return Get-ODChildItems -AccessToken $AccessToken -Path $Path -ElementID $ElementID -SelectProperties $SelectProperties -DriveID $DriveID -SearchText $SearchText
	}
}

function New-ODFolder {
	<#
			.SYNOPSIS
			Create a new folder

			.DESCRIPTION
			Create a new folder in OneDrive

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER FolderName
			Name of the new folder

			.PARAMETER Path
			Specifies the parent path for the new folder. If not given, the path is "/"

			.PARAMETER ElementID
			Specifies the element id for the new folder. If Path and ElementID are given, the ElementID is used with a warning

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.EXAMPLE
			PS C:\> New-ODFolder -AccessToken $AuthToken -Path "/data/documents" -FolderName "2016"

			Description
			-----------
			Creates a new folder "2016" under "/data/documents"

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[Parameter(Mandatory,
		HelpMessage = 'Name of the new folder')]
		[ValidateNotNullOrEmpty()]
		[string]$FolderName,
		[string]$Path = '/',
		[string]$ElementID = '',
		[string]$DriveID = ''
	)

	BEGIN {
		$rURI = (Format-ODPathorIDString -path $Path -ElementID $ElementID -DriveID $DriveID)
		$rURI = $rURI + '/children'
	}

	PROCESS {
		$NewODFolder = (Get-ODWebContent -AccessToken $AccessToken -Method POST -rURI $rURI -Body ('{"name": "' + $FolderName + '","folder": { },"@name.conflictBehavior": "fail"}'))
	}

	END {
		Write-Output -InputObject $NewODFolder
	}
}

function Remove-ODItem {
	<#
			.SYNOPSIS
			Delete an item

			.DESCRIPTION
			Delete an item (folder or file)

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER Path
			Specifies the path of the item to be deleted

			.PARAMETER ElementID
			Specifies the element id of the item to be deleted

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.EXAMPLE
			PS C:\> Remove-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016/Azure-big-picture.old.docx"

			Description
			-----------
			Deletes an item

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[Parameter(Mandatory,
		HelpMessage = 'Specifies the path of the item to be deleted')]
		[ValidateNotNullOrEmpty()]
		[string]$Path,
		[Parameter(Mandatory,
		HelpMessage = 'Specifies the element id of the item to be deleted')]
		[ValidateNotNullOrEmpty()]
		[string]$ElementID,
		[string]$DriveID = ''
	)

	PROCESS {
		if (($ElementID + $Path) -eq '') {
			debug-error('Path nor ElementID is set')
		} else {
			$rURI = (Format-ODPathorIDString -path $Path -ElementID $ElementID -DriveID $DriveID)
			$RemoveODItem = (Get-ODWebContent -AccessToken $AccessToken -Method DELETE -rURI $rURI)
		}
	}

	END {
		Write-Output -InputObject $RemoveODItem
	}
}

function Get-ODItem {
	<#
			.SYNOPSIS
			Download an item/file.

			.DESCRIPTION
			Download an item/file.
			Warning: A local file will be overwritten

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER Path
			Specifies the path of the file to download.

			.PARAMETER ElementID
			Specifies the element id of the file to download. If Path and ElementID are given, the ElementID is used with a warning

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.PARAMETER LocalPath
			Save file to path (if not given, the current local path is used)

			.PARAMETER LocalFileName
			Local filename. If not given, the file name of OneDrive is used

			.EXAMPLE
			PS C:\> Get-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016/Powershell array custom objects.docx"

			Description
			-----------
			Downloads a file from OneDrive

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[string]$Path = '',
		[string]$ElementID = '',
		[string]$DriveID = '',
		[string]$LocalPath = '',
		[string]$LocalFileName
	)

	PROCESS {
		if (($ElementID + $Path) -eq '') {
			debug-error('Path nor ElementID is set')
		} else {
			$Download = (Get-ODItemProperty -AccessToken $AccessToken -Path $Path -ElementID $ElementID -DriveID $DriveID -SelectProperties 'name,@content.downloadUrl')
			if ($LocalPath -eq '') {
				$LocalPath = (Get-Location)
			}

			if ($LocalFileName -eq '') {
				$SaveTo = $LocalPath.TrimEnd('\') + '\' + $Download.name
			} else {
				$SaveTo = $LocalPath.TrimEnd('\') + '\' + $LocalFileName
			}

			try {
				[Net.WebClient]::WebClient
				$client = (New-Object -TypeName System.Net.WebClient)
				$client.DownloadFile($Download.'@content.downloadUrl', $SaveTo)

				Write-Verbose -Message ('Download complete')

				return 0
			} catch {
				Write-Error -Message ('Download error: ' + $_.Exception.Response.StatusCode + "`n" + $_.Exception.Response.StatusDescription)
				return -1
			}
		}
	}
}

function Add-ODItem {
	<#
			.SYNOPSIS
			Upload an item/file.

			.DESCRIPTION
			Upload an item/file.
			Warning: An existing file will be overwritten

			.PARAMETER AccessToken
			A valid access token for bearer authorization

			.PARAMETER Path
			Specifies the path for the upload folder. If not given, the path is "/"

			.PARAMETER ElementID
			Specifies the element id for the upload folder. If Path and ElementID are given, the ElementID is used with a warning

			.PARAMETER DriveID
			Specifies the OneDrive drive id. If not set, the default drive is used

			.PARAMETER LocalFile
			Path and file of the local file to be uploaded

			.EXAMPLE
			PS C:\> Add-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016" -LocalFile "AzureML with PowerShell.docx"

			Description
			-----------
			Upload a file to OneDrive "/data/documents/2016"

			.NOTES
			Original author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer

			.LINK
			https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line
	#>

	param
	(
		[Parameter(Mandatory,
		HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[string]$Path = '/',
		[string]$ElementID = '',
		[string]$DriveID = '',
		[Parameter(Mandatory,
		HelpMessage = 'Path and file of the local file to be uploaded')]
		[ValidateNotNullOrEmpty()]
		[string]$LocalFile
	)

	BEGIN {
		$rURI = (Format-ODPathorIDString -path $Path -ElementID $ElementID -DriveID $DriveID)
	}

	PROCESS {
		try {
			$ODRootURI = 'https://api.onedrive.com/v1.0'
			$rURI = (($ODRootURI + $rURI).TrimEnd(':') + '/' + [IO.Path]::GetFileName($LocalFile) + ':/content').Replace('/root/', '/root:/')
			return $webRequest = Invoke-WebRequest -Method PUT -InFile $LocalFile -Uri $rURI -Headers @{
				Authorization = 'BEARER ' + $AccessToken
			} -ContentType 'multipart/form-data' -ErrorAction SilentlyContinue
		} catch {
			Write-Error -Message ('Upload error: ' + $_.Exception.Response.StatusCode + "`n" + $_.Exception.Response.StatusDescription)
			return -1
		}
	}
}

# SIG # Begin signature block
# MIIZXgYJKoZIhvcNAQcCoIIZTzCCGUsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUq7IWs1/xgCNpFt6tjZmUunT9
# VHygghPvMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0
# MTMxMDAwMDBaFw0yODAxMjgxMjAwMDBaMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlO9l
# +LVXn6BTDTQG6wkft0cYasvwW+T/J6U00feJGr+esc0SQW5m1IGghYtkWkYvmaCN
# d7HivFzdItdqZ9C76Mp03otPDbBS5ZBb60cO8eefnAuQZT4XljBFcm05oRc2yrmg
# jBtPCBn2gTGtYRakYua0QJ7D/PuV9vu1LpWBmODvxevYAll4d/eq41JrUJEpxfz3
# zZNl0mBhIvIG+zLdFlH6Dv2KMPAXCae78wSuq5DnbN96qfTvxGInX2+ZbTh0qhGL
# 2t/HFEzphbLswn1KJo/nVrqm4M+SU4B09APsaLJgvIQgAIMboe60dAXBKY5i0Eex
# +vBTzBj5Ljv5cH60JQIDAQABo4HlMIHiMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBRG2D7/3OO+/4Pm9IWbsN1q1hSpwTBHBgNV
# HSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFs
# c2lnbi5jb20vcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2Ny
# bC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRge2YaRQ2XyolQ
# L30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEATl5WkB5GtNlJMfO7FzkoG8IW
# 3f1B3AkFBJtvsqKa1pkuQJkAVbXqP6UgdtOGNNQXzFU6x4Lu76i6vNgGnxVQ380W
# e1I6AtcZGv2v8Hhc4EvFGN86JB7arLipWAQCBzDbsBJe/jG+8ARI9PBw+DpeVoPP
# PfsNvPTF7ZedudTbpSeE4zibi6c1hkQgpDttpGoLoYP9KOva7yj2zIhd+wo7AKvg
# IeviLzVsD440RZfroveZMzV+y5qKu0VN5z+fwtmK+mWybsd+Zf/okuEsMaL3sCc2
# SI8mbzvuTXYfecPlf5Y1vC0OzAGwjn//UYCAp5LUs0RGZIyHTxZjBzFLY7Df8zCC
# BJ8wggOHoAMCAQICEhEh1pmnZJc+8fhCfukZzFNBFDANBgkqhkiG9w0BAQUFADBS
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEoMCYGA1UE
# AxMfR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBHMjAeFw0xNjA1MjQwMDAw
# MDBaFw0yNzA2MjQwMDAwMDBaMGAxCzAJBgNVBAYTAlNHMR8wHQYDVQQKExZHTU8g
# R2xvYmFsU2lnbiBQdGUgTHRkMTAwLgYDVQQDEydHbG9iYWxTaWduIFRTQSBmb3Ig
# TVMgQXV0aGVudGljb2RlIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCwF66i07YEMFYeWA+x7VWk1lTL2PZzOuxdXqsl/Tal+oTDYUDFRrVZUjtC
# oi5fE2IQqVvmc9aSJbF9I+MGs4c6DkPw1wCJU6IRMVIobl1AcjzyCXenSZKX1GyQ
# oHan/bjcs53yB2AsT1iYAGvTFVTg+t3/gCxfGKaY/9Sr7KFFWbIub2Jd4NkZrItX
# nKgmK9kXpRDSRwgacCwzi39ogCq1oV1r3Y0CAikDqnw3u7spTj1Tk7Om+o/SWJMV
# TLktq4CjoyX7r/cIZLB6RA9cENdfYTeqTmvT0lMlnYJz+iz5crCpGTkqUPqp0Dw6
# yuhb7/VfUfT5CtmXNd5qheYjBEKvAgMBAAGjggFfMIIBWzAOBgNVHQ8BAf8EBAMC
# B4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAyAR4wNDAyBggrBgEFBQcCARYmaHR0cHM6
# Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0TBAIwADAWBgNV
# HSUBAf8EDDAKBggrBgEFBQcDCDBCBgNVHR8EOzA5MDegNaAzhjFodHRwOi8vY3Js
# Lmdsb2JhbHNpZ24uY29tL2dzL2dzdGltZXN0YW1waW5nZzIuY3JsMFQGCCsGAQUF
# BwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNv
# bS9jYWNlcnQvZ3N0aW1lc3RhbXBpbmdnMi5jcnQwHQYDVR0OBBYEFNSihEo4Whh/
# uk8wUL2d1XqH1gn3MB8GA1UdIwQYMBaAFEbYPv/c477/g+b0hZuw3WrWFKnBMA0G
# CSqGSIb3DQEBBQUAA4IBAQCPqRqRbQSmNyAOg5beI9Nrbh9u3WQ9aCEitfhHNmmO
# 4aVFxySiIrcpCcxUWq7GvM1jjrM9UEjltMyuzZKNniiLE0oRqr2j79OyNvy0oXK/
# bZdjeYxEvHAvfvO83YJTqxr26/ocl7y2N5ykHDC8q7wtRzbfkiAD6HHGWPZ1BZo0
# 8AtZWoJENKqA5C+E9kddlsm2ysqdt6a65FDT1De4uiAO0NOSKlvEWbuhbds8zkSd
# wTgqreONvc0JdxoQvmcKAjZkiLmzGybu555gxEaovGEzbM9OuZy5avCfN/61PU+a
# 003/3iCOTpem/Z8JvE3KGHbJsE2FUPKA0h0G9VgEB7EYMIIFTDCCBDSgAwIBAgIQ
# FtT3Ux2bGCdP8iZzNFGAXDANBgkqhkiG9w0BAQsFADB9MQswCQYDVQQGEwJHQjEb
# MBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRow
# GAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBD
# b2RlIFNpZ25pbmcgQ0EwHhcNMTUwNzE3MDAwMDAwWhcNMTgwNzE2MjM1OTU5WjCB
# kDELMAkGA1UEBhMCREUxDjAMBgNVBBEMBTM1NTc2MQ8wDQYDVQQIDAZIZXNzZW4x
# EDAOBgNVBAcMB0xpbWJ1cmcxGDAWBgNVBAkMD0JhaG5ob2ZzcGxhdHogMTEZMBcG
# A1UECgwQS3JlYXRpdlNpZ24gR21iSDEZMBcGA1UEAwwQS3JlYXRpdlNpZ24gR21i
# SDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK8jDmF0TO09qJndJ9eG
# Fqra1lf14NDhM8wIT8cFcZ/AX2XzrE6zb/8kE5sL4/dMhuTOp+SMt0tI/SON6BY3
# 208v/NlDI7fozAqHfmvPhLX6p/TtDkmSH1sD8AIyrTH9b27wDNX4rC914Ka4EBI8
# sGtZwZOQkwQdlV6gCBmadar+7YkVhAbIIkSazE9yyRTuffidmtHV49DHPr+ql4ji
# NJ/K27ZFZbwM6kGBlDBBSgLUKvufMY+XPUukpzdCaA0UzygGUdDfgy0htSSp8MR9
# Rnq4WML0t/fT0IZvmrxCrh7NXkQXACk2xtnkq0bXUIC6H0Zolnfl4fanvVYyvD88
# qIECAwEAAaOCAbIwggGuMB8GA1UdIwQYMBaAFCmRYP+KTfrr+aZquM/55ku9Sc4S
# MB0GA1UdDgQWBBSeVG4/9UvVjmv8STy4f7kGHucShjAOBgNVHQ8BAf8EBAMCB4Aw
# DAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzARBglghkgBhvhCAQEE
# BAMCBBAwRgYDVR0gBD8wPTA7BgwrBgEEAbIxAQIBAwIwKzApBggrBgEFBQcCARYd
# aHR0cHM6Ly9zZWN1cmUuY29tb2RvLm5ldC9DUFMwQwYDVR0fBDwwOjA4oDagNIYy
# aHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQ29kZVNpZ25pbmdDQS5j
# cmwwdAYIKwYBBQUHAQEEaDBmMD4GCCsGAQUFBzAChjJodHRwOi8vY3J0LmNvbW9k
# b2NhLmNvbS9DT01PRE9SU0FDb2RlU2lnbmluZ0NBLmNydDAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuY29tb2RvY2EuY29tMCMGA1UdEQQcMBqBGGhvY2h3YWxkQGty
# ZWF0aXZzaWduLm5ldDANBgkqhkiG9w0BAQsFAAOCAQEASSZkxKo3EyEk/qW0ZCs7
# CDDHKTx3UcqExigsaY0DRo9fbWgqWynItsqdwFkuQYJxzknqm2JMvwIK6BtfWc64
# WZhy0BtI3S3hxzYHxDjVDBLBy91kj/mddPjen60W+L66oNEXiBuIsOcJ9e7tH6Vn
# 9eFEUjuq5esoJM6FV+MIKv/jPFWMp5B6EtX4LDHEpYpLRVQnuxoc38mmd+NfjcD2
# /o/81bu6LmBFegHAaGDpThGf8Hk3NVy0GcpQ3trqmH6e3Cpm8Ut5UkoSONZdkYWw
# rzkmzFgJyoM2rnTMTh4ficxBQpB7Ikv4VEnrHRReihZ0zwN+HkXO1XEnd3hm+08j
# LzCCBeAwggPIoAMCAQICEC58h8wOk0pS/pT9HLfNNK8wDQYJKoZIhvcNAQEMBQAw
# gYUxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAO
# BgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMSswKQYD
# VQQDEyJDT01PRE8gUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTEzMDUw
# OTAwMDAwMFoXDTI4MDUwODIzNTk1OVowfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
# EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMR
# Q09NT0RPIENBIExpbWl0ZWQxIzAhBgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWdu
# aW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAppiQY3eRNH+K
# 0d3pZzER68we/TEds7liVz+TvFvjnx4kMhEna7xRkafPnp4ls1+BqBgPHR4gMA77
# YXuGCbPj/aJonRwsnb9y4+R1oOU1I47Jiu4aDGTH2EKhe7VSA0s6sI4jS0tj4CKU
# N3vVeZAKFBhRLOb+wRLwHD9hYQqMotz2wzCqzSgYdUjBeVoIzbuMVYz31HaQOjNG
# UHOYXPSFSmsPgN1e1r39qS/AJfX5eNeNXxDCRFU8kDwxRstwrgepCuOvwQFvkBoj
# 4l8428YIXUezg0HwLgA3FLkSqnmSUs2HD3vYYimkfjC9G7WMcrRI8uPoIfleTGJ5
# iwIGn3/VCwIDAQABo4IBUTCCAU0wHwYDVR0jBBgwFoAUu69+Aj36pvE8hI6t7jiY
# 7NkyMtQwHQYDVR0OBBYEFCmRYP+KTfrr+aZquM/55ku9Sc4SMA4GA1UdDwEB/wQE
# AwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEG
# A1UdIAQKMAgwBgYEVR0gADBMBgNVHR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLmNv
# bW9kb2NhLmNvbS9DT01PRE9SU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDBx
# BggrBgEFBQcBAQRlMGMwOwYIKwYBBQUHMAKGL2h0dHA6Ly9jcnQuY29tb2RvY2Eu
# Y29tL0NPTU9ET1JTQUFkZFRydXN0Q0EuY3J0MCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5jb21vZG9jYS5jb20wDQYJKoZIhvcNAQEMBQADggIBAAI/AjnD7vjKO4ne
# DG1NsfFOkk+vwjgsBMzFYxGrCWOvq6LXAj/MbxnDPdYaCJT/JdipiKcrEBrgm7EH
# IhpRHDrU4ekJv+YkdK8eexYxbiPvVFEtUgLidQgFTPG3UeFRAMaH9mzuEER2V2rx
# 31hrIapJ1Hw3Tr3/tnVUQBg2V2cRzU8C5P7z2vx1F9vst/dlCSNJH0NXg+p+IHdh
# yE3yu2VNqPeFRQevemknZZApQIvfezpROYyoH3B5rW1CIKLPDGwDjEzNcweU51qO
# OgS6oqF8H8tjOhWn1BUbp1JHMqn0v2RH0aofU04yMHPCb7d4gp1c/0a7ayIdiAv4
# G6o0pvyM9d1/ZYyMMVcx0DbsR6HPy4uo7xwYWMUGd8pLm1GvTAhKeo/io1Lijo7M
# JuSy2OU4wqjtxoGcNWupWGFKCpe0S0K2VZ2+medwbVn4bSoMfxlgXwyaiGwwrFIJ
# kBYb/yud29AgyonqKH4yjhnfe0gzHtdl+K7J+IMUk3Z9ZNCOzr41ff9yMU2fnr0e
# bC+ojwwGUPuMJ7N2yfTm18M04oyHIYZh/r9VdOEhdwMKaGy75Mmp5s9ZJet87EUO
# eWZo6CLNuO+YhU2WETwJitB/vCgoE/tqylSNklzNwmWYBp7OSFvUtTeTRkF8B93P
# +kPvumdh/31J4LswfVyA4+YWOUunMYIE2TCCBNUCAQEwgZEwfTELMAkGA1UEBhMC
# R0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9y
# ZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxIzAhBgNVBAMTGkNPTU9ETyBS
# U0EgQ29kZSBTaWduaW5nIENBAhAW1PdTHZsYJ0/yJnM0UYBcMAkGBSsOAwIaBQCg
# eDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEE
# AYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJ
# BDEWBBQ4rVn1FOXIDzcjKn7Or+g3Fx8dfjANBgkqhkiG9w0BAQEFAASCAQAocSS4
# DRhMNodVMIbZOeSBQQFxNlRLzmjSxlX2X39zawrXo3XBRWv2BVdwTmNHCXDmXmsG
# fenyC2oLpG9YIHKe/OBhpz5RCWRuKlcDVtZRXDckOkZXcjYgq8h+41+qB0aD4TQz
# QTYaMQS0ZuN5+WEgU2JKpEENLbGP7FQKZfXPnjLzh/D/lwnQe55L3YS1XrdY0pDz
# yg3aHH6qtlA9YvSbYvwbjiPOb7HRQPcnSNX/iO+lVMbUCJouPg3Kldr9tMvgv67g
# FBE621guxxxUdu9PX0iLf12RsTRIkzQS2kGjRdKALOzSjuWGQVQRDuM0v8iRyw5S
# U/lXk76R+hqzvZLpoYICojCCAp4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMT
# H0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh1pmnZJc+8fhCfukZ
# zFNBFDAJBgUrDgMCGgUAoIH9MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE2MDgyMjEwMzQxMlowIwYJKoZIhvcNAQkEMRYEFOTAJuHp
# j1aq+Gohp2t2WzGX2XsbMIGdBgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUY7gv
# q2H1g5CWlQULACScUCkz7HkwbDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoT
# EEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1w
# aW5nIENBIC0gRzICEhEh1pmnZJc+8fhCfukZzFNBFDANBgkqhkiG9w0BAQEFAASC
# AQA2NqZpCJYi+3Rg6xsiYdJITgH25It0A8zkAi/BjjlrvdY9n/LEFK6HasUiPU82
# imFoKGx4qUPjPkWEFVxKOn/F+WyhHxGwjSVnzwEHgxgEHRHbW4SRJOsz5KFNqGnv
# 5dtNq78sQDO1ASivUZjFJ8f0TlD4N+AzSVa9fYrxfD1DNM4XXwkkS1JCx/fywaSl
# lbISBsjynQ0AJ8jlR4GOUCP0FKDvfjNECMKn2z5PCYl4/mCo5E8W8lbu/xcj1PRN
# hL5hODcFZX4bfxjFtDnL+n3zI1J9WuDPjTt3YoUjZ9kANNce2XLgr2VsdFDnp2r+
# AZDGEyslgSpzZ9qbNUq1qoai
# SIG # End signature block
