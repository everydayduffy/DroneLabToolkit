#' Convert coordinates found in GPS exif tags
#'
#' @param in.path The full path of input photos
#' @param out.path The full path for output photos
#' @param crs.in The native coordinate system
#' @param crs.out The target coordinate system
#' @author James P. Duffy
#' @export


coord_convert_linux <-
  function(in.path,out.path,crs.in="+init=epsg:4326",crs.out="+init=epsg:27700"){
  ##Extract GPS information original photographs
  raw.data <- as.data.frame(system(paste0("exiftool -T -n -filename -gpslongitude -gpslatitude -gpsaltitude ",
                                          in.path), inter=TRUE))
  colnames(raw.data) <- "all"
  exif.data <- raw.data %>%
    tidyr::separate(all, into =  c("name", "longitude","latitude", "altitude"), sep = "\t")
  coords <- cbind(Easting =as.numeric(as.character(exif.data$longitude)),
                  Northing =as.numeric(as.character(exif.data$latitude)))
  exif.data.sp <-SpatialPointsDataFrame(coords,
                                        data=data.frame(exif.data$name,exif.data$altitude),
                                        proj4string=CRS(crs.in))
  exif.data.sp.out <-spTransform(exif.data.sp,CRS(crs.out))
  ##Progress bar
  print("Retag progress")
  pb <- txtProgressBar(min = 0, max = nrow(exif.data.sp.out), style = 3)
  ##Loop through all the photos tagging GPS info
  for (i in 1:nrow(exif.data.sp.out)) {
    system(paste0("exiftool -overwrite_original -q -gpslongitude=", exif.data.sp.out@coords[i,1],
                  " -gpslatitude=", exif.data.sp.out@coords[i,2], " -gpsaltitude=",
                  exif.data.sp.out@data$exif.data.altitude[i]," -gpslatituderef=N",
                  " -gpslongituderef=E", " -gpsaltituderef=above ",out.path, "/",
                  exif.data.sp.out@data$exif.data.name[i]), inter = TRUE)
    setTxtProgressBar(pb, i)
  }
  close(pb)
}
