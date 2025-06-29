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

## 🔬 Key Model Formulas

### Care-Seeking Behavior
```
Care_Seeking_Threshold = 0.5 - 0.2×Literacy + 0.15×Poverty + 0.1×(Distance/10) + 0.1×Ethnicity_Factor
```

### Skilled Birth Attendance
```
SBA_Probability = 0.4 + 0.1×ANC_Visits + 0.2×Literacy - 0.15×Poverty - 0.05×min(Distance/5, 0.4)
```

### Intervention Effectiveness
```
Improved_Coverage = Baseline_Coverage × (1 + Σ Intervention_Effects)

Intervention_Effects:
- Mobile App: +0.15    - CHW Visits: +0.20
- SMS Outreach: +0.10  - Incentives: +0.25
```

### Population Scaling
```
Real_Population = Simulated_Population × 10  (10% sampling)
```

### Target Population Estimation
```
Target_Women_15_49 = Total_Population × 0.26
Target_Children_U5 = Total_Population × 0.12
```

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

---

