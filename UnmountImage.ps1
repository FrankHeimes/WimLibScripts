# Unmount a backup image, Version 1.1.17197.0
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

# The directory to unmount. This must have been created using MountImage.ps1
$Global:mountFolder = 'C:\Mounted'

# Whether or not to apply changes in the mount folder to the image.
$Global:updateImage = $false

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
	"`n   U N M O U N T   I M A G E`n"
	"This script will perform the following tasks:"
	"---------------------------------------------"
	" 1. Let you choose the mount folder."
	" 2. Query whether or not to update the mounted image."
	" 3. Unmount the seleted image from that folder."
	" 4. Remove the mount folder."
	if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# Let user select or enter the mount folder.
function Get-MountFolder
{
	$answer = Read-Host "Enter the full path of an existing backup file ($mountFolder)"
	if (![string]::IsNullOrEmpty($answer)) { $Global:mountFolder = $answer }
}

# Let user select the mount folder. Abort script if user hits 'Cancel'
function Get-MountFolderDlg
{
	[void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
	$dialog.Description = "Select an existing mount folder"
	$dialog.SelectedPath = $mountFolder
	$dialog.ShowNewFolderButton = $false
	if ($dialog.ShowDialog() -eq 'Cancel') { Exit }
	$Global:mountFolder = $dialog.SelectedPath
}

# Query whether or not to update the image
function Query-UpdateImage
{
	$Global:updateImage = ((Read-Host "`nApply all changes in '$mountFolder' to the associated image (Y/N)?") -eq 'y')
}

# Let user confirm all selected parameters before commencing operation. Abort script if user does not confirm.
function Confirm-Parameters
{
	if ($updateImage) { $change = '' } else  { $change = ' NOT' }
	"`nPlease make sure that no application (including Windows Explorer) has any open file handles into that folder."
	"`nThe folder '$mountFolder' will be unmounted. Changes in that folder will$change be applied to the associated image ..."
	"`n W A R N I N G"
	"   The folder '$mountFolder' and all data it contains will be deleted permanently!"
	if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# Mount the image into the newly created folder
function Unmount-Volume
{
	"`nUnmounting folder '$mountFolder' ..."
	"This may take a few minutes ..."
	$dismArgs = @{Path = $mountFolder}
	if ($updateImage) {
		$dismArgs['Save'] = $true
		$dismArgs['CheckIntegrity'] = $true
	} else {
		$dismArgs['Discard'] = $true
	}
	Import-Module DISM
	Dismount-WindowsImage @dismArgs
}

# Remove the mount folder.
function Remove-Folder
{
	if (Test-Path $mountFolder) { Remove-Item $mountFolder }
}

# Explain script, collect imputs from user and perform unmount operation
function Run-UnmountImage
{
	Try {
		if ($runInteractive) {
			Configure-Host
			Confirm-Execution
			if ($useFileDialogs) { Get-MountFolderDlg } else { Get-MountFolder }
			Query-UpdateImage
			Confirm-Parameters
		}
		Unmount-Volume
		Remove-Folder
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
Run-UnmountImage
