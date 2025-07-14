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

data = pd.read_csv("/Users/tranlehai/Desktop/CEI-Simulation/results/national_pci_analysis_with_names.csv")
data["plot_data"] = data["PCI"]
gdf_vn = gpd.read_file('/Users/tranlehai/Desktop/CEI-Simulation/vietnam-plot/vietnam_provinces.geojson')

# Simplify geometries to remove holes and prevent Bokeh warnings
gdf_vn.geometry = gdf_vn.geometry.buffer(0)

vn_data = gdf_vn.merge(data[['Name', 'plot_data']], on='Name', how='left')
plot_data = json.dumps(json.loads(vn_data.to_json()))

geosource = GeoJSONDataSource(geojson=plot_data)
palette = brewer['Blues'][8][::-1]
high_val = np.ceil(data.plot_data.max())
color_mapper = LinearColorMapper(palette=palette, low=0, high=high_val)

# Dynamically generate tick labels for the color bar.
# This creates clear, evenly spaced labels based on the data's range.
step = 1
if high_val > 10:
    # If the range is large, increase the step size to avoid crowded labels
    step = int(np.ceil(high_val / 5))
    
ticks = range(0, int(high_val) + 1, step)
tick_labels = {str(tick): str(tick) for tick in ticks}

color_bar = ColorBar(
    color_mapper=color_mapper, 
    label_standoff=8,
    width=850, 
    height=20,
    border_line_color=None, 
    location = (0,0), 
    orientation = 'horizontal', 
    major_label_overrides = tick_labels
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

p.patches(
    xs='xs',
    ys='ys', 
    source=geosource,
    fill_color = {'field' :'plot_data', 'transform' : color_mapper}, # plot_data là field dùng để  quy định độ đậm nhạt màu tô
    line_color = 'black', 
    line_width = 0.25, 
    fill_alpha = 1
)

p.add_layout(color_bar, 'below')

from bokeh.io import export_png
export_png(p, filename=f"pci_vn_{datetime.datetime.now().strftime('%Y-%m-%d')}.png")