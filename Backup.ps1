# Backup a volume, Version 1.0.17114
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

# Whether or not to run the Windows Clean Manager before creating backup
$Global:runCleanMgr = $true

# Whether or not to copy an existing WIM file before modifying it
$Global:copyWIMFile = $true

# The source volume to backup. This may be the live system, too.
$Global:volume = 'C:\'

# The target file to add the image to. Preferably on a mounted external USB drive.
$Global:wimFile = 'M:\Backup\System.wim'

# The name for the new image in the backup file. Defaults to the date and time.
$Global:imageName = (Get-Date).DateTime

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
    "`n   B A C K U P   V O L U M E`n"
    "This script will perform the following tasks:"
    "------------------------------------------------"
    " 1. Query the volume to backup."
    " 2. Query the name of a WIM backup file."
    " 3. Query a name for this backup."
    " 4. Optionally make a copy of the WIM file if it exists."
    " 5. Optionally call the Clean Manager to remove obsolete data."
    "     You should run it once like this to configure what to delete:"
    "       'cleanmgr /sageset:1'"
    " 6. Create or update the backup file."
    " 7. Verify the integrity of the backup file."
    " 8. Create a log file with a list of files in the new image."
    if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# Let user select one of the available volumes to backup; CDRom volumes are skipped.
function Select-Volume
{
    # Name = Caption = DeviceID, Optionally interesting: VolumeSerialNumber
    Get-WmiObject Win32_logicaldisk | ?{ $_.DriveType -eq 3 } | Select Name,VolumeName,`
    @{Name="Total[GB]"; Expression={[Math]::Ceiling($_.Size / 1GB)}},`
    @{Name="Used[GB]"; Expression={[Math]::Ceiling(($_.Size - $_.FreeSpace) / 1GB)}},FileSystem,Description | `
    Format-Table -AutoSize
    "Enter the drive letter of the volume to backup."
    $answer = Read-Host "This can be the live system, too ($($volume.TrimEnd(':\')))"
    if (![string]::IsNullOrEmpty($answer)) { $Global:volume = $answer }
    $Global:volume = $volume.ToUpper().TrimEnd(':\') + ':\'
}

# Let user select or enter a WIM file. Aborts script if user hits 'Abort'
function Get-WIMFilename
{
    $initialFolder = Split-Path -Parent $wimFile
    "`nWIM files in ${initialFolder}:"
    "--------------------------------"
    if (Test-Path $initialFolder)
        { Get-ChildItem -Path $initialFolder '*.wim' | Format-Table -Property FullName -AutoSize }
    $answer = Read-Host "Enter the full path of an existing or new backup file ($wimFile)"
    if (![string]::IsNullOrEmpty($answer)) { $Global:wimFile = $answer }
}

# Let user select or enter a WIM file. Aborts script if user hits 'Abort'
function Get-WIMFilenameDlg
{
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.OverwritePrompt = $false
    $dialog.initialDirectory = Split-Path -Parent $wimFile
    $dialog.Title = "Select an existing backup file or select a folder and enter a new name"
    $initialFilename = [IO.Path]::GetFileNameWithoutExtension($wimFile)
    $dialog.FileName = $initialFilename
    $dialog.filter = "WIM (*.wim)| *.wim"
    [void]$dialog.ShowDialog()
    if ($initialFilename -eq $dialog.FileName) { Exit }
    $Global:wimFile = $dialog.FileName
}

# Test if the WIM file is on the volume that is to be backed up, if yes, report this and exit script 
function Reject-VolumeConflict
{
    if ($volume -eq "$(Split-Path -Qualifier $wimFile)\") {
        Throw "The backup of volume '$volume' cannot be written to the WIM file '$wimFile' on that same volume."
    }
}

# Let user override the name for this image
function Get-ImageName
{
    "`nAll images in a WIM file must have unique names,"
    "which should not contain special characters."
    $answer = Read-Host "`nEnter a name for this backup image ($imageName)"
    if (!([string]::IsNullOrEmpty($answer))) { $Global:imageName = $answer }
}

# Query whether or not to run Windows Clean Manager
function Query-CleanMgr
{
	$Global:runCleanMgr = (Read-Host "`nRun Clean Manager (Y/N)?") -eq 'y'
}

# Run Windows Clean Manager if configured
function Run-CleanMgr
{
    if ($runCleanMgr)
        { cleanmgr /sagerun:1 | Out-Null }  # | Out-Null waits for clean manager to finish
}

# Test if the specified file exists, if yes, report this and exit script 
function Reject-ExistingBackup([string]$wimFileBackup) 
{
    if (Test-Path $wimFileBackup) {
        Throw "File '$wimFileBackup' already exists.`n" + 
        "Rename or delete it first and try again."
    }
}

