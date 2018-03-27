#' Convert coordinates found in GPS exif tags
#'
#' @param img_path The full path of input photos
#' @param crs_in The native coordinate system
#' @param crs_out The target coordinate system
#' @param csv Write a .csv file with converted coordinates?
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export

exif_coord_convert <-
  function(img_path, crs_in="+init=epsg:4326", crs_out="+init=epsg:27700", csv=TRUE){

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

    #extract GPS information original images
    raw_data <- as.data.frame(system(paste0(exif_loc, " -T -n -filename",
                                            " -gpslongitude -gpslatitude",
                                            " -gpsaltitude ", img_path),
                                     inter=TRUE))

    colnames(raw_data) <- "all"
    exif_data <- raw_data %>%
      tidyr::separate(all, into =  c("name", "longitude","latitude",
                                     "altitude"), sep = "\t")
    coords <- cbind(Easting =as.numeric(as.character(exif_data$longitude)),
                    Northing =as.numeric(as.character(exif_data$latitude)))
    exif_data_sp <-sp::SpatialPointsDataFrame(coords,
                                              data=data.frame(exif_data$name,
                                                              exif_data$altitude),
                                              proj4string=sp::CRS(crs_in))
    exif_data_sp_out <-sp::spTransform(exif_data_sp,sp::CRS(crs_out))

    if(csv==TRUE) {
      csv_out <- as.data.frame(exif_data_sp_out)
      write.csv(csv_out,paste0(img_path,"/converted_coords.csv"),row.names = FALSE)
      print(paste0("CSV file written to ",img_path))
    }

    #progress bar
    print("Retag progress")
    pb <- txtProgressBar(min = 0, max = nrow(exif_data_sp_out), style = 3)
    #loop through all the photos tagging GPS info
    for (i in 1:nrow(exif_data_sp_out)) {
      system(paste0(exif_loc, " -overwrite_original -q -gpslongitude=", exif_data_sp_out@coords[i,1],
                    " -gpslatitude=", exif_data_sp_out@coords[i,2], " -gpsaltitude=",
                    exif_data_sp_out@data$exif_data.altitude[i]," -gpslatituderef=N",
                    " -gpslongituderef=E", " -gpsaltituderef=above ",img_path, "/",
                    exif_data_sp_out@data$exif_data.name[i]), inter = TRUE)
      setTxtProgressBar(pb, i)
    }
    close(pb)
  }
