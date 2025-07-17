import geopandas as gpd
import datetime
from bokeh.io import export_png
from bokeh.plotting import figure
from bokeh.models import GeoJSONDataSource, LabelSet, ColumnDataSource

# Load Vietnam provinces map
gdf_vn = gpd.read_file('/Users/tranlehai/Desktop/CEI-Simulation/vietnam-plot/vietnam_provinces.geojson')
gdf_vn.geometry = gdf_vn.geometry.buffer(0)

def safe_representative_point(geom):
    if geom is None or geom.is_empty:
        return (None, None)
    try:
        return geom.representative_point().coords[0]
    except Exception:
        return (None, None)

gdf_vn['coords'] = gdf_vn['geometry'].apply(safe_representative_point)
gdf_vn = gdf_vn[gdf_vn['coords'].apply(lambda c: c != (None, None))]
gdf_vn['x'] = [p[0] for p in gdf_vn['coords']]
gdf_vn['y'] = [p[1] for p in gdf_vn['coords']]
gdf_vn['label'] = gdf_vn['Name'].str.replace(r'\s*(Province|City)$', '', regex=True)

label_source = ColumnDataSource(data=dict(
    x=gdf_vn['x'],
    y=gdf_vn['y'],
    name=gdf_vn['label']
))

all_source = GeoJSONDataSource(geojson=gdf_vn.to_json())

p = figure(
    title_location='above',
    height=1000,
    width=900,
    toolbar_location=None
)

# Plot all provinces in gray
p.patches(
    xs='xs',
    ys='ys',
    source=all_source,
    fill_color='#EAEAEA',
    line_color='black',
    line_width=0.5,
)

# Add province names as labels
labels = LabelSet(x='x', y='y', text='name',
              x_offset=0, y_offset=0, source=label_source,
              text_align='center', text_baseline='middle',
              text_font_size="5pt", text_color="black",
              background_fill_color="white", background_fill_alpha=0.7)
p.add_layout(labels)

# Save the plot to a file
filename = f"All_Provinces_{datetime.datetime.now().strftime('%Y-%m-%d')}.png"
export_png(p, filename=filename)
print(f"Plot saved to {filename}")