# ==========================================================
# UGLC-based MDL Event Extraction within 30 km of NEH Stations
#
# Purpose:
# This script extracts UGLC landslide events located within 30 km
# of each NEH station and classifies moisture-driven landslides (MDLs)
# using hydrometeorological trigger keywords.
#
# Main steps:
# 1. Read NEH station metadata.
# 2. Read UGLC point inventory using a robust parser.
# 3. Enforce unique landslide events using NEWDATASET + ID.
# 4. Identify MDL events using rainfall/wetness-related trigger keywords.
# 5. Extract MDL events within 30 km of each station.
#
# Output:
# 1. Station-wise MDL files:
#    Uglc_<StationID>.txt
#
#    Columns:
#    Lon  Lat  Distance_km  Year  Month  Day  EventID
#
# 2. Summary Excel file:
#    UGLC_MDL_summary_within30km.xlsx
# ==========================================================


library(data.table)
library(readxl)
library(openxlsx)
library(geosphere)

has_stringi <- requireNamespace("stringi", quietly = TRUE)


# ================= USER SETTINGS =================

uglc_file <- "C:/lews_2022-2024/UGLC_point.csv"

metadata_file <- "C:/lews_2022-2024/3_new_stations_neh_new/all_stations_neh.xlsx"

output_folder <- "C:/lews_2022-2024/3_new_stations_neh_new/4__UGLC/UGLC_MDL_within30km/"

if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}

search_radius_km <- 30


# ================= HELPER FUNCTIONS =================

get_column_name <- function(df, candidates) {
  idx <- which(names(df) %in% candidates)
  if (!length(idx)) return(NULL)
  names(df)[idx[1]]
}


clean_station_id <- function(x) {
  s <- trimws(as.character(x))
  s <- gsub("\\.0+$", "", s)
  s
}


parse_event_date <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "NA", "ND", "nd")] <- NA_character_
  
  d <- as.Date(x, format = "%Y/%m/%d")
  
  bad <- is.na(d) & !is.na(x)
  if (any(bad)) {
    d[bad] <- as.Date(x[bad], format = "%Y-%m-%d")
  }
  
  d
}


parse_wkt_point <- function(wkt) {
  xy <- gsub("^\\s*POINT\\s*\\(|\\)\\s*$", "", wkt)
  xy <- trimws(xy)
  
  if (has_stringi) {
    sp <- stringi::stri_split_regex(xy, "\\s+", simplify = TRUE)
    lon <- suppressWarnings(as.numeric(sp[, 1]))
    lat <- suppressWarnings(as.numeric(sp[, 2]))
  } else {
    sp <- data.table::tstrsplit(xy, "\\s+")
    lon <- suppressWarnings(as.numeric(sp[[1]]))
    lat <- suppressWarnings(as.numeric(sp[[2]]))
  }
  
  list(lon = lon, lat = lat)
}


