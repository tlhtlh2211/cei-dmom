model DistrictLevelHealthABM

// USER PARAMETERS - Interactive District Selection

global {
    // USER CONFIGURABLE PARAMETERS
    string selected_province <- "Dien Bien";
    string selected_district <- "Dien Bien Phu";
    float user_sampling_rate <- 10.0;
    bool user_app_intervention <- false;
    bool user_sms_intervention <- false;
    bool user_chw_intervention <- false;
    bool user_incentives <- false;
    
    // Time and simulation parameters
    int current_week <- 0;
    int current_year <- 2019;
    
    // Extended simulation parameters for 2024-2030 logging
    bool logging_active <- false;
    string log_file_path <- "../data/district_simulation_log.csv";
    
    // Single district simulation parameters - now use user selections
    string target_district_name <- selected_district;
    string target_province_name <- selected_province;
    
    // Population sampling rates - user configurable
    float maternal_sampling_rate <- user_sampling_rate / 100.0; 
    float child_sampling_rate <- user_sampling_rate / 100.0;    
    
    // Behavioral parameters (calibrated for Vietnamese context)
    float base_pregnancy_rate <- 0.0015;  // 0.2% weekly chance (sustainable demographics)
    float mobile_penetration <- 0.65;     // 65% mobile access in rural areas
    
    // Health outcome counters (reset weekly)
    int total_pregnancies <- 0;
    int total_anc_visits <- 0;
    int total_births <- 0;
    int skilled_births <- 0;
    int total_immunizations <- 0;
    
    // Population change tracking
    int maternal_agents_aged_out <- 0;
    int children_aged_out <- 0;
    int new_children_born <- 0;
    
    // Age transition tracking (clear flow)
    int children_to_youth <- 0;        // Children 5 -> Youth 5-15
    int females_to_maternal <- 0;      // Female youth 15 -> Maternal agents  
    int males_aged_out <- 0;           // Male youth 15 -> Exit model
    int maternal_to_pregnant <- 0;     // Maternal -> Pregnant
    int pregnant_to_maternal <- 0;     // Pregnant -> Maternal (after birth)
    
    // Intervention flags - user configurable
    bool app_based_intervention <- user_app_intervention;
    bool sms_outreach_intervention <- user_sms_intervention;
    bool chw_visits_intervention <- user_chw_intervention;
    bool incentives_intervention <- user_incentives;
    
    // Data structures for district-level data
    matrix demographic_matrix;
    list<map> district_data;
    map<string, list<map>> district_time_series; // Store all years for each district
    
    // Actual vs Predicted comparison data
    map<int, float> actual_maternal_by_year;
    map<int, float> actual_children_u5_by_year;
    map<int, float> actual_youth_5_15_by_year;
    
    // Data file paths - REAL VIETNAMESE GOVERNMENT DATA
    // District-level demographics from both Dien Bien and Thai Nguyen provinces
    string dien_bien_data_path <- "/Users/tranlehai/Desktop/CEI-Simulation/data/demographics/demographics_dien_bien.csv";
    string thai_nguyen_data_path <- "/Users/tranlehai/Desktop/CEI-Simulation/data/demographics/demographics_thai_nguyen.csv";
    
    // Real Vietnamese government data by province and year
    map<string, map<int, float>> provincial_literacy_rates;
    map<string, map<int, float>> provincial_poverty_rates;
    
    // District-level indicators for simulation
    map<string, map<string, float>> district_indicators;
    
    /**
     * VALIDATE DISTRICT-PROVINCE MATCH
     * Ensures selected district belongs to selected province
     */
    action validate_district_province_match {
        list<string> dien_bien_districts <- ["Dien Bien", "Dien Bien Dong", "Dien Bien Phu", "Muong Ang", "Muong Cha", "Muong Lay", "Muong Nhe", "Nam Po", "Tua Chua", "Tuan Giao"];
        list<string> thai_nguyen_districts <- ["Dai Tu", "Dinh Hoa", "Dong Hy", "Pho Yen", "Phu Binh", "Phu Luong", "Song Cong", "Thanh Pho Thai Nguyen", "Vo Nhai"];
        
        if (selected_province = "Dien Bien") {
            if (!(selected_district in dien_bien_districts)) {
                write "⚠️  WARNING: " + selected_district + " is not a district in Dien Bien province!";
                write "🎯 Available Dien Bien districts: " + dien_bien_districts;
                write "🔄 Please select a district from Dien Bien province";
            } else {
                write "✅ VALID: " + selected_district + " is in " + selected_province + " province";
            }
        } else if (selected_province = "Thai Nguyen") {
            if (!(selected_district in thai_nguyen_districts)) {
                write "⚠️  WARNING: " + selected_district + " is not a district in Thai Nguyen province!";
                write "🎯 Available Thai Nguyen districts: " + thai_nguyen_districts;
                write "🔄 Please select a district from Thai Nguyen province";
            } else {
                write "✅ VALID: " + selected_district + " is in " + selected_province + " province";
            }
        }
    }
    
    /**
     * GLOBAL INITIALIZATION
     * Sets up real Vietnamese data, loads district demographic information, and creates agents
     */
    init {
        write "=== INITIALIZING DISTRICT-LEVEL HEALTH ABM (2019-2030) ===";
        
        // RESET SIMULATION STATE (Important for parameter changes)
        current_week <- 0;
        current_year <- 2019;
        logging_active <- false;
        
        // Reset counters
        total_pregnancies <- 0;
        total_anc_visits <- 0;
        total_births <- 0;
        skilled_births <- 0;
        total_immunizations <- 0;
        maternal_agents_aged_out <- 0;
        children_aged_out <- 0;
        new_children_born <- 0;
        children_to_youth <- 0;
        females_to_maternal <- 0;
        males_aged_out <- 0;
        maternal_to_pregnant <- 0;
        pregnant_to_maternal <- 0;
        
        write "✅ SIMULATION STATE RESET - Starting fresh from 2019";
        write "🎯 SELECTED PROVINCE: " + selected_province;
        write "🎯 SELECTED DISTRICT: " + selected_district;
        write "🎯 TARGET DISTRICT: " + target_district_name;
        write "🎯 TARGET PROVINCE: " + target_province_name;
        write "🎯 SAMPLING RATE: " + user_sampling_rate + "%";
        
        // Validate district belongs to selected province
        do validate_district_province_match;
        
        // Load real Vietnamese government data
        do initialize_real_vietnamese_data;
        
        // Initialize district-level framework
        do initialize_district_framework;
        
        // Load district-level demographic data for both provinces
        do load_district_demographics;
        
        write "Found " + length(district_data) + " districts with 2019 GSO baseline data";
        
        // Create single target district based on parameters
        map target_district_info <- nil;
        loop district_info over: district_data {
            string district_name <- string(district_info["district"]);
            string province_name <- string(district_info["province"]);
            
            if (district_name = target_district_name and province_name = target_province_name) {
                target_district_info <- district_info;
                break;
            }
        }
        
        if (target_district_info != nil) {
            create District with: [
                district_name: target_district_name,
                province_name: target_province_name,
                total_population: int(target_district_info["total_population"]),
                women_15_49: int(target_district_info["women_15_49"]),
                children_under_5: int(target_district_info["children_under_5"]),
                poverty_rate: get_real_poverty_rate(target_province_name, 2019),
                literacy_rate: get_real_literacy_rate(target_province_name, 2019)
            ];
            write "Created target district: " + target_district_name + " (" + target_province_name + ")";
        } else {
            write "ERROR: Target district not found: " + target_district_name + " in " + target_province_name;
        }
        
        write "Created " + length(District) + " district agents with REAL Vietnamese data";
        write "Loaded GSO demographic time series for " + length(district_time_series) + " districts (2019-2024)";
        
        // Initialize agents for each district based on real population data
        ask District {
            do initialize_agents;
        }
        
        // Initialize logging file
        do initialize_logging;
        
        // Load actual data for comparison charts
        do load_actual_data_for_comparison;
        
        write "=== SIMULATION READY WITH AUTHENTIC VIETNAMESE DISTRICT DATA ===";
        write "Maternal agents: " + length(MaternalAgent) + " across " + length(District) + " districts";
        write "Child agents U5: " + length(ChildAgent where (each.age_months < 60)) + " across " + length(District) + " districts";
        write "Simulation will log data from 2024-2030";
        write "✅ DISTRICT-LEVEL MODEL INITIALIZED";
    }
    
    /**
     * LOAD DISTRICT DEMOGRAPHICS
     * Aggregates commune data to district level from both provinces
     */
    action load_district_demographics {
        district_data <- [];
        district_time_series <- map([]);
        
        // Process Dien Bien data
        do process_province_data(dien_bien_data_path, "Dien Bien");
        
        // Process Thai Nguyen data (if file exists)
        if (file_exists(thai_nguyen_data_path)) {
            do process_province_data(thai_nguyen_data_path, "Thai Nguyen");
        }
    }
    
    /**
     * PROCESS PROVINCE DATA
     * Processes and aggregates commune data to district level for a specific province
     */
    action process_province_data(string data_path, string province_name) {
        matrix province_matrix <- matrix(csv_file(data_path, ",", true));
        map<string, map<int, map<string, int>>> district_aggregation <- map([]);
        
        // First pass: aggregate commune data by district and year
        loop i from: 1 to: province_matrix.rows - 1 {
            string district_name <- string(province_matrix[1,i]);
            int year <- int(province_matrix[3,i]);
            int total_pop <- int(province_matrix[4,i]);
            int women_15_49 <- int(province_matrix[5,i]);
            int children_u5 <- int(province_matrix[6,i]);
            
            // Initialize district aggregation structure
            if (district_aggregation[district_name] = nil) {
                district_aggregation[district_name] <- map([]);
            }
            if (district_aggregation[district_name][year] = nil) {
                district_aggregation[district_name][year] <- map([
                    "total_population" :: 0,
                    "women_15_49" :: 0,
                    "children_under_5" :: 0
                ]);
            }
            
            // Aggregate commune data to district level
            district_aggregation[district_name][year]["total_population"] <- 
                district_aggregation[district_name][year]["total_population"] + total_pop;
            district_aggregation[district_name][year]["women_15_49"] <- 
                district_aggregation[district_name][year]["women_15_49"] + women_15_49;
            district_aggregation[district_name][year]["children_under_5"] <- 
                district_aggregation[district_name][year]["children_under_5"] + children_u5;
        }
        
        // Second pass: create district records
        loop district_name over: district_aggregation.keys {
            map<int, map<string, int>> district_years <- district_aggregation[district_name];
            
            // Store all years for this district
            district_time_series[district_name] <- [];
            
            loop year over: district_years.keys {
                map district_info <- map([]);
                district_info["province"] <- province_name;
                district_info["district"] <- district_name;
                district_info["year"] <- year;
                district_info["total_population"] <- district_years[year]["total_population"];
                district_info["women_15_49"] <- district_years[year]["women_15_49"];
                district_info["children_under_5"] <- district_years[year]["children_under_5"];
                
                district_time_series[district_name] << district_info;
                
                // Use 2019 data for initialization
                if (year = 2019) {
                    district_data << district_info;
                }
            }
        }
        
        write "Processed " + length(district_aggregation) + " districts from " + province_name;
    }
    
    /**
     * INITIALIZE DISTRICT FRAMEWORK
     * Sets up the district-level indicator system
     */
    action initialize_district_framework {
        district_indicators <- map([]);
    }
    
    /**
     * INITIALIZE REAL VIETNAMESE DATA
     * Same as original model - loads authentic government statistics
     */
    action initialize_real_vietnamese_data {
        write "Loading REAL Vietnamese government data (literacy & poverty rates)...";
        
        // REAL LITERACY RATES from Vietnamese General Statistics Office (GSO)
        map<int, float> thai_nguyen_literacy <- map([
            2019 :: 98.20, 2020 :: 97.99, 2021 :: 98.32, 2022 :: 98.27, 
            2023 :: 98.75, 2024 :: 98.75, 2025 :: 98.80, 2026 :: 98.85,
            2027 :: 98.90, 2028 :: 98.95, 2029 :: 99.00, 2030 :: 99.00
        ]);
        
        map<int, float> dien_bien_literacy <- map([
            2019 :: 73.10, 2020 :: 75.58, 2021 :: 74.92, 2022 :: 77.63, 
            2023 :: 78.78, 2024 :: 78.78, 2025 :: 80.00, 2026 :: 81.50,
            2027 :: 83.00, 2028 :: 84.50, 2029 :: 86.00, 2030 :: 87.50
        ]);
        
        provincial_literacy_rates <- map([
            "Thai Nguyen" :: thai_nguyen_literacy,
            "Dien Bien" :: dien_bien_literacy
        ]);
        
        // REAL POVERTY RATES from Vietnamese government statistics
        map<int, float> thai_nguyen_poverty <- map([
            2019 :: 6.72, 2020 :: 5.64, 2021 :: 4.78, 2022 :: 4.35, 
            2023 :: 3.02, 2024 :: 3.02, 2025 :: 2.50, 2026 :: 2.00,
            2027 :: 1.50, 2028 :: 1.20, 2029 :: 1.00, 2030 :: 0.80
        ]);
        
        map<int, float> dien_bien_poverty <- map([
            2019 :: 33.05, 2020 :: 29.93, 2021 :: 26.76, 2022 :: 18.70, 
            2023 :: 26.57, 2024 :: 26.57, 2025 :: 24.00, 2026 :: 21.50,
            2027 :: 19.00, 2028 :: 16.50, 2029 :: 14.00, 2030 :: 12.00
        ]);
        
        provincial_poverty_rates <- map([
            "Thai Nguyen" :: thai_nguyen_poverty,
            "Dien Bien" :: dien_bien_poverty
        ]);
        
        write "[SUCCESS] Loaded REAL Vietnamese government data for 2019-2030 (with projections)";
    }
    
    /**
     * GET REAL LITERACY RATE
     * Returns actual Vietnamese government literacy rate for given province and year
     */
    float get_real_literacy_rate(string province, int year) {
        map<int, float> province_rates <- provincial_literacy_rates[province];
        if (province_rates != nil and province_rates[year] != nil) {
            return province_rates[year] / 100.0;
        } else {
            return 0.75; // Default fallback
        }
    }
    
    /**
     * GET REAL POVERTY RATE
     * Returns actual Vietnamese government poverty rate for given province and year
     */
    float get_real_poverty_rate(string province, int year) {
        map<int, float> province_rates <- provincial_poverty_rates[province];
        if (province_rates != nil and province_rates[year] != nil) {
            return province_rates[year] / 100.0;
        } else {
            return 0.30; // Default fallback
        }
    }
    
    /**
     * INITIALIZE LOGGING
     * Sets up CSV file for logging data from 2024-2030
     * Creates unique filename for each district to preserve data
     */
    action initialize_logging {
        // Create unique filename for each district
        string clean_district <- replace(target_district_name, " ", "_");
        string clean_province <- replace(target_province_name, " ", "_");
        log_file_path <- "../data/district_simulation_" + clean_district + "_" + clean_province + ".csv";
        
        save ["Year", "District", "Province", "Maternal_Agents", "Children_U5", "Youth_5_15",
              "Total_Pregnancies", "Total_Births", "Skilled_Births", "Total_Immunizations",
              "Literacy_Rate", "Poverty_Rate"] 
              to: log_file_path type: "csv" rewrite: true;
        write "Initialized logging file: " + log_file_path;
    }
    
    /**
     * LOAD ACTUAL DATA FOR COMPARISON
     * Loads actual Vietnamese government data for the target district to enable comparison charts
     */
    action load_actual_data_for_comparison {
        write "Loading actual data for comparison charts...";
        
        // Initialize maps
        actual_maternal_by_year <- map([]);
        actual_children_u5_by_year <- map([]);
        actual_youth_5_15_by_year <- map([]);
        
        // Find actual data for target district from district_time_series
        if (district_time_series[target_district_name] != nil) {
            list<map> target_series <- district_time_series[target_district_name];
            
            loop district_year_data over: target_series {
                int year <- int(district_year_data["year"]);
                int total_pop <- int(district_year_data["total_population"]);
                int women_15_49 <- int(district_year_data["women_15_49"]);
                int children_u5 <- int(district_year_data["children_under_5"]);
                
                // Apply same sampling rates as simulation
                float actual_maternal <- women_15_49 * maternal_sampling_rate;
                float actual_children <- children_u5 * child_sampling_rate;
                float actual_youth <- total_pop * 0.08 * child_sampling_rate; // 8% of population
                
                actual_maternal_by_year[year] <- actual_maternal;
                actual_children_u5_by_year[year] <- actual_children;
                actual_youth_5_15_by_year[year] <- actual_youth;
            }
            
            write "Loaded actual data for " + length(actual_maternal_by_year) + " years for comparison";
        } else {
            write "Warning: No actual data found for " + target_district_name;
        }
    }
    
    /**
     * LOG YEARLY DATA
     * Logs district-level data when logging is active (2024-2030)
     */
    action log_yearly_data {
        if (logging_active) {
            ask District {
                int district_maternal <- length(MaternalAgent where (!dead(each) and each.my_district = self));
                int district_children_u5 <- length(ChildAgent where (!dead(each) and each.my_district = self and each.age_months < 60));
                int district_youth_5_15 <- length(ChildAgent where (!dead(each) and each.my_district = self and each.age_months >= 60));
                
                list<string> log_row <- [
                    string(current_year),
                    district_name,
                    province_name,
                    string(district_maternal),
                    string(district_children_u5),
                    string(district_youth_5_15),
                    string(total_pregnancies),
                    string(total_births),
                    string(skilled_births),
                    string(total_immunizations),
                    string(literacy_rate * 100),
                    string(poverty_rate * 100)
                ];
                
                save log_row to: log_file_path type: "csv" rewrite: false;
            }
        }
    }
    
    /**
     * WEEKLY TIME PROGRESSION
     * Advances simulation time and manages logging
     */
    reflex weekly_step {
        current_week <- current_week + 1;
        
        // Update year
        if (current_week mod 52 = 0) {
            current_year <- current_year + 1;
            write "=== YEAR " + current_year + " ===";
            
            // Activate logging from 2024 onwards
            if (current_year >= 2024 and current_year <= 2030) {
                logging_active <- true;
                write "DATA LOGGING ACTIVE for year " + current_year;
            } else if (current_year > 2030) {
                logging_active <- false;
                write "=== SIMULATION COMPLETED ===";
                write "Finished simulating through 2030. Data logging complete.";
                write "Total simulation years: " + (current_year - 2019);
                write "CSV log saved to: " + log_file_path;
                write "Simulation stopping automatically...";
                
                // Auto-stop the simulation
                do halt;
            }
            
            // Update district demographics with real data (if available)
            do update_district_demographics_to_real_data;
        }
        
        // Log data yearly when active (at the end of each year)
        if (current_week mod 52 = 0) {
            do log_yearly_data;
        }
        
        // Reset weekly counters
        total_pregnancies <- 0;
        total_anc_visits <- 0;
        total_births <- 0;
        skilled_births <- 0;
        total_immunizations <- 0;
        
        // Reset population change counters
        maternal_agents_aged_out <- 0;
        children_aged_out <- 0;
        new_children_born <- 0;
        
        // Reset transition counters
        children_to_youth <- 0;
        females_to_maternal <- 0;
        males_aged_out <- 0;
        maternal_to_pregnant <- 0;
        pregnant_to_maternal <- 0;
    }
    
    /**
     * UPDATE DISTRICT DEMOGRAPHICS TO REAL DATA
     * Updates district populations based on actual Vietnamese government demographic trends
     */
    action update_district_demographics_to_real_data {
        if (current_year >= 2020 and current_year <= 2024) {
            write "[UPDATE] Updating district demographics to real " + current_year + " Vietnamese data...";
            
            int districts_updated <- 0;
            ask District {
                // Find real data for this district and year
                list<map> district_series <- district_time_series[district_name];
                map real_data <- nil;
                
                if (district_series != nil) {
                    loop district_year_data over: district_series {
                        if (int(district_year_data["year"]) = current_year) {
                            real_data <- district_year_data;
                            break;
                        }
                    }
                }
                
                if (real_data != nil) {
                    // Update with real demographic data
                    int real_total_pop <- int(real_data["total_population"]);
                    int real_women_15_49 <- int(real_data["women_15_49"]);
                    int real_children_u5 <- int(real_data["children_under_5"]);
                    
                    // Update district base demographics
                    total_population <- real_total_pop;
                    women_15_49 <- real_women_15_49;
                    children_under_5 <- real_children_u5;
                    
                    // Update socioeconomic indicators
                    literacy_rate <- world.get_real_literacy_rate(province_name, world.current_year);
                    poverty_rate <- world.get_real_poverty_rate(province_name, world.current_year);
                    
                    districts_updated <- districts_updated + 1;
                }
            }
            
            write "[SUCCESS] Updated " + districts_updated + " districts with real " + current_year + " data";
        }
    }
    
    /**
     * PERIODIC MONITORING
     * Outputs simulation statistics every month (4 weeks)
     */
    reflex monitor when: current_week mod 4 = 0 { 
        write "=== MONTHLY REPORT (Week " + current_week + ", Year " + current_year + ") ===";
        write "Districts active: " + length(District where (!dead(each)));
        write "Total maternal agents: " + length(MaternalAgent where (!dead(each)));
        write "Total children U5: " + length(ChildAgent where (!dead(each) and each.age_months < 60));
        write "Logging status: " + (logging_active ? "ACTIVE" : "INACTIVE");
        
        if (total_births > 0) {
            write "Skilled birth rate: " + (skilled_births / total_births * 100) + "%";
        }
    }
}

