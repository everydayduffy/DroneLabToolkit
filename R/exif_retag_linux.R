#' Retag images with GPS info from Ardupilot dataflash logs
#'
#' @param time_diff The difference in time between camera and GPS
#' @param img_path The location photos to be tagged
#' @param log_file The full path of the associated dataflash log
#' @param proj_name A name for this project (appended to output .csv)
#' @param csv_out Output folder for .csv file
#' @param leap_secs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @author James P. Duffy
#' @export

exif_retag_linux <-
  # arguments for exif retag
  function(time_diff=0,img_path,log_file,proj_name,csv_out,
           leap_secs= seq(10:50)) {

    ##Number of seconds in a week
    secs_week <- 604800
    ##GPS epoch date
    epoch_date <- "1980-01-06 00:00:00"

    ##leap_secs to default at 18 (as of December 2016)
    if(missing(leap_secs)){leap_secs = 18}
    ##Part 1: Obtain exif times
    exif_times <- as.data.frame(system(paste0("exiftool -T -filename -createdate ",
                                                  img_path), inter=TRUE))
    colnames(exif_times) <- "name_time_date"
    ##Tidy the data into separate columns
    exif_times <- tidyr::separate(exif_times, name_time_date,
                                  into =  c("name", "time"), sep ="\t") %>%
      tidyr::separate(.,time, into =  c("date", "time"), sep =" ") %>%
      data.frame()

    ##############################################
    ##Part 2: Match up photo times with log data##
    ##############################################

    ##Read in bin log that has been converted to .log file
    log_data <- read.delim(log_file, h=F, sep= ",",stringsAsFactors=FALSE)
    ##Filter out GPS data
    log_data <- dplyr::filter(log_data, V1=="GPS")
    ##Check the style of log (i.e. how many columns)
    if (ncol(log_data)<19) {
      add.val <- 0
    } else if (ncol(log_data)==19) {
      add.val <- 1
    }
    ##Filter out relevant columns
    log_data <- dplyr::select(log_data, c((2+add.val):(4+add.val),(7+add.val):(9+add.val)))
    ##Add column names
    colnames(log_data) <- c("status","timeMS","weeks","lat","long","alt")
    ##Convert 'weeks' data into numeric values
    log_data <- log_data %>%
      dplyr::mutate(.,weeks = as.numeric(as.character(weeks)))
    ##Create a list of GPS 'epoch' dates on which to add GPS times to
    epoch <- data.frame(time=c(rep(epoch_date,nrow(log_data))))
    ##Format them correctly so 'seconds' can be added
    epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
    ##Add seconds calculated from the data to the 'epoch' times + time_diff
    epoch$time <- epoch$time + (log_data$weeks*secs_week) + (as.numeric(log_data$timeMS)/1000) - leap_secs
    ##Add the time offset from particular dataset (defined at top of script)
    epoch$newtime <- epoch$time + time_diff
    ##Split date and time into 2 (both old and new)
    epoch <- data.frame(do.call('rbind', strsplit(as.character(epoch$time),' ',fixed=TRUE)),do.call('rbind', strsplit(as.character(epoch$newtime),' ',fixed=TRUE)))
    ##Drop the extra date column (duplicate)
    epoch <- dplyr::select(epoch, -3)
    colnames(epoch) <- c("date","oldtime","time")
    ##Reshuffle data to get relevant information for merging with exif data
    log_data <- data.frame(epoch$date,epoch$oldtime,epoch$time,log_data$long,log_data$lat,log_data$alt)
    colnames(log_data) <- c("date","oldtime","time","long","lat","alt")
    ##Removes duplicates, just taking the first reading for each second
    log_data <- subset(log_data, !duplicated(log_data$oldtime))
    ##Remove whitespace
    log_data[c('long', 'lat', 'alt', 'time')] <- lapply(log_data[c('long', 'lat', 'alt', 'time')], gsub, pattern=" ",replacement="")
    ##Tidy up dates and times to make them match
    log_data$date <- gsub(":", "-", log_data$date)
    exif_times$date <- gsub(":", "-", exif_times$date)
    combo <- merge(x=exif_times, y=log_data, by= c("date","time"))
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
    min_output <- data.frame(combo$name,combo$time,combo$long,combo$lat,combo$alt,combo$hor,combo$ver)
    colnames(min_output) <- c("name","time","long","lat","alt","hor","ver")
    ##Write the .csv
    write.csv(min_output, paste0(csv_out,"/",proj_name,"_exif_merge.csv"),row.names=F,quote=FALSE)
    ##Part 3: Retag the photos
    ##Progress bar
    print("Retag progress")
    pb <- txtProgressBar(min = 0, max = nrow(min_output), style = 3)
    ##Loop through all the photos tagging GPS info
    for (i in 1:nrow(min_output))
    {
      system(paste0("exiftool -overwrite_original -F -q -gpslongitude=",
                    min_output$long[i]," -gpslatitude=",min_output$lat[i],
                    " -gpslongituderef=",min_output$hor[i]," -gpslatituderef=",
                    min_output$ver[i]," -gpsaltitude=",min_output$alt[i],
                    " -gpsaltituderef=above ",img_path,"/",min_output$name[i]),
             inter=TRUE)
      setTxtProgressBar(pb, i)
    }
    close(pb)
  }
