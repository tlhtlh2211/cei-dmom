import geopandas as gpd
import pandas as pd
import numpy as np
import json
import datetime
from bokeh.plotting import figure
from bokeh.models import GeoJSONDataSource, LinearColorMapper, ColorBar
from bokeh.palettes import brewer
from bokeh.models.annotations import Title

# --- Configuration ---
# Change these variables to plot a different province
PROVINCE_NAME = 'Thái Nguyên'
# To plot Thai Nguyen, change the following line to:
# CSV_PATH = 'results/dci_results_thai_nguyen_target_based.csv'
CSV_PATH = 'results/dci_results_thai_nguyen_target_based.csv'

# --- Load Data ---
data = pd.read_csv(CSV_PATH)
data["plot_data"] = data["DCI"]

# Load all district boundaries from the GeoJSON file
gdf_districts = gpd.read_file('vietnam-plot/geoBoundaries-VNM-ADM2_simplified.geojson')


# --- Normalize District Names for a more reliable merge ---
from unidecode import unidecode

def normalize_name(name):
    """Converts to lowercase and removes accents/diacritics for consistent matching."""
    if not isinstance(name, str):
        return ""
    return unidecode(name).lower().replace(" ", "")

# Create a new column with normalized names in both dataframes
gdf_districts['normalized_name'] = gdf_districts['shapeName'].apply(normalize_name)
data['normalized_name'] = data['District'].apply(normalize_name)


# Merge the geographic data using the new normalized names.
# A 'right' merge ensures that we only plot districts present in the CSV file.
vn_data = gdf_districts.merge(data, on='normalized_name', how='right')

# The rest of the script remains the same as it correctly handles the merged data.
vn_data['ready'].fillna(False, inplace=True)

# Split the data into ready and not ready
ready_gdf = vn_data[vn_data['ready'] == True]
not_ready_gdf = vn_data[vn_data['ready'] == False]

# Create separate GeoJSON sources
ready_source = GeoJSONDataSource(geojson=ready_gdf.to_json())
not_ready_source = GeoJSONDataSource(geojson=not_ready_gdf.to_json())


# --- Blue Color Mapper for 'Ready' Districts ---
# We slice the palette to remove the lightest colors, so the scale starts from a more visible blue.
# We also reverse it to ensure higher values get darker colors.
palette_blue = brewer['Greens'][7][:4][::-1]
blue_color_mapper = LinearColorMapper(palette=palette_blue, low=75, high=100)

ticks_blue = list(range(75, 101, 5))
tick_labels_blue = {str(tick): str(tick) for tick in ticks_blue}

blue_color_bar = ColorBar(
    color_mapper=blue_color_mapper, title="Ready",
    label_standoff=8, width=500, height=20,
    border_line_color=None, location=(0, 0), orientation='horizontal',
    major_label_overrides=tick_labels_blue
)

# --- Red Color Mapper for 'Not Ready' Districts ---
# Slicing and reversing the palette for consistency with the blue scale.
palette_red = brewer['YlOrRd'][7][:4]
red_color_mapper = LinearColorMapper(palette=palette_red, low=50, high=75)

ticks_red = list(range(50, 76, 5))
tick_labels_red = {str(tick): str(tick) for tick in ticks_red}

red_color_bar = ColorBar(
    color_mapper=red_color_mapper, title="Not Ready",
    label_standoff=8, width=500, height=20,
    border_line_color=None, location=(0, 0), orientation='horizontal',
    major_label_overrides=tick_labels_red
)

# --- Create Plot ---
p = figure(
    title=f"DCI Results for {PROVINCE_NAME}",
    plot_height=800, plot_width=700,
    toolbar_location=None,
    tools="pan,wheel_zoom,box_zoom,reset"
)
p.title.text_font_size = '16pt'
p.title.align = "center"
p.xgrid.grid_line_color = None
p.ygrid.grid_line_color = None

# Plot 'not ready' districts only if there are any
if not not_ready_gdf.empty:
    p.patches(
        xs='xs', ys='ys', source=not_ready_source,
        fill_color={'field': 'plot_data', 'transform': red_color_mapper},
        line_color='black', line_width=0.5, fill_alpha=1
    )

# Plot 'ready' districts only if there are any
if not ready_gdf.empty:
    p.patches(
        xs='xs', ys='ys', source=ready_source,
        fill_color={'field': 'plot_data', 'transform': blue_color_mapper},
        line_color='black', line_width=0.5, fill_alpha=1
    )

# Add color bars only if the corresponding data exists
if not ready_gdf.empty:
    p.add_layout(blue_color_bar, 'below')
if not not_ready_gdf.empty:
    p.add_layout(red_color_bar, 'above')


# --- Save Plot ---
from bokeh.io import export_png
output_filename = f"{PROVINCE_NAME.replace(' ', '_').lower()}_dci_{datetime.datetime.now().strftime('%Y-%m-%d')}.png"
export_png(p, filename=output_filename)

print(f"Plot saved to {output_filename}")
