#!/usr/bin/env python3
"""
District-level Composite Index (DCI) and Provincial Upscaling Confidence (PUC) Calculator
Implementation following the exact formulas from the provincial upscaling framework
"""

import pandas as pd
import numpy as np
import glob
from pathlib import Path
from sklearn.linear_model import LinearRegression
import warnings
warnings.filterwarnings('ignore')

class DCIPUCCalculator:
    def __init__(self, data_path='data', simulation_path='CEI-Simulation/data'):
        self.data_path = Path(data_path)
        self.simulation_path = Path(simulation_path)
        
        # Target year T for provincial roll-out (e.g., 2030)
        self.T = 2030
        
        # Six-year period for analysis
        self.target_years = list(range(2025, 2031)) # New strategy: 2025-2030
        
        self.provinces = ['Dien Bien', 'Thai Nguyen']
        
        # Policy targets for beneficial indicators (higher is better)
        self.C_target = 10.0    # Target share of children <5 (%)
        self.W_target = 28.0    # Target share of women 15-49 (%)
        self.I_target = 100.0    # Target internet access rate (%)
        
        # Policy targets and worst values for adverse indicators (lower is better)
        self.P_target = 3.0     # Target poverty rate (%)
        self.L_target = 2.0     # Target illiteracy rate (%)  
        self.P_max = 15.0
        self.L_max = 30.0 
        
        # Readiness thresholds
        self.DCI_threshold = 75.0   # District readiness threshold
        self.PUC_threshold = 80.0   # Provincial readiness threshold
        
        # Initialize data containers
        self.simulation_data = {}
        self.demographic_data = {}
        self.metrics_data = {}
        self.indicators = {}
        self.six_year_means = {}
        self.normalized_indicators = {}
        self.dci_results = {}
        self.puc_results = {}
        
    def load_simulation_data(self):
        """Load simulation data from CEI-Simulation/data directory."""
        print("Loading simulation data...")
        
        # Find all simulation files
        simulation_files = glob.glob(str(self.simulation_path / "district_simulation_*.csv"))
        
        for province in self.provinces:
            province_data = []
            
            # Load files for this province
            for file_path in simulation_files:
                if province.replace(' ', '_') in file_path:
                    try:
                        # Read CSV, skipping the first row with quotes
                        df = pd.read_csv(file_path, skiprows=1)
                        
                        # Clean the data - remove any duplicate headers
                        df = df[df['Year'] != 'Year']  # Remove duplicate header
                        df = df.dropna()  # Remove any empty rows
                        
                        # Convert to numeric, handling any string values
                        df['Year'] = pd.to_numeric(df['Year'], errors='coerce')
                        df['Maternal_Agents'] = pd.to_numeric(df['Maternal_Agents'], errors='coerce')
                        df['Children_U5'] = pd.to_numeric(df['Children_U5'], errors='coerce')
                        df['Youth_5_15'] = pd.to_numeric(df['Youth_5_15'], errors='coerce')
                        df['Literacy_Rate'] = pd.to_numeric(df['Literacy_Rate'], errors='coerce')
                        df['Poverty_Rate'] = pd.to_numeric(df['Poverty_Rate'], errors='coerce')
                        
                        # Drop rows with any NaN values after conversion
                        df = df.dropna()
                        
                        province_data.append(df)
                        
                    except Exception as e:
                        print(f"Error loading {file_path}: {e}")
                        continue
            
            if province_data:
                combined_df = pd.concat(province_data, ignore_index=True)
                self.simulation_data[province] = combined_df
                
                districts = combined_df['District'].unique()
                print(f"Loaded simulation data for {province}: {len(districts)} districts, {len(combined_df)} records")
            else:
                print(f"No simulation data found for {province}")
    
    def load_demographic_data(self):
        """Load demographic data from data/demographics/ directory."""
        print("Loading demographic data...")
        
        for province in self.provinces:
            province_file = self.data_path / 'demographics' / f'demographics_{province.lower().replace(" ", "_")}.csv'
            if province_file.exists():
                self.demographic_data[province] = pd.read_csv(province_file)
                print(f"Loaded demographic data for {province}: {len(self.demographic_data[province])} records")
            else:
                print(f"Warning: {province_file} not found")
    
    def load_metrics_data(self):
        """Load actual I, P, L metrics data from data/metrics directory."""
        print("Loading actual metrics data (I, P, L indicators)...")
        
        try:
            # Load poverty rates (P indicator)
            poverty_df = pd.read_csv(self.data_path / 'metrics' / 'poverty_rates.csv')
            
            # Load literacy rates (L indicator)  
            literacy_df = pd.read_csv(self.data_path / 'metrics' / 'literacy_rates.csv')
            
            # Load GRDP per capita (I indicator proxy)
            grdp_df = pd.read_csv(self.data_path / 'metrics' / 'grdp_per_capita.csv')
            
            # Store metrics data
            self.metrics_data = {
                'poverty': poverty_df,
                'literacy': literacy_df,
                'grdp': grdp_df
            }
            
            print(f"Loaded metrics data:")
            print(f"- Poverty rates: {len(poverty_df)} records")
            print(f"- Literacy rates: {len(literacy_df)} records") 
            print(f"- GRDP per capita: {len(grdp_df)} records")
            
        except Exception as e:
            print(f"Error loading metrics data: {e}")
            self.metrics_data = {}
    
    def get_province_metric_trends(self, province, metric_type):
        """Get historical trends for a province metric and project to target years."""
        if metric_type not in self.metrics_data:
            return None
            
        metric_df = self.metrics_data[metric_type]
        province_data = metric_df[metric_df['Province'] == province].copy()
        
        if len(province_data) == 0:
            return None
            
        # Sort by year
        province_data = province_data.sort_values('Year')
        
        # Get the appropriate column name
        if metric_type == 'poverty':
            value_col = 'Poverty_Rate'
        elif metric_type == 'literacy':
            value_col = 'Literacy_Rate'
        elif metric_type == 'grdp':
            value_col = 'GRDP_Per_Capita_Million_VND'
        else:
            return None
            
        years = province_data['Year'].values
        values = province_data[value_col].values
        
        # Project to target years using linear regression
        projected_values = self.project_demographic_indicators(years, values)
        
        return projected_values
    
    def project_demographic_indicators(self, years, values):
        """Use linear regression to project future demographic values."""
        if len(years) < 2:
            return [values[-1]] * 6 if values else [0] * 6
        
        X = np.array(years).reshape(-1, 1)
        y = np.array(values)
        
        model = LinearRegression()
        model.fit(X, y)
        
        # Project using the model
        future_years = np.array(self.target_years).reshape(-1, 1)
        projected_values = model.predict(future_years)
        
        return projected_values
    
    def calculate_district_variations_by_year(self, district, province, total_population):
        """Calculate district-level I, P, L using actual poverty and literacy data."""
        
        # Get year-specific province projections
        poverty_projected = self.get_province_metric_trends(province, 'poverty')
        literacy_projected = self.get_province_metric_trends(province, 'literacy') 
        
        # Calculate year-specific values
        yearly_values = []
        
        for i, year in enumerate(self.target_years):
            # Get province base values for this year
            if poverty_projected is not None and len(poverty_projected) > i:
                poverty_rate = poverty_projected[i]  # Actual poverty rate (%)
            else:
                poverty_rate = 7.0  # Default realistic poverty rate
                
            if literacy_projected is not None and len(literacy_projected) > i:
                literacy_rate = literacy_projected[i]  # Actual literacy rate (%)
            else:
                literacy_rate = 90.0  # Default literacy rate
            
            # Fixed internet access for all districts (as per framework)
            district_internet = 95.0  
            
            # Use actual rates (not scores) for normalization later
            yearly_values.append({
                'year': year,
                'poverty_rate': poverty_rate,      # Actual poverty rate for P normalization
                'literacy_rate': literacy_rate,    # Actual literacy rate for L normalization  
                'internet_rate': district_internet # Internet access rate for I normalization
            })
        
        return yearly_values
    
    def calculate_indicators(self):
        """
        Calculate indicators with new strategy:
        - Xd (actual) is from GAMA model projections.
        - Xtarget (expected) is from linear regression on historical data.
        """
        print("\nCalculating indicators with new dynamic target strategy...")
        
        for province in self.provinces:
            if province not in self.simulation_data or province not in self.demographic_data:
                print(f"Missing data for {province}")
                continue
            
            # Get simulation data for I, P, L
            sim_df = self.simulation_data[province].copy()
            
            # Get demographic data for C, W
            demo_df = self.demographic_data[province].copy()
            
            # Process each district
            all_indicators = []
            districts = sim_df['District'].unique()
            
            for district in districts:
                # === 1. GET GAMA SIMULATION DATA (for Xd) ===
                district_sim = sim_df[sim_df['District'] == district].copy()
                if not district_sim.empty:
                    # Project GAMA outputs to cover the full 2025-2030 period
                    gama_years = district_sim['Year'].values
                    # USER CORRECTION: Multiply by 10 to scale up 1/10th population simulation
                    gama_children_abs = district_sim['Children_U5'].values * 10
                    gama_women_abs = district_sim['Maternal_Agents'].values * 10
                    projected_gama_c_abs = self.project_demographic_indicators(gama_years, gama_children_abs)
                    projected_gama_w_abs = self.project_demographic_indicators(gama_years, gama_women_abs)
                else:
                    projected_gama_c_abs = [0] * len(self.target_years)
                    projected_gama_w_abs = [0] * len(self.target_years)

                # === 2. GET HISTORICAL DATA & PROJECT BASELINE (for Xtarget) ===
                district_demo = demo_df[demo_df['district'] == district]
                if len(district_demo) == 0:
                    print(f"No demographic data for district {district} in {province}")
                    continue
                
                district_aggregated = district_demo.groupby('year')[['total_population', 'women_15_49', 'children_under_5']].sum().reset_index()
                
                # Project C and W absolute numbers from historical data for the dynamic target
                historical_years = district_aggregated['year'].tolist()
                historical_c_abs = district_aggregated['children_under_5'].tolist()
                historical_w_abs = district_aggregated['women_15_49'].tolist()
                projected_c_target_abs = self.project_demographic_indicators(historical_years, historical_c_abs)
                projected_w_target_abs = self.project_demographic_indicators(historical_years, historical_w_abs)
                
                total_population_mean = district_aggregated['total_population'].mean()
                
                variations = self.calculate_district_variations_by_year(district, province, total_population_mean)
                
                # === 3. COMBINE & STORE INDICATORS FOR 6-YEAR PERIOD ===
                for i, variation in enumerate(variations):
                    all_indicators.append({
                        'District': district,
                        'Year': self.target_years[i],
                        'C_gama_abs': projected_gama_c_abs[i],
                        'W_gama_abs': projected_gama_w_abs[i],
                        'C_target_abs': projected_c_target_abs[i],
                        'W_target_abs': projected_w_target_abs[i],
                        'I': variation['internet_rate'],
                        'P': variation['poverty_rate'],
                        'L': variation['literacy_rate'],
                    })
            
            self.indicators[province] = pd.DataFrame(all_indicators)
            print(f"Calculated indicators for {province}: {len(districts)} districts")
    
    def calculate_six_year_means(self):
        """Calculate six-year means for each indicator and district following Equation (1)."""
        print(f"\nCalculating six-year means for period {self.target_years[0]}-{self.target_years[-1]}...")
        
        for province in self.provinces:
            if province not in self.indicators:
                continue
            
            df = self.indicators[province]
            
            # Calculate six-year mean: X̄d = (1/6) * Σ(k=1 to 6) Xd,T-k
            means = df.groupby('District')[[
                'C_gama_abs', 'W_gama_abs', 'C_target_abs', 'W_target_abs', 
                'I', 'P', 'L'
            ]].mean().reset_index()
            
            # Store the means
            self.six_year_means[province] = means
            
            print(f"Six-year means calculated for {province}: {len(means)} districts")

    def normalize_indicators_formula(self):
        """Normalize indicators using exact formulas from Equations (2) and (3)."""
        print("\nApplying normalization formulas with new dynamic target strategy...")
        
        for province in self.provinces:
            if province not in self.six_year_means:
                continue
                
            df = self.six_year_means[province].copy()
            
            # New strategy for C and W: X*d = min(100, 100 * Xd_gama / Xd_target)
            # where values are the average absolute numbers.
            df['C_target_abs'] = df['C_target_abs'].replace(0, 1) # Avoid division by zero
            df['W_target_abs'] = df['W_target_abs'].replace(0, 1) # Avoid division by zero
            
            df['C_star'] = np.minimum(100, 100 * df['C_gama_abs'] / df['C_target_abs'])
            df['W_star'] = np.minimum(100, 100 * df['W_gama_abs'] / df['W_target_abs'])

            # Equation (2) for Internet Access (I)
            df['I_star'] = np.minimum(100, 100 * df['I'] / self.I_target)
            
            # Equation (3): Adverse indicators normalization (P and L) using fixed max values
            illiteracy_rate = 100 - df['L']
            df['P_star'] = self.normalize_adverse_indicator(df['P'], self.P_target, self.P_max)
            df['L_star'] = self.normalize_adverse_indicator(illiteracy_rate, self.L_target, self.L_max)
            
            # Cleanup non-finite values that may result from division issues
            df.replace([np.inf, -np.inf], 0, inplace=True)
            df.fillna(0, inplace=True)

            self.normalized_indicators[province] = df
            print(f"Applied dynamic target normalization for {province}")
            
            # Show normalization results
            for indicator in ['C_star', 'W_star', 'I_star', 'P_star', 'L_star']:
                values = df[indicator]
                print(f"  {indicator}: {values.min():.1f} - {values.max():.1f}")
    
    def normalize_adverse_indicator(self, X_values, X_target, X_max):
        """
        Apply Equation (3) for adverse indicators (where lower values are better).
        
        X*d = { 100,                           Xd ≤ Xtarget
              { 0,                             Xd ≥ Xmax  
              { 100 * (Xmax - Xd)/(Xmax - Xtarget),  otherwise
        """
        X_star = np.zeros_like(X_values, dtype=float)
        
        # Case 1: Xd ≤ Xtarget → X*d = 100
        mask_target = X_values <= X_target
        X_star[mask_target] = 100.0
        
        # Case 2: Xd ≥ Xmax → X*d = 0  
        mask_worst = X_values >= X_max
        X_star[mask_worst] = 0.0

        # USER LOGIC: If there is no variation (X_max == X_target), all districts get 100.
        # This also handles the case where X_max is less than X_target, which means all districts beat the target.
        if X_max <= X_target:
             X_star.fill(100.0)
             return X_star

        # Case 3: Xtarget < Xd < Xmax → X*d = 100 * (Xmax - Xd)/(Xmax - Xtarget)
        mask_between = (X_values > X_target) & (X_values < X_max)
        if X_max != X_target:  # Avoid division by zero
            X_star[mask_between] = 100 * (X_max - X_values[mask_between]) / (X_max - X_target)
        
        return X_star
    
    def calculate_dci_formula(self):
        """Calculate District-level Composite Index using Equation (4)."""
        print("\nCalculating DCI using Equation (4)...")
        
        for province in self.provinces:
            if province not in self.normalized_indicators:
                continue
            
            df = self.normalized_indicators[province].copy()
            
            # Equation (4): DCId = (C*d + W*d + I*d + P*d + L*d) / 5
            df['DCI'] = (df['C_star'] + df['W_star'] + df['I_star'] + df['P_star'] + df['L_star']) / 5
            
            # Equation (5): District readiness check DCId ≥ DCIthreshold
            df['ready'] = df['DCI'] >= self.DCI_threshold
            
            self.dci_results[province] = df
            
            print(f"DCI calculated for {province}")
            print(f"  Average DCI: {df['DCI'].mean():.2f}")
            print(f"  DCI range: {df['DCI'].min():.2f} - {df['DCI'].max():.2f}")
            print(f"  Ready districts (DCI ≥ {self.DCI_threshold}): {df['ready'].sum()}/{len(df)}")
    
    def calculate_puc_formula(self):
        """Calculate Provincial Upscaling Confidence using Equation (6)."""
        print("\nCalculating PUC using Equation (6)...")
        
        for province in self.provinces:
            if province not in self.dci_results:
                continue
            
            df = self.dci_results[province]
            
            # Count districts meeting readiness threshold
            N = len(df)  # Total number of districts
            n_pass = df['ready'].sum()  # Number of districts with DCId ≥ DCIthreshold
            
            # Equation (6): PUC = 100 × npass/N
            puc = 100 * (n_pass / N) if N > 0 else 0
            
            # Equation (7): Province readiness check PUC ≥ PUCthreshold
            province_ready = puc >= self.PUC_threshold
            
            # Determine recommended action
            if puc >= 85:
                action = "Proceed with full province-wide upscaling"
            elif puc >= self.PUC_threshold:
                action = "Proceed with phased upscaling - monitor lagging districts"
            elif puc >= 50:
                action = "Partial readiness - strengthen lagging districts first"
            else:
                action = "Postpone upscaling - major capacity building required"
            
            self.puc_results[province] = {
                'PUC': puc,
                'total_districts': N,
                'ready_districts': n_pass,
                'province_ready': province_ready,
                'action': action,
                'threshold_used': self.PUC_threshold
            }
            
            print(f"{province} PUC: {puc:.1f}%")
            print(f"  Province ready (PUC ≥ {self.PUC_threshold}%): {province_ready}")
            print(f"  Action: {action}")
    
    def create_summary_report(self):
        """Create comprehensive summary report following the exact framework."""
        print("\n" + "="*90)
        print("PROVINCIAL UPSCALING CONFIDENCE (PUC) ANALYSIS")
        print("Following Exact Mathematical Framework")
        print("="*90)
        
        print(f"\nFRAMEWORK PARAMETERS:")
        print(f"Target Year (T): {self.T}")
        print(f"Six-year period: {self.target_years[0]}-{self.target_years[-1]}")
        print(f"DCI Threshold: {self.DCI_threshold}")
        print(f"PUC Threshold: {self.PUC_threshold}%")
        
        print(f"\nPOLICY TARGETS:")
        print(f"Beneficial indicators (C, W) use a DYNAMIC target based on historical trends.")
        print(f"  I_target (internet access): {self.I_target}%")
        print(f"Adverse indicators (lower is better):")
        print(f"  P_target (poverty): {self.P_target}%, P_max: {self.P_max}%")
        print(f"  L_target (illiteracy): {self.L_target}%, L_max: {self.L_max}%")
        
        for province in self.provinces:
            if province not in self.dci_results:
                continue
            
            print(f"\n{province.upper()}")
            print("-" * 60)
            
            # PUC summary
            puc_data = self.puc_results[province]
            print(f"PUC: {puc_data['PUC']:.1f}%")
            print(f"Ready Districts: {puc_data['ready_districts']}/{puc_data['total_districts']}")
            print(f"Province Ready: {puc_data['province_ready']} (threshold: {puc_data['threshold_used']}%)")
            print(f"Recommendation: {puc_data['action']}")
            
            # District details
            dci_data = self.dci_results[province]
            print(f"\nDistrict Analysis (Absolute Numbers):")
            print(f"{'District':<25} {'C-Actual':<10} {'C-Expect':<10} {'W-Actual':<10} {'W-Expect':<10} {'DCI':<8} {'Ready':<8} {'C*':<6} {'W*':<6} {'I*':<6} {'P*':<6} {'L*':<6}")
            print("-" * 130)
            
            for _, row in dci_data.iterrows():
                ready_status = "YES" if row['ready'] else "NO"
                print(f"{row['District']:<25} {int(row['C_gama_abs']):<10} {int(row['C_target_abs']):<10} {int(row['W_gama_abs']):<10} {int(row['W_target_abs']):<10} {row['DCI']:<8.1f} {ready_status:<8} "
                      f"{row['C_star']:<6.1f} {row['W_star']:<6.1f} {row['I_star']:<6.1f} "
                      f"{row['P_star']:<6.1f} {row['L_star']:<6.1f}")
        
        print("\n" + "="*90)
        print("MATHEMATICAL FORMULAS APPLIED:")
        print("(1) Six-year mean: X̄d = (1/6) Σ Xd,T-k for period 2025-2030")
        print("(2) Beneficial normalization C*, W*: X*d = min(100, 100 * AVG_GAMA_NUMBER / AVG_REGRESSION_NUMBER)")
        print("    Beneficial normalization I*:   X*d = min(100, 100·Xd/Xtarget_fixed)")
        print("(3) Adverse normalization: X*d = 100·(Xmax-Xd)/(Xmax-Xtarget)")
        print("(4) District Composite Index: DCId = (C*d + W*d + I*d + P*d + L*d)/5")
        print("(5) District readiness: DCId ≥ DCIthreshold")
        print("(6) Provincial Upscaling Confidence: PUC = 100·npass/N")
        print("(7) Province readiness: PUC ≥ PUCthreshold")
        print("="*90)
    
    def save_results(self):
        """Save results to CSV files."""
        output_dir = Path('results')
        output_dir.mkdir(exist_ok=True)
        
        print(f"\nSaving results to {output_dir}/...")
        
        # Save DCI results
        for province in self.dci_results:
            filename = f"dci_results_{province.lower().replace(' ', '_')}_target_based.csv"
            self.dci_results[province].to_csv(output_dir / filename, index=False)
            print(f"Saved: {filename}")
        
        # Save PUC summary
        puc_summary = []
        for province, data in self.puc_results.items():
            puc_summary.append({
                'Province': province,
                'PUC': data['PUC'],
                'Total_Districts': data['total_districts'],
                'Ready_Districts': data['ready_districts'],
                'Action': data['action']
            })
        
        puc_df = pd.DataFrame(puc_summary)
        puc_df.to_csv(output_dir / 'puc_summary_target_based.csv', index=False)
        print("Saved: puc_summary_target_based.csv")
    
    def run_analysis(self):
        """Run the complete analysis following the exact mathematical framework."""
        print("Starting DCI/PUC Analysis - Exact Mathematical Framework")
        print("="*70)
        
        self.load_simulation_data()
        self.load_demographic_data()
        self.load_metrics_data()
        self.calculate_indicators()
        self.calculate_six_year_means()  # Changed from calculate_five_year_means
        self.normalize_indicators_formula()  # Changed to use exact formulas
        self.calculate_dci_formula()  # Changed to use exact formula
        self.calculate_puc_formula()  # Changed to use exact formula
        self.create_summary_report()
        self.save_results()
        
        print("\nAnalysis completed using new dynamic target strategy!")


def main():
    calculator = DCIPUCCalculator()
    calculator.run_analysis()


if __name__ == "__main__":
    main() 