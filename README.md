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

## 🔬 Agent State Transition Formulas

### Variable Notation

| Variable | Description |
|----------|-------------|
| $wp_i^t$ | weeks_pregnant for agent $i$ at time $t$ |
| $lit_i$ | literacy_level for agent $i$ (0.0-1.0) |
| $pov_i$ | poverty_level for agent $i$ (0.0-1.0) |
| $dist_i$ | distance_to_facility for agent $i$ |
| $age_i^t$ | age for agent $i$ at time $t$ |
| $anc_i^t$ | anc_visits for agent $i$ at time $t$ |
| $app_i^t$ | app_engagement for agent $i$ at time $t$ |
| $eth_i$ | ethnicity_factor for agent $i$ |
| $am_j^t$ | age_months for child $j$ at time $t$ |
| $gen_j$ | gender for child $j$ |
| $lit_{m_j}$ | literacy_level of mother of child $j$ |
| $pov_{m_j}$ | poverty_level of mother of child $j$ |
| $app_{m_j}$ | app_engagement of mother of child $j$ |
| $sms_i$ | received_sms for agent $i$ (boolean) |
| $chw_i$ | chw_contacted for agent $i$ (boolean) |
| $mobile_i$ | mobile_access for agent $i$ (boolean) |
| $week^t$ | current simulation week at time $t$ |
| $I_{type}^t$ | intervention indicator (1 if active, 0 if not) |
| $\mathbb{1}(condition)$ | indicator function (1 if true, 0 if false) |

### 1. MaternalAgent State Transitions

**State Space:** $S_i^t \in \{Maternal, Pregnant, Exit\}$

**General Transition Formula:**
$$S_i^{t+1} = f(S_i^t, age_i^t, wp_i^t, lit_i, pov_i, dist_i, interventions^t)$$

#### A. Maternal → Pregnant Transition
$$P(Maternal \rightarrow Pregnant) = 0.0015 \times fertility_i^t$$

Where $fertility_i^t = 1$ if all conditions met, $0$ otherwise:
- $(week^t - last\_birth_i) > 52$ (1-year spacing)
- $children_i < 3$ (max children limit)  
- $age_i^t < 45$ (fertility age limit)

#### B. Care-Seeking Threshold
$$threshold_i = \max(0.1, \min(0.9, 0.5 - 0.2 \times lit_i + 0.15 \times pov_i + 0.1 \times \min(dist_i/10, 0.3) + eth_i))$$

Where: $eth_i = 0.1$ if ethnicity ≠ "Kinh", else $0$

#### C. ANC Care-Seeking Probability
$$P(seek\_ANC_i^t) = [\min(0.95, base_i^t + 0.3 \times lit_i + boost_i^t)] \times [1 - threshold_i]$$

Where:
- $base_i^t = \min(0.8, 0.1 + 0.02 \times wp_i^t)$
- $boost_i^t = 0.2 \times I_{app}^t \times \mathbb{1}(app_i^t > 0.5) + 0.15 \times I_{sms}^t \times sms_i + 0.25 \times I_{chw}^t \times chw_i + 0.3 \times I_{incentives}^t \times \mathbb{1}(pov_i > 0.6)$

#### D. Skilled Birth Probability
$$P(skilled\_birth_i) = \max(0.1, \min(0.95, 0.4 + 0.1 \times anc_i^t + 0.2 \times lit_i - 0.15 \times pov_i - 0.05 \times \min(dist_i/5, 0.4)))$$

#### E. Aging Transition (Maternal/Pregnant → Exit)
$$P(S_i^{t+1} = Exit \mid age_i^t \geq 50) = 1$$

### 2. ChildAgent State Transitions

**State Space:** $S_j^t \in \{Child\_U5, Youth\_5\_15, Maternal, Exit\}$

**General Transition Formula:**
$$S_j^{t+1} = g(S_j^t, am_j^t, gen_j, lit_{m_j}, pov_{m_j}, interventions^t)$$

#### A. Age Progression (Monthly)
$$am_j^{t+1} = am_j^t + 1 \quad \text{if } (week^t \bmod 4 = 0)$$

#### B. Child U5 → Youth Transition
$$P(Child\_U5 \rightarrow Youth \mid am_j^t = 60) = 1$$

#### C. Youth → Maternal/Exit Transition
$$P(Youth \rightarrow Maternal \mid am_j^t \geq 180, gen_j = \text{"female"}) = 1$$
$$P(Youth \rightarrow Exit \mid am_j^t \geq 180, gen_j = \text{"male"}) = 1$$

#### D. Child Immunization Probability
$$P(immunization_j^t) = \max(0.05, \min(0.9, 0.3 + 0.2 \times lit_{m_j} - 0.1 \times pov_{m_j} + boost_j^t))$$

Where:
$$boost_j^t = 0.15 \times I_{app}^t \times \mathbb{1}(app_{m_j} > 0.4) + 0.25 \times I_{incentives}^t \times \mathbb{1}(pov_{m_j} > 0.5)$$

### 3. Commune-Level Environmental Dynamics

**Formula:**
$$env^{t+1} = h(real\_data^t, indicators^t, interventions^t)$$

**Real Data Integration:**
$$lit\_commune^t = GSO\_literacy(\text{"Dien\_Bien"}, year^t) + variation$$
$$pov\_commune^t = MOLISA\_poverty(\text{"Dien\_Bien"}, year^t) + variation$$

### 4. Intervention Effect Modifiers

**Digital App Engagement:**
$$app_i^{t+1} = f(mobile_i, lit_i, age_i^t, I_{app}^t)$$

**Community Health Worker Contact:**
$$P(chw_i^t) = f(chw\_deployment^t, dist_i, pov_i)$$

### 5. Population Dynamics

**Birth Rate (Weekly):**
$$births^t = \sum_i P(birth_i^t \mid wp_i^t \geq 40)$$

**Population Flow:**
$$Pop^{t+1} = Pop^t + births^t - aged\_out^t - exits^t$$

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

