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

# WimLibScripts CHANGES

## Version 1.1.17347.0

* Support for volumes that do not support filesystem snapshots.

## Version 1.1.17242.0

* Made exclusion list explicit in backup.ini.

## Version 1.1.17201.0

* Fixed error message for WIM files on network shares.

## Version 1.1.17197.0

* Removed the `--solid` flag to make the resulting images mountable by DISM.
* Added scripts `MountImage.ps1` and `UnmountImage.ps1`

Many thanks to `synchronicity` for his helpful comments on the [WimLib Forum](https://wimlib.net/forums/viewtopic.php?f=1&t=310).

## Version 1.0.17114.1

* Initial version.
