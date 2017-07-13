#' Convert coordinates found in GPS exif tags
#'
#' @param in.path The full path of input photos
#' @param crs.in The native coordinate system
#' @param crs.out The target coordinate system
#' @param exif.tool.path Full path of exiftool.exe location
#' @param csv Write a .csv file with converted coordinates?
#' @importFrom magrittr "%>%"
#' @author James P. Duffy
#' @export

coord_convert_windows <-
  function(in.path,crs.in="+init=epsg:4326",crs.out="+init=epsg:27700",
           exif.tool.path, csv=TRUE){
  ##Extract GPS information original photographs
  raw.data <- as.data.frame(system(paste0(exif.tool.path,
                                          " -T -n -filename -gpslongitude -gpslatitude -gpsaltitude ",
                                          in.path), inter=TRUE))
  colnames(raw.data) <- "all"
  exif.data <- raw.data %>%
    tidyr::separate(all, into =  c("name", "longitude","latitude", "altitude"), sep = "\t")
  coords <- cbind(Easting =as.numeric(as.character(exif.data$longitude)),
                  Northing =as.numeric(as.character(exif.data$latitude)))
  exif.data.sp <-sp::SpatialPointsDataFrame(coords,
                                        data=data.frame(exif.data$name,exif.data$altitude),
                                        proj4string=CRS(crs.in))
  exif.data.sp.out <-sp::spTransform(exif.data.sp,sp::CRS(crs.out))

  if(csv==TRUE) {
    csv.out <- as.data.frame(exif.data.sp.out)
    write.csv(csv.out,paste0(in.path,"/converted_coords.csv"),row.names = FALSE)
    print(paste0("CSV file written to ",in.path))
  }

  ##Progress bar
  print("Retag progress")
  pb <- txtProgressBar(min = 0, max = nrow(exif.data.sp.out), style = 3)
  ##Loop through all the photos tagging GPS info
  for (i in 1:nrow(exif.data.sp.out)) {
    system(paste0(exif.tool.path," -overwrite_original -q -gpslongitude=", exif.data.sp.out@coords[i,1],
                  " -gpslatitude=", exif.data.sp.out@coords[i,2], " -gpsaltitude=",
                  exif.data.sp.out@data$exif.data.altitude[i]," -gpslatituderef=N",
                  " -gpslongituderef=E", " -gpsaltituderef=above ",in.path, "/",
                  exif.data.sp.out@data$exif.data.name[i]), inter = TRUE)
    setTxtProgressBar(pb, i)
  }
  close(pb)
  }
