#' Extract GPS and attitude information for each photo position.
#'
#' @param timediff The difference in time between camera and GPS
#' @param photo.folder.path The location photos to be tagged
#' @param log.file.path The full path of the associated dataflash log
#' @param proj.name A name for this project (appended to output .csv)
#' @param csv.out Output folder for .csv file
#' @param leapsecs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @author James P. Duffy
#' @export

extract_gps_attitude_linux <-
  # arguments for exif retag
  function(timediff=0,photo.folder.path,log.file.path,proj.name,csv.out,
           leapsecs= seq(10:50)) {
    ##Leapsecs to default at 18 (as of December 2016)
    if(missing(leapsecs)){leapsecs = 18}
    ##Part 1: Obtain exif times
    exif.time.data <- as.data.frame(system(paste0(exiftool," -T -filename -createdate ",
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

    ##Log data in old format (less than 19 columns doesn't have attitude microseconds column). Can't process it.
    if(ncol(log.data)<19){
      stop("Cannot extract attitude information from this log.")
    }
    ##Filter out ATT data
    att.data <- dplyr::filter(log.data, V1=="ATT")
    ##Filter out relevant columns
    att.data <- dplyr::select(att.data, c(2,3,5,7))
    ##Add column names (ms_time is microseconds which is also found in GPS data)
    colnames(att.data) <- c("log_time","roll","pitch","yaw")

    ##Filter out GPS data
    gps.data <- dplyr::filter(log.data, V1=="GPS")
    ##Check the style of log (i.e. how many columns)
    ##Filter out relevant columns
    gps.data <- dplyr::select(gps.data, c(2,3:5,8:10))
    ##Add column names
    colnames(gps.data) <- c("log_time","status","timeMS","weeks","lat","long","alt")

    ##Select attitude data that most closely matches GPS data (based on microseconds)
    ##log_time is used to match readings from both the GPS and the ATT parts of the log.
    ##Find closest match in att.data for log_time in gps.data
    match.index <- sapply(gps.data$log_time, function(x){which.min(abs(att.data$log_time - x))})
    att.data.sub <- att.data[match.index,]

    ##Add roll pitch and yaw back into GPS data
    gps.data <- cbind(gps.data,att.data.sub[,2:4])

    ##Convert 'weeks' data into numeric values
    gps.data$weeks <- as.numeric(as.character(gps.data$weeks))
    ##Create a list of GPS 'epoch' dates on which to add GPS times to
    epoch <- data.frame(time=c(rep(epochdate,dim(gps.data)[1])))
    ##Format them correctly so 'seconds' can be added
    epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
    ##Add seconds calculated from the data to the 'epoch' times + timediff
    epoch$time <- epoch$time + (gps.data$weeks*secsweek) + (as.numeric(gps.data$timeMS)/1000) - leapsecs
    ##Add the time offset from particular dataset (defined at top of script)
    epoch$newtime <- epoch$time + timediff
    ##Split date and time into 2 (both old and new)
    epoch <- data.frame(do.call('rbind', strsplit(as.character(epoch$time),' ',fixed=TRUE)),do.call('rbind', strsplit(as.character(epoch$newtime),' ',fixed=TRUE)))
    ##Drop the extra date column (duplicate)
    epoch <- dplyr::select(epoch, -3)
    colnames(epoch) <- c("date","oldtime","time")
    ##Reshuffle data to get relevant information for merging with exif data
    gps.data <- data.frame(epoch$date,epoch$oldtime,epoch$time,gps.data$long,gps.data$lat,gps.data$alt,gps.data$roll,gps.data$pitch,gps.data$yaw)
    colnames(gps.data) <- c("date","oldtime","time","long","lat","alt","roll","pitch","yaw")
    ##Removes duplicates, just taking the first reading for each second
    gps.data <- subset(gps.data, !duplicated(gps.data$oldtime))
    ##Remove whitespace
    gps.data[c('long', 'lat', 'alt', 'time', 'roll', 'pitch', 'yaw')] <- lapply(gps.data[c('long', 'lat', 'alt', 'time', 'roll', 'pitch', 'yaw')], gsub, pattern=" ",replacement="")
    ##Tidy up dates and times to make them match
    gps.data$date <- gsub(":", "-", gps.data$date)
    exif.time.data$date <- gsub(":", "-", exif.time.data$date)
    combo <- merge(x=exif.time.data, y=gps.data, by= c("date","time"))
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
    minimal.output <- data.frame(combo$name,combo$time,combo$long,combo$lat,combo$alt,combo$hor,combo$ver,combo$roll,combo$pitch,combo$yaw)
    colnames(minimal.output) <- c("name","time","long","lat","alt","hor","ver","roll","pitch","yaw")
    ##Write the .csv
    write.csv(minimal.output, paste0(csv.out,"/",proj.name,"_gps_attitude.csv"),row.names=F,quote=FALSE)

  }
