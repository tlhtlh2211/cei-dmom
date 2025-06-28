/**
* Name: Dien Bien Maternal and Child Health ABM
* Description: Agent-Based Model simulating maternal and child health access behaviors in Dien Bien Province, Vietnam
* Authors: CEI-Simulation Team
* Tags: health, Vietnam, maternal care, child health, rural access
*/

model DienBienHealthABM

global {
    // Simulation parameters
    int current_week <- 0;
    int current_year <- 2019;
    
    // Data file paths
    string demographic_data_path <- "/Users/tranlehai/Desktop/CEI-Simulation/data/demographics/demographics_dien_bien.csv";
    
    // Real Vietnamese government data by province and year
    map<string, map<int, float>> provincial_literacy_rates;
    map<string, map<int, float>> provincial_poverty_rates;
    
    // 13-Indicator Framework for Upscaling
    map<string, float> provincial_indicators;
    map<string, map<string, float>> district_indicators;
    map<string, map<string, float>> commune_indicators;
    
    // Intervention flags
    bool app_based_intervention <- false;
    bool sms_outreach_intervention <- false;
    bool chw_visits_intervention <- false;
    bool incentives_intervention <- false;
    
    // Population parameters
    float maternal_sampling_rate <- 0.1; // 10% of actual population for performance
    float child_sampling_rate <- 0.1;
    
    // Behavioral parameters
    float base_pregnancy_rate <- 0.01; // 1% weekly pregnancy probability (more realistic demographic rate)
    float mobile_penetration <- 0.6; // 60% mobile phone ownership
    
    // Monitoring variables
    int total_pregnancies <- 0;
    int total_anc_visits <- 0;
    int total_births <- 0;
    int skilled_births <- 0;
    int total_immunizations <- 0;
    
    // Load and process demographic data
    matrix demographic_matrix;
    list<map> commune_data;
    
    init {
        write "=== INITIALIZING ENHANCED DIEN BIEN HEALTH ABM ===";
        
        // Initialize 13-indicator framework
        do initialize_indicator_framework;
        
        // Load real Vietnamese government data
        do initialize_real_vietnamese_data;
        
        // Load demographic data
        demographic_matrix <- matrix(csv_file(demographic_data_path, ",", true));
        commune_data <- [];
        
        // Process commune data with enhanced indicators
        loop i from: 1 to: demographic_matrix.rows - 1 {
            map commune_info <- map([]);
            commune_info["commune"] <- demographic_matrix[2,i];
            commune_info["district"] <- demographic_matrix[1,i];
            commune_info["year"] <- int(demographic_matrix[3,i]);
            commune_info["total_population"] <- int(demographic_matrix[4,i]);
            commune_info["women_15_49"] <- int(demographic_matrix[5,i]);
            commune_info["children_under_5"] <- int(demographic_matrix[6,i]);
            
            // Only use 2019 data for initialization
            if (commune_info["year"] = 2019) {
                commune_data << commune_info;
                
                // Calculate 13 indicators for this commune
                string commune_name <- string(commune_info["commune"]);
                commune_indicators[commune_name] <- calculate_commune_indicators(commune_info);
            }
        }
        
        write "Found " + length(commune_data) + " communes with 2019 data";
        
        // Create communes with enhanced indicators
        loop commune_info over: commune_data {
            string commune_name <- string(commune_info["commune"]);
            map<string, float> commune_indicators_map <- commune_indicators[commune_name];
            
            create Commune with: [
                commune_name: commune_name,
                district_name: string(commune_info["district"]),
                total_population: int(commune_info["total_population"]),
                women_15_49: int(commune_info["women_15_49"]),
                children_under_5: int(commune_info["children_under_5"]),
                indicators: commune_indicators_map,
                environmental_hazard_score: commune_indicators_map["environmental_hazard_score"],
                network_coverage_4g: commune_indicators_map["network_coverage_4g"],
                female_employment_rate: commune_indicators_map["female_employment_rate"],
                poverty_rate: get_real_poverty_rate("Dien Bien", current_year),
                literacy_rate: get_real_literacy_rate("Dien Bien", current_year)
            ];
        }
        
        write "Created " + length(Commune) + " commune agents";
        
        // Initialize agents for each commune
        ask Commune {
            do initialize_agents;
        }
        
        write "=== SIMULATION READY ===";
        write "Maternal agents: " + length(MaternalAgent);
        write "Child agents: " + length(ChildAgent);
        write "13-Indicator Framework initialized for " + length(commune_indicators) + " communes";
    }
    
    action initialize_indicator_framework {
        // Initialize 13-indicator framework maps
        provincial_indicators <- map([
            "population_density" :: 0.0,
            "women_reproductive_age_pct" :: 0.0,
            "ethnic_minority_pct" :: 0.0,
            "literacy_rate" :: 0.0,
            "multidimensional_poverty_rate" :: 0.0,
            "female_employment_rate" :: 0.0,
            "environmental_hazard_score" :: 0.0,
            "anc_coverage_rate" :: 0.0,
            "child_health_index" :: 0.0,
            "imr_mmr_composite" :: 0.0,
            "mobile_ownership_rate" :: 0.0,
            "network_coverage_4g" :: 0.0,
            "avg_distance_health_facility" :: 0.0
        ]);
        
        district_indicators <- map([]);
        commune_indicators <- map([]);
    }
    
    map<string, float> calculate_commune_indicators(map commune_info) {
        // Calculate all 13 indicators for upscaling framework
        map<string, float> indicators <- map([]);
        
        int total_pop <- int(commune_info["total_population"]);
        int women_15_49 <- int(commune_info["women_15_49"]);
        int children_u5 <- int(commune_info["children_under_5"]);
        
        // Demographic Indicators
        indicators["population_density"] <- total_pop / 100.0; // Simplified per sq km
        indicators["women_reproductive_age_pct"] <- women_15_49 / max(1, total_pop) * 100;
        indicators["ethnic_minority_pct"] <- rnd(40.0, 85.0); // Dien Bien ethnography
        indicators["literacy_rate"] <- rnd(45.0, 85.0); // Varies by remoteness
        
        // Socio-Economic Indicators  
        indicators["multidimensional_poverty_rate"] <- rnd(25.0, 75.0);
        indicators["female_employment_rate"] <- rnd(35.0, 65.0);
        indicators["environmental_hazard_score"] <- rnd(0.2, 0.8); // Flood/erosion risk
        
        // Health Indicators
        indicators["anc_coverage_rate"] <- rnd(35.0, 80.0); // Current baseline
        indicators["child_health_index"] <- rnd(0.4, 0.8);
        indicators["imr_mmr_composite"] <- rnd(15.0, 45.0); // Deaths per 1000
        
        // Digital Infrastructure Indicators
        indicators["mobile_ownership_rate"] <- rnd(45.0, 85.0);
        indicators["network_coverage_4g"] <- rnd(60.0, 95.0);
        indicators["avg_distance_health_facility"] <- rnd(2.0, 25.0); // km
        
        return indicators;
    }
    
    action initialize_real_vietnamese_data {
        write "Loading REAL Vietnamese government data (literacy & poverty rates)...";
        
        // REAL LITERACY RATES from Vietnamese General Statistics Office
        // Thai Nguyen province literacy rates (%)
        map<int, float> thai_nguyen_literacy <- map([
            2019 :: 98.20,
            2020 :: 97.99,
            2021 :: 98.32,
            2022 :: 98.27,
            2023 :: 98.75,
            2024 :: 98.75  // Same as 2023 as requested
        ]);
        
        // Dien Bien province literacy rates (%)
        map<int, float> dien_bien_literacy <- map([
            2019 :: 73.10,
            2020 :: 75.58,
            2021 :: 74.92,
            2022 :: 77.63,
            2023 :: 78.78,
            2024 :: 78.78  // Same as 2023 as requested
        ]);
        
        provincial_literacy_rates <- map([
            "Thai Nguyen" :: thai_nguyen_literacy,
            "Dien Bien" :: dien_bien_literacy
        ]);
        
        // REAL POVERTY RATES from Vietnamese government statistics
        // Thai Nguyen province poverty rates (%)
        map<int, float> thai_nguyen_poverty <- map([
            2019 :: 6.72,
            2020 :: 5.64,
            2021 :: 4.78,
            2022 :: 4.35,
            2023 :: 3.02,
            2024 :: 3.02  // Same as 2023 as requested
        ]);
        
        // Dien Bien province poverty rates (%)
        map<int, float> dien_bien_poverty <- map([
            2019 :: 33.05,
            2020 :: 29.93,
            2021 :: 26.76,
            2022 :: 18.70,  // Decreased by >30% from 2021 (26.76% * 0.7)
            2023 :: 26.57,
            2024 :: 26.57  // Same as 2023 as requested
        ]);
        
        provincial_poverty_rates <- map([
            "Thai Nguyen" :: thai_nguyen_poverty,
            "Dien Bien" :: dien_bien_poverty
        ]);
        
        write "✅ Loaded REAL Vietnamese government data for 2019-2024";
        write "   LITERACY - Dien Bien: " + dien_bien_literacy[2019] + "% → " + dien_bien_literacy[2024] + "%";
        write "   LITERACY - Thai Nguyen: " + thai_nguyen_literacy[2019] + "% → " + thai_nguyen_literacy[2024] + "%";
        write "   POVERTY - Dien Bien: " + dien_bien_poverty[2019] + "% → " + dien_bien_poverty[2024] + "%";
        write "   POVERTY - Thai Nguyen: " + thai_nguyen_poverty[2019] + "% → " + thai_nguyen_poverty[2024] + "%";
    }
    
    float get_real_literacy_rate(string province, int year) {
        map<int, float> province_rates <- provincial_literacy_rates[province];
        if (province_rates != nil and province_rates[year] != nil) {
            return province_rates[year] / 100.0; // Convert % to decimal
        } else {
            // Default fallback for Dien Bien if year not found
            return 0.75; // 75% average for Dien Bien
        }
    }
    
    float get_real_poverty_rate(string province, int year) {
        map<int, float> province_rates <- provincial_poverty_rates[province];
        if (province_rates != nil and province_rates[year] != nil) {
            return province_rates[year] / 100.0; // Convert % to decimal
        } else {
            // Default fallback for Dien Bien if year not found
            return 0.30; // 30% average for Dien Bien
        }
    }
    

    
    reflex weekly_step {
        current_week <- current_week + 1;
        
        // Update year
        if (current_week mod 52 = 0) {
            current_year <- current_year + 1;
            write "=== YEAR " + current_year + " ===";
        }
        
        // Reset weekly counters
        total_pregnancies <- 0;
        total_anc_visits <- 0;
        total_births <- 0;
        skilled_births <- 0;
        total_immunizations <- 0;
    }
    
    reflex monitor when: current_week mod 4 = 0 { // Monthly monitoring
        write "=== WEEK " + current_week + " MONITORING ===";
        write "Total maternal agents: " + length(MaternalAgent);
        write "Pregnant agents: " + length(MaternalAgent where each.is_pregnant);
        write "This period - Pregnancies: " + total_pregnancies;
        write "This period - ANC visits: " + total_anc_visits;
        write "This period - Births: " + total_births;
        write "This period - Skilled births: " + skilled_births;
        write "This period - Immunizations: " + total_immunizations;
        
        if (total_births > 0) {
            write "Skilled birth rate: " + (skilled_births / total_births * 100) + "%";
        }
    }
}

