#!/usr/bin/env python3
"""
Plot Actual vs Predicted Data for District-Level ABM
====================================================

This script creates visualization plots comparing:
1. Actual Vietnamese government data (2019-2024)
2. Simulation predictions (2024-2030)

For maternal agents and children U5 populations at district level.
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# Set up plotting style
plt.style.use('default')
sns.set_palette("husl")

class DistrictDataVisualizer:
    def __init__(self, data_dir="../data"):
        self.data_dir = Path(data_dir)
        self.simulation_log_path = self.data_dir / "district_simulation_log.csv"
        self.dien_bien_path = self.data_dir / "demographics" / "demographics_dien_bien.csv"
        self.thai_nguyen_path = self.data_dir / "demographics" / "demographics_thai_nguyen.csv"
        
        # Load data
        self.actual_data = None
        self.simulation_data = None
        self.district_name = None
        self.province_name = None
        
    def load_actual_data(self, target_district, target_province):
        """Load and aggregate actual Vietnamese government data for target district"""
        print(f"Loading actual data for {target_district}, {target_province}...")
        
        # Load appropriate province data
        if target_province == "Dien Bien":
            df = pd.read_csv(self.dien_bien_path)
        elif target_province == "Thai Nguyen":
            df = pd.read_csv(self.thai_nguyen_path)
        else:
            raise ValueError(f"Unknown province: {target_province}")
        
        # Aggregate commune data to district level
        district_data = df[df['district'] == target_district].groupby('year').agg({
            'total_population': 'sum',
            'women_15_49': 'sum',
            'children_under_5': 'sum'
        }).reset_index()
        
        # Apply sampling rates (same as simulation)
        maternal_sampling_rate = 0.1
        child_sampling_rate = 0.1
        
        district_data['actual_maternal'] = (district_data['women_15_49'] * maternal_sampling_rate).astype(int)
        district_data['actual_children_u5'] = (district_data['children_under_5'] * child_sampling_rate).astype(int)
        district_data['actual_youth_5_15'] = (district_data['total_population'] * 0.1 * child_sampling_rate).astype(int)
        
        self.actual_data = district_data
        self.district_name = target_district
        self.province_name = target_province
        
        print(f"Loaded actual data for years: {district_data['year'].min()}-{district_data['year'].max()}")
        return district_data
    
    def load_simulation_data(self):
        """Load simulation predictions from CSV log"""
        if not self.simulation_log_path.exists():
            print(f"Warning: Simulation log not found at {self.simulation_log_path}")
            return None
        
        print("Loading simulation predictions...")
        sim_data = pd.read_csv(self.simulation_log_path)
        
        # Filter for target district if multiple districts logged
        if self.district_name and self.province_name:
            sim_data = sim_data[
                (sim_data['District'] == self.district_name) & 
                (sim_data['Province'] == self.province_name)
            ]
        
        self.simulation_data = sim_data
        print(f"Loaded simulation data for years: {sim_data['Year'].min()}-{sim_data['Year'].max()}")
        return sim_data
    
    def create_comparison_plots(self, save_path="../plots"):
        """Create comprehensive comparison plots"""
        if self.actual_data is None:
            print("Error: No actual data loaded. Call load_actual_data() first.")
            return
        
        # Create plots directory
        plots_dir = Path(save_path)
        plots_dir.mkdir(exist_ok=True)
        
        # Set up the plotting
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle(f'Actual vs Predicted: {self.district_name}, {self.province_name}', 
                     fontsize=16, fontweight='bold')
        
        # Plot 1: Maternal Agents
        self._plot_maternal_agents(axes[0, 0])
        
        # Plot 2: Children U5
        self._plot_children_u5(axes[0, 1])
        
        # Plot 3: Youth 5-15 (if simulation data available)
        self._plot_youth_5_15(axes[1, 0])
        
        # Plot 4: Combined Overview
        self._plot_combined_overview(axes[1, 1])
        
        plt.tight_layout()
        
        # Save plot
        save_file = plots_dir / f"actual_vs_predicted_{self.district_name.replace(' ', '_')}_{self.province_name.replace(' ', '_')}.png"
        plt.savefig(save_file, dpi=300, bbox_inches='tight')
        print(f"Plot saved to: {save_file}")
        
        plt.show()
    
    def _plot_maternal_agents(self, ax):
        """Plot maternal agents actual vs predicted"""
        # Plot actual data
        ax.plot(self.actual_data['year'], self.actual_data['actual_maternal'], 
                'o-', color='blue', linewidth=2, markersize=8, label='Actual (GSO Data)')
        
        # Plot simulation data if available
        if self.simulation_data is not None and len(self.simulation_data) > 0:
            ax.plot(self.simulation_data['Year'], self.simulation_data['Maternal_Agents'], 
                    's--', color='red', linewidth=2, markersize=8, label='Predicted (Simulation)')
            
            # Add overlap period (2024) for validation
            overlap_actual = self.actual_data[self.actual_data['year'] == 2024]
            overlap_sim = self.simulation_data[self.simulation_data['Year'] == 2024]
            
            if len(overlap_actual) > 0 and len(overlap_sim) > 0:
                ax.scatter(2024, overlap_actual['actual_maternal'].iloc[0], 
                          color='green', s=100, marker='*', label='2024 Validation', zorder=5)
        
        ax.set_title('Maternal Agents (Women 15-49)', fontweight='bold')
        ax.set_xlabel('Year')
        ax.set_ylabel('Number of Agents')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Add vertical line at 2024 (transition from actual to predicted)
        ax.axvline(x=2024, color='gray', linestyle=':', alpha=0.7, label='Prediction Start')
    
    def _plot_children_u5(self, ax):
        """Plot children U5 actual vs predicted"""
        # Plot actual data
        ax.plot(self.actual_data['year'], self.actual_data['actual_children_u5'], 
                'o-', color='orange', linewidth=2, markersize=8, label='Actual (GSO Data)')
        
        # Plot simulation data if available
        if self.simulation_data is not None and len(self.simulation_data) > 0:
            ax.plot(self.simulation_data['Year'], self.simulation_data['Children_U5'], 
                    's--', color='purple', linewidth=2, markersize=8, label='Predicted (Simulation)')
            
            # Add overlap period (2024) for validation
            overlap_actual = self.actual_data[self.actual_data['year'] == 2024]
            overlap_sim = self.simulation_data[self.simulation_data['Year'] == 2024]
            
            if len(overlap_actual) > 0 and len(overlap_sim) > 0:
                ax.scatter(2024, overlap_actual['actual_children_u5'].iloc[0], 
                          color='green', s=100, marker='*', label='2024 Validation', zorder=5)
        
        ax.set_title('Children Under 5', fontweight='bold')
        ax.set_xlabel('Year')
        ax.set_ylabel('Number of Agents')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Add vertical line at 2024
        ax.axvline(x=2024, color='gray', linestyle=':', alpha=0.7)
    
    def _plot_youth_5_15(self, ax):
        """Plot youth 5-15 actual vs predicted"""
        # Plot actual data (estimated 10% of population)
        ax.plot(self.actual_data['year'], self.actual_data['actual_youth_5_15'], 
                'o-', color='green', linewidth=2, markersize=8, label='Actual (10% est.)')
        
        # Plot simulation data if available
        if self.simulation_data is not None and len(self.simulation_data) > 0 and 'Youth_5_15' in self.simulation_data.columns:
            ax.plot(self.simulation_data['Year'], self.simulation_data['Youth_5_15'], 
                    's--', color='brown', linewidth=2, markersize=8, label='Predicted (Simulation)')
        
        ax.set_title('Youth 5-15 Years', fontweight='bold')
        ax.set_xlabel('Year')
        ax.set_ylabel('Number of Agents')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Add vertical line at 2024
        ax.axvline(x=2024, color='gray', linestyle=':', alpha=0.7)
    
    def _plot_combined_overview(self, ax):
        """Plot combined overview with percentage changes"""
        # Calculate percentage changes from 2024 baseline
        baseline_year = 2024
        
        if self.simulation_data is not None and len(self.simulation_data) > 0:
            baseline_maternal = self.simulation_data[self.simulation_data['Year'] == baseline_year]['Maternal_Agents'].iloc[0]
            baseline_children = self.simulation_data[self.simulation_data['Year'] == baseline_year]['Children_U5'].iloc[0]
            
            # Calculate percentage changes for predictions
            maternal_pct = ((self.simulation_data['Maternal_Agents'] - baseline_maternal) / baseline_maternal * 100)
            children_pct = ((self.simulation_data['Children_U5'] - baseline_children) / baseline_children * 100)
            
            ax.plot(self.simulation_data['Year'], maternal_pct, 
                    's--', color='red', linewidth=2, label='Maternal % Change')
            ax.plot(self.simulation_data['Year'], children_pct, 
                    's--', color='purple', linewidth=2, label='Children U5 % Change')
        
        ax.set_title('Population Change from 2024 Baseline (%)', fontweight='bold')
        ax.set_xlabel('Year')
        ax.set_ylabel('Percentage Change (%)')
        ax.legend()
        ax.grid(True, alpha=0.3)
        ax.axhline(y=0, color='black', linestyle='-', alpha=0.5)
    
    def generate_summary_report(self):
        """Generate a summary report of actual vs predicted comparison"""
        if self.actual_data is None:
            return "No actual data loaded."
        
        report = []
        report.append(f"District-Level ABM Validation Report")
        report.append(f"=" * 40)
        report.append(f"District: {self.district_name}")
        report.append(f"Province: {self.province_name}")
        report.append("")
        
        # Actual data summary
        report.append("ACTUAL DATA (Vietnamese Government):")
        report.append(f"Years: {self.actual_data['year'].min()}-{self.actual_data['year'].max()}")
        if 2024 in self.actual_data['year'].values:
            actual_2024 = self.actual_data[self.actual_data['year'] == 2024].iloc[0]
            report.append(f"2024 Baseline:")
            report.append(f"  - Maternal Agents: {actual_2024['actual_maternal']:,}")
            report.append(f"  - Children U5: {actual_2024['actual_children_u5']:,}")
            report.append(f"  - Youth 5-15: {actual_2024['actual_youth_5_15']:,}")
        
        # Simulation data summary
        report.append("")
        if self.simulation_data is not None and len(self.simulation_data) > 0:
            report.append("SIMULATION DATA (ABM Predictions):")
            report.append(f"Years: {self.simulation_data['Year'].min()}-{self.simulation_data['Year'].max()}")
            
            if 2030 in self.simulation_data['Year'].values:
                sim_2030 = self.simulation_data[self.simulation_data['Year'] == 2030].iloc[0]
                report.append(f"2030 Projections:")
                report.append(f"  - Maternal Agents: {sim_2030['Maternal_Agents']:,}")
                report.append(f"  - Children U5: {sim_2030['Children_U5']:,}")
                if 'Youth_5_15' in self.simulation_data.columns:
                    report.append(f"  - Youth 5-15: {sim_2030['Youth_5_15']:,}")
        else:
            report.append("SIMULATION DATA: Not available (run simulation first)")
        
        return "\n".join(report)


def main():
    """Main function to run the visualization"""
    print("District-Level ABM: Actual vs Predicted Data Visualization")
    print("=" * 60)
    
    # Initialize visualizer
    visualizer = DistrictDataVisualizer()
    
    # Example: Visualize Thai Nguyen city data
    try:
        # Load actual government data
        actual_data = visualizer.load_actual_data("Thanh Pho Thai Nguyen", "Thai Nguyen")
        print(f"\nActual data loaded: {len(actual_data)} years")
        
        # Load simulation data (if available)
        sim_data = visualizer.load_simulation_data()
        if sim_data is not None:
            print(f"Simulation data loaded: {len(sim_data)} years")
        else:
            print("Simulation data not available - run the ABM model first")
        
        # Create comparison plots
        print("\nGenerating plots...")
        visualizer.create_comparison_plots()
        
        # Generate summary report
        print("\n" + visualizer.generate_summary_report())
        
    except Exception as e:
        print(f"Error: {e}")
        print("\nTip: Make sure you have:")
        print("1. Run the district-level ABM simulation")
        print("2. The demographic CSV files are available")
        print("3. Specified the correct district and province names")

if __name__ == "__main__":
    main() 