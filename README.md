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

# WimLibScripts

WimLibScripts is a collection of PowerShell scripts to backup and restore entire Windows volumes.
It uses PowerShell to query all required settings and perform checks,
and the excellent open source library [WimLib](https://wimlib.net) to perform the actual backup and restore task.

The scripts can easily be configured to run fully interactively with file selection dialogs,
interactive but strictly text based, or fully automated with preset parameters.

## Motivation

Over the years, I had used *Acronis TrueImage*, *DriveImage XML*, *Norton GhostImage*, and the *Windows 7* built-in backup,
none of which fully satisfied me. So I stumbled over several articles that describe the features of [WimLib](https://wimlib.net),
which exploits the [WIM](https://de.wikipedia.org/wiki/Windows_Imaging_Format_Archive) file format
that is also used by Microsoft to bundle its software releases.

#### My initial experiments showed remarkable results:
 * the [WimLib](https://wimlib.net) library is rock solid and reliably creates and restores images.
 * it is ***very*** space efficient. An image consumes only about a third of the space used by the files on the volume.
 * it skips well-known space hoggers, like `pagefile.sys`, `swapfile.sys`, or `System Volume Information`, among others.
 * it adds additional images as differential changes to the WIM file.
   So the size of the WIM file only increases by about a third of the size of the modified files.
 * it is ***very*** CPU efficient. While compressing the file data in parallel, it used all of my four cores to 99%.
 * the generated WIM file can easily be browsed and extracted using the free [7-Zip](http://www.7-zip.org/) program.

Since the web pages I found merely describe the steps to manually issue a backup and how to restore an image,
I wrote these scripts to make this a regular, easy and less error prone task.

## Manual

For an explanation of the scripts, see the [MANUAL](MANUAL.md).

## License

Copyright (c) 2017 Dr. Frank Heimes  
See the [LICENSE](LICENSE.md) file for license rights and limitations (MIT).

## Support

Plaudits :smirk:, feature requests, and constructive comments are highly appreciated.
Since I'm using the scripts myself, I will continue to maintain them.

Feel free to contact me on [Twitter](https://twitter.com/DrFGHde) or [Facebook](https://www.facebook.com/dr.frank.heimes) :sunglasses:
