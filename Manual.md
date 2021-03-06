<!--
Original work Copyright (c) 2017 Dr. Frank Heimes (twitter.com/DrFGHde, www.facebook.com/dr.frank.heimes)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-->

# WimLibScripts MANUAL

## Prerequisites

1. The scripts have been developed with PowerShell 5.0.  
   I don't know if they work with previous versions of PowerShell.
2. The scripts use the [WimLib](https://wimlib.net) library. Download it from https://wimlib.net.
3. To run the scripts `Backup.ps1`, `Restore.ps1`, `MountImage.ps1`, and `UnmountImage.ps1`, you need Administrator privileges.
4. To restore an image to the live Windows system, you need a bootable medium,
   e.g. a Windows volume on a USB drive or an installation CD.
5. Since both, WimLib as well as PowerShell, are available for Linux,
   you might even be able to use Linux to restore a Windows volume.

## Installation

1. Download the [WimLib](https://wimlib.net) library.
2. Unpack it into an arbitrary folder, preferably `C:\My\WimLib`.
3. Download the [WimLibScripts](https://github.com/FrankHeimes/WimLibScripts) repository.
3. Place all PowerShell scripts `*.ps1` into the same folder as `wimlib-imagex.exe` and `libwim-15.dll`.

## How to use

To execute a script, open the context menu for it and select *Run with PowerShell*
![Screenshot of Context Menu](./RunWithPowerShell.gif)
This way, you don't need to modify the global ExecutionPolicy of the system.

Upon first invocation, the following security warning may appear:
![Screenshot of Security Warning](./SecurityWarning.gif)
```
Execution Policy Change
The execution policy helps protect you from scripts that you do not trust. Changing the execution policy might expose
you to the security risks described in the about_Execution_Policies help topic at
http://go.microsoft.com/fwlink/?LinkID=135170. Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"):
```
To continue the script, answer `Y`.

The scripts that require elevated privileges restart themselves with Administrator privileges if started from a limited account.

All scripts contain a configuration section with default parameters.
You can run the scripts interactively or execute them using the default parameters.

Several consistency and security checks are performed. In case of an error, an exception is thrown.
In interactive mode, the error is reported before aborting the script.
							  
This repository currently contains the following scripts:

---

## Backup.ps1

This script creates a backup from an entire volume and adds that as an image to a WIM file, creating the latter if necessary.
It queries all required parameters and runs the Windows Clean Manager in advance.
It verifies the backup and creates a table of contents for the new image.

### Configuration
The script contains a `--- Configuration ---` section with the following parameters

| Parameter | Default | Explanation
| --------- | ------- | -----------
| `$Global:runInteractive` | `$true` | If `$true`, all parameters can be entered interactively and have to be confirmed. If `$false`, the parameters in this section are used for the backup and all dialogs and queries are skipped.
| `$Global:useFileDialogs` | `$true` | If `$true`, a Windows Forms SaveFileDialog is opened to interactively select the WIM file. If `$false`, the path has to be entered as string.
| `$Global:runCleanMgr` | `$true` | If `$true`, the Windows Clean Manager is called before creating the backup. You can call it once to configure what to delete: `cleanmgr /sageset:1`
| `$Global:copyWIMFile` | `$true` | If `$true`, the WIM file is copied before adding the new image to it. This is a safety precaution to avoid corruption of the WIM file in case of a system crash, hardware failure, or power outage.
| `$Global:volume` | `'C:\'` | The volume to backup. This can and should be the live system, because the clean manager is most effective in this case.
| `$Global:wimFile` | `'M:\Backup\System.wim'` | The target WIM file to add the backup image to. This cannot be the volume to backup and it should not be on the same physical drive.
| `$Global:imageName` | Long date and time | A descriptive name for the new backup image. |

The file `Backup.ini`, located in the same directory as Backup.ps1, contains the exclusion list.
You may add additional files and folders to exclude from backup.

### WARNING
**When setting `$Global:runInteractive` to `$false`, make sure all remaining parameters are correct!**

### Performance
The [WimLib](https://wimlib.net) library is configured to use LZMS compression in parallel on all available cores.
The backup operation processes about 20 GB per hour using four cores of an intel Core i5.

---

## Restore.ps1

This script restores a volume from a backup image in a WIM file. It queries all required parameters and verifies the backup.
Before restoring the data, the volume is quick formatted.

### Configuration
The script contains a `--- Configuration ---` section with the following parameters

| Parameter | Default | Explanation
| --------- | ------- | -----------
| `$Global:runInteractive` | `$true` | If `$true`, all parameters can be entered interactively and have to be confirmed. If `$false`, the parameters in this section are used for the restore and all dialogs and queries are skipped.
| `$Global:useFileDialogs` | `$true` | If `$true`, a Windows Forms OpenFileDialog is opened to interactively select the WIM file. If `$false`, the path has to be entered as string.
| `$Global:volume` | `'G:\'` | The volume to restore. This can *neither* be the live system *nor* the volume holding the WIM file.
| `$Global:wimFile` | `'M:\Backup\System.wim'` | The source WIM file to take the backup image from. This cannot reside on the volume to restore.
| `$Global:imageIndex` | 9999 | The image index in the WIM file to restore. If this number is too high, then the highest available index is picked.

### WARNING
**When setting `$Global:runInteractive` to `$false`, make sure all remaining parameters are correct!
This is particularly important for this restore script.
With the wrong parameters you can easily damage your data or operating system beyond repair!**

### Performance
The restore operation yields about 140 GB per hour on a SSD.

---

## ListImageContents.ps1

This script creates a table of contents for an image in a WIM file into a text file.

### Configuration
The script contains a `--- Configuration ---` section with the following parameters

| Parameter | Default | Explanation
| --------- | ------- | -----------
| `$Global:runInteractive` | `$true` | If `$true`, all parameters can be entered interactively. If `$false`, the parameters in this section are used for the listing and all dialogs and queries are skipped.
| `$Global:useFileDialogs` | `$true` | If `$true`, a Windows Forms OpenFileDialog is opened to interactively select the WIM file. If `$false`, the path has to be entered as string.
| `$Global:wimFile` | `'M:\Backup\System.wim'` | The WIM file to examine.
| `$Global:imageIndex` | 9999 | The image index in the WIM file to examine. If this number is too high, then the highest available index is picked.

---

## MountImage.ps1

This script mounts a backup image from a WIM file. It queries all required parameters.

### Configuration
The script contains a `--- Configuration ---` section with the following parameters

| Parameter | Default | Explanation
| --------- | ------- | -----------
| `$Global:runInteractive` | `$true` | If `$true`, all parameters can be entered interactively and have to be confirmed. If `$false`, the parameters in this section are used for the mount operation and all dialogs and queries are skipped.
| `$Global:useFileDialogs` | `$true` | If `$true`, a Windows Forms OpenFileDialog is opened to interactively select the WIM file. If `$false`, the path has to be entered as string.
| `$Global:mountFolder` | `'C:\Mounted'` | The directory to mount the image to. This must *not* exist.
| `$Global:wimFile` | `'M:\Backup\System.wim'` | The source WIM file to take the backup image from.
| `$Global:imageIndex` | 9999 | The image index in the WIM file to mount. If this number is too high, then the highest available index is picked.
| `$Global:readOnly` | `$true` | If `$true`, the image is mounted read-only and protected against changes. If `$false`, you can update the image contents.

### WARNING
**When setting `$Global:runInteractive` to `$false`, make sure all remaining parameters are correct!**

---

## UnmountImage.ps1

This script unmounts a backup image from a mounted folder. It queries all required parameters.

### Configuration
The script contains a `--- Configuration ---` section with the following parameters

| Parameter | Default | Explanation
| --------- | ------- | -----------
| `$Global:runInteractive` | `$true` | If `$true`, all parameters can be entered interactively and have to be confirmed. If `$false`, the parameters in this section are used for the restore and all dialogs and queries are skipped.
| `$Global:useFileDialogs` | `$true` | If `$true`, a Windows Forms OpenFileDialog is opened to interactively select the WIM file. If `$false`, the path has to be entered as string.
| `$Global:mountFolder` | `'C:\Mounted'` | The directory the image is currently mounted to. This *must* exist.
| `$Global:updateImage` | `$false` | If `$true`, the image contents is updated from the changes made in the mount folder. This requires that the folder has *not* been mounted read-only.

### WARNING
**When setting `$Global:runInteractive` to `$false`, make sure all remaining parameters are correct!**

---

### Known Issues
The following are merely issues of the [WimLib](https://wimlib.net) library or the
[WIM](https://de.wikipedia.org/wiki/Windows_Imaging_Format_Archive) file format as such,
because the PowerShell scripts do little more but invoke `wimlib-imagex.exe`
- The reported sizes of the images in the WIM file do not reflect the size of the extracted files on the volume;
the Windows `DISM` command reports the same figure.
According to my observation, the reported size is about 30% too large.
This may cause the `Restore.ps1` script to warn about an allegedly insufficiently large volume.
*Any hints about how to correctly determine the size of a WIM image are highly welcome.*
- After restoring an image, I compared its space consumption - as displayed in the volume properties dialog -
with that of the original volume and noticed that these always differ by a few percent.
So I compared the exact file list and reported size using [WinDirStat](https://windirstat.net/) and the `ListImageContents.ps1` script
and could confirm that the actual contents is always identical.
So the consumed space, as reported by Windows, can safely be assumed to be merely an *educated guess*.
- On a Windows 8.1 system, when restoring a volume, the `-Force` option of the `Format-Volume` cmdlet is ignored,
resulting in an additional unnecessary confirmation query after the WIM file has been verified. On Windows 10, the option is respected.
- When restoring an image, WimLib typically issues `[WARNING] Ignoring FILE_ATTRIBUTE_SPARSE_FILE of nn files`
for a small number `nn` of files. To my knowledge, this has no negative side effects.

## Tips
#### Browse and Extract
Use the free [7-Zip](http://www.7-zip.org/) archiver (version 16.04 or newer) to open and browse a WIM file or to extract a limited number of files.
This is faster than mounting and unmounting the image.
You will probably want to use the `Restore.ps1` script to extract the entire volume as this also recreates all file meta data and permissions.

#### Quick Launch
To allow a PowerShell script to run with a double-click, you have two choices:
1. Set the system wide execution policy for PowerShell scripts, as described by [Microsoft](http://go.microsoft.com/fwlink/?LinkID=135170).
2. Create a Windows Shortcut with this target (e.g. for `Backup.ps1`):  
  `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe –ExecutionPolicy Unrestricted –NoProfile –File C:\My\WimLib\lib\Backup.ps1`

But beware that Windows shortcuts always contain absolute paths!
These may act surprisingly if running this script from the live system or a backup USB system.

#### Shrink Volume
After formatting a volume, Windows places some internal NTFS data as system files roughly at the center of the volume. As a consequence, if you try to shrink a volume, Windows will typically allow you to do so by up to 50% but no more. But if you backup and restore the volume system, the volume is formatted again and the unmovable system files will be placed at the center of the new volume. So by repeating the steps - shrink, backup, restore - you can shrink a volume down to the size that is actually occupied by data.

#### Create Bootable Virtual Disk
If you create a new virtual machine in Hyper-V, the default disk is not fit to host a Windows 10 system right away. I was unable to make a restored image bootable using bcdboot as described on some sites. So to create a new virtual machine from your existing WIM backup,
1. Download an ISO image from Microsoft with a Windows 10 installation.
2. Attach the ISO file as virtual DVD to your virtual machine.
3. Start the virtual machine and let Windows install itself.  
   You'll need to delete the largest existing partition and let the setup create its own partitions.
4. Shut down Windows in the virtual machine as soon as the OOBE program allows you to do so.
5. Mount the new VHDX file of your virtual machine using the context menu.
6. Restore the backup to the only visible volume on the virtual drive,
overwriting the fresh installation.
7. Detach / Eject the logical drive that has been mapped to the VHDX file.
8. Start the virtual machine again.
9. Depending on the type of Windows license you have, you may have to activate Windows (in the VM) again or obtain and enter a different license key into the system settings page.
