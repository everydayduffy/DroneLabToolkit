#' Synthesise dataflash logs
#'
#' @param log_path The location of log files
#' @param out_path The location for output file
#' @param out_name The name of the output text file. Default is 'synthesised_Logs'
#' @param recursive Recursively search folders?
#' @param leap_secs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export


synthesise <-
  #arguments needed for synthesise
  function(log_path, out_path, out_name="synthesised_Logs",
           recursive=FALSE, leap_secs= seq(10:50), ...){
    #leap_secs to default at 18 (as of December 2016)
    if(missing(leap_secs)){leap_secs = 18}
    #default in and out directories working directory
    if(missing(log_path)){log_path=getwd()}
    if(missing(out_path)){out_path=getwd()}

    #number of seconds in a week
    secs_week <- 604800
    #GPS epoch date
    epoch_date <- "1980-01-06 00:00:00"

    #list all potential log files
    if(recursive==TRUE) {
      files <- list.files(path=log_path, pattern="*\\.log$", recursive=TRUE)
    } else {
      files <- list.files(path=log_path, pattern="*\\.log$", recursive=FALSE)
    }

    #check valid files are present
    if(length(files)==0){
      stop('No valid log files found. Please choose a directory with .log files in it.')
    }

    #create short file names without path
    short_files <- gsub(paste0(log_path,"/"), "", files)
    #create output
    output <- as.data.frame(matrix(,length(files),9))
    colnames(output) <- c("log_name","date","time","lat","lon",
                          "gps_dur_mins","avg_alt","max_alt","firmware")
    output$log_name <- short_files


    for (i in 1:length(files))
    {
      #read in the .log file
      logname <- files[i]

      raw_data <- read.delim(paste0(log_path,"/",logname),h=F,sep=",",
                             stringsAsFactors=FALSE)

      print(paste0("Processing ",short_files[i]))

      #subset the GPS data
      gps_data <- raw_data %>%
        dplyr::filter(.,V1 == "GPS") %>%
        data.frame

      print("Extracting GPS data")

      #check for whether GPS data is present, if not skips to near end of loop
      if (dim(gps_data)[1]!=0) {
        #check for the type of log and adjust column searches
        if (dim(raw_data)[2]<19) {
          add_val <- 0
        }
        else if (dim(raw_data)[2]==19) {
          add_val <- 1
        }


        #save firmware version to output
        print("Extracting firmware version")

        #subset message data
        msg_data <- raw_data %>%
          dplyr::filter(.,V1 == "MSG") %>%
          data.frame()


        #grep the firmware version from the MSG part of the log (select
        #the first if there are multiple)
        output$firmware[i] <- msg_data[grep("Ardu|APM:",msg_data[,(2+add_val)]),
                                       (2+add_val)][1]
        #remove white space in 'GPS Status column' so that it can be
        #checked properly
        gps_data[,2+add_val] <- gsub(" ", "",gps_data[,(2+add_val)])


        #check for 3D fixes
        if (max(gps_data[,2+add_val])>=3) {
          #filter out data that is only 3D fixes
          gps_data <- gps_data[which(gps_data[,2+add_val]>=3),]
          #get mean lat and lon values and store in table
          output$lat[i] <- mean(as.numeric(gps_data[1:dim(gps_data)[1],
                                                    (7+add_val)]))
          output$lon[i] <- mean(as.numeric(gps_data[1:dim(gps_data)[1],
                                                     (8+add_val)]))
          #get GPS start and end times to create duration value
          #filter out relevant columns
          sub_gps_data <- data.frame(gps_data[,(2+add_val):(4+add_val)],
                                     gps_data[,(7+add_val):(9+add_val)])

          colnames(sub_gps_data) <- c("status","timeMS","weeks","lat","lon",
                                      "alt")


          #convert 'weeks' data into numeric values
          sub_gps_data$weeks <- as.numeric(as.character(sub_gps_data$weeks))
          #create a list of GPS 'epoch' dates on which to add GPS times to
          epoch <- data.frame(time=c(rep(epoch_date,dim(sub_gps_data)[1])))
          #format them correctly so 'seconds' can be added
          epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
          #add seconds calculated from the data to the 'epoch' times
          epoch$time <- epoch$time + (sub_gps_data$weeks*secs_week) +
            (as.numeric(sub_gps_data$timeMS)/1000) - leap_secs
          #store time and date separately in output file
          output$date[i] <- strsplit(as.character(epoch$time[1])," +")[[1]][1]
          output$time[i] <- strsplit(as.character(epoch$time[1])," +")[[1]][2]
          #calculate time difference in minutes (using first and last date/times)
          output$gps_dur_mins[i] <- round(as.numeric(difftime(epoch$time[dim(epoch)[1]],
                                                                   epoch$time[1],units="mins")),2)


          #format time into mm:ss
          time_data <- strsplit(as.character(output$gps_dur_mins[i]),"[.]")
          #if the value is a whole number (i.e just mins, no secs)
          if (length(time_data[[1]])==1) {
            output$gps_dur_mins[i] <- paste0(time_data[[1]][1],":00")
          } else {
            #if the seconds value is 2 digits (more than 9 seconds), then stitch them next to minutes
            if (round((as.numeric(time_data[[1]][2])/100)*60,0)>9) {
              output$gps_dur_mins[i] <- paste0(time_data[[1]][1],":",
                                                    round((as.numeric(time_data[[1]][2])/100)*60,0))
              #otherwise, add a trailing 0 before stitching
            } else {
              output$gps_dur_mins[i] <- paste0(time_data[[1]][1],":0",
                                                    round((as.numeric(time_data[[1]][2])/100)*60,0))
            }
            #extract average (mode) altitude (rounded) to determine mission altitude
            output$avg_alt[i] <- avg_alt(sub_gps_data$alt)
            #extract max altitude (rounded)
            output$max_alt[i] <- max_alt(sub_gps_data$alt)
          }
        }
        else {
          print("No 3D fix data found")
          output[i,2:6] <- NA
        }
      }
      else {
        print("No data found")
      }
    }
    write.table(output,paste0(out_path,"/",out_name,".txt"),row.names=F,
                sep = ",")
  }
