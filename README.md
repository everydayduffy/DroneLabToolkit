# DroneLabToolkit

An `R` package for manipulating and harvesting data from log files produced by autopilots running the [Arducopter](http://www.arducopter.co.uk/) flight stack. Functions include synthesising logs and tagging
images with GPS data.

This package requires the following  `R` packages to work correctly `dplyr`,`magrittr`,`sp` and `tidyr`.

It also requires [exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to be installed for some functions to work. On windows systems, users will be prompted for the location of `exiftool.exe` on their machine. For mac and linux systems, the tool will be called automatically.  


## Installation

```
devtools::install_github("everydayduffy/DroneLabToolkit")
library(DroneLabToolkit)
```

## Functions

#### exif_coord_convert

This function is used to read the GPS exif tags from one set of images, converts them to a new coordinate system and writes the new coordinates back onto the exif metadata associated with the images.

##### Example

```
exif_coord_convert(img_path="/home/images", crs_in="+init=epsg:4326",
crs_out="+init=epsg:27700", csv=TRUE)
```

#### exif_retag
This function is used to take a `.log` dataflash file, extract GPS data and tag images with the positional
information (x,y,z) collected by the autopilot.

##### Example
```
exif_retag(timediff = 17, img_path = "/home/images",
log_file = "/home/Logs/log1.log", proj_name = "project_1",
csv_out = "/home/Output", leap_secs=17)
```

#### extract_attitude

This function is used to take a `.log` dataflash file, extract GPS and attitude information, then select this information that matches the time each image was taken and export as a .csv.

##### Example

```
extract_attitude(time_diff = 17, img_path = "/home/images",
log_file = "/home/Logs/log1.log", proj_name = "project_1",
csv_out = "/home/Output", leap_secs=17)
```

#### synthesise

This function collates useful information from a number of `.log` dataflash log files, and outputs them
as a `.csv`.

##### Example

```
synthesise(log_path="/home/logs", out_path="/home/logs", out_name="my_logs", recursive=TRUE, leap_secs=17)
```

## Stuck?

Help can be found over at the [Wiki](https://github.com/everydayduffy/DroneLabToolkit/wiki/Calculating-TIme-Difference) (e.g. on how to calculate time difference (`timediff`)).
