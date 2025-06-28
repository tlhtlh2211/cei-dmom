#!/usr/bin/env python3
"""
Agent-Based Model (ABM) for Maternal and Child Health Access in Vietnam
Simulates health-seeking behaviors in Dien Bien and Thai Nguyen provinces

Based on the research framework for Vietnamese health systems using multi-level ABM
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import random
from pathlib import Path

# Set random seed for reproducibility
np.random.seed(42)
random.seed(42)

@dataclass
class AgentAttributes:
    """Base attributes for all agents"""
    age: int
    ethnicity: str  # Kinh, Hmong, Thai, etc.
    literacy_level: float  # 0-1 scale
    poverty_level: float  # 0-1 scale (1 = highest poverty)
    mobile_access: bool
    internet_access: bool
    distance_to_facility: float  # km

class MaternalAgent:
    """Agent representing mothers of reproductive age (15-49)"""
    
    def __init__(self, agent_id: str, commune: str, attributes: AgentAttributes):
        self.agent_id = agent_id
        self.commune = commune
        self.attributes = attributes
        
        # Health seeking behavior parameters
        self.anc_visits = 0
        self.anc_target = 4  # WHO recommendation
        self.weeks_pregnant = 0
        self.is_pregnant = False
        self.has_skilled_birth_attendant = False
        self.app_engagement = 0.0  # 0-1 scale
        self.received_sms = False
        self.chw_contacted = False
        
        # Behavioral thresholds (influenced by agent attributes)
        self.care_seeking_threshold = self._calculate_care_seeking_threshold()
        self.digital_engagement_threshold = self._calculate_digital_threshold()
        
    def _calculate_care_seeking_threshold(self) -> float:
        """Calculate threshold for seeking healthcare based on agent attributes"""
        # Lower threshold = more likely to seek care
        base_threshold = 0.5
        
        # Literacy increases care-seeking
        literacy_factor = -0.2 * self.attributes.literacy_level
        
        # Poverty decreases care-seeking
        poverty_factor = 0.15 * self.attributes.poverty_level
        
        # Distance decreases care-seeking
        distance_factor = 0.1 * min(self.attributes.distance_to_facility / 10, 0.3)
        
        # Ethnicity factor (minorities may have cultural barriers)
        ethnicity_factor = 0.1 if self.attributes.ethnicity != "Kinh" else 0
        
        threshold = base_threshold + literacy_factor + poverty_factor + distance_factor + ethnicity_factor
        return max(0.1, min(0.9, threshold))  # Bound between 0.1 and 0.9
    
    def _calculate_digital_threshold(self) -> float:
        """Calculate threshold for digital engagement"""
        if not self.attributes.mobile_access:
            return 1.0  # Cannot engage if no mobile access
            
        base_threshold = 0.6
        literacy_factor = -0.3 * self.attributes.literacy_level
        age_factor = 0.01 * max(0, self.attributes.age - 25)  # Older = less digital
        
        threshold = base_threshold + literacy_factor + age_factor
        return max(0.1, min(0.9, threshold))
    
    def become_pregnant(self):
        """Agent becomes pregnant"""
        self.is_pregnant = True
        self.weeks_pregnant = 1
        self.anc_visits = 0
        
    def progress_pregnancy(self):
        """Progress pregnancy by one week"""
        if self.is_pregnant:
            self.weeks_pregnant += 1
            
    def seek_anc_care(self, intervention_active: Dict[str, bool]) -> bool:
        """Decide whether to seek ANC care this week"""
        if not self.is_pregnant or self.anc_visits >= self.anc_target:
            return False
            
        # Base probability influenced by weeks pregnant
        base_prob = min(0.8, 0.1 + 0.02 * self.weeks_pregnant)
        
        # Intervention effects
        intervention_boost = 0.0
        
        if intervention_active.get('app_based', False) and self.app_engagement > 0.5:
            intervention_boost += 0.2
            
        if intervention_active.get('sms_outreach', False) and self.received_sms:
            intervention_boost += 0.15
            
        if intervention_active.get('chw_visits', False) and self.chw_contacted:
            intervention_boost += 0.25
            
        if intervention_active.get('incentives', False) and self.attributes.poverty_level > 0.6:
            intervention_boost += 0.3
            
        final_prob = min(0.95, base_prob + intervention_boost)
        
        # Decision based on threshold and probability
        if random.random() < final_prob and random.random() > self.care_seeking_threshold:
            self.anc_visits += 1
            return True
        return False
    
    def give_birth(self) -> bool:
        """Agent gives birth, returns whether skilled birth attendant was used"""
        if self.weeks_pregnant >= 40:
            # Probability of skilled birth attendant based on ANC visits and other factors
            base_prob = 0.4 + 0.1 * self.anc_visits
            
            # Literacy and poverty influence
            literacy_boost = 0.2 * self.attributes.literacy_level
            poverty_penalty = -0.15 * self.attributes.poverty_level
            
            # Distance penalty
            distance_penalty = -0.05 * min(self.attributes.distance_to_facility / 5, 0.4)
            
            final_prob = max(0.1, min(0.95, base_prob + literacy_boost + poverty_penalty + distance_penalty))
            
            self.has_skilled_birth_attendant = random.random() < final_prob
            self.is_pregnant = False
            self.weeks_pregnant = 0
            
            return self.has_skilled_birth_attendant
        return False

class ChildAgent:
    """Agent representing children under 5"""
    
    def __init__(self, agent_id: str, commune: str, mother_id: str, attributes: AgentAttributes):
        self.agent_id = agent_id
        self.commune = commune
        self.mother_id = mother_id
        self.attributes = attributes
        self.age_months = random.randint(0, 59)  # 0-59 months
        
        # Immunization tracking
        self.immunizations_received = 0
        self.immunizations_target = 8  # Standard childhood immunizations
        self.care_seeking_delays = 0  # Number of delayed care episodes
        
    def need_immunization(self) -> bool:
        """Check if child needs immunization based on age and current status"""
        expected_immunizations = min(self.immunizations_target, self.age_months // 2)
        return self.immunizations_received < expected_immunizations
        
    def receive_care(self, mother_agent: MaternalAgent, intervention_active: Dict[str, bool]) -> bool:
        """Receive healthcare (mainly immunizations) based on mother's behavior"""
        if not self.need_immunization():
            return False
            
        # Care probability largely depends on mother's characteristics
        base_prob = 0.3
        
        # Mother's literacy and poverty influence child care
        literacy_boost = 0.2 * mother_agent.attributes.literacy_level
        poverty_penalty = -0.1 * mother_agent.attributes.poverty_level
        
        # Intervention effects
        intervention_boost = 0.0
        if intervention_active.get('app_based', False) and mother_agent.app_engagement > 0.4:
            intervention_boost += 0.15
            
        if intervention_active.get('incentives', False) and mother_agent.attributes.poverty_level > 0.5:
            intervention_boost += 0.25
            
        final_prob = max(0.05, min(0.9, base_prob + literacy_boost + poverty_penalty + intervention_boost))
        
        if random.random() < final_prob:
            self.immunizations_received += 1
            return True
        else:
            self.care_seeking_delays += 1
            return False

