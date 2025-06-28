#!/usr/bin/env python3
"""
Simple Data Validation Script for ABM Simulation
"""

import pandas as pd
import sys
from pathlib import Path

def validate_demographics_data(file_path):
    """Validate demographic data CSV file for ABM simulation"""
    errors = []
    
    try:
        df = pd.read_csv(file_path)
        print(f"✓ Successfully loaded {len(df)} rows from {file_path}")
        
        # Check required columns
        required_columns = [
            'province', 'district', 'commune', 'year',
            'total_population', 'women_15_49', 'children_under_5', 'admin_level'
        ]
        
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            errors.append(f"Missing required columns: {missing_columns}")
        
        # Basic data checks
        key_columns = ['total_population', 'women_15_49', 'children_under_5']
        for col in key_columns:
            if col in df.columns:
                missing_count = df[col].isna().sum()
                if missing_count > 0:
                    errors.append(f"Column '{col}' has {missing_count} missing values")
                
                if (df[col] < 0).any():
                    errors.append(f"Column '{col}' contains negative values")
        
        # Population consistency check
        if all(col in df.columns for col in key_columns):
            invalid_pop = df[(df['women_15_49'] + df['children_under_5'] > df['total_population'])]
            if len(invalid_pop) > 0:
                errors.append(f"Found {len(invalid_pop)} rows where women_15_49 + children_under_5 > total_population")
                # Add specific row details for debugging
                for idx, row in invalid_pop.iterrows():
                    errors.append(f"  Row {idx}: {row['commune']} ({row['year']}) - "
                                f"women_15_49={row['women_15_49']}, "
                                f"children_under_5={row['children_under_5']}, "
                                f"total_population={row['total_population']}")
            if len(invalid_pop) > 0:
                errors.append(f"Found {len(invalid_pop)} rows where women_15_49 + children_under_5 > total_population")
        
        # Summary statistics
        if not errors:
            print("\n=== DATA SUMMARY ===")
            print(f"Provinces: {df['province'].nunique()}")
            print(f"Districts: {df['district'].nunique()}")
            print(f"Communes: {df['commune'].nunique()}")
            print(f"Year range: {df['year'].min()} - {df['year'].max()}")
            print(f"Total population range: {df['total_population'].min():,} - {df['total_population'].max():,}")
            
            # District breakdown
            print(f"\n=== DISTRICT BREAKDOWN ===")
            district_summary = df.groupby('district')['commune'].nunique().sort_values(ascending=False)
            for district, commune_count in district_summary.items():
                print(f"  - {district}: {commune_count} communes")
        
        return len(errors) == 0, errors
        
    except Exception as e:
        return False, [f"Error reading file: {str(e)}"]

def main():
    if len(sys.argv) != 2:
        print("Usage: python validate_data.py <path_to_demographics_csv>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not Path(file_path).exists():
        print(f"Error: File {file_path} does not exist")
        sys.exit(1)
    
    print(f"Validating demographic data: {file_path}")
    print("=" * 50)
    
    is_valid, errors = validate_demographics_data(file_path)
    
    if is_valid:
        print("\n✓ Data validation PASSED!")
        print("Your data is ready for ABM simulation.")
    else:
        print("\n✗ Data validation FAILED!")
        print("Issues found:")
        for i, error in enumerate(errors, 1):
            print(f"  {i}. {error}")
        sys.exit(1)

if __name__ == "__main__":
    main() 