/**
 * DISTRICT SPECIES
 * Represents districts in Dien Bien and Thai Nguyen provinces
 * Contains demographic data and manages local agents
 */
species District {
    string district_name;
    string province_name;
    int total_population;
    int women_15_49;
    int children_under_5;
    
    float poverty_rate;
    float literacy_rate;
    float distance_to_hospital <- rnd(5.0, 30.0); // 5-30km to hospital
    
    /**
     * INITIALIZE AGENTS
     * Creates maternal and child agents for this district based on demographic data
     */
    action initialize_agents {
        // Create maternal agents (women 15-49)
        int target_maternal <- int(women_15_49 * maternal_sampling_rate);
        
        loop i from: 0 to: target_maternal - 1 {
            create MaternalAgent with: [
                my_district: self,
                age: sample_realistic_maternal_age(),
                ethnicity: sample_ethnicity(),
                literacy_level: sample_literacy(),
                poverty_level: sample_poverty(),
                mobile_access: flip(mobile_penetration),
                distance_to_facility: distance_to_hospital + rnd(-5.0, 5.0)
            ];
        }
        
        // Create child agents (under 5)
        int target_children_u5 <- int(children_under_5 * child_sampling_rate);
        
        loop i from: 0 to: target_children_u5 - 1 {
            create ChildAgent with: [
                my_district: self,
                age_months: sample_realistic_child_age(),
                mother_agent: one_of(MaternalAgent where (each.my_district = self))
            ];
        }
        
        // Create youth agents (5-15 years) - 10% of total population
        int target_youth_5_15 <- int(total_population * 0.06 * child_sampling_rate);
        
        loop i from: 0 to: target_youth_5_15 - 1 {
            create ChildAgent with: [
                my_district: self,
                age_months: sample_realistic_youth_age(),
                mother_agent: one_of(MaternalAgent where (each.my_district = self))
            ];
        }
        
        write district_name + " (" + province_name + "): " + target_maternal + " maternal, " + target_children_u5 + " children U5, " + target_youth_5_15 + " youth 5-15";
    }
    
    /**
     * SAMPLE ETHNICITY
     * Returns ethnicity based on province characteristics
     */
    string sample_ethnicity {
        if (province_name = "Thai Nguyen") {
            return flip(0.8) ? "Kinh" : "Tay";
        } else {
            return flip(0.3) ? "Kinh" : "Thai";
        }
    }
    
    /**
     * SAMPLE LITERACY
     * Returns literacy level based on real Vietnamese government data
     */
    float sample_literacy {
        float base_rate <- literacy_rate;
        return max(0.1, min(0.95, base_rate + rnd(-0.15, 0.15)));
    }
    
    /**
     * SAMPLE POVERTY
     * Returns poverty level based on real Vietnamese government data
     */
    float sample_poverty {
        float base_rate <- poverty_rate;
        return max(0.0, min(1.0, base_rate + rnd(-0.1, 0.1)));
    }
    
    /**
     * SAMPLE REALISTIC MATERNAL AGE
     * Returns age with normal distribution reflecting real reproductive demographics
     */
    int sample_realistic_maternal_age {
        float age_float <- gauss(27.0, 6.0);
        int age_result <- int(max(15, min(49, age_float)));
        return age_result;
    }
    
    /**
     * SAMPLE REALISTIC CHILD AGE
     * Returns age in months using Gaussian distribution
     */
    int sample_realistic_child_age {
        float age_months_float <- gauss(30.0, 18.0);
        int age_result <- int(max(0, min(59, age_months_float)));
        return age_result;
    }
    
    /**
     * SAMPLE REALISTIC YOUTH AGE
     * Returns age in months for youth 5-15 years (60-179 months)
     */
    int sample_realistic_youth_age {
        int age_result <- int(rnd(60, 179));
        return age_result;
    }
    
    // Visual representation
    aspect default {
        color <- province_name = "Dien Bien" ? #blue : #green;
        draw circle(total_population/5000) color: color border: #black;
    }
}

