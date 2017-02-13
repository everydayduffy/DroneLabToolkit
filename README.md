# ArducopteR

An `R` package for manipulating and harvesting data from log files produced by autopilots running the [Arducopter](http://www.arducopter.co.uk/) flight stack. Functions include synthesising logs and tagging
photos with GPS data. 


## Installation

```
devtools::install_github("everydayduffy/ArducopteR")
library(ArducopteR)
```

## Functions

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
