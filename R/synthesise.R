#' Synthesise dataflash logs
#'
#' @param in.folder The location of log files
#' @param out.folder The location for output file
#' @param out.name The name of the output text file. Default is 'Synthesised_Logs'
#' @param recursive Recursively search folders?
#' @param leapsecs Number leapseconds in GPS time since the epoch. default
#' is 18
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export

synthesise <-
  # arguments needed for synthesise
  function(in.folder,out.folder,out.name="Synthesised_Logs",recursive=FALSE,leapsecs= seq(10:50),...){
    ##Leapsecs to default at 18 (as of December 2016)
    if(missing(leapsecs)){leapsecs = 18}
    ##Default in and out directories working directory
    if(missing(in.folder)){in.folder=getwd()}
    if(missing(out.folder)){out.folder=getwd()}
    ##Number of seconds in a week
    secsweek <- 604800
    ##GPS epoch date
    epochdate <- "1980-01-06 00:00:00"
    ##List all potential log files
    #files <- Sys.glob(paste0(in.folder,"/*.log"))
    if(recursive==TRUE){
      files <- list.files(path=in.folder, pattern="*\\.log$", recursive=TRUE)
    } else {
      files <- list.files(path=in.folder, pattern="*\\.log$", recursive=FALSE)
    }
    ##Check valid files are present
    if(length(files)==0){
      stop('No valid log files found. Please choose a directory with .log files in it.')
    }
    ##Create short file names without path
    short.files <- gsub(paste0(in.folder,"/"), "", files)
    ##Create output
    output <- as.data.frame(matrix(,length(files),9))
    colnames(output) <- c("Log_Name","Date","Time","Lat","Long",
                          "GPS_Duration_mins","Avg_Alt","Max_Alt","Firmware")
    output$Log_Name <- short.files
    for (i in 1:length(files))
    {
      ##Read in the .log file
      logname <- files[i]
      raw.data <- read.delim(paste0(in.folder,"/",logname),h=F,sep=",",
                             stringsAsFactors=FALSE)
      print(paste0("Processing ",short.files[i]))
      ##Subset the GPS data
      gps.data <- raw.data[which(raw.data[,1]=="GPS"),]
      print("Extracting GPS data")
      ##Add a check for whether GPS data is present, if not skips to near end of loop
      if (dim(gps.data)[1]!=0) {
        ##Add a check for the type of log and adjust column searches
        if (dim(raw.data)[2]<19) {
          add.val <- 0
        }
        else if (dim(raw.data)[2]==19) {
          add.val <- 1
        }
        ##Subset MSG data
        ##Save firmware version to output
        print("Extracting Firmware version")
        msg.data <- raw.data[which(raw.data[,1]=="MSG"),]
        ##Grep the firmware version from the MSG part of the log (select the first if there are multiple)
        output$Firmware[i] <- msg.data[grep("Ardu|APM:",msg.data[,(2+add.val)]),(2+add.val)][1]
        ##Get rid of white space in 'GPS Status column' so that it can be
        ##checked properly
        gps.data[,2+add.val] <- gsub(" ", "",gps.data[,(2+add.val)])
        ##Check for 3D fixes
        if (max(gps.data[,2+add.val])>=3) {
          ##Filter out data that is only 3D fixes
          gps.data <- gps.data[which(gps.data[,2+add.val]>=3),]
          ##Get mean lat and long values and store in table
          output$Lat[i] <- mean(as.numeric(gps.data[1:dim(gps.data)[1],(7+add.val)]))
          output$Long[i] <- mean(as.numeric(gps.data[1:dim(gps.data)[1],(8+add.val)]))
          ##Get GPS start and end times to create duration value
          ##Filter out relevant columns
          sub.gps.data <- data.frame(gps.data[,(2+add.val):(4+add.val)],gps.data[,(7+add.val):(9+add.val)])
          ##Add column names
          colnames(sub.gps.data) <- c("status","timeMS","weeks","lat","long","alt")
          ##Convert 'weeks' data into numeric values
          sub.gps.data$weeks <- as.numeric(as.character(sub.gps.data$weeks))
          ##Create a list of GPS 'epoch' dates on which to add GPS times to
          epoch <- data.frame(time=c(rep(epochdate,dim(sub.gps.data)[1])))
          ##Format them correctly so 'seconds' can be added
          epoch$time <- strptime(epoch$time,"%Y-%m-%d %H:%M:%S")
          ##Add seconds calculated from the data to the 'epoch' times
          epoch$time <- epoch$time + (sub.gps.data$weeks*secsweek) + (as.numeric(sub.gps.data$timeMS)/1000) - leapsecs
          ##Store time and date separately in output file
          output$Date[i] <- strsplit(as.character(epoch$time[1])," +")[[1]][1]
          output$Time[i] <- strsplit(as.character(epoch$time[1])," +")[[1]][2]
          ##Calculate time difference in minutes (using first and last date/times)
          output$GPS_Duration_mins[i] <- round(as.numeric(difftime(epoch$time[dim(epoch)[1]],epoch$time[1],units="mins")),2)
          ##Format time into mm:ss
          temp1 <- strsplit(as.character(output$GPS_Duration_mins[i]),"[.]")
          ##If the value is a whole number (i.e just mins, no secs)
          if (length(temp1[[1]])==1) {
            output$GPS_Duration_mins[i] <- paste0(temp1[[1]][1],":00")
          } else {
            ##If the seconds value is 2 digits (more than 9 seconds), then stitch them next to minutes
            if (round((as.numeric(temp1[[1]][2])/100)*60,0)>9) {
              output$GPS_Duration_mins[i] <- paste0(temp1[[1]][1],":",round((as.numeric(temp1[[1]][2])/100)*60,0))
              ##Otherwise, add a trailing 0 before stitching
            } else {
              output$GPS_Duration_mins[i] <- paste0(temp1[[1]][1],":0",round((as.numeric(temp1[[1]][2])/100)*60,0))
            }
            ##Extract average (mode) altitude (rounded) to determine mission altitude
            avg.alt.raw.data <- round(as.numeric(sub.gps.data$alt),0)
            output$Avg_Alt[i] <- names(table(avg.alt.raw.data))[table(avg.alt.raw.data)==max(table(avg.alt.raw.data))]
            ##Extract max altitutde to determine if flight was proper
            output$Max_Alt[i] <- max(as.numeric(sub.gps.data$alt))
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
    write.table(output,paste0(out.folder,"/",out.name,".txt"),row.names=F,
                sep = ",")
  }
