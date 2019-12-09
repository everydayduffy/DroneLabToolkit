#' Estimate the time difference between a dataflash log and image capture time.
#' Currently returns the time differences for a photo taken at ~4 m altitude after take-off.
#'
#' @param log_file The full path of the dataflash log
#' @param img_file The full path of the image
#' @param exif_loc Location of exiftool.exe (Windows only)
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export


find_time_diff <-
  function(log_file, img_file, exif_loc, leap_secs = seq(10:50)) {

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
    epoch_date <- lubridate::ymd_hms("1980-01-06 00:00:00")

    #leap_secs to default at 18 (as of December 2016)
    if(missing(leap_secs)){leap_secs = 18}

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
      dplyr::mutate(.,weeks = as.numeric(as.character(weeks))) %>%
      tibble::as_tibble()

    #create a list of GPS 'epoch' dates on which to add GPS times to
    epoch <- data.frame(time=c(rep(epoch_date,nrow(log_data)))) %>%
      dplyr::mutate(., time = time + (log_data$weeks*secs_week) + (as.numeric(log_data$timeMS)/1000) - leap_secs) %>%
      tibble::as_tibble()

    log_data <- epoch %>%
      dplyr::bind_cols(.,log_data) %>% # join to log data
      dplyr::select(., time, lon ,lat, alt) %>%
      dplyr::mutate(., alt = as.numeric(alt)) %>%
      dplyr::mutate(., alt = ceiling(alt) - ceiling(alt) %% 2) %>% # round to even numbers
      dplyr::filter(., alt == 4) %>%
      tibble::as_tibble()

    log_time_4m <- log_data$time[1] # the first reading @ ~4 m
    photo_time_4m <- lubridate::ymd_hms(system(paste0(exif_loc,
                                                      " -T -createdate ", img_file),
                                               inter=TRUE)) # time from photo
    # work out time difference
    time_diff <- as.numeric(photo_time_4m - log_time_4m, units = "secs")

    return(round(time_diff))
}