# Query whether or not to create a backup of an existing WIM file
function Query-WIMFileBackup
{
    if ($copyWIMFile)
		{ $Global:copyWIMFile = (Read-Host "`nCopy '$wimFile' as '$wimFileBackup' (Y/N)?") -eq 'y' }
}

# Creates a copy of the WIM file after user confirmation
function Create-WIMFileBackup([string]$wimFileBackup)
{
    if (!$copyWIMFile)
        { return }

    Reject-ExistingBackup $wimFileBackup
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $wimFile -Destination $wimFileBackup `
        -Description "Copying '$wimFile' as '$wimFileBackup'" -DisplayName "Copying backup file"
}

# Let user confirm all selected parameters before commencing operation. Abort script if user does not confirm.
function Confirm-Parameters
{
	''
	if ($runCleanMgr) { "The Windows Clean Manager will be called." }
	if ($copyWIMFile) { "The existing WIM file '$wimFile' will be copied." }
    "A backup of volume '$volume' with the name '$imageName'"
    "will be added to the WIM file '$wimFile'"
    if ((Read-Host "`nContinue (Y/N)?") -ne 'y') { Exit }
}

# $true if a new WIM file has been created, $false if an existing one was updated
$Global:newWIMFile = $false

# Creates a named image of the specified volume in the specified WIM file
function Create-Image
{
    if (Test-Path $wimFile) {
	    "`nUpdating backup file '$wimFile' ..."
        $command = 'append'
		$Global:newWIMFile = $false
    } else {
	    "`nCreating new backup file '$wimFile' ..."
        $command = 'capture'
		$Global:newWIMFile = $true
    }
    ImageX $command, $volume, $wimFile, $imageName, --boot, --check, --solid, --snapshot
}

# Verifies the integrity of the WIM file
function Verify-WIMFile
{
    ImageX verify, $wimFile
}

# Get the index of the latest image from the backup file. Abort script on failure
function Get-ImageIndex
{
    if (ImageX info, $wimFile | ?{ $_ -match 'Image Count:\s*(\d+)' })
        { return $Matches[1] }

    Throw "Could not extract the number of images in file '$wimFile'`n" +
    "Please check the contents of the file yourself."
}

# Create a file list (i.e. table of contents) of the WIM file into a text file
function Create-FileList
{
    $listFile = Join-Path (Split-Path -Parent $wimFile) $([IO.Path]::GetFileNameWithoutExtension($wimFile) + "$imageIndex.txt")
    "`nListing files of image $imageIndex in '$wimFile' to '$listFile' ..."
    ImageX dir, $wimFile, $imageIndex > $listFile
    "Listed files of image $imageIndex into '$(Resolve-Path $listFile)'"
    "You can add a description of the volume changes at the beginning of that file using a text editor."
}

# Compute and report the execution time w.r.t. the provided start time
function Report-ExecutionTime([DateTime]$startTime)
{
    "`nBackup ran for " + ((Get-Date) - $startTime).ToString("h\:mm\:ss")
}

# Inform user that he can delete 
function Final-Message([string]$wimFileBackup)
{
	if ($newWIMFile) {
		"`nSince this is the first backup of volume '$volume', you are highly encouraged"
		"to restore it right away to make sure that everything works smoothly."
		"That includes booting the Windows on a USB drive or an installation CD."
	}
	
    if (Test-Path $wimFileBackup) {
        "`nYou may now move or delete the WIM backup file '$wimFileBackup'"
        "if the updated WIM file '$wimFile' was verified successfully."
    }
}

# Explain script, collect imputs from user and perform backup operation
function Run-Backup
{
    Try {
        if ($runInteractive) {
            Configure-Host
            Confirm-Execution
            Select-Volume
            if ($useFileDialogs) { Get-WIMFilenameDlg } else { Get-WIMFilename }
            Reject-VolumeConflict
            Get-ImageName
			Query-CleanMgr
		}
		$Global:copyWIMFile = (Test-Path $wimFile)
        if ($runInteractive) {
			Query-WIMFileBackup
            Confirm-Parameters
        }
        $wimFileName = $([IO.Path]::GetFileNameWithoutExtension($wimFile))
        $wimFileBackup = Join-Path (Split-Path $wimFile -Parent) "$wimFileName-$((Get-Date).ToShortDateString()).wim"
        Run-CleanMgr
        Create-WIMFileBackup $wimFileBackup
        $startTime = Get-Date
        Create-Image
        Verify-WIMFile
        $Global:imageIndex = Get-ImageIndex
        Create-FileList
        Report-ExecutionTime $startTime
        Final-Message $wimFileBackup
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
Run-Backup