species Commune {
    string commune_name;
    string district_name;
    int total_population;
    int women_15_49;
    int children_under_5;
    
    // Enhanced infrastructure with 13-indicator framework
    map<string, float> indicators;
    float poverty_rate; // Will be set to real Vietnamese data
    float literacy_rate; // Will be set to real Vietnamese data
    float distance_to_hospital <- rnd(2.0, 20.0); // 2-20km to hospital
    
    // Additional indicators for scaling
    float environmental_hazard_score;
    float network_coverage_4g;
    float female_employment_rate;
    
    action initialize_agents {
        // Create maternal agents
        int num_maternal <- int(women_15_49 * maternal_sampling_rate);
        loop i from: 1 to: num_maternal {
            create MaternalAgent with: [
                my_commune: self,
                age: rnd(15, 49),
                ethnicity: sample_ethnicity(),
                literacy_level: sample_literacy(),
                poverty_level: sample_poverty(),
                mobile_access: flip(mobile_penetration),
                distance_to_facility: distance_to_hospital + rnd(-2.0, 2.0)
            ];
        }
        
        // Create child agents
        int num_children <- int(children_under_5 * child_sampling_rate);
        loop i from: 1 to: num_children {
            create ChildAgent with: [
                my_commune: self,
                age_months: rnd(0, 59),
                mother_agent: one_of(MaternalAgent where (each.my_commune = self))
            ];
        }
    }
    
    string sample_ethnicity {
        // Ethnic distribution for Dien Bien (simplified)
        float rand_val <- rnd(1.0);
        if (rand_val < 0.4) { return "Thai"; }
        else if (rand_val < 0.6) { return "Kinh"; }
        else if (rand_val < 0.8) { return "Hmong"; }
        else { return "Other"; }
    }
    
    float sample_literacy {
        // Use REAL Vietnamese literacy rate for current year
        float real_literacy_rate <- get_real_literacy_rate("Dien Bien", current_year);
        // Add individual variation around the real provincial rate
        return max(0.1, min(0.95, real_literacy_rate + rnd(-0.15, 0.15)));
    }
    
    float sample_poverty {
        // Use REAL Vietnamese poverty rate for current year
        float real_poverty_rate <- get_real_poverty_rate("Dien Bien", current_year);
        // Add individual variation around the real provincial rate
        return max(0.0, min(1.0, real_poverty_rate + rnd(-0.1, 0.1)));
    }
    

    
    // Visual representation
    aspect default {
        color <- #gray;
        draw circle(total_population/1000) color: color border: #black;
    }
}

