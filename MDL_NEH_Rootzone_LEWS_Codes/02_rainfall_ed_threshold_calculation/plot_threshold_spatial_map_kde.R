# ============================================================
# Spatial Map and KDE of 3-day Rainfall Threshold
#
# Purpose:
# This script plots the spatial distribution and probability density
# of station-wise 3-day rainfall thresholds derived from the
# at-site E-D threshold workflow.
#
# Input:
# 1. Himalayan shapefile
# 2. Final_Threshold_Output.xlsx
#
# Main variable:
# E3_P20 = 3-day rainfall threshold at tau = 0.20
#
# Outputs:
# 1. Spatial map of station-wise rainfall threshold
# 2. KDE/PDF plot of rainfall threshold distribution
# ============================================================


# ================= LOAD PACKAGES =================

library(sf)
library(ggplot2)
library(readxl)
library(dplyr)
library(viridis)
library(grid)


# ================= USER SETTINGS =================

shapefile_path <- "C:/lews_2022-2024/western_himalayas_landslide/spatial_variation_map/my_study_shape/Himalayan_UP_Bihar.shp"

threshold_file <- "C:/lews_2022-2024/3_new_stations_neh_new/Final_Threshold_Output.xlsx"

output_folder <- "C:/lews_2022-2024/3_new_stations_neh_new/figures_neh_soil_moisture/3_day_threshold"

if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}

# Threshold column to plot
threshold_column <- "E3_P20"


# ================= HELPER FUNCTION =================

p_to_tau <- function(column_name) {
  p_value <- as.numeric(gsub(".*_P", "", column_name))
  if (is.na(p_value)) return(NA_real_)
  p_value / 100
}

tau_value <- p_to_tau(threshold_column)


# ================= READ SHAPEFILE =================

shape_data <- st_read(shapefile_path, quiet = TRUE) |>
  st_transform(4326) |>
  st_make_valid()


# ================= READ THRESHOLD DATA =================

station_data <- read_excel(threshold_file)

names(station_data) <- trimws(names(station_data))

# Expected columns in Final_Threshold_Output.xlsx:
# Station, IMD_ID, Lat, Lon/Long, E3_Pxx threshold columns

if (!threshold_column %in% names(station_data)) {
  stop(paste("Threshold column not found:", threshold_column))
}

# Handle longitude column name
if ("Long" %in% names(station_data)) {
  lon_column <- "Long"
} else if ("Lon" %in% names(station_data)) {
  lon_column <- "Lon"
} else {
  stop("Longitude column not found. Expected 'Long' or 'Lon'.")
}

if (!"Lat" %in% names(station_data)) {
  stop("Latitude column not found. Expected 'Lat'.")
}

station_data <- station_data |>
  mutate(
    Lat = as.numeric(.data$Lat),
    Lon = as.numeric(.data[[lon_column]]),
    Threshold_mm = as.numeric(.data[[threshold_column]])
  ) |>
  filter(
    is.finite(Lat),
    is.finite(Lon),
    is.finite(Threshold_mm)
  )


# ================= CONVERT STATIONS TO SF =================

stations_sf <- st_as_sf(
  station_data,
  coords = c("Lon", "Lat"),
  crs = 4326
)


# ================= KEEP MAP POLYGONS AROUND STATIONS =================

intersect_id <- lengths(st_intersects(shape_data, stations_sf)) > 0

shape_keep <- shape_data[intersect_id, ]

shape_keep$map_id <- seq_len(nrow(shape_keep))

# Keep largest polygon part for each intersecting feature
shape_keep_main <- shape_keep |>
  st_make_valid() |>
  st_cast("POLYGON", warn = FALSE) |>
  mutate(area_value = as.numeric(st_area(geometry))) |>
  group_by(map_id) |>
  slice_max(area_value, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-map_id, -area_value)


# ================= MAP EXTENT =================

bbox_map <- st_bbox(shape_keep_main)

x_padding <- 0.35
y_padding <- 0.35

x_limits <- c(
  bbox_map["xmin"] - x_padding,
  bbox_map["xmax"] + x_padding
)

y_limits <- c(
  bbox_map["ymin"] - y_padding,
  bbox_map["ymax"] + y_padding
)


# ================= LEGEND TITLE =================

legend_title <- if (!is.na(tau_value)) {
  bquote("Rainfall threshold (mm) at " * tau == .(sprintf("%.2f", tau_value)))
} else {
  "Rainfall threshold (mm)"
}


# ============================================================
# FIGURE 1: SPATIAL MAP
# ============================================================