/**
 * MATERNAL AGENT SPECIES
 * Same as original model - represents women of reproductive age (15-49)
 */
species MaternalAgent {
    District my_district;
    int age;
    string ethnicity;
    float literacy_level;
    float poverty_level;
    bool mobile_access;
    float distance_to_facility;
    
    // Health status
    bool is_pregnant <- false;
    int weeks_pregnant <- 0;
    int anc_visits <- 0;
    int anc_target <- 4;
    bool has_skilled_birth_attendant <- false;
    int weeks_since_last_birth <- -60;
    int total_children <- 0;
    
    // Intervention engagement
    float app_engagement <- 0.0;
    bool received_sms <- false;
    bool chw_contacted <- false;
    
    // Behavioral thresholds
    float care_seeking_threshold;
    
    /**
     * AGENT INITIALIZATION
     */
    init {
        care_seeking_threshold <- calculate_care_seeking_threshold();
        
        if (flip(base_pregnancy_rate / 4)) {
            do become_pregnant;
        }
    }
    
    /**
     * CALCULATE CARE SEEKING THRESHOLD
     */
    float calculate_care_seeking_threshold {
        float base_threshold <- 0.5;
        float literacy_factor <- -0.2 * literacy_level;
        float poverty_factor <- 0.15 * poverty_level;
        float distance_factor <- 0.1 * min(distance_to_facility / 10, 0.3);
        float ethnicity_factor <- (ethnicity = "Kinh") ? 0.0 : 0.1;
        
        return max(0.1, min(0.9, base_threshold + literacy_factor + poverty_factor + distance_factor + ethnicity_factor));
    }
    
    /**
     * BECOME PREGNANT
     */
    action become_pregnant {
        is_pregnant <- true;
        weeks_pregnant <- 1;
        anc_visits <- 0;
        total_pregnancies <- total_pregnancies + 1;
        maternal_to_pregnant <- maternal_to_pregnant + 1;
    }
    
    /**
     * PREGNANCY PROGRESSION
     */
    reflex pregnancy_progression when: is_pregnant {
        weeks_pregnant <- weeks_pregnant + 1;
        
        if (weeks_pregnant mod 4 = 0 and seek_anc_care()) {
            anc_visits <- anc_visits + 1;
            total_anc_visits <- total_anc_visits + 1;
        }
        
        if (weeks_pregnant >= 40) {
            do give_birth;
        }
    }
    
    /**
     * SEEK ANC CARE
     */
    bool seek_anc_care {
        if (anc_visits >= anc_target) { return false; }
        
        float base_prob <- min(0.8, 0.1 + 0.02 * weeks_pregnant);
        float literacy_boost <- 0.3 * literacy_level;
        
        float intervention_boost <- 0.0;
        
        if (app_based_intervention and app_engagement > 0.5) {
            intervention_boost <- intervention_boost + 0.2;
        }
        
        if (sms_outreach_intervention and received_sms) {
            intervention_boost <- intervention_boost + 0.15;
        }
        
        if (chw_visits_intervention and chw_contacted) {
            intervention_boost <- intervention_boost + 0.25;
        }
        
        if (incentives_intervention and poverty_level > 0.6) {
            intervention_boost <- intervention_boost + 0.3;
        }
        
        float final_prob <- min(0.95, base_prob + literacy_boost + intervention_boost);
        
        return flip(final_prob) and flip(1.0 - care_seeking_threshold);
    }
    
    /**
     * GIVE BIRTH
     */
    action give_birth {
        float base_prob <- 0.4 + 0.1 * anc_visits;
        float literacy_boost <- 0.2 * literacy_level;
        float poverty_penalty <- -0.15 * poverty_level;
        float distance_penalty <- -0.05 * min(distance_to_facility / 5, 0.4);
        
        float final_prob <- max(0.1, min(0.95, base_prob + literacy_boost + poverty_penalty + distance_penalty));
        
        has_skilled_birth_attendant <- flip(final_prob);
        
        if (has_skilled_birth_attendant) {
            skilled_births <- skilled_births + 1;
        }
        
        total_births <- total_births + 1;
        total_children <- total_children + 1;
        
        // Create new child agent
        create ChildAgent with: [
            my_district: my_district,
            age_months: 0,
            mother_agent: self,
            gender: flip(0.5) ? "female" : "male"
        ];
        new_children_born <- new_children_born + 1;
        
        // Transition back to maternal
        is_pregnant <- false;
        weeks_pregnant <- 0;
        weeks_since_last_birth <- current_week;
        
        if (age < 50) {
            pregnant_to_maternal <- pregnant_to_maternal + 1;
        } else {
            maternal_agents_aged_out <- maternal_agents_aged_out + 1;
            do die;
        }
    }
    
    /**
     * AGENT AGING
     */
    reflex age_progression {
        if (current_week mod 52 = 0) {
            age <- age + 1;
            
            if (age > 49) {
                maternal_agents_aged_out <- maternal_agents_aged_out + 1;
                do die;
            }
        }
    }
    
    /**
     * REPRODUCTIVE BEHAVIOR
     */
    reflex reproductive_behavior when: !is_pregnant and (current_week - weeks_since_last_birth) > 52 {
        if (flip(base_pregnancy_rate)) {
            do become_pregnant;
        }
    }
    
    // Visual representation
    aspect default {
        color <- is_pregnant ? #red : #blue;
        draw circle(0.5) color: color;
    }
}