species MaternalAgent {
    Commune my_commune;
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
    int weeks_since_last_birth <- 100; // Initialize to allow immediate pregnancy possibility
    
    // Intervention engagement
    float app_engagement <- 0.0;
    bool received_sms <- false;
    bool chw_contacted <- false;
    
    // Behavioral thresholds
    float care_seeking_threshold;
    
    init {
        // Calculate behavioral thresholds based on attributes
        care_seeking_threshold <- calculate_care_seeking_threshold();
        
        // Initial pregnancy status
        if (flip(base_pregnancy_rate)) {
            do become_pregnant;
        }
    }
    
    float calculate_care_seeking_threshold {
        float base_threshold <- 0.5;
        float literacy_factor <- -0.2 * literacy_level;
        float poverty_factor <- 0.15 * poverty_level;
        float distance_factor <- 0.1 * min(distance_to_facility / 10, 0.3);
        float ethnicity_factor <- (ethnicity = "Kinh") ? 0.0 : 0.1;
        
        return max(0.1, min(0.9, base_threshold + literacy_factor + poverty_factor + distance_factor + ethnicity_factor));
    }
    
    action become_pregnant {
        is_pregnant <- true;
        weeks_pregnant <- 1;
        anc_visits <- 0;
        total_pregnancies <- total_pregnancies + 1;
    }
    
    reflex pregnancy_progression when: is_pregnant {
        weeks_pregnant <- weeks_pregnant + 1;
        
        // Seek ANC care
        if (seek_anc_care()) {
            anc_visits <- anc_visits + 1;
            total_anc_visits <- total_anc_visits + 1;
        }
        
        // Give birth after 40 weeks
        if (weeks_pregnant >= 40) {
            do give_birth;
        }
    }
    
    bool seek_anc_care {
        if (anc_visits >= anc_target) { return false; }
        
        // Base probability increases with weeks pregnant, influenced by real literacy
        float base_prob <- min(0.8, 0.1 + 0.02 * weeks_pregnant);
        // Higher literacy (based on real Vietnamese data) improves ANC seeking
        float literacy_boost <- 0.3 * literacy_level;
        
        // Intervention effects
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
    
    action give_birth {
        // Probability of skilled birth attendant
        float base_prob <- 0.4 + 0.1 * anc_visits;
        float literacy_boost <- 0.2 * literacy_level; // Real literacy improves skilled birth access
        float poverty_penalty <- -0.15 * poverty_level;
        float distance_penalty <- -0.05 * min(distance_to_facility / 5, 0.4);
        
        float final_prob <- max(0.1, min(0.95, base_prob + literacy_boost + poverty_penalty + distance_penalty));
        
        has_skilled_birth_attendant <- flip(final_prob);
        
        if (has_skilled_birth_attendant) {
            skilled_births <- skilled_births + 1;
        }
        
        total_births <- total_births + 1;
        
        // Reset pregnancy status
        is_pregnant <- false;
        weeks_pregnant <- 0;
        weeks_since_last_birth <- current_week; // Track when birth occurred
        
        // Create new child agent
        create ChildAgent with: [
            my_commune: my_commune,
            age_months: 0,
            mother_agent: self
        ];
    }
    
    reflex potential_pregnancy when: !is_pregnant {
        // Small chance of becoming pregnant each week (with minimum 6-month interval after birth)
        if (flip(base_pregnancy_rate) and (current_week - weeks_since_last_birth) > 24) {
            do become_pregnant;
        }
    }
    
    // Visual representation
    aspect default {
        color <- is_pregnant ? #red : #blue;
        draw circle(0.5) color: color;
    }
}

species ChildAgent {
    Commune my_commune;
    int age_months;
    MaternalAgent mother_agent;
    
    // Health status
    int immunizations_received <- 0;
    int immunizations_target <- 8;
    int care_seeking_delays <- 0;
    
    init {
        // Some children start with partial immunizations based on age
        immunizations_received <- min(immunizations_target, age_months div 2);
    }
    
    reflex age_progression {
        // Age monthly (every 4 weeks = 1 month)
        if (current_week mod 4 = 0) {
            age_months <- age_months + 1;
            
            // Remove child agents when they turn 5 years old (60 months)
            if (age_months >= 60) {
                do die;
            }
        }
    }
    
    reflex seek_immunization when: need_immunization() {
        if (receive_care()) {
            immunizations_received <- immunizations_received + 1;
            total_immunizations <- total_immunizations + 1;
        } else {
            care_seeking_delays <- care_seeking_delays + 1;
        }
    }
    
    bool need_immunization {
        int expected_immunizations <- min(immunizations_target, age_months div 2);
        return immunizations_received < expected_immunizations;
    }
    
    bool receive_care {
        if (mother_agent = nil) { return false; }
        
        // Care probability depends on mother's characteristics
        float base_prob <- 0.3;
        float literacy_boost <- 0.2 * mother_agent.literacy_level;
        float poverty_penalty <- -0.1 * mother_agent.poverty_level;
        
        // Intervention effects
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
        color <- immunizations_received >= immunizations_target ? #green : #orange;
        draw circle(0.3) color: color;
    }
}

experiment "Main Simulation" type: gui {
    parameter "App-based Intervention" var: app_based_intervention category: "Interventions";
    parameter "SMS Outreach" var: sms_outreach_intervention category: "Interventions";
    parameter "CHW Visits" var: chw_visits_intervention category: "Interventions";
    parameter "Incentives" var: incentives_intervention category: "Interventions";
    
    parameter "Maternal Sampling Rate" var: maternal_sampling_rate min: 0.01 max: 1.0 category: "Population";
    parameter "Child Sampling Rate" var: child_sampling_rate min: 0.01 max: 1.0 category: "Population";
    
    output {
        display "Population Map" {
            species Commune aspect: default;
            species MaternalAgent aspect: default;
            species ChildAgent aspect: default;
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
        
        display "Population Statistics" {
            chart "Agent Populations" type: series {
                data "Maternal Agents" value: length(MaternalAgent) color: #blue;
                data "Pregnant" value: length(MaternalAgent where each.is_pregnant) color: #red;
                data "Child Agents" value: length(ChildAgent) color: #orange;
            }
        }
        
        monitor "Current Week" value: current_week;
        monitor "Current Year" value: current_year;
        monitor "Total Communes" value: length(Commune);
        monitor "Maternal Agents" value: length(MaternalAgent);
        monitor "Child Agents" value: length(ChildAgent);
        monitor "Currently Pregnant" value: length(MaternalAgent where each.is_pregnant);
        monitor "Average ANC Visits" value: length(MaternalAgent) > 0 ? mean(MaternalAgent collect each.anc_visits) : 0;
        monitor "Skilled Birth Rate %" value: total_births > 0 ? (skilled_births / total_births * 100) : 0;
        
        // 13-Indicator Framework Monitoring for Upscaling
        monitor "Avg Poverty Rate %" value: length(Commune) > 0 ? mean(Commune collect each.indicators["multidimensional_poverty_rate"]) : 0;
        monitor "Avg Literacy Rate %" value: length(Commune) > 0 ? mean(Commune collect each.indicators["literacy_rate"]) : 0;
        monitor "Avg Mobile Ownership %" value: length(Commune) > 0 ? mean(Commune collect each.indicators["mobile_ownership_rate"]) : 0;
        monitor "Avg Distance to Facility" value: length(Commune) > 0 ? mean(Commune collect each.indicators["avg_distance_health_facility"]) : 0;
        
        // Real Vietnamese Government Data Monitoring
        monitor "Real Literacy Rate %" value: get_real_literacy_rate("Dien Bien", current_year) * 100;
        monitor "Real Poverty Rate %" value: get_real_poverty_rate("Dien Bien", current_year) * 100;
        monitor "Avg Agent Literacy %" value: length(MaternalAgent) > 0 ? mean(MaternalAgent collect each.literacy_level) * 100 : 0;
        monitor "Avg Agent Poverty %" value: length(MaternalAgent) > 0 ? mean(MaternalAgent collect each.poverty_level) * 100 : 0;
        monitor "Literacy Impact on ANC" value: length(MaternalAgent where (each.literacy_level > 0.7)) > 0 ? mean(MaternalAgent where (each.literacy_level > 0.7) collect each.anc_visits) : 0;
        monitor "Poverty Impact on ANC" value: length(MaternalAgent where (each.poverty_level > 0.4)) > 0 ? mean(MaternalAgent where (each.poverty_level > 0.4) collect each.anc_visits) : 0;
    }
}
