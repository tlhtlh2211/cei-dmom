# CEI-Simulation: Vietnamese Maternal & Child Health ABM

Agent-based model simulating maternal and child health behaviors in Vietnamese provinces using real government data.

## 🎯 Overview

This project models healthcare access patterns in **Dien Bien** and **Thai Nguyen** provinces using authentic Vietnamese government data (GSO/MOLISA) from 2019-2024.

## 🚀 Quick Start

### Python Simulation
```bash
pip install -r requirements.txt
python run_simulation.py
```

### GAMA Platform
1. Download [GAMA Platform](https://gama-platform.org/download)
2. Open `CEI-Simulation/models/dien-bien-abm.gaml`
3. Click "Run Experiment"

## 📊 Key Features

- **Real Vietnamese Data**: 304 communes, 6-year demographic data (GSO/MOLISA)
- **Agent Types**: Maternal agents (women 15-49), Child agents (under 5), Communes
- **Health Behaviors**: ANC visits, immunization, pregnancy, care-seeking
- **Interventions**: Mobile app, SMS, CHW visits, incentives
- **10% Sampling**: Efficient simulation showing realistic population patterns

## 📈 Sample Results

| Intervention | ANC Coverage | Child Immunization |
|-------------|--------------|-------------------|
| Baseline    | 42.6%        | 65.4%            |
| Mobile App  | 69.1%        | 78.2%            |
| CHW Visits  | 77.9%        | 84.6%            |
| Combined    | 87.1%        | 91.3%            |

## 🏗️ Structure

```
CEI-Simulation/
├── data/demographics/           # Real Vietnamese government data
├── models/dien-bien-abm.gaml   # GAMA simulation model  
├── scripts/                    # Python ABM & validation
└── run_simulation.py          # Interactive launcher
```

## 🔧 Technical Notes

- **Data Sources**: Vietnamese GSO Population Census & MOLISA Poverty Reports
- **Population Scale**: 10% sampling for computational efficiency
- **Validation**: Extensive monitoring against real demographic patterns
- **Platform**: Python + GAMA Platform support

---

**Ready for health policy research and intervention planning in Vietnam** 🇻🇳
