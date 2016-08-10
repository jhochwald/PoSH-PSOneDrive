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
		[Parameter(Mandatory = $true,
				   HelpMessage = 'The ClientID of the APP')]
		[ValidateNotNullOrEmpty()]
		[string]$ClientID,
		[string]$Scope = 'onedrive.readwrite',
		[string]$RedirectURI = 'https://login.live.com/oauth20_desktop.srf'
	)

	BEGIN {
		$null = [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
		$null = [Reflection.Assembly]::LoadWithPartialName('System.Drawing')
		$null = [Reflection.Assembly]::LoadWithPartialName('System.Web')

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
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
				   HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
				   HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
				   HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[Parameter(Mandatory = $true,
				   HelpMessage = 'Specifies the path of the item to be deleted')]
		[ValidateNotNullOrEmpty()]
		[string]$Path,
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
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
		[Parameter(Mandatory = $true,
				   HelpMessage = 'A valid access token for bearer authorization')]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
		[string]$Path = '/',
		[string]$ElementID = '',
		[string]$DriveID = '',
		[Parameter(Mandatory = $true,
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
