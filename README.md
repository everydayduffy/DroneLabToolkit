# ArducopteR

An `R` package for manipulating and harvesting data from log files produced by autopilots running the [Arducopter](http://www.arducopter.co.uk/) flight stack. Functions include synthesising logs and tagging
photos with GPS data. 


## Installation

```
devtools::install_github("everydayduffy/ArducopteR")
library(ArducopteR)
```

## Functions

#### coord_convert_linux

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to read the GPS exif tags from one set of photos, converts them to a new coordinate system and writes the new coordinates back onto the photos. 

##### Example

```
coord_convert_linux(in.path="./IN",out.path="./OUT",crs.in="+init=epsg:4326",
crs.out="+init=epsg:27700")
```

#### coord_convert_windows

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to read the GPS exif tags from one set of photos, converts them to a new coordinate system and writes the new coordinates back onto the photos. 

This function is identical to `coord_convert_linux` except that the location of `exiftool.exe` has to be defined. 

##### Example

```
coord_convert_linux(in.path="C:/IN",out.path="C:/OUT",crs.in="+init=epsg:4326",
crs.out="+init=epsg:27700",exif.tool.path="C:/exiftool/exiftool.exe")
```

#### exif_retag_linux

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to take a `.log` dataflash file, extract GPS information and tag photographs with the positional
information collected by the autopilot. 

##### Example

```
exif.retag(timediff = 17, photo.folder.path = "./Photos", 
log.file.path = "./Logs/log1.log", proj.name = "project_1",
csv.out = "./Output",leapsecs=17)
```

#### exif_retag_windows

This function requires the installation of [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to work.
It is used to take a `.log` dataflash file, extract GPS information and tag photographs with the positional
information collected by the autopilot. 

This function is identical to `exif_retag_linux` except that the location of `exiftool.exe` has to be
defined. 

##### Example

```
exif.retag(timediff = 17, photo.folder.path = "C:/Photos", 
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
