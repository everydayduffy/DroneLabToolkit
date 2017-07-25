# DroneLabToolkit

An `R` package for manipulating and harvesting data from log files produced by autopilots running the [Arducopter](http://www.arducopter.co.uk/) flight stack. Functions include synthesising logs and tagging
photos with GPS data.

This package requires the following packages to work correctly `dplyr`,`magrittr`,`sp` and `tidyr`.


## Installation

```
devtools::install_github("everydayduffy/DroneLabToolkit")
library(DroneLabToolkit)
```

## Functions

#### coord_convert_linux

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to read the GPS exif tags from one set of photos, converts them to a new coordinate system and writes the new coordinates back onto the photos.

##### Example

```
coord_convert_linux(in.path="/home/IN",crs.in="+init=epsg:4326",
crs.out="+init=epsg:27700",csv=TRUE)
```

#### coord_convert_windows

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to read the GPS exif tags from one set of photos, converts them to a new coordinate system and writes the new coordinates back onto the photos.

This function is identical to `coord_convert_linux` except that the location of `exiftool.exe` has to be defined.

##### Example

```
coord_convert_windows(in.path="C:/IN",crs.in="+init=epsg:4326",
crs.out="+init=epsg:27700",exif.tool.path="C:/exiftool/exiftool.exe", csv=TRUE)
```

#### exif_retag_linux

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to take a `.log` dataflash file, extract GPS information and tag photographs with the positional
information collected by the autopilot.

##### Example

```
exif_retag_linux(timediff = 17, photo.folder.path = "/home/Photos",
log.file.path = "/home/Logs/log1.log", proj.name = "project_1",
csv.out = "/home/Output",leapsecs=17)
```

#### exif_retag_windows

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to take a `.log` dataflash file, extract GPS information and tag photographs with the positional
information collected by the autopilot.

This function is identical to `exif_retag_linux` except that the location of `exiftool.exe` has to be
defined.

##### Example

```
exif_retag_windows(timediff = 17, photo.folder.path = "C:/Photos",
log.file.path = "C:/Logs/log1.log", proj.name = "project_1",
csv.out = "C:/Output",leapsecs=17,exif.tool.path="C:/exiftool/exiftool.exe")
```

#### extract_gps_attitude_linux

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to take a `.log` dataflash file, extract GPS and attitude information, then select this information that matches the time each photo was taken and export as a .csv.

##### Example

```
extract_gps_attitude_linux(timediff = 17, photo.folder.path = "/home/Photos",
log.file.path = "/home/Logs/log1.log", proj.name = "project_1",
csv.out = "/home/Output",leapsecs=17)
```

#### extract_gps_attitude_windows

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to take a `.log` dataflash file, extract GPS and attitude information, then select this information that matches the time each photo was taken and export as a .csv.

This function is identical to `extract_gps_attitude_linux` except that the location of `exiftool.exe` has to be
defined.

##### Example

```
extract_gps_attitude_windows(timediff = 17, photo.folder.path = "C:/Photos",
log.file.path = "C:/Logs/log1.log", proj.name = "project_1",
csv.out = "C:/Output",leapsecs=17,exif.tool.path="C:/exiftool/exiftool.exe")
```

#### synthesise

This function collates useful information from a number of `.log` dataflash log files, and outputs them
as a `.csv`.

##### Example

```
synthesise(in.folder="C:/Logs",out.folder="C:/Out",out.name="my_logs",
recursive=TRUE,leapsecs=17)
```

## Stuck?

Help can be found over at the [Wiki](https://github.com/everydayduffy/DroneLabToolkit/wiki/Calculating-TIme-Difference) (e.g. on how to calculate time difference (`timediff`)).
