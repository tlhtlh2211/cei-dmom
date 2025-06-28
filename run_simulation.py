#!/usr/bin/env python3
"""
Interactive Launcher for Maternal and Child Health ABM Simulation
Choose from different simulation scenarios and run analysis
"""

import sys
import os
from pathlib import Path

def print_banner():
    """Print welcome banner"""
    print("=" * 70)
    print("   MATERNAL & CHILD HEALTH ABM SIMULATION - VIETNAM")
    print("   Dien Bien and Thai Nguyen Provinces")
    print("=" * 70)
    print()

def main_menu():
    """Display main menu and get user choice"""
    print("Choose simulation option:")
    print("1. Run Python ABM Simulation (Quick Start)")
    print("2. Run Single Scenario")
    print("3. Run All Scenarios (Baseline + All Interventions)")
    print("4. Quick Test (Short Duration)")
    print("5. Exit")
    print()
    
    while True:
        try:
            choice = int(input("Enter your choice (1-5): "))
            if 1 <= choice <= 5:
                return choice
            else:
                print("Please enter a number between 1 and 5")
        except ValueError:
            print("Please enter a valid number")

def run_python_simulation():
    """Run the main Python ABM simulation"""
    print("\n" + "="*50)
    print("RUNNING PYTHON ABM SIMULATION")
    print("="*50)
    
    try:
        # Import and run the simulation
        sys.path.append('scripts')
        from maternal_child_abm import ABMSimulation
        
        # Initialize simulation
        print("Initializing simulation...")
        sim = ABMSimulation("data")
        
        # Run all scenarios
        print("\nRunning all intervention scenarios (52 weeks)...")
        results = sim.run_all_scenarios(duration_weeks=52)
        
        # Analyze results
        print("\nAnalyzing results...")
        df = sim.analyze_results()
        
        # Export results
        sim.export_results()
        
        print("\n✓ Simulation completed successfully!")
        print("Results saved to 'abm_simulation_results.csv'")
        
        return sim, df
        
    except ImportError as e:
        print(f"Error importing simulation: {e}")
        print("Make sure you have all required packages installed:")
        print("pip install pandas numpy matplotlib seaborn")
        return None, None
    except Exception as e:
        print(f"Error running simulation: {e}")
        return None, None

def run_single_scenario():
    """Run a single scenario"""
    print("\n" + "="*50)
    print("SINGLE SCENARIO SIMULATION")
    print("="*50)
    
    scenarios = {
        '1': ('baseline', {}),
        '2': ('app_based', {'app_based': True}),
        '3': ('sms_outreach', {'sms_outreach': True}),
        '4': ('chw_visits', {'chw_visits': True}),
        '5': ('incentives', {'incentives': True}),
        '6': ('combined', {'app_based': True, 'sms_outreach': True, 'chw_visits': True, 'incentives': True})
    }
    
    print("Available scenarios:")
    print("1. Baseline (no interventions)")
    print("2. App-based intervention")
    print("3. SMS outreach intervention")
    print("4. CHW visits intervention")
    print("5. Incentives intervention")
    print("6. Combined interventions")
    
    while True:
        choice = input("\nSelect scenario (1-6): ")
        if choice in scenarios:
            break
        print("Please select a valid scenario number")
    
    scenario_name, interventions = scenarios[choice]
    
    try:
        sys.path.append('scripts')
        from maternal_child_abm import ABMSimulation
        
        sim = ABMSimulation("data")
        
        print(f"\nRunning scenario: {scenario_name}")
        results = sim.run_scenario(scenario_name, duration_weeks=52, interventions=interventions)
        
        df = sim.analyze_results()
        sim.export_results(f'abm_results_{scenario_name}.csv')
        
        print(f"\n✓ Scenario '{scenario_name}' completed successfully!")
        print(f"Results saved to 'abm_results_{scenario_name}.csv'")
        
        return sim, df
        
    except Exception as e:
        print(f"Error running scenario: {e}")
        return None, None

def run_quick_test():
    """Run a quick test simulation"""
    print("\n" + "="*50)
    print("QUICK TEST SIMULATION")
    print("="*50)
    print("Running 12 weeks simulation for quick testing...")
    
    try:
        sys.path.append('scripts')
        from maternal_child_abm import ABMSimulation
        
        sim = ABMSimulation("data")
        
        # Quick test with baseline and one intervention
        scenarios = {
            'baseline_test': {},
            'app_test': {'app_based': True}
        }
        
        all_results = {}
        for scenario_name, interventions in scenarios.items():
            sim._initialize_communes()  # Reset
            results = sim.run_scenario(scenario_name, duration_weeks=12, interventions=interventions)
            all_results.update(results)
        
        sim.results = all_results
        df = sim.analyze_results()
        sim.export_results('abm_quick_test_results.csv')
        
        print("\n✓ Quick test completed successfully!")
        print("Results saved to 'abm_quick_test_results.csv'")
        
        return sim, df
        
    except Exception as e:
        print(f"Error running quick test: {e}")
        return None, None

def check_requirements():
    """Check if required packages are installed"""
    required_packages = ['pandas', 'numpy', 'matplotlib', 'seaborn']
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print("⚠️  Missing required packages:")
        for package in missing_packages:
            print(f"   - {package}")
        print("\nPlease install them using:")
        print(f"pip install {' '.join(missing_packages)}")
        return False
    
    return True

def check_data():
    """Check if data files exist"""
    data_files = [
        'data/demographics/demographics_dien_bien.csv',
        'data/demographics/demographics_thai_nguyen.csv'
    ]
    
    for file_path in data_files:
        if not Path(file_path).exists():
            print(f"⚠️  Missing data file: {file_path}")
            return False
    
    return True

def main():
    """Main function"""
    print_banner()
    
    # Check requirements
    if not check_requirements():
        print("\nPlease install required packages before running the simulation.")
        return
    
    if not check_data():
        print("\nPlease ensure data files are in the correct location.")
        return
    
    print("✓ All requirements and data files found!")
    print()
    
    while True:
        choice = main_menu()
        
        if choice == 1:
            sim, df = run_python_simulation()
        elif choice == 2:
            sim, df = run_single_scenario()
        elif choice == 3:
            sim, df = run_python_simulation()  # Same as option 1
        elif choice == 4:
            sim, df = run_quick_test()
        elif choice == 5:
            print("Goodbye!")
            break
        
        if choice != 5:
            input("\nPress Enter to return to main menu...")
            print("\n" + "="*70)

if __name__ == "__main__":
    main() 