#' Extract GPS and attitude information for each image position.
#'
#' @param time_diff The difference in time between camera and GPS
#' @param img_path The location image to be tagged
#' @param log_file The full path of the associated dataflash log
#' @param proj_name A name for this project (appended to output .csv)
#' @param csv_out Output folder for .csv file
#' @param leap_secs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export


extract_attitude <-
  # arguments
  function(time_diff=0, img_path, log_file, proj_name, csv_out,
           leap_secs= seq(10:50)) {

    #function to prompt user for location of exiftool
    where_tool <- function() {
      x <- readline("What is the path of your exiftool install? (end with a '/')")
      return(x)
    }

    #if it's Windows, ask for the location of the tool
    if (.Platform$OS.type == "windows") {

      exif_loc <- paste0(where_tool(),"exiftool.exe")

      #else for linux and mac, the tool is in the path and can be blank
    } else {

      exif_loc <- "exiftool"
    }

    #leapsecs to default at 18 (as of December 2016)
    if(missing(leap_secs)){leap_secs = 18}

    #############################
    ##Part 1: Obtain exif times##
    #############################

    exif_times <- as.data.frame(system(paste0(exif_loc, " -T -filename -createdate ",
                                              img_path), inter=TRUE))

    colnames(exif_times) <- "name_date_time"
    #tidy the data into separate columns
    exif_times <- tidyr::separate(exif_times, name_date_time,
                                  into =  c("name", "date_time"), sep ="\t") %>%
      tidyr::separate(.,date_time, into =  c("date", "time"), sep =" ") %>%
      data.frame()

    ##############################################
    ##Part 2: Match up photo times with log data##
    ##############################################

    #number of seconds in a week
    secs_week <- 604800
    #GPS epoch date
    epoch_date <- "1980-01-06 00:00:00"
    #read in bin log that has been converted to .log file
    log_data <- read.delim(log_file, h=F, sep= ",",stringsAsFactors=FALSE)

    #log data in old format (less than 19 columns doesn't have attitude microseconds column). Can't process it.
    if(ncol(log_data)<19){
      stop("Cannot extract attitude information from this log as the information has not been logged.")
    }
    #filter out ATT data
    att_data <- dplyr::filter(log_data, V1=="ATT") %>%
      #filter out relevant columns
      dplyr::select(., c(2,3,5,7))
    #add column names (ms_time is microseconds which is also found in GPS data)
    colnames(att_data) <- c("log_time","roll","pitch","yaw")

    #filter out GPS data
    gps_data <- dplyr::filter(log_data, V1=="GPS") %>%
    #filter out relevant columns
      dplyr::select(., c(2,3:5,8:10))
    #add column names
    colnames(gps_data) <- c("log_time","status","timeMS","weeks","lat","lon","alt")

    #select attitude data that most closely matches GPS data (based on microseconds)
    #log_time is used to match readings from both the GPS and the ATT parts of the log.
    #find closest match in att.data for log_time in gps.data
    match_index <- sapply(gps_data$log_time, function(x){which.min(abs(att_data$log_time - x))})
    att_data_sub <- att_data[match_index,]

    #add roll pitch and yaw back into GPS data
    gps_data <- cbind(gps_data,att_data_sub[,2:4]) %>%
      #convert 'weeks' data into numeric values
      dplyr::mutate(., weeks = as.numeric(as.character(weeks)))

    #create a list of GPS 'epoch' dates on which to add GPS times to
    epoch <- data.frame(time=c(rep(epoch_date,dim(gps_data)[1])))
    #format them correctly so 'seconds' can be added
    epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
    #add seconds calculated from the data to the 'epoch' times + timediff
    epoch$time <- epoch$time + (gps_data$weeks*secs_week) + (as.numeric(gps_data$timeMS)/1000) - leap_secs
    #add the time offset from particular dataset (defined at top of script)
    epoch$newtime <- epoch$time + time_diff
    #split date and time into 2 (both old and new)
    epoch <- data.frame(do.call('rbind', strsplit(as.character(epoch$time),' ',fixed=TRUE)),do.call('rbind', strsplit(as.character(epoch$newtime),' ',fixed=TRUE)))
    #drop the extra date column (duplicate)
    epoch <- dplyr::select(epoch, -3)
    colnames(epoch) <- c("date","oldtime","time")
    #reshuffle data to get relevant information for merging with exif data
    gps_data <- data.frame(epoch$date,epoch$oldtime,epoch$time,gps_data$lon,gps_data$lat,gps_data$alt,gps_data$roll,gps_data$pitch,gps_data$yaw)
    colnames(gps_data) <- c("date","oldtime","time","lon","lat","alt","roll","pitch","yaw")
    #remove duplicates, just taking the first reading for each second
    gps_data <- subset(gps_data, !duplicated(gps_data$oldtime))
    #remove whitespace
    gps_data[c('lon', 'lat', 'alt', 'time', 'roll', 'pitch', 'yaw')] <- lapply(gps_data[c('lon', 'lat', 'alt', 'time', 'roll', 'pitch', 'yaw')], gsub, pattern=" ",replacement="")
    #tidy up dates and times to make them match
    gps_data$date <- gsub(":", "-", gps_data$date)
    exif_times$date <- gsub(":", "-", exif_times$date)

    #join image data to position data
    combo <- dplyr::left_join(exif_times, gps_data, by = c("date", "time")) %>%
      #apply NESW labels for exif tagging
      dplyr::mutate(., hor = dplyr::case_when(
        as.numeric(lon) < 0 ~ "W",
        as.numeric(lon) >= 0 ~ "E")) %>%
      dplyr::mutate(., ver = dplyr::case_when(
        as.numeric(lat) < 0 ~ "S",
        as.numeric(lat) >= 0 ~ "N")) %>%
      data.frame()

    #combine useful info into a .csv
    min_output <- data.frame(combo$name,combo$time,combo$lon,combo$lat,combo$alt,combo$hor,combo$ver,combo$roll,combo$pitch,combo$yaw)
    colnames(min_output) <- c("name","time","lon","lat","alt","hor","ver","roll","pitch","yaw")
    #write the .csv
    write.csv(min_output, paste0(csv_out,"/", proj_name, "_gps_attitude.csv"), row.names=F, quote=FALSE)

  }
