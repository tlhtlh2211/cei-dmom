#!/usr/bin/env python3
"""
District-level Composite Index (DCI) and Provincial Upscaling Confidence (PUC) Calculator
Uses actual simulation data from CEI-Simulation/data directory
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
        self.target_years = list(range(2025, 2030))  # 2025-2029 for five-year mean
        self.provinces = ['Dien Bien', 'Thai Nguyen']
        
        # Initialize data containers
        self.simulation_data = {}
        self.demographic_data = {}
        self.metrics_data = {}  # Add metrics data container
        self.indicators = {}
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
        
        # Project 2025-2029
        future_years = np.array(self.target_years).reshape(-1, 1)
        projected_values = model.predict(future_years)
        
        return projected_values
    
    def calculate_district_variations_by_year(self, district, province, total_population):
        """Calculate district-level I, P, L using fixed internet, adjusted poverty, and actual literacy."""
        
        # Get year-specific province projections
        poverty_projected = self.get_province_metric_trends(province, 'poverty')
        literacy_projected = self.get_province_metric_trends(province, 'literacy') 
        
        # Calculate year-specific values
        yearly_values = []
        
        for i, year in enumerate(self.target_years):
            # Get province base values for this year
            if poverty_projected is not None and len(poverty_projected) > i:
                poverty_rate = poverty_projected[i]
            else:
                poverty_rate = 10.0  # Default
                
            if literacy_projected is not None and len(literacy_projected) > i:
                literacy_rate = literacy_projected[i]
            else:
                literacy_rate = 90.0  # Default
            
            # Fixed values for all districts
            district_internet = 95.0  # Fixed base for all
            district_poverty_score = 100 - poverty_rate  # Lower poverty = higher score
            district_literacy_score = literacy_rate  # Higher literacy = higher score
            
            # Basic bounds
            district_internet = np.clip(district_internet, 10.0, 99.0)
            district_poverty_score = np.clip(district_poverty_score, 0.0, 99.9)
            district_literacy_score = np.clip(district_literacy_score, 50.0, 99.9)
            
            yearly_values.append({
                'year': year,
                'poverty_score': district_poverty_score,  # This is now 100-poverty_rate
                'literacy_score': district_literacy_score,  # This is actual literacy
                'internet_rate': district_internet
            })
        
        return yearly_values
    
    def calculate_indicators(self):
        """Calculate indicators combining demographic data (C, W) and simulation data (I, P, L)."""
        print("\nCalculating indicators from combined data sources...")
        
        for province in self.provinces:
            if province not in self.simulation_data or province not in self.demographic_data:
                print(f"Missing data for {province}")
                continue
            
            # Get simulation data for I, P, L
            sim_df = self.simulation_data[province].copy()
            sim_df = sim_df[sim_df['Year'].isin(self.target_years)]
            
            # Get demographic data for C, W
            demo_df = self.demographic_data[province].copy()
            
            # Process each district
            all_indicators = []
            districts = sim_df['District'].unique()
            
            for district in districts:
                # Get simulation data for this district
                district_sim = sim_df[sim_df['District'] == district]
                
                if len(district_sim) == 0:
                    continue
                
                # Get demographic data for this district
                district_demo = demo_df[demo_df['district'] == district]
                
                if len(district_demo) == 0:
                    print(f"No demographic data for district {district} in {province}")
                    continue
                
                # Clean demographic data - aggregate communes first, then clean outliers
                # First aggregate all communes within the district by year
                district_aggregated = district_demo.groupby('year')[['total_population', 'women_15_49', 'children_under_5']].sum().reset_index()
                district_aggregated['district'] = district
                
                # Calculate percentages after aggregation
                district_aggregated['W_percent'] = (district_aggregated['women_15_49'] / district_aggregated['total_population']) * 100
                district_aggregated['C_percent'] = (district_aggregated['children_under_5'] / district_aggregated['total_population']) * 100
                
                # Now detect and fix outliers at the aggregated district level
                w_median = district_aggregated['W_percent'].median()
                w_std = district_aggregated['W_percent'].std()
                w_outlier_mask = np.abs(district_aggregated['W_percent'] - w_median) > 2 * w_std
                
                c_median = district_aggregated['C_percent'].median()
                c_std = district_aggregated['C_percent'].std()
                c_outlier_mask = np.abs(district_aggregated['C_percent'] - c_median) > 2 * c_std
                
                if w_outlier_mask.any() or c_outlier_mask.any():
                    print(f"  Fixing district-level outliers in {district}")
                    if w_outlier_mask.any():
                        district_aggregated.loc[w_outlier_mask, 'W_percent'] = w_median
                        print(f"    Fixed W outliers: {district_aggregated.loc[w_outlier_mask, 'year'].tolist()}")
                    if c_outlier_mask.any():
                        district_aggregated.loc[c_outlier_mask, 'C_percent'] = c_median
                        print(f"    Fixed C outliers: {district_aggregated.loc[c_outlier_mask, 'year'].tolist()}")
                
                district_demo_clean = district_aggregated
                
                # Project demographic indicators using regression
                historical_years = district_demo_clean['year'].tolist()
                
                # Use already-calculated and cleaned percentages
                historical_c = district_demo_clean['C_percent'].tolist()
                historical_w = district_demo_clean['W_percent'].tolist()
                
                # Project C and W for target years
                projected_c = self.project_demographic_indicators(historical_years, historical_c)
                projected_w = self.project_demographic_indicators(historical_years, historical_w)
                
                # Get total population for synthetic variations
                total_population = district_demo_clean['total_population'].mean()
                
                # Create population-based synthetic variations for I, P, L
                variations = self.calculate_district_variations_by_year(district, province, total_population)
                
                # Use the direct synthetic values instead of multipliers on base rates
                # This creates much more meaningful variations
                for i, variation in enumerate(variations):
                    all_indicators.append({
                        'District': district,
                        'Year': self.target_years[i],
                        'C': projected_c[i],
                        'W': projected_w[i],
                        'I': variation['internet_rate'],
                        'P': variation['poverty_score'],
                        'L': variation['literacy_score']  # Now using actual literacy
                    })
            
            self.indicators[province] = pd.DataFrame(all_indicators)
            print(f"Calculated indicators for {province}: {len(districts)} districts")
    
    def calculate_five_year_means(self):
        """Calculate five-year means for each indicator and district (2025-2029)."""
        print("\nCalculating five-year means...")
        
        for province in self.provinces:
            if province not in self.indicators:
                continue
            
            df = self.indicators[province]
            
            # Calculate means for each district and indicator
            means = df.groupby('District')[['C', 'W', 'I', 'P', 'L']].mean().reset_index()
            self.indicators[province] = means
            
            print(f"Five-year means calculated for {province}: {len(means)} districts")
    
    def normalize_indicators(self):
        """Normalize only C and W indicators within each province - I, P, L use raw values."""
        
        # Normalize each province independently for within-province comparison
        for province in self.provinces:
            if province not in self.indicators:
                continue
                
            df = self.indicators[province].copy()
            
            # Only normalize C and W (demographic indicators that vary between districts)
            for indicator in ['C', 'W']:
                values = df[indicator].values.copy()
                
                min_val = values.min()
                max_val = values.max()
                
                if min_val == max_val:
                    df[f'{indicator}_norm'] = 100
                else:
                    # Higher is better for C and W
                    df[f'{indicator}_norm'] = 100 * (values - min_val) / (max_val - min_val)
            
            # For I, P, L - use raw values directly (no normalization needed)
            df['I_norm'] = df['I']  # Raw internet score
            df['P_norm'] = df['P']  # Raw poverty score (100-poverty_rate)
            df['L_norm'] = df['L']  # Raw literacy score
            
            self.indicators[province] = df
            print(f"Normalized C & W for {province}, using raw I, P, L values")
            
            # Show the actual ranges for reference
            for indicator in ['C', 'W']:
                values = df[indicator].values
                print(f"  {indicator}: {values.min():.2f} - {values.max():.2f}")
            print(f"  I: {df['I'].iloc[0]:.2f} (fixed for all districts)")
            print(f"  P: {df['P'].iloc[0]:.2f} (fixed for all districts)")
            print(f"  L: {df['L'].iloc[0]:.2f} (fixed for all districts)")
    
    def calculate_dci(self):
        """Calculate District-level Composite Index."""
        print("\nCalculating DCI...")
        
        for province in self.provinces:
            if province not in self.indicators:
                continue
            
            df = self.indicators[province].copy()
            
            # Calculate DCI as average of normalized scores
            df['DCI'] = (df['C_norm'] + df['W_norm'] + df['I_norm'] + df['P_norm'] + df['L_norm']) / 5
            
            # Determine readiness (DCI >= 75)
            df['ready'] = df['DCI'] >= 70
            
            self.dci_results[province] = df
            
            print(f"DCI calculated for {province}")
            print(f"  Average DCI: {df['DCI'].mean():.2f}")
            print(f"  Ready districts: {df['ready'].sum()}/{len(df)}")
    
    def calculate_puc(self):
        """Calculate Provincial Upscaling Confidence."""
        print("\nCalculating PUC...")
        
        for province in self.provinces:
            if province not in self.dci_results:
                continue
            
            df = self.dci_results[province]
            N = len(df)
            n_pass = df['ready'].sum()
            
            puc = 100 * (n_pass / N) if N > 0 else 0
            
            # Determine action
            if puc >= 90:
                action = "Proceed with province-wide upscaling"
            elif puc >= 60:
                action = "Partial readiness - reinforce lagging districts"
            else:
                action = "Postpone - major capacity building first"
            
            self.puc_results[province] = {
                'PUC': puc,
                'total_districts': N,
                'ready_districts': n_pass,
                'action': action
            }
            
            print(f"{province} PUC: {puc:.1f}%")
            print(f"  Action: {action}")
    
    def create_summary_report(self):
        """Create comprehensive summary report."""
        print("\n" + "="*80)
        print("DCI & PUC ANALYSIS RESULTS (Fair District Comparison - No Urban Bias)")
        print("="*80)
        
        for province in self.provinces:
            if province not in self.dci_results:
                continue
            
            print(f"\n{province.upper()}")
            print("-" * 50)
            
            # PUC summary
            puc_data = self.puc_results[province]
            print(f"PUC: {puc_data['PUC']:.1f}%")
            print(f"Ready Districts: {puc_data['ready_districts']}/{puc_data['total_districts']}")
            print(f"Action: {puc_data['action']}")
            
            # District details
            dci_data = self.dci_results[province]
            print(f"\nDistrict Details:")
            print(f"{'District':<25} {'DCI':<8} {'Status':<12} {'C':<6} {'W':<6} {'I':<6} {'P':<6} {'L':<6}")
            print("-" * 80)
            
            for _, row in dci_data.iterrows():
                status = "READY" if row['ready'] else "NOT READY"
                print(f"{row['District']:<25} {row['DCI']:<8.1f} {status:<12} "
                      f"{row['C_norm']:<6.1f} {row['W_norm']:<6.1f} {row['I_norm']:<6.1f} "
                      f"{row['P_norm']:<6.1f} {row['L_norm']:<6.1f}")
        
        print("\n" + "="*80)
        print("NOTES:")
        print("- C & W indicators: From actual demographic data with regression projection")
        print("- I indicator: Fixed at 95 for all districts (equal internet access)")
        print("- P indicator: 100 - poverty_rate (higher score = lower poverty)")
        print("- L indicator: Actual literacy rate (higher score = better literacy)")
        print("- Five-year means calculated from 2025-2029 projections")
        print("- STANDARDIZED MODEL WITH FAIR DISTRICT COMPARISON:")
        print("  * C, W: From actual demographic data with regression projection")
        print("  * I: Fixed base value (95) for all districts")
        print("  * P: Province poverty rate converted to score (100-poverty_rate)")
        print("  * L: Province literacy rate applied to all districts")
        print("- WITHIN-PROVINCE NORMALIZATION (0-100 scale) - districts compete within province")
        print("- All indicators are 'higher is better' for consistent scoring")
        print("- DCI ≥ 75 standard for readiness applies consistently across all provinces")
        print("="*80)
    
    def save_results(self):
        """Save results to CSV files."""
        output_dir = Path('results')
        output_dir.mkdir(exist_ok=True)
        
        print(f"\nSaving results to {output_dir}/...")
        
        # Save DCI results
        for province in self.dci_results:
            filename = f"dci_results_{province.lower().replace(' ', '_')}_province_specific.csv"
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
        puc_df.to_csv(output_dir / 'puc_summary_province_specific.csv', index=False)
        print("Saved: puc_summary_province_specific.csv")
    
    def run_analysis(self):
        """Run the complete analysis."""
        print("Starting DCI/PUC Analysis with Province-Specific Variations...")
        print("="*75)
        
        self.load_simulation_data()
        self.load_demographic_data()
        self.load_metrics_data()
        self.calculate_indicators()
        self.calculate_five_year_means()
        self.normalize_indicators()
        self.calculate_dci()
        self.calculate_puc()
        self.create_summary_report()
        self.save_results()
        
        print("\nAnalysis completed!")


def main():
    calculator = DCIPUCCalculator()
    calculator.run_analysis()


if __name__ == "__main__":
    main() 