read_uglc_inventory <- function(file, min_lat, max_lat, min_lon, max_lon,
                                chunk_lines = 200000) {
  
  cat("\nReading UGLC inventory using robust chunk parser...\n")
  
  con <- file(file, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  
  header <- readLines(con, n = 1)
  if (!length(header)) {
    stop("UGLC file is empty.")
  }
  
  output_list <- list()
  k <- 0L
  
  get_field <- function(spl, idx) {
    vapply(
      spl,
      function(x) if (length(x) >= idx) x[idx] else NA_character_,
      FUN.VALUE = ""
    )
  }
  
  total_read <- 0L
  total_kept <- 0L
  
  repeat {
    
    lines <- readLines(con, n = chunk_lines)
    if (!length(lines)) break
    
    total_read <- total_read + length(lines)
    
    spl <- if (has_stringi) {
      stringi::stri_split_fixed(lines, "|", simplify = FALSE)
    } else {
      strsplit(lines, "|", fixed = TRUE)
    }
    
    WKT  <- get_field(spl, 1)
    NEWD <- get_field(spl, 2)
    ID   <- get_field(spl, 3)
    VER  <- get_field(spl, 6)
    SD   <- get_field(spl, 9)
    ED   <- get_field(spl, 10)
    PF   <- get_field(spl, 12)
    REL  <- get_field(spl, 13)
    
    # NOTES may contain extra pipe symbols.
    NOTES <- vapply(
      seq_along(spl),
      function(i) {
        x <- spl[[i]]
        L <- length(x)
        
        if (L < 17) return(NA_character_)
        if (L == 18) return(x[17])
        if (L > 18) return(paste(x[17:(L - 1)], collapse = "|"))
        
        x[17]
      },
      FUN.VALUE = ""
    )
    
    coord <- parse_wkt_point(WKT)
    
    lon <- coord$lon
    lat <- coord$lat
    
    valid_location <- is.finite(lon) & is.finite(lat)
    
    in_neh_box <- valid_location &
      lat >= min_lat & lat <= max_lat &
      lon >= min_lon & lon <= max_lon
    
    if (!any(in_neh_box)) next
    
    dt_chunk <- data.table(
      WKT_GEOM = WKT[in_neh_box],
      NEWDATASET = NEWD[in_neh_box],
      ID = ID[in_neh_box],
      VERSION = VER[in_neh_box],
      STARTDATE = SD[in_neh_box],
      ENDDATE = ED[in_neh_box],
      PHYSICALFACTORS = PF[in_neh_box],
      RELIABILITY = REL[in_neh_box],
      NOTES = NOTES[in_neh_box],
      Lon = lon[in_neh_box],
      Lat = lat[in_neh_box]
    )
    
    k <- k + 1L
    output_list[[k]] <- dt_chunk
    
    total_kept <- total_kept + nrow(dt_chunk)
    
    cat(
      "  Chunk kept:", nrow(dt_chunk),
      "| Total kept:", total_kept,
      "| Total read:", total_read, "\n"
    )
  }
  
  if (!length(output_list)) {
    stop("No UGLC records found within the NEH bounding box.")
  }
  
  DT <- rbindlist(output_list, use.names = TRUE, fill = TRUE)
  
  # Unique event identifier.
  DT[, EventID := paste0(NEWDATASET, "_", ID)]
  
  # Keep best record per unique event:
  # priority 1 = higher version
  # priority 2 = higher reliability
  DT[, version_number := suppressWarnings(as.integer(VERSION))]
  DT[, reliability_number := suppressWarnings(as.numeric(RELIABILITY))]
  
  setorder(DT, EventID, -version_number, -reliability_number)
  
  before <- nrow(DT)
  DT <- DT[!duplicated(EventID)]
  after <- nrow(DT)
  
  cat(
    "\nUnique UGLC events retained:", after,
    "| Duplicate records removed:", before - after, "\n"
  )
  
  DT[, c("version_number", "reliability_number") := NULL]
  
  DT
}


# ================= READ STATION METADATA =================

metadata <- readxl::read_excel(metadata_file)
names(metadata) <- tolower(trimws(names(metadata)))

col_station <- get_column_name(metadata, c("station", "stationname", "station_name"))
col_id      <- get_column_name(metadata, c("imd", "stationid", "station_id", "wmo", "wmo_id"))
col_lat     <- get_column_name(metadata, c("lat", "latitude"))
col_lon     <- get_column_name(metadata, c("long", "lon", "longitude"))

if (is.null(col_id) || is.null(col_lat) || is.null(col_lon)) {
  stop("Metadata must contain station ID, latitude, and longitude columns.")
}

StationName <- if (!is.null(col_station)) {
  as.character(metadata[[col_station]])
} else {
  rep("", nrow(metadata))
}

StationID <- clean_station_id(metadata[[col_id]])
StationLat <- suppressWarnings(as.numeric(metadata[[col_lat]]))
StationLon <- suppressWarnings(as.numeric(metadata[[col_lon]]))

valid_station <- is.finite(StationLat) &
  is.finite(StationLon) &
  !is.na(StationID) &
  StationID != ""

StationName <- StationName[valid_station]
StationID <- StationID[valid_station]
StationLat <- StationLat[valid_station]
StationLon <- StationLon[valid_station]

n_stations <- length(StationID)

cat("Stations loaded:", n_stations, "\n")


# ================= DEFINE NEH BOUNDING BOX =================

min_lat <- min(StationLat) - 1
max_lat <- max(StationLat) + 1
min_lon <- min(StationLon) - 1
max_lon <- max(StationLon) + 1


# ================= READ UGLC INVENTORY =================

UGLC <- read_uglc_inventory(
  file = uglc_file,
  min_lat = min_lat,
  max_lat = max_lat,
  min_lon = min_lon,
  max_lon = max_lon
)

cat("Unique UGLC events within NEH bounding box:", nrow(UGLC), "\n")


# ================= PARSE EVENT DATES =================

start_date <- parse_event_date(UGLC$STARTDATE)
end_date <- parse_event_date(UGLC$ENDDATE)

start_year <- suppressWarnings(as.integer(format(start_date, "%Y")))

invalid_start <- is.na(start_date) |
  is.na(start_year) |
  start_year < 1800

event_date <- start_date
event_date[invalid_start] <- end_date[invalid_start]

UGLC[, Year := as.integer(format(event_date, "%Y"))]
UGLC[, Month := as.integer(format(event_date, "%m"))]
UGLC[, Day := as.integer(format(event_date, "%d"))]


# ================= CLASSIFY MDL EVENTS =================

physical_text <- tolower(trimws(UGLC$PHYSICALFACTORS))
notes_text <- tolower(trimws(UGLC$NOTES))

trigger_text <- paste(physical_text, notes_text)

mdl_keywords <- c(
  "rain", "rainfall", "precip", "downpour", "storm", "monsoon",
  "cloudburst", "cyclone", "tropical", "typhoon", "hurricane",
  "water", "saturation", "soil moisture", "groundwater",
  "snow", "snowmelt", "flood", "flooding", "melt", "thaw",
  "freeze", "wet"
)

non_mdl_keywords <- c(
  "earthquake", "seismic", "volcan", "eruption", "mining",
  "quarry", "excavation", "construction", "roadcut", "road cut",
  "blasting", "anthropogenic", "human", "reservoir", "dam",
  "tunneling", "tunnel", "pipeline", "leak"
)

mdl_pattern <- paste0("(", paste(mdl_keywords, collapse = "|"), ")")
non_mdl_pattern <- paste0("(", paste(non_mdl_keywords, collapse = "|"), ")")

UGLC[, is_MDL := grepl(mdl_pattern, trigger_text, ignore.case = TRUE) &
       !grepl(non_mdl_pattern, trigger_text, ignore.case = TRUE)]

cat("UGLC MDL events within NEH bounding box:", sum(UGLC$is_MDL, na.rm = TRUE), "\n")


# ================= EXTRACT MDLS WITHIN 30 KM OF EACH STATION =================

event_points <- cbind(UGLC$Lon, UGLC$Lat)

Summary <- data.table(
  StationID = StationID,
  StationName = StationName,
  Lat = StationLat,
  Lon = StationLon,
  Total_unique_events_within30km = integer(n_stations),
  MDL_unique_events_within30km = integer(n_stations),
  MDL_percent_within30km = numeric(n_stations)
)

cat("\nStarting station-wise 30 km extraction...\n")

for (i in seq_len(n_stations)) {
  
  sid <- StationID[i]
  
  cat("  Processing station", i, "of", n_stations, "| ID =", sid, "\n")
  
  station_point <- matrix(c(StationLon[i], StationLat[i]), nrow = 1)
  
  distance_km <- geosphere::distHaversine(station_point, event_points) / 1000
  
  within_30km <- distance_km <= search_radius_km
  
  idx_all <- which(within_30km)
  idx_mdl <- idx_all[UGLC$is_MDL[idx_all]]
  
  Summary$Total_unique_events_within30km[i] <- length(unique(UGLC$EventID[idx_all]))
  Summary$MDL_unique_events_within30km[i] <- length(unique(UGLC$EventID[idx_mdl]))
  
  if (Summary$Total_unique_events_within30km[i] > 0) {
    Summary$MDL_percent_within30km[i] <-
      100 * Summary$MDL_unique_events_within30km[i] /
      Summary$Total_unique_events_within30km[i]
  } else {
    Summary$MDL_percent_within30km[i] <- NA_real_
  }
  
  if (!length(idx_mdl)) {
    
    output_table <- data.table(
      Lon = numeric(),
      Lat = numeric(),
      Distance_km = numeric(),
      Year = integer(),
      Month = integer(),
      Day = integer(),
      EventID = character()
    )
    
  } else {
    
    output_table <- data.table(
      Lon = UGLC$Lon[idx_mdl],
      Lat = UGLC$Lat[idx_mdl],
      Distance_km = round(distance_km[idx_mdl], 3),
      Year = UGLC$Year[idx_mdl],
      Month = UGLC$Month[idx_mdl],
      Day = UGLC$Day[idx_mdl],
      EventID = UGLC$EventID[idx_mdl]
    )
    
    setorder(output_table, EventID, Distance_km)
    output_table <- output_table[!duplicated(EventID)]
    
    output_table[, date_key := ifelse(
      is.na(Year) | is.na(Month) | is.na(Day),
      Inf,
      Year * 10000 + Month * 100 + Day
    )]
    
    setorder(output_table, date_key, Distance_km)
    output_table[, date_key := NULL]
  }
  
  output_file <- file.path(output_folder, sprintf("Uglc_%s.txt", sid))
  
  fwrite(output_table, output_file, sep = "\t", na = "NA")
}


# ================= SAVE SUMMARY =================

Summary[, MDL_percent_within30km := round(MDL_percent_within30km, 2)]

summary_file <- file.path(output_folder, "UGLC_MDL_summary_within30km.xlsx")

openxlsx::write.xlsx(Summary, summary_file, overwrite = TRUE)

cat("\nUGLC-based MDL extraction completed.\n")
cat("Summary written to:\n", summary_file, "\n")