/**
 * CHILD AGENT SPECIES
 * Same as original model - represents children (U5 and youth 5-15)
 */
species ChildAgent {
    District my_district;
    int age_months;
    string gender;
    MaternalAgent mother_agent;
    
    // Health status
    int immunizations_received <- 0;
    int last_immunization_week <- -1;
    int immunizations_target <- 8;
    int care_seeking_delays <- 0;
    
    /**
     * CHILD INITIALIZATION
     */
    init {
        gender <- flip(0.5) ? "female" : "male";
        immunizations_received <- min(immunizations_target, age_months div 6);
    }
    
    /**
     * AGE PROGRESSION
     */
    reflex age_progression {
        if (current_week mod 4 = 0) {
            age_months <- age_months + 1;
            
            // Transition from Child U5 to Youth 5-15
            if (age_months = 60) {
                children_to_youth <- children_to_youth + 1;
            }
            
            // Transition from Youth to Maternal/Exit
            if (age_months >= 180) {
                if (mother_agent != nil and !dead(mother_agent)) {
                    mother_agent.total_children <- mother_agent.total_children - 1;
                }
                
                if (gender = "female") {
                    females_to_maternal <- females_to_maternal + 1;
                    
                    create MaternalAgent with: [
                        my_district: my_district,
                        age: 15,
                        ethnicity: my_district.sample_ethnicity(),
                        literacy_level: my_district.sample_literacy(),
                        poverty_level: my_district.sample_poverty(),
                        mobile_access: flip(mobile_penetration),
                        distance_to_facility: my_district.distance_to_hospital + rnd(-2.0, 2.0),
                        weeks_since_last_birth: -60
                    ];
                } else {
                    males_aged_out <- males_aged_out + 1;
                }
                
                do die;
            }
        }
    }
    
    /**
     * SEEK IMMUNIZATION
     */
    reflex seek_immunization when: age_months < 60 and need_immunization() and can_seek_immunization() {
        if (receive_care()) {
            immunizations_received <- immunizations_received + 1;
            total_immunizations <- total_immunizations + 1;
            last_immunization_week <- current_week;
        } else {
            care_seeking_delays <- care_seeking_delays + 1;
        }
    }
    
    /**
     * NEED IMMUNIZATION
     */
    bool need_immunization {
        int expected_immunizations <- min(immunizations_target, age_months div 6);
        return immunizations_received < expected_immunizations;
    }
    
    /**
     * CAN SEEK IMMUNIZATION
     */
    bool can_seek_immunization {
        return (current_week - last_immunization_week) >= 8;
    }
    
    /**
     * RECEIVE CARE
     */
    bool receive_care {
        if (mother_agent = nil or dead(mother_agent)) { return false; }
        
        float base_prob <- 0.3;
        float literacy_boost <- 0.2 * mother_agent.literacy_level;
        float poverty_penalty <- -0.1 * mother_agent.poverty_level;
        
        float intervention_boost <- 0.0;
        if (app_based_intervention and mother_agent.app_engagement > 0.4) {
            intervention_boost <- intervention_boost + 0.15;
        }
        
        if (incentives_intervention and mother_agent.poverty_level > 0.5) {
            intervention_boost <- intervention_boost + 0.25;
        }
        
        float final_prob <- max(0.05, min(0.9, base_prob + literacy_boost + poverty_penalty + intervention_boost));
        
        return flip(final_prob);
    }
    
    // Visual representation
    aspect default {
        color <- age_months < 60 ? #orange : #purple;
        draw circle(0.3) color: color;
    }
}

