#' Retag photos with GPS info from Ardupilot dataflash logs
#'
#' @param timediff The difference in time between camera and GPS
#' @param photo.folder.path The location photos to be tagged
#' @param log.file.path The full path of the associated dataflash log
#' @param proj.name A name for this project (appended to output .csv)
#' @param csv.out Output folder for .csv file
#' @param leapsecs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @param exif.tool.path Full path of exiftool.exe location
#' @author James P. Duffy
#' @export

exif_retag_windows <-
  # arguments for exif retag
  function(timediff=0,photo.folder.path,log.file.path,proj.name,csv.out,
           leapsecs= seq(10:50),exif.tool.path) {
    ##Leapsecs to default at 18 (as of December 2016)
    if(missing(leapsecs)){leapsecs = 18}
    ##Part 1: Obtain exif times
    exif.time.data <- as.data.frame(system(paste0(exif.tool.path," -T -filename -createdate ",
                                                photo.folder.path), inter=TRUE))
    colnames(exif.time.data) <- "name_time_date"
    ##Tidy the data into separate columns
    exif.time.data <- tidyr::separate(exif.time.data, name_time_date, into =  c("name", "time"), sep ="\t") %>%
    tidyr::separate(.,time, into =  c("date", "time"), sep =" ") %>%
    data.frame()
    ##Part 2: Match up photo times with log data
    ##Number of seconds in a week
    secsweek <- 604800
    ##GPS epoch date
    epochdate <- "1980-01-06 00:00:00"
    ##Read in bin log that has been converted to .log file
    log.data <- read.delim(log.file.path, h=F, sep= ",",stringsAsFactors=FALSE)
    ##Filter out GPS data
    log.data <- dplyr::filter(log.data, V1=="GPS")
    ##Check the style of log (i.e. how many columns)
    if (ncol(log.data)<19) {
      add.val <- 0
      } else if (ncol(log.data)==19) {
        add.val <- 1
        }
    ##Filter out relevant columns
    log.data <- dplyr::select(log.data, c((2+add.val):(4+add.val),(7+add.val):(9+add.val)))
    ##Add column names
    colnames(log.data) <- c("status","timeMS","weeks","lat","long","alt")
    ##Convert 'weeks' data into numeric values
    log.data$weeks <- as.numeric(as.character(log.data$weeks))
    ##Create a list of GPS 'epoch' dates on which to add GPS times to
    epoch <- data.frame(time=c(rep(epochdate,dim(log.data)[1])))
    ##Format them correctly so 'seconds' can be added
    epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
    ##Add seconds calculated from the data to the 'epoch' times + timediff
    epoch$time <- epoch$time + (log.data$weeks*secsweek) + (as.numeric(log.data$timeMS)/1000) - leapsecs
    ##Add the time offset from particular dataset (defined at top of script)
    epoch$newtime <- epoch$time + timediff
    ##Split date and time into 2 (both old and new)
    epoch <- data.frame(do.call('rbind', strsplit(as.character(epoch$time),' ',fixed=TRUE)),do.call('rbind', strsplit(as.character(epoch$newtime),' ',fixed=TRUE)))
    ##Drop the extra date column (duplicate)
    epoch <- dplyr::select(epoch, -3)
    colnames(epoch) <- c("date","oldtime","time")
    ##Reshuffle data to get relevant information for merging with exif data
    log.data <- data.frame(epoch$date,epoch$oldtime,epoch$time,log.data$long,log.data$lat,log.data$alt)
    colnames(log.data) <- c("date","oldtime","time","long","lat","alt")
    ##Removes duplicates, just taking the first reading for each second
    log.data <- subset(log.data, !duplicated(log.data$oldtime))
    ##Remove whitespace
    log.data[c('long', 'lat', 'alt', 'time')] <- lapply(log.data[c('long', 'lat', 'alt', 'time')], gsub, pattern=" ",replacement="")
    ##Tidy up dates and times to make them match
    log.data$date <- gsub(":", "-", log.data$date)
    exif.time.data$date <- gsub(":", "-", exif.time.data$date)
    combo <- merge(x=exif.time.data, y=log.data, by= c("date","time"))
    ##Create a new columns with N/S/E/W references for lat long - to feed into exiftool
    combo$hor <- rep(NA,nrow(combo))
    combo$ver <- rep(NA,nrow(combo))
    ##For longitudes, choose E/W. For latitudes, choose N/S
    for (i in 1:dim(combo)[1])
      {
      if (as.numeric(combo$long[i])<0) {
        combo$hor[i] <- "W"
        } else {
          combo$hor[i] <- "E"
          }
      if (as.numeric(combo$lat[i])<0) {
        combo$ver[i] <- "S"
        } else {
          combo$ver[i] <- "N"
        }
      }
    ##Combine useful info into a .csv
    minimal.output <- data.frame(combo$name,combo$time,combo$long,combo$lat,combo$alt,combo$hor,combo$ver)
    colnames(minimal.output) <- c("name","time","long","lat","alt","hor","ver")
    ##Write the .csv
    write.csv(minimal.output, paste0(csv.out,"/",proj.name,"_exif_merge.csv"),row.names=F,quote=FALSE)
    ##Part 3: Retag the photos
    ##Progress bar
    print("Retag progress")
    pb <- txtProgressBar(min = 0, max = nrow(minimal.output), style = 3)
    ##Loop through all the photos tagging GPS info
    for (i in 1:nrow(minimal.output))
      {
      system(paste0(exif.tool.path," -overwrite_original -F -q -gpslongitude=",
                  minimal.output$long[i]," -gpslatitude=",minimal.output$lat[i],
                  " -gpslongituderef=",minimal.output$hor[i]," -gpslatituderef=",
                  minimal.output$ver[i]," -gpsaltitude=",minimal.output$alt[i],
                  " -gpsaltituderef=above ",photo.folder.path,"/",minimal.output$name[i]),
           inter=TRUE)
      setTxtProgressBar(pb, i)
      }
    close(pb)
}