class CHWAgent:
    """Community Health Worker agent"""
    
    def __init__(self, agent_id: str, commune: str, coverage_area: int):
        self.agent_id = agent_id
        self.commune = commune
        self.coverage_area = coverage_area  # Number of households covered
        self.visits_this_month = 0
        self.max_visits_per_month = 20
        
    def conduct_visit(self, target_agent: MaternalAgent) -> bool:
        """Conduct home visit to maternal agent"""
        if self.visits_this_month < self.max_visits_per_month:
            target_agent.chw_contacted = True
            self.visits_this_month += 1
            return True
        return False

class HealthFacility:
    """Healthcare facility agent"""
    
    def __init__(self, facility_id: str, commune: str, capacity: int, services: List[str]):
        self.facility_id = facility_id
        self.commune = commune
        self.capacity = capacity
        self.services = services
        self.patients_served_this_month = 0
        
    def can_serve_patient(self) -> bool:
        """Check if facility can serve more patients"""
        return self.patients_served_this_month < self.capacity
        
    def serve_patient(self, service_type: str) -> bool:
        """Serve a patient if capacity allows"""
        if service_type in self.services and self.can_serve_patient():
            self.patients_served_this_month += 1
            return True
        return False

class Commune:
    """Commune environment containing agents and facilities"""
    
    def __init__(self, name: str, province: str, demographic_data: pd.Series):
        self.name = name
        self.province = province
        self.demographic_data = demographic_data
        
        # Initialize agents
        self.maternal_agents: List[MaternalAgent] = []
        self.child_agents: List[ChildAgent] = []
        self.chw_agents: List[CHWAgent] = []
        self.health_facilities: List[HealthFacility] = []
        
        # Performance metrics
        self.metrics = {
            'anc_coverage': 0.0,
            'skilled_birth_attendance': 0.0,
            'immunization_coverage': 0.0,
            'digital_engagement': 0.0,
            'care_seeking_delays': 0
        }
        
        self._initialize_agents()
        self._initialize_facilities()
        
    def _initialize_agents(self):
        """Initialize agents based on demographic data"""
        # Create maternal agents
        num_women = int(self.demographic_data['women_15_49'])
        
        for i in range(num_women):
            # Generate realistic agent attributes
            attributes = AgentAttributes(
                age=random.randint(15, 49),
                ethnicity=self._sample_ethnicity(),
                literacy_level=self._sample_literacy(),
                poverty_level=self._sample_poverty(),
                mobile_access=random.random() < 0.8,  # 80% mobile access
                internet_access=random.random() < 0.4,  # 40% internet access
                distance_to_facility=random.exponential(3.0)  # Average 3km
            )
            
            agent = MaternalAgent(f"{self.name}_M_{i}", self.name, attributes)
            
            # Some agents start pregnant
            if random.random() < 0.15:  # 15% pregnancy rate
                agent.become_pregnant()
                
            self.maternal_agents.append(agent)
            
        # Create child agents
        num_children = int(self.demographic_data['children_under_5'])
        
        for i in range(num_children):
            # Children inherit some characteristics from mothers
            mother_id = random.choice(self.maternal_agents).agent_id if self.maternal_agents else None
            
            attributes = AgentAttributes(
                age=random.randint(0, 5),
                ethnicity=self._sample_ethnicity(),
                literacy_level=0.0,  # Children are not literate
                poverty_level=self._sample_poverty(),
                mobile_access=False,
                internet_access=False,
                distance_to_facility=random.exponential(3.0)
            )
            
            child = ChildAgent(f"{self.name}_C_{i}", self.name, mother_id or f"Unknown_{i}", attributes)
            self.child_agents.append(child)
            
        # Create CHW agents (1 per 500 people roughly)
        num_chw = max(1, int(self.demographic_data['total_population'] / 500))
        for i in range(num_chw):
            chw = CHWAgent(f"{self.name}_CHW_{i}", self.name, 100)
            self.chw_agents.append(chw)
    
    def _sample_ethnicity(self) -> str:
        """Sample ethnicity based on province characteristics"""
        if self.province == "Dien Bien":
            # More ethnic minorities in Dien Bien
            return random.choices(
                ["Kinh", "Thai", "Hmong", "Muong", "Other"],
                weights=[0.3, 0.25, 0.2, 0.15, 0.1]
            )[0]
        else:  # Thai Nguyen
            # More Kinh majority
            return random.choices(
                ["Kinh", "Tay", "Nung", "Thai", "Other"],
                weights=[0.6, 0.15, 0.1, 0.1, 0.05]
            )[0]
    
    def _sample_literacy(self) -> float:
        """Sample literacy level based on province characteristics"""
        if self.province == "Dien Bien":
            # Lower literacy in Dien Bien
            return max(0.0, np.random.normal(0.6, 0.2))
        else:  # Thai Nguyen
            # Higher literacy in Thai Nguyen
            return max(0.0, np.random.normal(0.8, 0.15))
    
    def _sample_poverty(self) -> float:
        """Sample poverty level based on province characteristics"""
        if self.province == "Dien Bien":
            # Higher poverty in Dien Bien
            return max(0.0, min(1.0, np.random.normal(0.7, 0.2)))
        else:  # Thai Nguyen
            # Lower poverty in Thai Nguyen
            return max(0.0, min(1.0, np.random.normal(0.4, 0.2)))
    
    def _initialize_facilities(self):
        """Initialize healthcare facilities"""
        # Basic health facility per commune
        facility = HealthFacility(
            f"{self.name}_Clinic",
            self.name,
            capacity=50,  # Patients per month
            services=["anc", "delivery", "immunization", "general"]
        )
        self.health_facilities.append(facility)
    
    def apply_intervention(self, intervention_type: str, coverage: float = 0.7):
        """Apply intervention to agents in commune"""
        if intervention_type == "app_based":
            # Target agents with mobile and internet access
            eligible_agents = [a for a in self.maternal_agents 
                             if a.attributes.mobile_access and a.attributes.internet_access]
            
            num_targeted = int(len(eligible_agents) * coverage)
            targeted_agents = random.sample(eligible_agents, min(num_targeted, len(eligible_agents)))
            
            for agent in targeted_agents:
                if random.random() > agent.digital_engagement_threshold:
                    agent.app_engagement = random.uniform(0.6, 0.9)
                    
        elif intervention_type == "sms_outreach":
            # Target agents with mobile access
            eligible_agents = [a for a in self.maternal_agents if a.attributes.mobile_access]
            
            num_targeted = int(len(eligible_agents) * coverage)
            targeted_agents = random.sample(eligible_agents, min(num_targeted, len(eligible_agents)))
            
            for agent in targeted_agents:
                agent.received_sms = True
                
        elif intervention_type == "chw_visits":
            # CHW visits prioritize high-poverty, low-access areas
            eligible_agents = [a for a in self.maternal_agents 
                             if a.attributes.poverty_level > 0.6 or a.attributes.distance_to_facility > 5]
            
            # CHWs can only visit limited number of households
            total_visits_possible = sum(chw.max_visits_per_month for chw in self.chw_agents)
            num_targeted = min(int(len(eligible_agents) * coverage), total_visits_possible)
            
            if eligible_agents:
                targeted_agents = random.sample(eligible_agents, min(num_targeted, len(eligible_agents)))
                
                for agent in targeted_agents:
                    # Find available CHW
                    available_chw = [chw for chw in self.chw_agents 
                                   if chw.visits_this_month < chw.max_visits_per_month]
                    if available_chw:
                        chw = random.choice(available_chw)
                        chw.conduct_visit(agent)
    
    def step(self, week: int, intervention_active: Dict[str, bool]):
        """Execute one simulation step (week)"""
        # Reset monthly counters every 4 weeks
        if week % 4 == 0:
            for chw in self.chw_agents:
                chw.visits_this_month = 0
            for facility in self.health_facilities:
                facility.patients_served_this_month = 0
        
        # Maternal agent actions
        for agent in self.maternal_agents:
            if agent.is_pregnant:
                agent.progress_pregnancy()
                agent.seek_anc_care(intervention_active)
                agent.give_birth()
            else:
                # Chance of becoming pregnant
                if random.random() < 0.002:  # ~10% annual pregnancy rate
                    agent.become_pregnant()
        
        # Child agent actions (monthly)
        if week % 4 == 0:
            for child in self.child_agents:
                # Find child's mother
                mother = next((m for m in self.maternal_agents if m.agent_id == child.mother_id), None)
                if mother:
                    child.receive_care(mother, intervention_active)
    
    def calculate_metrics(self) -> Dict[str, float]:
        """Calculate performance metrics for the commune"""
        # ANC Coverage (≥4 visits)
        pregnant_or_recently_pregnant = [a for a in self.maternal_agents 
                                       if a.is_pregnant or a.anc_visits > 0]
        
        if pregnant_or_recently_pregnant:
            anc_coverage = sum(1 for a in pregnant_or_recently_pregnant 
                             if a.anc_visits >= 4) / len(pregnant_or_recently_pregnant)
        else:
            anc_coverage = 0.0
        
        # Skilled Birth Attendance
        mothers_who_gave_birth = [a for a in self.maternal_agents if a.anc_visits > 0]
        if mothers_who_gave_birth:
            skilled_birth_rate = sum(1 for a in mothers_who_gave_birth 
                                   if a.has_skilled_birth_attendant) / len(mothers_who_gave_birth)
        else:
            skilled_birth_rate = 0.0
        
        # Immunization Coverage
        children_needing_immunization = [c for c in self.child_agents if c.age_months >= 12]
        if children_needing_immunization:
            immunization_coverage = np.mean([min(1.0, c.immunizations_received / c.immunizations_target) 
                                           for c in children_needing_immunization])
        else:
            immunization_coverage = 0.0
        
        # Digital Engagement
        digital_agents = [a for a in self.maternal_agents if a.attributes.mobile_access]
        if digital_agents:
            digital_engagement = np.mean([a.app_engagement for a in digital_agents])
        else:
            digital_engagement = 0.0
        
        # Care-seeking delays
        total_delays = sum(c.care_seeking_delays for c in self.child_agents)
        
        self.metrics = {
            'anc_coverage': anc_coverage,
            'skilled_birth_attendance': skilled_birth_rate,
            'immunization_coverage': immunization_coverage,
            'digital_engagement': digital_engagement,
            'care_seeking_delays': total_delays
        }
        
        return self.metrics