/**
 * MAIN SIMULATION EXPERIMENT
 * District-level simulation with data logging from 2024-2030
 */
experiment "District Level Simulation" type: gui {
    parameter "Province" var: selected_province among: ["Dien Bien", "Thai Nguyen"] category: "Location";
    parameter "District" var: selected_district among: ["Dien Bien", "Dien Bien Dong", "Dien Bien Phu", "Muong Ang", "Muong Cha", "Muong Lay", "Muong Nhe", "Nam Po", "Tua Chua", "Tuan Giao", "Dai Tu", "Dinh Hoa", "Dong Hy", "Pho Yen", "Phu Binh", "Phu Luong", "Song Cong", "Thanh Pho Thai Nguyen", "Vo Nhai"] category: "Location";
    
    parameter "Population Sampling %" var: user_sampling_rate min: 1.0 max: 100.0 category: "Simulation";
    parameter "Enable Mobile App" var: user_app_intervention category: "Interventions";
    parameter "Enable SMS Outreach" var: user_sms_intervention category: "Interventions";
    parameter "Enable CHW Visits" var: user_chw_intervention category: "Interventions";
    parameter "Enable Incentives" var: user_incentives category: "Interventions";
    
    output {
        display "Single District Demographics" {
            chart "Population by Age Group" type: series {
                data "Maternal Agents (15-49)" value: length(MaternalAgent where (!dead(each))) color: #blue;
                data "Children U5 (0-4)" value: length(ChildAgent where (!dead(each) and each.age_months < 60)) color: #orange;
                data "Youth (5-15)" value: length(ChildAgent where (!dead(each) and each.age_months >= 60)) color: #purple;
            }
        }
        
        display "Actual vs Predicted: Maternal Agents" {
            chart "Maternal Agents Comparison" type: series {
                data "Actual (GSO Data)" value: actual_maternal_by_year[current_year] != nil ? actual_maternal_by_year[current_year] : 0 color: #blue;
                data "Predicted (Simulation)" value: length(MaternalAgent where (!dead(each))) color: #red;
            }
        }
        
        display "Actual vs Predicted: Children U5" {
            chart "Children U5 Comparison" type: series {
                data "Actual (GSO Data)" value: actual_children_u5_by_year[current_year] != nil ? actual_children_u5_by_year[current_year] : 0 color: #orange;
                data "Predicted (Simulation)" value: length(ChildAgent where (!dead(each) and each.age_months < 60)) color: #purple;
            }
        }
        
        display "Actual vs Predicted: Youth 5-15" {
            chart "Youth 5-15 Comparison" type: series {
                data "Actual (7% est.)" value: actual_youth_5_15_by_year[current_year] != nil ? actual_youth_5_15_by_year[current_year] : 0 color: #green;
                data "Predicted (Simulation)" value: length(ChildAgent where (!dead(each) and each.age_months >= 60)) color: #brown;
            }
        }
        
        display "Health Indicators" {
            chart "Weekly Health Metrics" type: series {
                data "Pregnancies" value: total_pregnancies color: #red;
                data "ANC Visits" value: total_anc_visits color: #blue;
                data "Births" value: total_births color: #green;
                data "Skilled Births" value: skilled_births color: #purple;
                data "Immunizations" value: total_immunizations color: #orange;
            }
        }
        
        display "Model Validation Summary" {
            chart "Prediction Accuracy %" type: series {
                data "Maternal Accuracy %" value: (actual_maternal_by_year[current_year] != nil and actual_maternal_by_year[current_year] > 0) ? 
                    (100 - abs(length(MaternalAgent where (!dead(each))) - actual_maternal_by_year[current_year]) / actual_maternal_by_year[current_year] * 100) : 0 color: #blue;
                data "Children U5 Accuracy %" value: (actual_children_u5_by_year[current_year] != nil and actual_children_u5_by_year[current_year] > 0) ? 
                    (100 - abs(length(ChildAgent where (!dead(each) and each.age_months < 60)) - actual_children_u5_by_year[current_year]) / actual_children_u5_by_year[current_year] * 100) : 0 color: #orange;
                data "Target Accuracy (95%)" value: 95 color: #green;
            }
        }
        
        // =============================================================================
        // SINGLE DISTRICT MONITORING
        // =============================================================================
        monitor "Current Week" value: current_week;
        monitor "Current Year" value: current_year;
        monitor "Target District" value: target_district_name + " (" + target_province_name + ")";
        monitor "Maternal Agents" value: length(MaternalAgent where (!dead(each)));
        monitor "Children U5" value: length(ChildAgent where (!dead(each) and each.age_months < 60));
        monitor "Youth 5-15" value: length(ChildAgent where (!dead(each) and each.age_months >= 60));
        monitor "Youth % of Total Population" value: length(District) > 0 ? (length(ChildAgent where (!dead(each) and each.age_months >= 60)) / one_of(District).total_population * 100) : 0;
        monitor "Currently Pregnant" value: length(MaternalAgent where (!dead(each) and each.is_pregnant));
        monitor "Average ANC Visits" value: length(MaternalAgent where (!dead(each))) > 0 ? mean(MaternalAgent where (!dead(each)) collect each.anc_visits) : 0;
        monitor "Skilled Birth Rate %" value: total_births > 0 ? (skilled_births / total_births * 100) : 0;
        
        // =============================================================================
        // YEARLY LOGGING STATUS
        // =============================================================================
        monitor "[LOGGING] Status" value: logging_active ? "ACTIVE (Yearly 2024-2030)" : "INACTIVE";
        monitor "[LOGGING] File Path" value: log_file_path;
        monitor "[LOGGING] Current Phase" value: current_year < 2024 ? "Baseline (2019-2023)" : (current_year <= 2030 ? "Data Collection" : "Complete");
        
        // =============================================================================
        // SINGLE DISTRICT INFO
        // =============================================================================
        monitor "[DISTRICT] Name" value: target_district_name;
        monitor "[DISTRICT] Province" value: target_province_name;
        
        // =============================================================================
        // ACTUAL VS PREDICTED VALIDATION
        // =============================================================================
        monitor "[VALIDATION] Actual Maternal (GSO)" value: actual_maternal_by_year[current_year] != nil ? actual_maternal_by_year[current_year] : 0;
        monitor "[VALIDATION] Predicted Maternal" value: length(MaternalAgent where (!dead(each)));
        monitor "[VALIDATION] Maternal Accuracy %" value: (actual_maternal_by_year[current_year] != nil and actual_maternal_by_year[current_year] > 0) ? 
            (100 - abs(length(MaternalAgent where (!dead(each))) - actual_maternal_by_year[current_year]) / actual_maternal_by_year[current_year] * 100) : 0;
        
        monitor "[VALIDATION] Actual Children U5 (GSO)" value: actual_children_u5_by_year[current_year] != nil ? actual_children_u5_by_year[current_year] : 0;
        monitor "[VALIDATION] Predicted Children U5" value: length(ChildAgent where (!dead(each) and each.age_months < 60));
        monitor "[VALIDATION] Children U5 Accuracy %" value: (actual_children_u5_by_year[current_year] != nil and actual_children_u5_by_year[current_year] > 0) ? 
            (100 - abs(length(ChildAgent where (!dead(each) and each.age_months < 60)) - actual_children_u5_by_year[current_year]) / actual_children_u5_by_year[current_year] * 100) : 0;
        
        monitor "[VALIDATION] Data Phase" value: actual_maternal_by_year[current_year] != nil ? "Validation (Has Actual Data)" : "Prediction (No Actual Data)";
        monitor "[VALIDATION] Overall Status" value: 
            (actual_maternal_by_year[current_year] != nil and 
             ((100 - abs(length(MaternalAgent where (!dead(each))) - actual_maternal_by_year[current_year]) / actual_maternal_by_year[current_year] * 100) > 85) and
             ((100 - abs(length(ChildAgent where (!dead(each) and each.age_months < 60)) - actual_children_u5_by_year[current_year]) / actual_children_u5_by_year[current_year] * 100) > 85)) ? 
             "GOOD VALIDATION" : (actual_maternal_by_year[current_year] != nil ? "NEEDS CALIBRATION" : "PREDICTION MODE");
        
        // =============================================================================
        // DATA VALIDATION
        // =============================================================================
        monitor "[DATA] Source" value: "Vietnamese Government (GSO) District-Level";
        monitor "[DATA] Time Range" value: "2019-2030 (with projections from 2025)";
        monitor "[SIMULATION] Years Completed" value: current_year - 2019;
        monitor "[SIMULATION] Progress %" value: ((current_year - 2019) / 11.0) * 100;
        monitor "[SIMULATION] Auto-Stop" value: current_year <= 2030 ? ("Will stop after " + (2030 - current_year + 1) + " more years") : "COMPLETED";
    }
} 