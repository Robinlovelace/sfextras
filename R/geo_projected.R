#' Select a custom projected CRS for the area of interest
#'
#' This function takes a spatial object with a geographic (WGS84)
#' CRS and returns a custom projected CRS focussed on the centroid of the object.
#' This function is especially useful for using units of metres in all directions
#' for data collected anywhere in the world.
#'
#' The function is based on this stackexchange answer:
#' <https://gis.stackexchange.com/questions/121489>
#'
#' @param shp A spatial object with a geographic (WGS84) coordinate system
#' @export
#' @examples
#' nc = sf::st_read(system.file("shape/nc.shp", package="sf"))
#' geo_select_aeq(nc)
#' @export
geo_select_aeq <- function(shp) {
  cent <- sf::st_geometry(shp)
  coords <- sf::st_coordinates(shp)
  coords_mat <- matrix(coords[, 1:2], ncol = 2)
  midpoint <- apply(coords_mat, 2, mean)
  aeqd <- sprintf(
    "+proj=aeqd +lat_0=%s +lon_0=%s +x_0=0 +y_0=0",
    midpoint[2], midpoint[1]
  )
  sf::st_crs(aeqd)
}


#' Perform GIS functions on a temporary, projected version of a spatial object
#'
#' This function performs operations on projected data.
#'
#' @param shp A spatial object with a geographic (WGS84) coordinate system
#' @param fun A function to perform on the projected object (e.g. the the rgeos or sf packages)
#' @param crs An optional coordinate reference system (if not provided it is set
#' automatically by [geo_select_aeq()])
#' @param silent A binary value for printing the CRS details (default: TRUE)
#' @param ... Arguments to pass to `fun`, e.g. `byid = TRUE` if the function is `rgeos::gLength()`
#' @aliases gprojected
#' @export
#' @examples
#' lib_versions <- sf::sf_extSoftVersion()
#' lib_versions
#' nc = sf::st_read(system.file("shape/nc.shp", package="sf"))
#' shp <- nc[2:4, ]
#' # fails on some systems (with early versions of PROJ)
#' if (lib_versions[3] >= "6.3.1") {
#'   nc_buffer = geo_projected(shp, sf::st_buffer, dist = 1000)
#' }
geo_projected <- function(shp, fun, crs = geo_select_aeq(shp), silent = TRUE, ...) {
  # assume it's not projected  (i.e. lat/lon) if there is no CRS
  if (is.na(sf::st_crs(shp))) {
    sf::st_crs(shp) <- sf::st_crs(4326)
  }
  crs_orig <- sf::st_crs(shp)
  shp_projected <- sf::st_transform(shp, crs)
  if (!silent) {
    message(paste0("Running function on a temporary projection: ", crs$proj4string))
  }
  res <- fun(shp_projected, ...)
  if (grepl("sf", x = class(res)[1])) {
    res <- sf::st_transform(res, crs_orig)
  }
  res
}

#' Perform a buffer operation on a temporary projected CRS
#'
#' This function solves the problem that buffers will not be circular when used on
#' non-projected data.
#'
#' Requires recent version of PROJ (>= 6.3.0).
#' Buffers on `sf` objects with geographic (lon/lat) coordinates can also
#' be done with the [`s2`](https://r-spatial.github.io/s2/) package.
#'
#' @param shp A spatial object with a geographic CRS (e.g. WGS84)
#' around which a buffer should be drawn
#' @param dist The distance (in metres) of the buffer (when buffering simple features)
#' @param ... Arguments passed to the buffer (see `?rgeos::gBuffer` or `?sf::st_buffer` for details)
#' @examples
#' lib_versions <- sf::sf_extSoftVersion()
#' lib_versions
#' nc = sf::st_read(system.file("shape/nc.shp", package="sf"))
#' if (lib_versions[3] >= "6.3.1") {
#'   buff_sf <- geo_buffer(nc, dist = 50)
#'   plot(buff_sf$geometry)
#'   geo_buffer(nc$geometry, dist = 50)
#'   # on legacy sp objects (not tested)
#'   # buff_sp <- geo_buffer(routes_fast, width = 100)
#'   # class(buff_sp)
#'   # plot(buff_sp, col = "red")
#' }
#' @export
geo_buffer <- function(shp, dist = NULL,  ...) {
  geo_projected(shp, sf::st_buffer, dist = dist, ...)
}
#' Calculate line length of line with geographic or projected CRS
#'
#' Takes a line (represented in sf or sp classes)
#' and returns a numeric value representing distance in meters.
#' @param shp A spatial line object
#' @examples
#' lib_versions <- sf::sf_extSoftVersion()
#' lib_versions
#' nc = sf::st_read(system.file("shape/nc.shp", package="sf"))
#' if (lib_versions[3] >= "6.3.1") {
#'   geo_length(nc)
#' }
#' @export
geo_length <- function(shp) {
  l <- lwgeom::st_geod_length(shp)
  as.numeric(l)
}
