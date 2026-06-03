# ============================================================
# Root-zone Wetness Amplification Maps
#
# Purpose:
# This script plots spatial maps of:
# 1. Rainfall-only MDL likelihood:
#    P(MDL | R_high)
#
# 2. Wetness-conditioned MDL likelihood:
#    P(MDL | R_high, S_eff[1] >= S_eff,80)
#
# 3. Root-zone wetness amplification ratio:
#    AR = P(MDL | R_high, S_eff[1] >= S_eff,80) /
#         P(MDL | R_high)
#
# Input:
# 1. NEH station metadata
# 2. Root-zone wetness amplification summary table
# 3. Himalayan shapefile
#
# Output:
# Three spatial maps saved as TIFF and PNG.
# ============================================================


# ================= LOAD PACKAGES =================

library(sf)
library(ggplot2)
library(readxl)
library(dplyr)
library(viridis)
library(scales)
library(grid)


# ================= USER SETTINGS =================

base_folder <- "C:/lews_2022-2024/3_new_stations_neh_new"

shapefile_path <- "C:/lews_2022-2024/western_himalayas_landslide/spatial_variation_map/my_study_shape/Himalayan_UP_Bihar.shp"

station_file <- file.path(
  base_folder,
  "all_stations_neh.xlsx"
)

amplification_file <- file.path(
  base_folder,
  "figures_neh_soil_moisture",
  "figure_final_9_amplification_ratio",
  "AR_summary_exact_values_with_formulas.xlsx"
)

amplification_sheet <- "AR_summary"

output_folder <- file.path(
  base_folder,
  "figures_neh_soil_moisture",
  "rootzone_wetness_amplification_maps"
)

if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}


# ================= READ SHAPEFILE =================

shape_data <- st_read(shapefile_path, quiet = TRUE) |>
  st_transform(4326) |>
  st_make_valid()


# ================= READ STATION METADATA =================

stations <- read_excel(station_file)

names(stations) <- trimws(names(stations))

# Expected columns:
# IMD or IMD_ID = station ID
# Lat = latitude
# Long/Lon = longitude

if ("IMD" %in% names(stations)) {
  stations$StationID <- stations$IMD
} else if ("IMD_ID" %in% names(stations)) {
  stations$StationID <- stations$IMD_ID
} else {
  stop("Station ID column not found. Expected IMD or IMD_ID.")
}

if (!"Lat" %in% names(stations)) {
  stop("Latitude column not found. Expected Lat.")
}

if ("Long" %in% names(stations)) {
  stations$Lon <- stations$Long
} else if ("Lon" %in% names(stations)) {
  stations$Lon <- stations$Lon
} else {
  stop("Longitude column not found. Expected Long or Lon.")
}

stations <- stations |>
  mutate(
    StationID = as.integer(StationID),
    Lat = as.numeric(Lat),
    Lon = as.numeric(Lon)
  ) |>
  filter(
    is.finite(StationID),
    is.finite(Lat),
    is.finite(Lon)
  )


# ================= READ AMPLIFICATION RESULTS =================

AR <- read_excel(
  amplification_file,
  sheet = amplification_sheet
)

names(AR) <- trimws(names(AR))

# ----------------------------------------------------------------
# IMPORTANT:
# The old Excel file uses old column names:
# IMD      = station ID
# p_Thigh  = P(MDL | R_high)
# p_TS085  = P(MDL | R_high, S_eff[1] >= S_eff,80)
# AR_085   = amplification ratio
#
# Internally, we rename them to manuscript-style names.
# ----------------------------------------------------------------

required_cols <- c("IMD", "p_Thigh", "p_TS085", "AR_085")

missing_cols <- setdiff(required_cols, names(AR))

if (length(missing_cols) > 0) {
  stop(paste("Missing columns in amplification file:", paste(missing_cols, collapse = ", ")))
}

AR_clean <- AR |>
  transmute(
    StationID = as.integer(IMD),
    P_MDL_given_Rhigh = as.numeric(p_Thigh),
    P_MDL_given_Rhigh_Seff80 = as.numeric(p_TS085),
    AmplificationRatio = as.numeric(AR_085)
  )


# ================= MERGE STATION AND AR DATA =================

plot_data <- stations |>
  left_join(AR_clean, by = "StationID") |>
  filter(
    is.finite(P_MDL_given_Rhigh),
    is.finite(P_MDL_given_Rhigh_Seff80),
    is.finite(AmplificationRatio)
  )

stations_sf <- st_as_sf(
  plot_data,
  coords = c("Lon", "Lat"),
  crs = 4326,
  remove = FALSE
)


# ================= PREPARE MAP BOUNDARY =================

intersect_id <- lengths(st_intersects(shape_data, stations_sf)) > 0

shape_keep <- shape_data[intersect_id, ]

shape_keep$map_id <- seq_len(nrow(shape_keep))

shape_keep_main <- shape_keep |>
  st_make_valid() |>
  st_cast("POLYGON", warn = FALSE) |>
  mutate(area_value = as.numeric(st_area(geometry))) |>
  group_by(map_id) |>
  slice_max(area_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-map_id, -area_value)

bbox_map <- st_bbox(shape_keep_main)

padding_degree <- 0.6

x_limits <- c(
  bbox_map["xmin"] - padding_degree,
  bbox_map["xmax"] + padding_degree
)

y_limits <- c(
  bbox_map["ymin"] - padding_degree,
  bbox_map["ymax"] + padding_degree
)


# ================= COMMON THEME =================

