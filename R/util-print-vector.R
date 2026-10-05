#' Print vector elements as comma list
#'
#' @param vec 
#'
#' @return string to print
#' @export
#'
#' @examples
print_vector <- function(vec, .last_append = ", and") {
  if (length(vec) == 1) {          # single element only ------------------
    return(vec)
  } else if (length(vec) == 2) {   # vector of 2 elements -----------------
    return(paste(vec, collapse = " and "))
  } else {
    return(paste(
              paste(vec[-length(vec)], collapse = ", ")
          , .last_append
          , vec[length(vec)]
          )
          )
  }
}