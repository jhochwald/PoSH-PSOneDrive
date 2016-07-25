# PoSH-PSOneDrive

## Table Of Contents
<!-- MarkdownTOC depth=3 autolink=true autoanchor=true bracket=round -->

- [SYNOPSIS](#synopsis)
- [DESCRIPTION](#description)
- [Changes](#changes)
	- [Why the Fork](#why-the-fork)
- [Plan](#plan)
- [Copyright](#copyright)
- [Source](#source)
	- [PowerShell Galery](#powershell-galery)

<!-- /MarkdownTOC -->

<a name="synopsis"></a>
## SYNOPSIS
Provides function to access OneDrive with PowerShell.

<a name="description"></a>
## DESCRIPTION
You can list directories, get metadata of files and folder, create folders, delete folders and file and for sure: Upload and download files.

This module uses the OneDrive web api and you need a free id to use this module von Microsoft (https://dev.onedrive.com/app-registration.htm).

At this time there are some functions missing, like rename files.

Please write Marcel Meurer a mail if you find some errors or if you have a request. You will find his address in the Code ;-)

<a name="changes"></a>
## Changes
I just did some refactoring for now.

<a name="why-the-fork"></a>
### Why the Fork
Found the Module on [PowerShell Galery](https://www.powershellgallery.com/packages/OneDrive/0.9.2) and I want to try if I can get rid of the Web-Form for the Login.

<a name="plan"></a>
## Plan
* Add some Pester Tests (started)
* Get rid of the Web-Form (That one is a Challenge)

<a name="copyright"></a>
## Copyright
(c) 2016 Marcel Meurer - sepago GmbH

<a name="source"></a>
## Source
https://www.sepago.com/blog/2016/02/21/Use-PowerShell-Module-OneDrive-from-PowerShellGallery-command-line

<a name="powershell-galery"></a>
### PowerShell Galery
https://www.powershellgallery.com/packages/OneDrive/0.9.2
