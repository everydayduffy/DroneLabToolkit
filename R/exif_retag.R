#' Retag images with GPS info from Ardupilot dataflash logs
#'
#' @param time_diff The difference in time between camera and GPS
#' @param img_path The location images to be tagged
#' @param log_file The full path of the associated dataflash log
#' @param proj_name A name for this project (appended to output .csv)
#' @param csv_out Output folder for .csv file
#' @param exif_loc Location of *exiftool.exe* (Windows only)
#' @param leap_secs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export

exif_retag <-
  # arguments for exif retag
  function(time_diff=0,img_path,log_file,proj_name,csv_out,exif_loc,
           leap_secs= seq(10:50)) {

    #function to prompt user for location of exiftool
    where_tool <- function() {
      x <- readline("What is the path of your exiftool install? (end with a '/')")
      return(x)
    }

    # if location not provided...
    if(missing(exif_loc)) {

      #if it's Windows, ask for the location of the tool
      if (.Platform$OS.type == "windows") {

        exif_loc <- paste0(where_tool(),"exiftool.exe")

        #else for linux and mac, the tool is in the path and can be blank
      } else {

        exif_loc <- "exiftool"
      }
    }

    #number of seconds in a week
    secs_week <- 604800
    #GPS epoch date
    epoch_date <- "1980-01-06 00:00:00"

    #leap_secs to default at 18 (as of December 2016)
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
    ##Part 2: Match up image times with log data##
    ##############################################

    #read in bin log that has been converted to .log file
    log_data <- read.delim(log_file, h=F, sep= ",",stringsAsFactors=FALSE)
    #filter out GPS data
    log_data <- dplyr::filter(log_data, V1=="GPS")
    #check the style of log (i.e. how many columns)
    if (ncol(log_data)<19) {
      add.val <- 0
    } else if (ncol(log_data)==19) {
      add.val <- 1
    }
    #filter out relevant columns
    log_data <- dplyr::select(log_data, c((2+add.val):(4+add.val),(7+add.val):(9+add.val)))
    #add column names
    colnames(log_data) <- c("status","timeMS","weeks","lat","lon","alt")
    #convert 'weeks' data into numeric values
    log_data <- log_data %>%
      dplyr::mutate(.,weeks = as.numeric(as.character(weeks)))
    #create a list of GPS 'epoch' dates on which to add GPS times to
    epoch <- data.frame(time=c(rep(epoch_date,nrow(log_data))))
    #format them correctly so 'seconds' can be added
    epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
    #add seconds calculated from the data to the 'epoch' times + time_diff
    epoch$time <- epoch$time + (log_data$weeks*secs_week) + (as.numeric(log_data$timeMS)/1000) - leap_secs
    #add the time offset from particular dataset (defined at top of script)
    epoch$newtime <- epoch$time + time_diff

    #split date and time into 2 (both old and new) and format
    epoch <- epoch %>%
      tidyr::separate(.,time, c("date1","oldtime"), sep = " ") %>%
      tidyr::separate(.,newtime, c("date2","time"), sep = " ") %>%
      dplyr::select(., -date2) %>%
      dplyr::rename(date = date1) %>%
      data.frame()

    #reshuffle data to get relevant information for merging with exif data
    log_data <- data.frame(epoch$date,epoch$oldtime,epoch$time,log_data$lon,log_data$lat,log_data$alt)
    colnames(log_data) <- c("date","oldtime","time","lon","lat","alt")

    log_data <- log_data %>%
      #remove duplicate times (one reading per second)
      dplyr::distinct(., oldtime, .keep_all=TRUE) %>%
      #tidy up whitespace
      dplyr::mutate(., lon = gsub(" ", "", lon)) %>%
      dplyr::mutate(., lat = gsub(" ", "", lat)) %>%
      dplyr::mutate(., alt = gsub(" ", "", alt)) %>%
      dplyr::mutate(., time = gsub(" ", "", time)) %>%
      #tidy up dates and times to make them match
      dplyr::mutate(., date = gsub(":", "-", date)) %>%
      data.frame()

    #tidy up dates and times to make them match
    exif_times <- dplyr::mutate(exif_times, date = gsub(":", "-", date))

    #join image data to position data
    combo <- dplyr::left_join(exif_times, log_data, by = c("date", "time")) %>%
      #apply NESW labels for exif tagging
      dplyr::mutate(., hor = dplyr::case_when(
        as.numeric(lon) < 0 ~ "W",
        as.numeric(lon) >= 0 ~ "E")) %>%
      dplyr::mutate(., ver = dplyr::case_when(
        as.numeric(lat) < 0 ~ "S",
        as.numeric(lat) >= 0 ~ "N")) %>%
      data.frame()

    #combine useful info into a .csv
    min_output <- combo %>%
      dplyr::select(., name, time, lon, lat, alt, hor, ver) %>%
      data.frame()

    #write the .csv
    write.csv(min_output, paste0(csv_out,"/",proj_name,"_exif_merge.csv"),row.names=F,quote=FALSE)

    ############################
    ##Part 3: Retag the images##
    ############################

    ##Progress bar
    print("Retag progress")
    pb <- txtProgressBar(min = 0, max = nrow(min_output), style = 3)
    ##Loop through all the images tagging GPS info
    for (i in 1:nrow(min_output))
    {
      system(paste0(exif_loc, " -overwrite_original -F -q -gpslongitude=",
                    min_output$lon[i]," -gpslatitude=",min_output$lat[i],
                    " -gpslongituderef=",min_output$hor[i]," -gpslatituderef=",
                    min_output$ver[i]," -gpsaltitude=",min_output$alt[i],
                    " -gpsaltituderef=above ",img_path,"/",min_output$name[i]),
             inter=TRUE)
      setTxtProgressBar(pb, i)
    }
    close(pb)
}
