#' Calculate average altitude
#'
#' @keywords internal
#' @author James P. Duffy
#' @export

avg_alt <-
  function(x){
    # round altitude data
    dat <- round(as.numeric(x),0)
    # remove 0 values
    dat <- dat[dat > 0]
    # check to see if any values left
    if(length(dat)==0) {
      # if all were 0's output 0
      avg_alt <- 0
    } else {
      # calculate the mode altitude
      uniqdat <- unique(dat)
      avg_alt <- uniqdat[which.max(tabulate(match(dat, uniqdat)))]
    }
    return(avg_alt)
  }
