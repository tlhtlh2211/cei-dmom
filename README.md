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

## 🔬 Agent Behavior (Simplified)

> **For detailed mathematical formulas**, see the GAML model files or technical documentation.

### Key Variables
- **weeks_pregnant_i**: Number of weeks agent i has been pregnant
- **literacy_i**: Literacy level for agent i (0.0-1.0)  
- **poverty_i**: Poverty level for agent i (0.0-1.0)
- **distance_i**: Distance to health facility for agent i
- **age_i**: Age of agent i
- **anc_visits_i**: Number of ANC visits for agent i
- **ethnicity_i**: Ethnicity factor (0.1 for non-Kinh, 0 for Kinh)
- **current_week**: Current simulation week
- **intervention_boost**: Effects from app, SMS, CHW, incentives

### 1. MaternalAgent State Transitions

**State Space:** $S_i^t \in \{Maternal, Pregnant, Exit\}$

**General Transition Formula:**
```
S_i(t+1) = f(S_i(t), age_i, weeks_pregnant_i, literacy_i, poverty_i, distance_i, interventions)
```

#### A. Maternal → Pregnant Transition
```
P(Maternal → Pregnant) = 0.0015 × fertility_constraints_i
```

Where fertility_constraints_i = 1 if all conditions met, 0 otherwise:
- (current_week - weeks_since_last_birth_i) > 52 (1-year spacing)
- total_children_i < 3 (max children limit)  
- age_i < 45 (fertility age limit)

#### B. Care-Seeking Threshold
```
threshold_i = max(0.1, min(0.9, 0.5 - 0.2×literacy_i + 0.15×poverty_i + 0.1×distance_i/10 + ethnicity_i))
```

#### C. ANC Care-Seeking Probability  
```
P(seek_ANC_i) = [min(0.95, base_prob_i + 0.3×literacy_i + intervention_boost_i)] × [1 - threshold_i]
```

Where:
- base_prob_i = min(0.8, 0.1 + 0.02×weeks_pregnant_i)
- intervention_boost_i = intervention effects from apps, SMS, CHW visits, incentives

#### D. Skilled Birth Probability
```
P(skilled_birth_i) = max(0.1, min(0.95, 0.4 + 0.1×anc_visits_i + 0.2×literacy_i - 0.15×poverty_i - 0.05×distance_i/5))
```

#### E. Aging Transition  
```
P(Maternal/Pregnant → Exit | age_i ≥ 50) = 1
```

### 2. ChildAgent State Transitions

#### A. Age Progression (Monthly)
```
age_months_j(t+1) = age_months_j(t) + 1    if (current_week mod 4 = 0)
```

#### B. Transitions by Age
- **Child U5 → Youth**: at age_months_j = 60 (age 5)
- **Youth → Maternal** (females): at age_months_j ≥ 180 (age 15)  
- **Youth → Exit** (males): at age_months_j ≥ 180 (age 15)

#### C. Child Immunization Probability
```
P(receive_immunization_j) = max(0.05, min(0.9, 0.3 + 0.2×literacy_mother_j - 0.1×poverty_mother_j + intervention_boost_j))
```

Where:
- literacy_mother_j, poverty_mother_j = mother's characteristics
- intervention_boost_j = effects from app engagement, incentives

### 3. Key Model Dynamics

**Population Flow:**
$$Pop(t+1) = Pop(t) + births(t) - exits(t)$$

**Real Data Integration:**
- Literacy/poverty rates updated from Vietnamese government data (GSO/MOLISA)
- Commune demographics change over time (2019-2024)

**Intervention Effects:**
- **Mobile app**: +20% ANC care-seeking (if engaged)
- **SMS outreach**: +15% ANC care-seeking  
- **CHW visits**: +25% ANC care-seeking
- **Incentives**: +30% care-seeking (for poor households)

### Key Model Parameters

- **Pregnancy Rate**: $0.0015$ (0.15% weekly)
- **Mobile Penetration**: $0.65$ (65% rural access)  
- **Sampling Rates**: $0.1$ (10% of population)
- **ANC Target**: $4$ visits (WHO recommendation)
- **Immunization Target**: $8$ doses (Vietnamese schedule)

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

