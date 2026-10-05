#' Read zip-archive
#'
#' @param .pth path to zip-archive
#' @param .archive actual zip-file
#' @param .path_unzip any temp folder path for the unzipped archive
#' @param .files vector of filenames in zip-archive
#' @param ...
#'
#' @return
#' @export
#'
#' @examples
read_zip <- function( .pth, .archive, .files = NULL, .path_unzip = "tmp_unzip"
                      ,.show_col_types = FALSE, ...){
  # create tmp_dir, if not existing
  if(! dir.exists(.path_unzip)) dir.create(.path_unzip)
  # unzip archive
  this_zip <- paste(.pth, .archive, sep = "/")
  # extract subset from zip archive -------------------------------------
  if(is.null(.files)){
    unzip(this_zip, exdir = .path_unzip, junkpaths = TRUE)
  }else{
    unzip(this_zip, files = .files, exdir = .path_unzip, junkpaths = TRUE)
  }
  # check for files -----------------------------------------------------
  # detect file extension and extract with associated helper
  fns <- list.files(path = .path_unzip, full.names = TRUE)
  codec <- detect_file_extension(fns)
  
  if(codec == "xlsx"){
    ds <- purrr::map(.x = fns,
                     .f = ~ readxl::read_xlsx(.x, col_types = "text")
    )
  }
  if(codec == "csv"){
    #ds  <- purrr::map_df(fns, readr::read_csv2, ...)
    ds <- purrr::map( .x = fns,
                      ,.f = ~ read_csv12(.x, .colspec = NULL, .show_col_types = .show_col_types, ...)
    )
  }
  if(codec == "parquet"){
    ds <- purrr::map( .x = fns,
                      ,.f = ~ arrow::read_parquet(.x)
    )
  }
  # #clean up (remove temp dir) -------------------------------------------
  unlink(.path_unzip, recursive = TRUE)
  
  if(length(ds) == 1) ds <- ds[[1]]  # single element - return tibble
  
  return(ds)
}


check_zip_content <- function(.pth, .archive, ...){
  # go and look into archive
  this_zip <- paste(.pth, .archive, sep = "/")
  unzip(this_zip, list = TRUE)
}

filter_zip_content <- function(.pth, .archive, .pattern = NULL, ...){
  my_content <- check_zip_content(.pth, .archive)
  if(is.null(.pattern)){
    warning("YOU NEED TO PROVIDE A PATTERN")
    return(my_content)
  }else{
    my_content <- my_content |>
      dplyr::filter(grepl(pattern = .pattern, x = Name)) |>
      dplyr::pull(Name)
    return(my_content)
  }
}

detect_file_extension <- function(.filename_vec){
  ext <- .filename_vec |> tools::file_ext() |> unique()
  return(ext)
}

#' Read csv files switching csv and csv2
#'
#' Utility function wrapper for readr::read_csv and readr::read_csv2.
#' Function tests the csv file and then picks the respective parser csv or csv2.
#'
#' @param .fn filename (including file path)
#' @param .colspec optional reading of selective columns
#' @param ...
#'
#' @return
#' @export
#'
#' @examples
read_csv12 <- function(.fn, .colspec = NULL, .show_col_types = FALSE, ...){
  # test for csv or csv2
  tst <- readr::read_csv(.fn, n_max = 3, show_col_types = .show_col_types)
  siz <- dim(tst)[2]   # dim[2] == 1 for semicolon as read_csv expects comma
  
  # read data files
  if(siz > 1){
    df <- readr::read_csv(.fn, col_types = .colspec, show_col_types = .show_col_types)
  }else{
    df <- readr::read_csv2(.fn, col_types = .colspec, show_col_types = .show_col_types)
  }
  return(df)
}
