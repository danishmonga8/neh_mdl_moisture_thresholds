# ============================================================
# Peak MDL Probability Month Map and Bar Plot
#
# Purpose:
# This script plots the station-wise peak month of moisture-driven
# landslide (MDL) probability across the NEH study region.
#
# Input:
# 1. Himalayan study-area shapefile
# 2. River shapefile
# 3. Station metadata file containing station location and peak month
#
# Output:
# 1. Spatial map of peak MDL probability month
# 2. Bar plot showing number of stations peaking in each JJAS month
# ============================================================


# ================= LOAD PACKAGES =================

library(sf)
library(ggplot2)
library(RColorBrewer)
library(readxl)
library(dplyr)


# ================= USER SETTINGS =================

base_folder <- "C:/lews_2022-2024/3_new_stations_neh_new"

shapefile_path <- "C:/lews_2022-2024/western_himalayas_landslide/spatial_variation_map/my_study_shape/Himalayan_UP_Bihar.shp"

riverfile_path <- "C:/lews_2022-2024/western_himalayas_landslide/Himalayan/River_Himalaya.shp"

station_file <- file.path(
  base_folder,
  "all_stations_neh.xlsx"
)

output_folder <- file.path(
  base_folder,
  "figures_neh_soil_moisture",
  "peak_mdl_probability_month"
)

if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}


# ================= READ SHAPEFILES =================

shape_data <- st_read(shapefile_path, quiet = TRUE) |>
  st_transform(4326) |>
  st_make_valid()

river_data <- st_read(riverfile_path, quiet = TRUE) |>
  st_transform(4326) |>
  st_make_valid()


# ================= READ STATION DATA =================

station_data <- read_excel(station_file)

names(station_data) <- trimws(names(station_data))

# Expected columns in all_stations_neh.xlsx:
# Column 3 = Latitude
# Column 4 = Longitude
# Column 6 = Peak MDL probability month

station_data <- station_data |>
  mutate(
    Lat = as.numeric(.data[[3]]),
    Lon = as.numeric(.data[[4]]),
    Peak_month_probability = as.integer(.data[[6]])
  ) |>
  filter(
    is.finite(Lat),
    is.finite(Lon),
    Peak_month_probability %in% c(6, 7, 8, 9)
  )


# ================= CONVERT STATIONS TO SF =================

stations_sf <- st_as_sf(
  station_data,
  coords = c("Lon", "Lat"),
  crs = 4326,
  remove = FALSE
)


# ================= KEEP STUDY-AREA POLYGONS =================

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


# ================= CLIP RIVERS TO STUDY AREA =================

river_keep <- st_intersection(
  st_make_valid(river_data),
  st_union(shape_keep_main)
)


# ================= MAP EXTENT =================

bbox_map <- st_bbox(shape_keep_main)

pad_degree <- 0.6

x_limits <- c(
  bbox_map["xmin"] - pad_degree,
  bbox_map["xmax"] + pad_degree
)

y_limits <- c(
  bbox_map["ymin"] - pad_degree,
  bbox_map["ymax"] + pad_degree
)


# ================= MONTH COLORS =================

base_cols <- brewer.pal(12, "Paired")

month_colors <- c(
  "6" = base_cols[6],
  "7" = base_cols[7],
  "8" = base_cols[8],
  "9" = "#D81B60"
)


# ============================================================
# FIGURE 1: PEAK MDL MONTH MAP
# ============================================================

map_plot <- ggplot() +
  
  geom_sf(
    data = shape_keep_main,
    fill = "gray95",
    color = "gray50",
    linewidth = 0.6
  ) +
  
  geom_sf(
    data = river_keep,
    color = "#3399FF",
    linewidth = 0.9
  ) +
  
  geom_sf(
    data = stations_sf,
    aes(fill = factor(Peak_month_probability, levels = c(6, 7, 8, 9))),
    shape = 21,
    color = "black",
    size = 5,
    alpha = 0.70,
    stroke = 1.4
  ) +
  
  scale_fill_manual(
    values = month_colors,
    name = "Peak MDL probability month",
    breaks = c("6", "7", "8", "9"),
    labels = month.abb[6:9]
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
  
  theme_minimal(base_size = 18) +
  
  theme(
    axis.title = element_text(size = 18, face = "bold"),
    axis.text  = element_text(size = 16),
    
    legend.position = "bottom",
    legend.title = element_text(size = 18, face = "bold"),
    legend.text  = element_text(size = 16),
    
    panel.grid.major = element_line(
      color = "gray87",
      linetype = "dashed"
    ),
    
    panel.background = element_rect(fill = "white", color = "white"),
    plot.background  = element_rect(fill = "white", color = "white")
  )

print(map_plot)


# ================= SAVE MAP =================

ggsave(
  filename = file.path(output_folder, "peak_mdl_probability_month_map_NEH.png"),
  plot = map_plot,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "peak_mdl_probability_month_map_NEH.tiff"),
  plot = map_plot,
  dpi = 300,
  width = 11,
  height = 8,
  units = "in",
  bg = "white"
)


# ============================================================
# FIGURE 2: MONTH-WISE STATION COUNT BAR PLOT
# ============================================================

month_counts <- station_data |>
  filter(Peak_month_probability %in% c(6, 7, 8, 9)) |>
  count(Peak_month_probability, name = "n") |>
  right_join(
    data.frame(Peak_month_probability = c(6, 7, 8, 9)),
    by = "Peak_month_probability"
  ) |>
  mutate(
    n = ifelse(is.na(n), 0, n),
    month_key = factor(Peak_month_probability, levels = c(6, 7, 8, 9)),
    month_label = factor(month.abb[Peak_month_probability], levels = month.abb[6:9])
  )

ymax <- max(month_counts$n)
y_breaks <- seq(0, ymax, by = 1)

bar_plot <- ggplot(
  month_counts,
  aes(x = month_label, y = n, fill = as.character(month_key))
) +
  
  geom_col(
    color = "black",
    linewidth = 0.8,
    width = 0.75,
    alpha = 0.85
  ) +
  
  scale_fill_manual(
    values = month_colors,
    guide = "none"
  ) +
  
  scale_y_continuous(
    breaks = y_breaks,
    limits = c(0, ymax),
    expand = expansion(mult = c(0, 0.05))
  ) +
  
  labs(
    x = NULL,
    y = "Number of stations"
  ) +
  
  theme_minimal(base_size = 18) +
  
  theme(
    axis.title = element_text(size = 18, face = "bold"),
    axis.text  = element_text(size = 16),
    
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(
      color = "gray87",
      linetype = "dashed"
    ),
    
    panel.background = element_rect(fill = "white", color = "white"),
    plot.background  = element_rect(fill = "white", color = "white")
  )

print(bar_plot)


# ================= SAVE BAR PLOT =================

ggsave(
  filename = file.path(output_folder, "peak_mdl_probability_month_bar_NEH.png"),
  plot = bar_plot,
  dpi = 300,
  width = 6.5,
  height = 5.0,
  units = "in",
  bg = "white"
)

ggsave(
  filename = file.path(output_folder, "peak_mdl_probability_month_bar_NEH.tiff"),
  plot = bar_plot,
  dpi = 300,
  width = 6.5,
  height = 5.0,
  units = "in",
  bg = "white"
)


cat("\nPeak MDL probability month map and bar plot saved in:\n")
cat(output_folder, "\n")