class ABMSimulation:
    """Main simulation class orchestrating the ABM"""
    
    def __init__(self, data_path: str):
        self.data_path = Path(data_path)
        self.communes: List[Commune] = []
        self.results: Dict[str, List[Dict]] = {}
        
        # Load and prepare data
        self._load_data()
        self._initialize_communes()
        
    def _load_data(self):
        """Load demographic data for both provinces"""
        dien_bien_data = pd.read_csv(self.data_path / "demographics" / "demographics_dien_bien.csv")
        thai_nguyen_data = pd.read_csv(self.data_path / "demographics" / "demographics_thai_nguyen.csv")
        
        # Use most recent year data
        self.demographic_data = pd.concat([
            dien_bien_data[dien_bien_data['year'] == dien_bien_data['year'].max()],
            thai_nguyen_data[thai_nguyen_data['year'] == thai_nguyen_data['year'].max()]
        ]).reset_index(drop=True)
        
        print(f"Loaded data for {len(self.demographic_data)} communes")
        
    def _initialize_communes(self):
        """Initialize commune agents"""
        for _, commune_data in self.demographic_data.iterrows():
            commune = Commune(
                name=commune_data['commune'],
                province=commune_data['province'],
                demographic_data=commune_data
            )
            self.communes.append(commune)
            
        print(f"Initialized {len(self.communes)} communes with agents")
    
    def run_scenario(self, scenario_name: str, duration_weeks: int = 52, 
                    interventions: Dict[str, bool] = None) -> Dict[str, List[Dict]]:
        """Run simulation scenario"""
        
        if interventions is None:
            interventions = {
                'app_based': False,
                'sms_outreach': False,
                'chw_visits': False,
                'incentives': False
            }
        
        print(f"\nRunning scenario: {scenario_name}")
        print(f"Interventions active: {[k for k, v in interventions.items() if v]}")
        
        # Apply interventions at the start
        for commune in self.communes:
            for intervention_type, is_active in interventions.items():
                if is_active:
                    commune.apply_intervention(intervention_type)
        
        # Run simulation
        scenario_results = []
        
        for week in range(duration_weeks):
            week_results = {'week': week, 'communes': []}
            
            for commune in self.communes:
                commune.step(week, interventions)
                
                # Calculate metrics every 4 weeks
                if week % 4 == 0:
                    metrics = commune.calculate_metrics()
                    commune_result = {
                        'commune': commune.name,
                        'province': commune.province,
                        'week': week,
                        **metrics
                    }
                    week_results['communes'].append(commune_result)
            
            if week % 4 == 0:
                scenario_results.extend(week_results['communes'])
                
            # Progress indicator
            if week % 13 == 0:
                print(f"  Week {week}/{duration_weeks} completed")
        
        self.results[scenario_name] = scenario_results
        return {scenario_name: scenario_results}
    
    def run_all_scenarios(self, duration_weeks: int = 52) -> Dict[str, List[Dict]]:
        """Run all intervention scenarios"""
        
        scenarios = {
            'baseline': {},
            'app_based': {'app_based': True},
            'sms_outreach': {'sms_outreach': True},
            'chw_visits': {'chw_visits': True},
            'incentives': {'incentives': True},
            'combined': {
                'app_based': True,
                'sms_outreach': True,
                'chw_visits': True,
                'incentives': True
            }
        }
        
        all_results = {}
        
        for scenario_name, interventions in scenarios.items():
            # Reset simulation state
            self._initialize_communes()
            
            # Run scenario
            scenario_results = self.run_scenario(scenario_name, duration_weeks, interventions)
            all_results.update(scenario_results)
        
        self.results = all_results
        return all_results
    
    def analyze_results(self) -> pd.DataFrame:
        """Analyze and summarize simulation results"""
        if not self.results:
            print("No results to analyze. Run simulation first.")
            return pd.DataFrame()
        
        # Combine all scenario results
        all_data = []
        for scenario, results in self.results.items():
            for result in results:
                result['scenario'] = scenario
                all_data.append(result)
        
        df = pd.DataFrame(all_data)
        
        # Calculate summary statistics
        summary = df.groupby(['scenario', 'province']).agg({
            'anc_coverage': ['mean', 'std'],
            'skilled_birth_attendance': ['mean', 'std'],
            'immunization_coverage': ['mean', 'std'],
            'digital_engagement': ['mean', 'std'],
            'care_seeking_delays': ['mean', 'sum']
        }).round(3)
        
        print("\n=== SIMULATION RESULTS SUMMARY ===")
        print(summary)
        
        return df
    
    def visualize_results(self, save_plots: bool = True):
        """Create visualizations of simulation results"""
        if not self.results:
            print("No results to visualize. Run simulation first.")
            return
        
        # Prepare data
        df = self.analyze_results()
        
        # Set up the plotting style
        plt.style.use('seaborn-v0_8')
        fig, axes = plt.subplots(2, 3, figsize=(18, 12))
        fig.suptitle('ABM Simulation Results: Maternal and Child Health Interventions', fontsize=16)
        
        metrics = ['anc_coverage', 'skilled_birth_attendance', 'immunization_coverage', 
                  'digital_engagement', 'care_seeking_delays']
        
        for i, metric in enumerate(metrics):
            row = i // 3
            col = i % 3
            ax = axes[row, col]
            
            # Create box plot by scenario and province
            if metric != 'care_seeking_delays':
                sns.boxplot(data=df, x='scenario', y=metric, hue='province', ax=ax)
                ax.set_ylim(0, 1)
                ax.set_ylabel(f'{metric.replace("_", " ").title()}')
            else:
                sns.boxplot(data=df, x='scenario', y=metric, hue='province', ax=ax)
                ax.set_ylabel('Care Seeking Delays (Count)')
            
            ax.set_xlabel('Intervention Scenario')
            ax.tick_params(axis='x', rotation=45)
            ax.legend(title='Province')
        
        # Remove empty subplot
        if len(metrics) < 6:
            fig.delaxes(axes[1, 2])
        
        plt.tight_layout()
        
        if save_plots:
            plt.savefig('abm_simulation_results.png', dpi=300, bbox_inches='tight')
            print("Visualization saved as 'abm_simulation_results.png'")
        
        plt.show()
        
        # Provincial comparison
        fig, ax = plt.subplots(1, 1, figsize=(12, 8))
        
        # Calculate improvement over baseline
        baseline_data = df[df['scenario'] == 'baseline'].groupby('province')[['anc_coverage', 'skilled_birth_attendance', 'immunization_coverage']].mean()
        
        improvement_data = []
        for scenario in df['scenario'].unique():
            if scenario == 'baseline':
                continue
                
            scenario_data = df[df['scenario'] == scenario].groupby('province')[['anc_coverage', 'skilled_birth_attendance', 'immunization_coverage']].mean()
            
            for province in scenario_data.index:
                for metric in ['anc_coverage', 'skilled_birth_attendance', 'immunization_coverage']:
                    improvement = ((scenario_data.loc[province, metric] - baseline_data.loc[province, metric]) / 
                                 baseline_data.loc[province, metric]) * 100
                    
                    improvement_data.append({
                        'scenario': scenario,
                        'province': province,
                        'metric': metric,
                        'improvement_percent': improvement
                    })
        
        improvement_df = pd.DataFrame(improvement_data)
        
        # Pivot for heatmap
        pivot_data = improvement_df.pivot_table(
            index=['scenario', 'province'], 
            columns='metric', 
            values='improvement_percent'
        )
        
        sns.heatmap(pivot_data, annot=True, fmt='.1f', cmap='RdYlBu_r', center=0, ax=ax)
        ax.set_title('Percentage Improvement Over Baseline by Scenario and Province')
        ax.set_xlabel('Health Metrics')
        ax.set_ylabel('Scenario and Province')
        
        plt.tight_layout()
        
        if save_plots:
            plt.savefig('abm_improvement_heatmap.png', dpi=300, bbox_inches='tight')
            print("Improvement heatmap saved as 'abm_improvement_heatmap.png'")
        
        plt.show()
    
    def export_results(self, filename: str = 'abm_simulation_results.csv'):
        """Export simulation results to CSV"""
        if not self.results:
            print("No results to export. Run simulation first.")
            return
        
        df = self.analyze_results()
        df.to_csv(filename, index=False)
        print(f"Results exported to {filename}")

def main():
    """Main function to run the ABM simulation"""
    print("=== Agent-Based Model for Maternal and Child Health in Vietnam ===")
    print("Simulating health access behaviors in Dien Bien and Thai Nguyen provinces")
    
    # Initialize simulation
    sim = ABMSimulation("data")
    
    # Run all scenarios
    print("\nRunning all intervention scenarios...")
    results = sim.run_all_scenarios(duration_weeks=52)  # 1 year simulation
    
    # Analyze results
    print("\nAnalyzing results...")
    df = sim.analyze_results()
    
    # Create visualizations
    print("\nCreating visualizations...")
    sim.visualize_results()
    
    # Export results
    sim.export_results()
    
    print("\n=== Simulation Complete ===")
    print("Check the generated plots and CSV file for detailed results.")
    
    return sim, df

if __name__ == "__main__":
    simulation, results_df = main() 