import geopandas as gpd
import pandas as pd
import numpy as np
import json
import datetime
from bokeh.io import output_notebook, show, output_file
from bokeh.plotting import figure
from bokeh.models import GeoJSONDataSource, LinearColorMapper, ColorBar
from bokeh.palettes import brewer
from bokeh.models.annotations import Title

data = pd.read_csv("/Users/tranlehai/Desktop/CEI-Simulation/results/national_pci_analysis_with_names_new.csv")
data2 = pd.read_csv("/Users/tranlehai/Desktop/CEI-Simulation/results/national_pci_analysis_with_names.csv")
data['Province'] = data2['Name']
data.rename(columns={'Province': 'Name'}, inplace=True)

data["plot_data"] = data["PCI"]
gdf_vn = gpd.read_file('/Users/tranlehai/Desktop/CEI-Simulation/vietnam-plot/vietnam_provinces.geojson')

# Simplify geometries to remove holes and prevent Bokeh warnings
gdf_vn.geometry = gdf_vn.geometry.buffer(0)

vn_data = gdf_vn.merge(data[['Name', 'plot_data', 'Ready']], on='Name', how='left')
vn_data['Ready'].fillna(False, inplace=True)

# Split the data into ready and not ready provinces
ready_gdf = vn_data[vn_data['Ready'] == True]
not_ready_gdf = vn_data[vn_data['Ready'] == False]

# Create separate GeoJSON sources for plotting
ready_source = GeoJSONDataSource(geojson=ready_gdf.to_json())
not_ready_source = GeoJSONDataSource(geojson=not_ready_gdf.to_json())

# --- Green Color Mapper for 'Ready' Provinces ---
# We slice and reverse the palette to ensure higher values get darker colors.
palette_green = brewer['Greens'][7][:4][::-1]
green_color_mapper = LinearColorMapper(palette=palette_green, low=80, high=100)

ticks_green = list(range(80, 101, 4))
tick_labels_green = {str(tick): str(tick) for tick in ticks_green}

green_color_bar = ColorBar(
    color_mapper=green_color_mapper,
    label_standoff=8,
    width=800, 
    height=20,
    border_line_color=None, 
    location=(0,0), 
    orientation='horizontal', 
    major_label_overrides=tick_labels_green,
    title="Ready"
)

# --- Red Color Mapper for 'Not Ready' Provinces ---
# Slicing and reversing the palette for consistency with the green scale.
palette_red = brewer['YlOrRd'][7][:4]
red_color_mapper = LinearColorMapper(palette=palette_red, low=60, high=80)

ticks_red = list(range(60, 81, 4))
tick_labels_red = {str(tick): str(tick) for tick in ticks_red}

red_color_bar = ColorBar(
    color_mapper=red_color_mapper,
    label_standoff=8,
    width=800, 
    height=20,
    border_line_color=None, 
    location=(0,0), 
    orientation='horizontal', 
    major_label_overrides=tick_labels_red,
    title="Not Ready"
)

datestr = datetime.datetime.now().strftime("%d/%m/%Y")
title = Title()
# Tùy theo giá trị muốn vẽ mà thay đổi tiêu đề cho phù hợp
title.text = f"Vietnam PCI Index - {datestr}"
title.text_font_size = '16pt'
title.align = "center"

p = figure(
    title=title, 
    title_location='above',
    plot_height=1000 , 
    plot_width=900, 
    toolbar_location=None
)

# tinh chỉnh một số thuộc tính của hai trục
p.xgrid.grid_line_color = None
p.ygrid.grid_line_color = None
p.xaxis.axis_label = 'Kinh độ (longitude)'
p.xaxis.axis_label_text_font_size = "14pt"
p.yaxis.axis_label = 'Vĩ độ (latitude)'
p.yaxis.axis_label_text_font_size = "14pt"
p.yaxis.major_label_text_font_size = "12pt"
p.xaxis.major_label_text_font_size = "12pt"

# Plot 'not ready' provinces in red with intensity
p.patches(
    xs='xs',
    ys='ys', 
    source=not_ready_source,
    fill_color={'field' :'plot_data', 'transform' : red_color_mapper},
    line_color='black', 
    line_width=0.25, 
    fill_alpha=1
)

# Plot 'ready' provinces in green with intensity
p.patches(
    xs='xs',
    ys='ys', 
    source=ready_source,
    fill_color={'field' :'plot_data', 'transform' : green_color_mapper},
    line_color='black', 
    line_width=0.25, 
    fill_alpha=1
)

p.add_layout(green_color_bar, 'below')
p.add_layout(red_color_bar, 'above')

from bokeh.io import export_png
export_png(p, filename=f"pci_vn_{datetime.datetime.now().strftime('%Y-%m-%d')}.png")