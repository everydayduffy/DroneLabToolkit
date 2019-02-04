#' Format time and date
#'
#' @keywords internal
#' @author James P. Duffy
#' @export

format_time_date <- function(weeks, mS, epoch_date, leap_secs) {

  secs_week <- 604800

  #convert 'weeks' data into numeric values
  weeks <- as.numeric(as.character(weeks))
  #create a list of GPS 'epoch' dates on which to add GPS times to
  epoch <- data.frame(time=c(rep(epoch_date,length(weeks))))
  #format them correctly so 'seconds' can be added
  epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
  #add seconds calculated from the data to the 'epoch' times
  epoch$time <- epoch$time + (weeks*secs_week) +
    (as.numeric(sub_gps_data$timeMS)/1000) - leap_secs
  #store time and date separately in output file
  out_date <- strsplit(as.character(epoch$time[1])," +")[[1]][1]
  out_time <- strsplit(as.character(epoch$time[1])," +")[[1]][2]
  #calculate time difference in minutes (using first and last date/times)
  out_dur_mins <- round(as.numeric(difftime(epoch$time[dim(epoch)[1]],
                                                      epoch$time[1],units="mins")),2)
  #format time into mm:ss
  time_data <- strsplit(as.character(out_dur_mins),"[.]")
  #if the value is a whole number (i.e just mins, no secs)
  if (length(time_data[[1]])==1) {
    out_dur_mins <- paste0(time_data[[1]][1],":00")
  } else {
    #if the seconds value is 2 digits (more than 9 seconds), then stitch them next to minutes
    if (round((as.numeric(time_data[[1]][2])/100)*60,0)>9) {
      out_dur_mins <- paste0(time_data[[1]][1],":",
                                       round((as.numeric(time_data[[1]][2])/100)*60,0))
      #otherwise, add a trailing 0 before stitching
    } else {
      out_dur_mins <- paste0(time_data[[1]][1],":0",
                                       round((as.numeric(time_data[[1]][2])/100)*60,0))
    }
  }
  return(c(out_date, out_time, out_dur_mins))
}
