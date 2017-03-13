# WimLibScripts

WimLibScripts is a collection of PowerShell scripts to backup and restore entire Windows volumes.
It uses PowerShell to query all required settings and perform checks,
and the excellent open source library [WimLib](https://wimlib.net) to perform the actual backup and restore task.

The scripts can easily be configured to run fully interactive with file selection dialogs,
interactive but strictly text based, or fully automated with preset parameters.

## Motivation

Over the years, I had used *Acronis TrueImage*, *DriveImage XML*, *Norton GhostImage*, and the *Windows 7* builtin backup,
non of which fully satisfied me. So I stumbled over several articles that describe the features of [WimLib](https://wimlib.net),
which exploits the [WIM](https://de.wikipedia.org/wiki/Windows_Imaging_Format_Archive) file format
that is also used by Microsoft to bundle its software releases.

#### My initial experiments showed remarkable results:
 * the [WimLib](https://wimlib.net) library is rock solid and reliably creates and restores images.
 * it is **very** space efficient. An image consumes only about a third of the space used by the files on the volume.
 * it skips well-known space hoggers, like `pagefile.sys`, `swapfile.sys`, or `System Volume Information`, among others.
 * it adds additional images as differential changes to the WIM file.
   So the size of the WIM file only increases by about a third of the size of the modified files.
 * it is **very** CPU efficient. While compressing the file data in parallel, it used all of my eight cores to 99%.

Since the web pages I found merely describe the steps to manually issue a backup and how to restore an image,
I wrote these scripts to make this a regularly, easy and less error prone task.

## Manual

For an explanation of the scripts, see [MANUAL.md](MANUAL.md)

## License

Copyright (C) 2017 Dr. Frank Heimes  
See the [LICENSE](LICENSE.md) file for license rights and limitations (MIT).
