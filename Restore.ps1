# Restore a volume, Version 1.1.17491.0
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
  else { Start-Process powershell.exe -Verb RunAs -ArgumentList ('-ExecutionPolicy Unrestricted -noprofile -nologo -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition)) }
  exit
}


# ---------------------- Configuration ----------------------

# Whether or not to run interactively.
#  W A R N I N G :  When setting this to $false, make sure all remaining parameters are correct!
#                   I'm really serious - You can annihilate your operating system with one click!
$Global:runInteractive = $true

# Whether or not to use file dialog boxes for more convenient file selection.
$Global:useFileDialogs = $true

# The target volume to restore. This can NOT be the live system.
$Global:volume = 'G:\'

# The source file to take the image from.
$Global:wimFile = 'M:\Backup\System.wim'

# The image index in the WIM file to restore. Use highest available if possible
$Global:imageIndex = 9999

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
	$Global:Win32SetWindowPos = Add-Type -memberDefinition '[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);' `
	-name 'Win32SetWindowPos' -namespace Win32Functions -passThru
	[void]$Global:Win32SetWindowPos::SetWindowPos(((Get-Process -Id $pid).MainWindowHandle), 0, 40, 0, 0, 0, 0x4255)
}

# Make the host window almost the height of the screen and place it at the top
function Configure-Host
{
	$MySize = $host.UI.RawUI.WindowSize
	$MySize.Height = $host.UI.RawUI.MaxPhysicalWindowSize.Height - 2
	$host.UI.RawUI.set_windowSize($MySize)
	Move-WindowToTop
}

# Explain what the script does and let user confirm execution
function Confirm-Execution
{
	"`n   R E S T O R E   V O L U M E`n"
	"This script will perform the following tasks:"
	"------------------------------------------------"
	" 1. Let you choose the name of a WIM file."
	" 2. Let you choose an image from the WIM file to restore."
	" 3. Let you choose which volume to restore."
	" 4. Verify the integrity of the WIM file."
	" 5. Quick format the volume as NTFS."
	" 6. Restore the selected image to the formatted volume."
	if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# Let user select one of the available volumes to restore;
# The live volume, the CDRom, and the drive holding the WIM file is skipped.
function Select-Volume
{
	"`nSelect a volume to restore."
	"This must NEITHER be the live system ($env:SystemDrive), NOR the volume holding the WIM file!"
	# Name = Caption = DeviceID, Optionally interesting: VolumeSerialNumber
	if ($wimFile.StartsWith('\\')) { $qualifier = '0' } else { $qualifier = Split-Path -Qualifier $wimFile }
	Get-WmiObject Win32_logicaldisk | ?{ $_.Name -ne "${env:SystemDrive}" -and $_.Name -ne $qualifier -and $_.DriveType -eq 3 } | `
	Select Name,VolumeName,FileSystem,Description,@{Name="Size[GB]"; Expression={[Math]::Ceiling($_.Size / 1GB)}} | `
	Format-Table -AutoSize
	$answer = Read-Host "Enter the drive letter of the volume to restore ($($volume.TrimEnd(':\')))"
	if (![string]::IsNullOrEmpty($answer)) { $Global:volume = $answer }
	$Global:volume = $volume.ToUpper().TrimEnd(':\') + ':\'
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
	$answer = Read-Host "`nEnter 1-based 'Index' of the image to restore ($imageIndex)"
	if (![string]::IsNullOrEmpty($answer)) { $Global:imageIndex = [int]$answer }
}

# Test if the selected volume is the live volume, if yes, report this and exit script 
function Reject-LiveVolume
{
	if ($volume.TrimEnd(':\') -eq $env:SystemDrive.TrimEnd(':\'))
		{ Throw "You cannot restore to the live system $env:SystemDrive\" }
}

# Warn user if the target volume contains a page file. That may or may not be in use.
function Warn-AboutPageFile
{
	Get-WmiObject Win32_PageFileUsage | %{ $pageFilePath = $_.Name ; [int]$pageFileUse = $_.CurrentUsage }
	$pageFile = $volume.TrimEnd(':\') + ":\pagefile.sys"
	if ((Test-Path $pageFile) -and ($pageFilePath -eq $pageFile) -and ($pageFileUse -gt 0)) {
		"`nWarning: The currently active paging file '$pageFile' may render the volume '$volume' read-only."
		"In the advanced system settings, make sure that '$pageFile' is not ACTIVELY being used."
		"Verify again that '$volume' is the correct volume!"
		if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
	}
}

# Warn user if the target volume is too small to hold the entire image.
function Warn-AboutSmallVolume
{
	[int64]$volumeSize = Get-WmiObject Win32_logicaldisk | ?{ $_.Name -eq $volume.TrimEnd('\') } | %{ $_.Size }
	[int64]$imageSize = 0
	if (ImageX info, $wimFile, $imageIndex | ?{ $_ -match 'Total Bytes:\s*(\d+)' })
		{ $imageSize = $Matches[1] }

	if ($imageSize -gt $volumeSize) {
		"`nWarning: The volume '$volume' might be too small to hold the entire image."
		"The volume size is just $([Math]::Round($volumeSize / 1GB,0).ToString('N0')) GB, but the image size may be up to $([Math]::Ceiling($imageSize / 1GB).ToString('N0')) GB."
		"You will be able to extract some of the image files but the"
		"volume may not be complete and it might be corrupted."
		if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
	}
}

# Let user confirm all selected parameters before commencing operation. Abort script if user does not confirm.
function Confirm-Parameters
{
	"`nVolume '$volume' will be formatted. Then image '$imageIndex' from the"
	"WIM file '$wimFile' will be applied to the volume."
	"`n W A R N I N G"
	"   All data currently on volume '$volume' will be deleted permanently!"
	if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
	"`nNote: You can still abort the script (at your own risk!) as long as the volume formatting has not begun."
}

# Verifies the integrity of the WIM file
function Verify-WIMFile
{
	ImageX verify, $wimFile
}

# Format the target volume. Throw on failure.
function Format-TargetVolume
{
	$volumeName = Get-WmiObject Win32_logicaldisk | ?{ $_.Name -eq $volume.TrimEnd('\') } | %{ $_.VolumeName }
	if ([string]::IsNullOrEmpty($volumeName)) { $volumeName = 'Restored' }
	"`nFormating volume '$volume' ($volumeName) ..."
	$errorCount = $Error.Count
	Format-Volume -DriveLetter $volume.TrimEnd(':\') -FileSystem 'NTFS' -NewFileSystemLabel $volumeName -Force
	if (($LastExitCode -ne 0) -or ($Error.Count -gt $errorCount))
		{ Throw "Format-Volume failed" }

	# Without this delay, the summary of Format-Volume appear later in the output, mixed with other messages.
	Start-Sleep 1
}

# Format the target partition before restoring the contents
function Restore-Volume
{
	"`nRestoring image $imageIndex from '$wimFile' to partition '$volume' ..."
	ImageX apply, $wimFile, $imageIndex, $volume
}

# Compute and report the execution time w.r.t. the provided start time
function Report-ExecutionTime([DateTime]$startTime)
{
	"`nRestore ran for " + ((Get-Date) - $startTime).ToString("h\:mm\:ss")
}

# Explain script, collect imputs from user and perform restore operation
function Run-Restore
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
			Select-Volume
		}
		Reject-LiveVolume
		if ($runInteractive) {
			Warn-AboutPageFile
			Warn-AboutSmallVolume
			Confirm-Parameters
		}
		$startTime = Get-Date
		Verify-WIMFile
		Format-TargetVolume
		Restore-Volume
		Report-ExecutionTime $startTime
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
Run-Restore