fig_map <- ggplot() +
  
  geom_sf(
    data = shape_keep_main,
    fill = "gray95",
    color = "black",
    linewidth = 0.75
  ) +
  
  geom_point(
    data = station_data,
    aes(x = Lon, y = Lat, fill = Threshold_mm),
    shape = 21,
    color = "black",
    stroke = 1.25,
    size = 5.5,
    alpha = 0.75
  ) +
  
  scale_fill_viridis_c(
    option = "C",
    direction = -1,
    name = legend_title,
    guide = guide_colorbar(
      title.position = "top",
      title.hjust = 0.5,
      direction = "horizontal",
      barwidth = unit(15, "cm"),
      barheight = unit(0.70, "cm"),
      ticks = TRUE
    )
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
  
  theme_minimal(base_size = 20) +
  
  theme(
    text = element_text(family = "Arial"),
    
    axis.title = element_text(size = 24, face = "bold", color = "black"),
    axis.text  = element_text(size = 20, color = "black"),
    
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.title = element_text(size = 19, color = "black"),
    legend.text  = element_text(size = 17, color = "black"),
    
    panel.grid.major = element_line(
      color = "gray82",
      linetype = "dashed",
      linewidth = 0.45
    ),
    panel.grid.minor = element_blank(),
    
    panel.background = element_rect(fill = "white", color = "white"),
    plot.background  = element_rect(fill = "white", color = "white"),
    
    legend.margin = margin(t = 4, r = 0, b = 2, l = 0),
    plot.margin   = margin(t = 8, r = 8, b = 8, l = 8)
  )

print(fig_map)


# ================= SAVE SPATIAL MAP =================

map_png <- file.path(
  output_folder,
  paste0("NEH_", threshold_column, "_spatial_map.png")
)

map_jpeg <- file.path(
  output_folder,
  paste0("NEH_", threshold_column, "_spatial_map.jpeg")
)

ggsave(
  filename = map_png,
  plot = fig_map,
  dpi = 600,
  width = 8.8,
  height = 6.9,
  units = "in",
  bg = "white"
)

ggsave(
  filename = map_jpeg,
  plot = fig_map,
  dpi = 600,
  width = 8.8,
  height = 6.9,
  units = "in",
  bg = "white"
)


# ============================================================
# FIGURE 2: KDE / PDF OF THRESHOLD VALUES
# ============================================================

threshold_values <- station_data$Threshold_mm
threshold_values <- threshold_values[is.finite(threshold_values)]

x_min <- min(threshold_values)
x_max <- max(threshold_values)
x_pad <- 0.04 * (x_max - x_min)

x_limits_kde <- c(
  x_min - x_pad,
  x_max + x_pad
)

density_fit <- density(
  threshold_values,
  from = x_limits_kde[1],
  to = x_limits_kde[2],
  n = 1200,
  bw = bw.nrd0(threshold_values)
)

density_df <- data.frame(
  Rainfall_threshold_mm = density_fit$x,
  Density = density_fit$y
)

median_threshold <- median(threshold_values)

median_df <- data.frame(
  Rainfall_threshold_mm = c(median_threshold, median_threshold),
  Density = c(0, max(density_df$Density))
)


fig_kde <- ggplot() +
  
  geom_line(
    data = density_df,
    aes(x = Rainfall_threshold_mm, y = Density, color = "PDF"),
    linewidth = 2.2
  ) +
  
  geom_line(
    data = median_df,
    aes(x = Rainfall_threshold_mm, y = Density, color = "Median"),
    linewidth = 1.8,
    linetype = "dashed"
  ) +
  
  scale_color_manual(
    values = c(
      "PDF" = "red",
      "Median" = "red"
    ),
    breaks = c("PDF", "Median"),
    labels = c("PDF", "Median"),
    name = NULL
  ) +
  
  geom_hline(
    yintercept = 0,
    color = "gray35",
    linewidth = 0.7
  ) +
  
  labs(
    x = "Rainfall threshold (mm)",
    y = "Density"
  ) +
  
  coord_cartesian(
    xlim = x_limits_kde,
    ylim = c(0, max(density_df$Density) * 1.08)
  ) +
  
  theme_minimal(base_size = 24) +
  
  theme(
    text = element_text(family = "Arial"),
    
    axis.title = element_text(size = 28, face = "bold", color = "black"),
    axis.text  = element_text(size = 24, color = "black"),
    
    legend.position = "top",
    legend.text = element_text(size = 22, color = "black"),
    
    panel.grid.major = element_line(
      color = "gray88",
      linewidth = 0.45
    ),
    panel.grid.minor = element_blank(),
    
    panel.background = element_rect(fill = "white", color = "white"),
    plot.background  = element_rect(fill = "white", color = "white"),
    
    plot.margin = margin(t = 8, r = 8, b = 8, l = 8)
  )

print(fig_kde)


# ================= SAVE KDE FIGURE =================

kde_png <- file.path(
  output_folder,
  paste0("NEH_", threshold_column, "_kde.png")
)

kde_jpeg <- file.path(
  output_folder,
  paste0("NEH_", threshold_column, "_kde.jpeg")
)

ggsave(
  filename = kde_png,
  plot = fig_kde,
  dpi = 600,
  width = 8.8,
  height = 6.4,
  units = "in",
  bg = "white"
)

ggsave(
  filename = kde_jpeg,
  plot = fig_kde,
  dpi = 600,
  width = 8.8,
  height = 6.4,
  units = "in",
  bg = "white"
)


cat("\nDone. Spatial map and KDE figures saved in:\n")
cat(output_folder, "\n")