base_theme <- theme_minimal(base_size = 26) +
  theme(
    axis.title = element_text(size = 26, face = "bold"),
    axis.text  = element_text(size = 24, color = "black"),
    
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(size = 24, face = "bold", hjust = 0.5),
    legend.text  = element_text(size = 21),
    
    panel.grid.major = element_line(
      color = "gray88",
      linetype = "dashed",
      linewidth = 0.45
    ),
    panel.grid.minor = element_blank(),
    
    panel.background = element_rect(fill = "white", color = "white"),
    plot.background  = element_rect(fill = "white", color = "white"),
    
    plot.margin = margin(10, 12, 18, 12)
  )

colorbar_guide <- guide_colorbar(
  title.position = "top",
  title.hjust = 0.5,
  barwidth = unit(20, "cm"),
  barheight = unit(0.7, "cm"),
  ticks = TRUE,
  frame.colour = "black",
  ticks.colour = "black"
)


# ================= COMMON LIMITS FOR PROBABILITY MAPS =================

prob_values <- c(
  plot_data$P_MDL_given_Rhigh,
  plot_data$P_MDL_given_Rhigh_Seff80
)

prob_values <- prob_values[is.finite(prob_values)]

prob_min <- 0
prob_max <- as.numeric(quantile(prob_values, 0.95, na.rm = TRUE))
prob_max <- ceiling(prob_max * 100) / 100

prob_step <- if (prob_max <= 0.05) {
  0.01
} else if (prob_max <= 0.20) {
  0.02
} else {
  0.05
}

prob_breaks <- seq(prob_min, prob_max, by = prob_step)


# ================= LEGEND TITLES =================

legend_rain_only <- expression(P(MDL~"|"~R[high]))

legend_rain_wetness <- expression(
  P(MDL~"|"~R[high]*","~S[eff][1] >= S[eff,80])
)

legend_ar <- "Amplification ratio"


# ================= MAP FUNCTIONS =================

make_probability_map <- function(variable_name, legend_title) {
  
  ggplot() +
    
    geom_sf(
      data = shape_keep_main,
      fill = "gray95",
      color = "gray55",
      linewidth = 0.6
    ) +
    
    geom_sf(
      data = stations_sf,
      aes(fill = .data[[variable_name]]),
      shape = 21,
      color = "black",
      stroke = 1.5,
      size = 5.8,
      alpha = 0.75
    ) +
    
    scale_fill_viridis_c(
      option = "D",
      direction = -1,
      limits = c(prob_min, prob_max),
      breaks = prob_breaks,
      labels = percent_format(accuracy = 1),
      oob = squish,
      name = legend_title,
      guide = colorbar_guide
    ) +
    
    labs(
      x = "Longitude",
      y = "Latitude"
    ) +
    
    coord_sf(
      xlim = x_limits,
      ylim = y_limits,
      expand = FALSE
    ) +
    
    base_theme
}


make_ar_map <- function(variable_name, legend_title) {
  
  ar_values <- stations_sf[[variable_name]]
  ar_values <- ar_values[is.finite(ar_values)]
  
  ar_min <- as.numeric(quantile(ar_values, 0.05, na.rm = TRUE))
  ar_max <- as.numeric(quantile(ar_values, 0.95, na.rm = TRUE))
  
  ar_min <- min(ar_min, 1)
  ar_max <- max(ar_max, 1)
  
  ar_min <- floor(ar_min * 10) / 10
  ar_max <- ceiling(ar_max * 10) / 10
  
  ar_breaks <- pretty(c(ar_min, ar_max), n = 6)
  
  ggplot() +
    
    geom_sf(
      data = shape_keep_main,
      fill = "gray95",
      color = "gray55",
      linewidth = 0.6
    ) +
    
    geom_sf(
      data = stations_sf,
      aes(fill = .data[[variable_name]]),
      shape = 21,
      color = "black",
      stroke = 1.5,
      size = 5.8,
      alpha = 0.75
    ) +
    
    scale_fill_viridis_c(
      option = "C",
      direction = -1,
      limits = c(ar_min, ar_max),
      breaks = ar_breaks,
      labels = function(x) sprintf("%.1f×", x),
      oob = squish,
      name = legend_title,
      guide = colorbar_guide
    ) +
    
    labs(
      x = "Longitude",
      y = "Latitude"
    ) +
    
    coord_sf(
      xlim = x_limits,
      ylim = y_limits,
      expand = FALSE
    ) +
    
    base_theme
}


# ================= CREATE MAPS =================

map_rain_only <- make_probability_map(
  "P_MDL_given_Rhigh",
  legend_rain_only
)

map_rain_wetness <- make_probability_map(
  "P_MDL_given_Rhigh_Seff80",
  legend_rain_wetness
)

map_amplification <- make_ar_map(
  "AmplificationRatio",
  legend_ar
)

print(map_rain_only)
print(map_rain_wetness)
print(map_amplification)


# ================= SAVE MAPS =================

ggsave(
  filename = file.path(output_folder, "map_P_MDL_given_Rhigh.tiff"),
  plot = map_rain_only,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "map_P_MDL_given_Rhigh_Seff80.tiff"),
  plot = map_rain_wetness,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "map_AmplificationRatio.tiff"),
  plot = map_amplification,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "map_P_MDL_given_Rhigh.png"),
  plot = map_rain_only,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "map_P_MDL_given_Rhigh_Seff80.png"),
  plot = map_rain_wetness,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "map_AmplificationRatio.png"),
  plot = map_amplification,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

cat("\nRoot-zone wetness amplification maps saved in:\n")
cat(output_folder, "\n")