# Input data

The full analysis needs the following inputs, placed under the data root (`NEH_ROOT`, default `data/`). The exact paths each script uses are listed in `docs/path_reference.md`.

| Input | Content | Source |
|---|---|---|
| `all_stations_neh.xlsx` (sheet `Sheet1`) | Station name, IMD ID, latitude, longitude, ideal lag N*, ADF and terrain descriptors; one row per station (21 stations) | compiled by the authors |
| Daily rainfall per station | One text file per IMD ID with date and daily rainfall (mm), 2007-2019 | IMD gridded daily rainfall |
| `<IMD>_SMrz_Seff.txt` | Daily root-zone effective saturation S_eff per station (0-1) | derived from GLEAM root-zone soil moisture |
| Landslide master catalogue (CSV) | Event date, latitude, longitude, size class, trigger, source | COOLR, UGLC and GFLD records merged and de-duplicated |
| `supplementary_data/Supplementary_Dataset_S3_Predictive_Modeling_Dataset.xlsx` | Storm-level predictive modelling dataset used by the TSS scripts | produced by the earlier steps |
| `shapefiles/` | State boundaries and rivers for the maps | public boundary data |

The raw rainfall, soil-moisture and catalogue files are not redistributed here; obtain them from the original providers and place them as listed.

## Sample data

`sample_data/` holds a small synthetic data set (two stations, 2007-2019, 164 landslides) in a simplified layout. It exists to run and check the code and has no scientific meaning.

```
python sample_data/generate_sample_data.py     # writes the sample files (seed 7)
python sample_data/run_sample_pipeline.py      # ADF, Kendall tau, E-D threshold, JEP
```

`run_sample_pipeline.py` accepts a directory with the same file names as its first argument, so it also runs on real data exported to that layout. It writes `output_station_summary.csv` and `output_jep_large_events.csv` next to itself.

| File | Columns |
|---|---|
| `stations.csv` | `Station, IMD, Lat, Long, Ideal_lag` |
| `rain_<IMD>.csv` | `date` (YYYY-MM-DD), `rain_mm` |
| `seff_<IMD>.csv` | `date`, `seff` |
| `landslides.csv` | `IMD, Station, EventDate, landslide_size` (`small`, `medium` or `large`) |
