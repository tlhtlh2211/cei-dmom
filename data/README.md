# Data Directory Structure for ABM Simulation

This directory contains all data files needed for the Agent-Based Model simulation of maternal and child health access in Vietnamese provinces.

## Overview

**Complete Database Coverage:**
- ✅ **Dien Bien Province**: 770 records (10 districts, 125 communes)  
- ✅ **Thai Nguyen Province**: 1,080 records (5 districts, 106 communes)
- 📊 **Total Coverage**: 1,850 demographic records across 2 provinces
- 📅 **Temporal Range**: 2019-2024 (6-year longitudinal data)

## Directory Structure

```
data/
├── demographics/           # Population and demographic data
│   ├── demographics_dien_bien.csv      # Complete Dien Bien province data
│   ├── demographics_thai_nguyen.csv    # Complete Thai Nguyen province data
│   └── spatial_hierarchy.csv
├── spatial/               # Geographic and spatial data
│   ├── commune_boundaries.shp
│   ├── health_facilities.csv
│   └── transport_networks.csv
├── behavioral/            # Survey and behavioral parameters
│   ├── survey_parameters.csv
│   └── behavioral_rules.csv
├── economic/              # Economic and poverty indicators
│   ├── poverty_indicators.csv
│   └── household_economics.csv
└── validation/            # Data for model validation
    ├── baseline_outcomes.csv
    └── historical_trends.csv
```

## File Descriptions

### demographics/

#### **demographics_dien_bien.csv** 
- **Coverage**: Complete Dien Bien Province
- **Districts**: 10 districts (Tuan Giao, Dien Bien Dong, Muong Cha, Muong Ang, Muong Lay, Dien Bien Phu, Nam Po, Dien Bien, Muong Nhe, Tua Chua)
- **Communes**: 125 communes
- **Records**: 770 demographic records (2019-2024)
- **Data**: Population counts, women aged 15-49, children under 5

#### **demographics_thai_nguyen.csv**
- **Coverage**: Complete Thai Nguyen Province  
- **Districts**: 5 major districts (Dong Hy, Vo Nhai, Phu Binh, Dinh Hoa, Dai Tu)
- **Communes**: 106 communes
- **Records**: 1,080 demographic records (2019-2024)
- **Data**: Population counts, women aged 15-49, children under 5

#### **spatial_hierarchy.csv**
- Administrative hierarchy (province > district > commune)

### spatial/
- **commune_boundaries.shp**: GIS shapefile with commune boundaries
- **health_facilities.csv**: Location and capacity of health facilities
- **transport_networks.csv**: Road networks and travel times

### behavioral/
- **survey_parameters.csv**: Behavioral parameters from household surveys
- **behavioral_rules.csv**: Decision-making rules for agents

### economic/
- **poverty_indicators.csv**: Multidimensional poverty indicators by location
- **household_economics.csv**: Economic data for agent initialization

### validation/
- **baseline_outcomes.csv**: Known health outcomes for model calibration
- **historical_trends.csv**: Historical data for validation

## Data Schema

Each demographic CSV file contains these columns:
- `province`: Province name (Dien Bien or Thai Nguyen)
- `district`: District name within the province
- `commune`: Commune name within the district  
- `year`: Data year (2019-2024)
- `total_population`: Total population count
- `women_15_49`: Number of women aged 15-49 (reproductive age)
- `children_under_5`: Number of children under 5 years old
- `admin_level`: Administrative level indicator (commune)

## Data Quality Standards

✅ **Complete Coverage**: All administrative units included  
✅ **Consistent Format**: Standardized CSV structure across provinces  
✅ **Validated Data**: Population consistency checks passed  
✅ **Temporal Completeness**: 6-year coverage (2019-2024)  
✅ **ABM-Ready**: Formatted for GAMA Platform simulation  

All CSV files follow these standards:
- UTF-8 encoding
- Comma-separated values
- Header row with descriptive column names
- No missing values in key identifier columns
- Consistent naming conventions (snake_case)
- Vietnamese diacritics preserved in place names

## Usage

### Data Validation
```bash
# Validate Dien Bien data
python scripts/validate_data.py data/demographics/demographics_dien_bien.csv

# Validate Thai Nguyen data  
python scripts/validate_data.py data/demographics/demographics_thai_nguyen.csv
```

### GAMA Model Integration
1. Place data files in appropriate subdirectories
2. Import data into GAMA model using provided import scripts
3. Configure simulation parameters for chosen province(s)
4. Run ABM simulation with complete demographic foundation

## Research Applications

This comprehensive dataset enables:
- **Maternal Health Access Modeling**: Simulate ANC visit patterns
- **Child Health Interventions**: Model immunization coverage
- **Health System Planning**: Optimize facility placement
- **Policy Impact Analysis**: Compare intervention scenarios
- **Geographic Health Equity**: Analyze urban-rural disparities
- **Multi-Province Comparisons**: Comparative policy analysis

## Data Sources

All demographic data manually transcribed from official Vietnamese government statistics with commune-level granularity, ensuring authentic representation of administrative hierarchies and population distributions for accurate Agent-Based Modeling. 