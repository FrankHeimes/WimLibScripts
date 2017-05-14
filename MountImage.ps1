# Mount a backup image, Version 1.1.17197.0
#
# Original work Copyright (c) 2017 Dr. Frank Heimes (twitter.com/DrFGHde, www.facebook.com/dr.frank.heimes)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

param([switch]$elevated)
if (!(New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
  if ($elevated) { Read-Host 'Failed to elevate' }
  else { Start-Process powershell.exe -Verb RunAs -ArgumentList ('–ExecutionPolicy Unrestricted -noprofile -nologo -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition)) }
  exit
}


# ---------------------- Configuration ----------------------

# Whether or not to run interactively.
#  W A R N I N G :  When setting this to $false, make sure all remaining parameters are correct!
$Global:runInteractive = $true

# Whether or not to use file dialog boxes for more convenient file selection.
$Global:useFileDialogs = $true

# The directory to mount the image to. This must NOT exist.
$Global:mountFolder = 'C:\Mounted'

# The source file to take the image from.
$Global:wimFile = 'M:\Backup\System.wim'

# The image index in the WIM file to mount. Use highest available if possible
$Global:imageIndex = 9999

# Whether or not to mount the image read-only.
$Global:readOnly = $true

# -----------------------------------------------------------


# Call wimlib-imagex with the specified arguments and throw on failure
function ImageX([string[]]$wimlibArgs)
{
	if (!(Test-Path '.\wimlib-imagex.exe'))
		{ Throw "wimlib-imagex.exe not found. Please download from http://wimlib.net" }

	''
	$errorCount = $Error.Count
	.\wimlib-imagex.exe $wimlibArgs
	if (($LastExitCode -ne 0) -or ($Error.Count -gt $errorCount))
		{ Throw "wimlib-imagex.exe failed" }
}

# Moves the window that executes this script to column 40 at the top of the screen
function Move-WindowToTop
{
	$Global:Win32SetWindowPos = Add-Type –memberDefinition '[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);' `
	-name 'Win32SetWindowPos' -namespace Win32Functions –passThru
	[void]$Global:Win32SetWindowPos::SetWindowPos(((Get-Process -Id $pid).MainWindowHandle), 0, 40, 0, 0, 0, 0x4255)
}

# Make the host window almost the height of the screen and place it at the top
function Configure-Host
{
	$MySize = $host.UI.RawUI.WindowSize
	$MySize.Height = $host.UI.RawUI.MaxPhysicalWindowSize.Height - 2
	$host.UI.RawUI.set_windowSize($MySize)
	Move-WindowToTop
}

# Explain what the script does and let user confirm execution
function Confirm-Execution
{
	"`n   M O U N T   I M A G E`n"
	"This script will perform the following tasks:"
	"---------------------------------------------"
	" 1. Let you choose the name of a WIM file."
	" 2. Let you choose an image from the WIM file to mount."
	"    Note: SOLID images are not supported."
	" 3. Query whether or not to mount the image read-only."
	" 4. Query the name of a mount folder."
	" 5. Create the mount folder."
	" 6. Mount the seleted image into that folder."
	if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# Let user select or enter a WIM file.
function Get-WIMFilename
{
	$initialFolder = Split-Path -Parent $wimFile
	"`nWIM files in ${initialFolder}:"
	"--------------------------------"
	if (Test-Path $initialFolder)
		{ Get-ChildItem -Path $initialFolder '*.wim' | Format-Table -Property FullName -AutoSize }
	$answer = Read-Host "Enter the full path of an existing backup file ($wimFile)"
	if (![string]::IsNullOrEmpty($answer)) { $Global:wimFile = $answer }
}

# Let user select a WIM file. Aborts script if user hits 'Abort'
function Get-WIMFilenameDlg
{
	[void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
	$dialog = New-Object System.Windows.Forms.OpenFileDialog
	$dialog.initialDirectory = Split-Path -Parent $wimFile
	$dialog.Title = "Select an existing backup file"
	$initialFilename = [IO.Path]::GetFileNameWithoutExtension($wimFile)
	$dialog.FileName = $initialFilename
	$dialog.filter = "WIM (*.wim)| *.wim"
	[void]$dialog.ShowDialog()
	if ($initialFilename -eq $dialog.FileName) { Exit }
	$Global:wimFile = $dialog.FileName
}

# Determine highest image index in the WIM file
function Get-MaxImageIndex
{
	if (!(ImageX info, $wimFile | ?{ $_ -match 'Image Count:\s*(\d+)' }))
		{ Throw "Could not extract the number of images in file '$wimFile'" }

	$Global:imageIndex = ([int]$Matches[1], $imageIndex | Measure -Min).Minimum
}

# Let user select one of the images in the WIM file
function Select-ImageIndex
{
	ImageX info, $wimFile | ?{ $_ -notmatch`
	'(Architecture|Attributes|Boot Index|Build|Chunk Size|Compression|Default Language|Description|Display (Description|Name)|Edition ID|Flags|GUID|HAL|Hard Link Bytes|Installation Type|Languages|Modification Time|Part Number|Product (Suite|Type)|Service Pack Level|System Root|Version|WIMBoot compatible):' } | `
	%{ if ($_ -match '(Total Bytes:\s*)(\d+)') {
		  if ([int64]$Matches[2] -ge 1GB) { $divider = 1GB ; $unit = " GB" } else { $divider = 1MB ; $unit = " MB" }
		  $Matches[1] + [Math]::Ceiling($Matches[2] / $divider).ToString("N0") + $unit
	   } else { $_ }}
	$answer = Read-Host "`nEnter 1-based 'Index' of the image to mount ($imageIndex)"
	if (![string]::IsNullOrEmpty($answer)) { $Global:imageIndex = [int]$answer }
}

# Query whether or not to mount the image read-only
function Query-ReadOnly
{
	$Global:readOnly = ((Read-Host "`nDo you intend to modify the mounted contents and update`nthe image in '$wimFile' (Y/N)?") -ne 'y')
}

# Let user confirm all selected parameters before commencing operation. Abort script if user does not confirm.
function Confirm-Parameters
{
	if ($readOnly) { $access = 'read-only' } else  { $access = 'writable' }
	"`nImage $imageIndex from '$wimFile' will be mounted into folder '$mountFolder' and will be $access ..."
	if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# Create the mount folder. Reject existing folders to avoid data corruption.
function Create-Folder
{
	if (Test-Path $mountFolder)
		{ Throw "Folder '$mountFolder' already exists. Please specify a non-existing folder." }

	[void](New-Item -Type Directory $mountFolder)
}

# Mount the image into the newly created folder
function Mount-Volume
{
	"`nMounting image $imageIndex from '$wimFile' to mount folder '$mountFolder' ..."
	"This may take a few minutes ..."
	$dismArgs = @{ImagePath = $wimFile; Index = $imageIndex; Path = $mountFolder; Optimize = $true; CheckIntegrity = $true}
	if ($readOnly) { $dismArgs['ReadOnly'] = $true }
	Import-Module DISM
	Mount-WindowsImage @dismArgs
	"`nNote: The image is mounted sparsly, i.e. folders and files are only mounted if you access them."
	"        As a side effect, the total number of files and folders reported by Windows explorer may not be correct."
}

# Explain script, collect imputs from user and perform mount operation
function Run-MountImage
{
	Try {
		if ($runInteractive) {
			Configure-Host
			Confirm-Execution
			if ($useFileDialogs) { Get-WIMFilenameDlg } else { Get-WIMFilename }
		}
		Get-MaxImageIndex
		if ($runInteractive) {
			Select-ImageIndex
			Query-ReadOnly
			Confirm-Parameters
		}
		Create-Folder
		Mount-Volume
		if ($runInteractive)
			{ Read-Host "`nDone. Press Enter to finish" }
	}
	Catch {
		Write-Error $_
		if ($runInteractive)
			{ Read-Host "`nPress Enter to abort" }
	}
}

Set-Location ($MyInvocation.InvocationName | Split-Path -Parent)
Run-MountImage
