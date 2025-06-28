/**
* Name: Multi-Level Dien Bien Health ABM - Upscaling Framework
* Description: Agent-Based Model with integrated indicators for district-to-province scaling
* Authors: CEI-Simulation Team  
* Tags: health, Vietnam, maternal care, scaling, ML-ABM
*/

model DienBienScaledHealthABM

global {
    // Simulation parameters
    int current_week <- 0;
    int current_year <- 2019;
    
    // Multi-level scaling parameters
    string simulation_level <- "district" among: ["district", "province", "national"];
    bool enable_hierarchical_interactions <- true;
    float district_to_province_scaling_factor <- 1.0;
    
    // Enhanced data paths
    string demographic_data_path <- "/Users/tranlehai/Desktop/CEI-Simulation/data/demographics/demographics_dien_bien.csv";
    
    // 13-Indicator Framework Implementation
    map<string, float> provincial_indicators;
    map<string, map<string, float>> district_indicators;
    map<string, map<string, float>> commune_indicators;
    
    // Intervention flags
    bool app_based_intervention <- false;
    bool sms_outreach_intervention <- false;
    bool chw_visits_intervention <- false;
    bool incentives_intervention <- false;
    
    // Population sampling for scaling
    float maternal_sampling_rate <- 0.1;
    float child_sampling_rate <- 0.1;
    
    // Behavioral parameters with spatial variation
    float base_pregnancy_rate <- 0.01;
    map<string, float> ethnicity_care_seeking_modifiers;
    map<string, float> district_digital_readiness;
    
    // Monitoring variables with multi-level aggregation
    map<string, int> district_pregnancies;
    map<string, int> district_anc_visits;
    map<string, int> district_skilled_births;
    map<string, float> district_digital_engagement;
    
    // Load and process multi-level data
    matrix demographic_matrix;
    list<map> commune_data;
    list<map> district_data;
    
    init {
        write "=== INITIALIZING MULTI-LEVEL ABM FOR SCALING ===";
        
        // Initialize indicator framework
        do initialize_indicator_framework;
        
        // Initialize ethnicity modifiers based on research
        ethnicity_care_seeking_modifiers <- map([
            "Thai" :: 0.1,     // Cultural barriers in Dien Bien
            "Kinh" :: 0.0,     // Baseline (majority ethnic group)
            "Hmong" :: 0.15,   // Higher barriers - language, traditional practices
            "Other" :: 0.12    // Mixed ethnic minorities
        ]);
        
        // Load demographic data with enhanced processing
        demographic_matrix <- matrix(csv_file(demographic_data_path, ",", true));
        commune_data <- [];
        district_data <- [];
        
        // Process and aggregate data at multiple levels
        do process_multilevel_data;
        
        // Create administrative hierarchy
        do create_administrative_hierarchy;
        
        write "=== SCALING FRAMEWORK INITIALIZED ===";
        write "Districts: " + length(District);
        write "Communes: " + length(Commune);
        write "Simulation Level: " + simulation_level;
    }
    
    action initialize_indicator_framework {
        // Initialize 13-indicator framework for scaling
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
    
    action process_multilevel_data {
        // Process commune-level data
        loop i from: 1 to: demographic_matrix.rows - 1 {
            map commune_info <- map([]);
            commune_info["commune"] <- demographic_matrix[2,i];
            commune_info["district"] <- demographic_matrix[1,i];
            commune_info["year"] <- int(demographic_matrix[3,i]);
            commune_info["total_population"] <- int(demographic_matrix[4,i]);
            commune_info["women_15_49"] <- int(demographic_matrix[5,i]);
            commune_info["children_under_5"] <- int(demographic_matrix[6,i]);
            
            if (commune_info["year"] = 2019) {
                commune_data << commune_info;
                
                // Calculate commune-level indicators
                string commune_name <- string(commune_info["commune"]);
                string district_name <- string(commune_info["district"]);
                
                commune_indicators[commune_name] <- calculate_commune_indicators(commune_info);
                
                // Aggregate to district level
                if (district_indicators[district_name] = nil) {
                    district_indicators[district_name] <- map([]);
                }
                do aggregate_to_district(commune_name, district_name);
            }
        }
        
        // Aggregate to provincial level
        do aggregate_to_provincial;
        
        write "Processed indicators for " + length(commune_indicators) + " communes";
        write "Processed indicators for " + length(district_indicators) + " districts";
    }
    
    map<string, float> calculate_commune_indicators(map commune_info) {
        map<string, float> indicators <- map([]);
        
        // Calculate all 13 indicators at commune level
        int total_pop <- int(commune_info["total_population"]);
        int women_15_49 <- int(commune_info["women_15_49"]);
        int children_u5 <- int(commune_info["children_under_5"]);
        
        indicators["population_density"] <- total_pop / 100.0; // Simplified per sq km
        indicators["women_reproductive_age_pct"] <- women_15_49 / max(1, total_pop) * 100;
        indicators["ethnic_minority_pct"] <- rnd(40.0, 85.0); // Based on Dien Bien ethnography
        indicators["literacy_rate"] <- rnd(45.0, 85.0); // Varying by commune remoteness
        indicators["multidimensional_poverty_rate"] <- rnd(25.0, 75.0); // High variation in Dien Bien
        indicators["female_employment_rate"] <- rnd(35.0, 65.0);
        indicators["environmental_hazard_score"] <- rnd(0.2, 0.8); // Flood/erosion risk
        indicators["anc_coverage_rate"] <- rnd(35.0, 80.0); // Current baseline
        indicators["child_health_index"] <- rnd(0.4, 0.8);
        indicators["imr_mmr_composite"] <- rnd(15.0, 45.0); // Deaths per 1000
        indicators["mobile_ownership_rate"] <- rnd(45.0, 85.0);
        indicators["network_coverage_4g"] <- rnd(60.0, 95.0); // Even remote areas have some coverage
        indicators["avg_distance_health_facility"] <- rnd(2.0, 25.0); // km
        
        return indicators;
    }
    
    action aggregate_to_district(string commune_name, string district_name) {
        // Weighted aggregation from commune to district
        map<string, float> commune_data <- commune_indicators[commune_name];
        map<string, float> district_data <- district_indicators[district_name];
        
        // Initialize district data if empty
        if (length(district_data) = 0) {
            district_data <- map([]);
            loop indicator_key over: commune_data.keys {
                district_data[indicator_key] <- 0.0;
            }
            district_data["commune_count"] <- 0.0;
        }
        
        // Aggregate using simple averaging (could be weighted by population)
        loop indicator_key over: commune_data.keys {
            district_data[indicator_key] <- district_data[indicator_key] + commune_data[indicator_key];
        }
        district_data["commune_count"] <- district_data["commune_count"] + 1;
        
        district_indicators[district_name] <- district_data;
    }
    
    action aggregate_to_provincial {
        // Calculate provincial indicators from district aggregates
        loop indicator_key over: provincial_indicators.keys {
            float total_value <- 0.0;
            int district_count <- 0;
            
            loop district_name over: district_indicators.keys {
                map<string, float> district_data <- district_indicators[district_name];
                if (district_data[indicator_key] != nil) {
                    float avg_value <- district_data[indicator_key] / max(1, district_data["commune_count"]);
                    total_value <- total_value + avg_value;
                    district_count <- district_count + 1;
                }
            }
            
            provincial_indicators[indicator_key] <- total_value / max(1, district_count);
        }
        
        write "Provincial aggregation complete - Example indicators:";
        write "- Ethnic minority %: " + provincial_indicators["ethnic_minority_pct"];
        write "- Literacy rate: " + provincial_indicators["literacy_rate"];
        write "- Mobile ownership: " + provincial_indicators["mobile_ownership_rate"];
    }
    
    action create_administrative_hierarchy {
        // Create district agents first
        list<string> unique_districts <- remove_duplicates(commune_data collect string(each["district"]));
        
        loop district_name over: unique_districts {
            create District with: [
                district_name: district_name,
                indicators: district_indicators[district_name]
            ];
        }
        
        // Create commune agents with district references
        loop commune_info over: commune_data {
            string district_name <- string(commune_info["district"]);
            District parent_district <- District first_with (each.district_name = district_name);
            
            create Commune with: [
                commune_name: string(commune_info["commune"]),
                district_name: district_name,
                parent_district: parent_district,
                total_population: int(commune_info["total_population"]),
                women_15_49: int(commune_info["women_15_49"]),
                children_under_5: int(commune_info["children_under_5"]),
                indicators: commune_indicators[string(commune_info["commune"])]
            ];
        }
        
        // Initialize agents based on scaling level
        if (simulation_level = "district") {
            ask Commune {
                do initialize_agents;
            }
        } else if (simulation_level = "province") {
            // Scaled population for province-wide simulation
            maternal_sampling_rate <- maternal_sampling_rate * district_to_province_scaling_factor;
            child_sampling_rate <- child_sampling_rate * district_to_province_scaling_factor;
            ask Commune {
                do initialize_agents;
            }
        }
    }
    
    reflex weekly_step {
        current_week <- current_week + 1;
        
        if (current_week mod 52 = 0) {
            current_year <- current_year + 1;
            write "=== YEAR " + current_year + " ===";
            
            // Annual indicator updates for scaling
            do update_annual_indicators;
        }
        
        // Multi-level aggregation
        ask District {
            do aggregate_weekly_metrics;
        }
    }
    
    action update_annual_indicators {
        // Update dynamic indicators that change over time
        // This supports temporal scaling for multi-year simulations
        
        // Example: Digital readiness improvement
        loop district_name over: district_indicators.keys {
            map<string, float> indicators <- district_indicators[district_name];
            indicators["mobile_ownership_rate"] <- min(95.0, indicators["mobile_ownership_rate"] + rnd(0.5, 2.0));
            indicators["network_coverage_4g"] <- min(98.0, indicators["network_coverage_4g"] + rnd(0.2, 1.0));
            district_indicators[district_name] <- indicators;
        }
        
        write "Updated annual indicators for scaling purposes";
    }
}

// Enhanced District species for hierarchical scaling
species District {
    string district_name;
    map<string, float> indicators;
    
    // Aggregated metrics from communes
    int total_maternal_agents <- 0;
    int total_child_agents <- 0;
    float anc_coverage_rate <- 0.0;
    float digital_engagement_rate <- 0.0;
    
    action aggregate_weekly_metrics {
        // Aggregate metrics from all communes in this district
        list<Commune> my_communes <- Commune where (each.parent_district = self);
        
        total_maternal_agents <- sum(my_communes collect length(each.my_maternal_agents));
        total_child_agents <- sum(my_communes collect length(each.my_child_agents));
        
        // Calculate district-level indicators
        if (total_maternal_agents > 0) {
            int total_anc_visits <- sum(my_communes collect sum(each.my_maternal_agents collect each.anc_visits));
            anc_coverage_rate <- total_anc_visits / max(1, total_maternal_agents);
        }
    }
    
    aspect default {
        draw square(5) color: #darkgreen border: #black;
    }
}

// Enhanced Commune species with indicator integration
species Commune {
    string commune_name;
    string district_name;
    District parent_district;
    int total_population;
    int women_15_49;
    int children_under_5;
    map<string, float> indicators;
    
    // Agent containers for tracking
    list<MaternalAgent> my_maternal_agents <- [];
    list<ChildAgent> my_child_agents <- [];
    
    action initialize_agents {
        // Enhanced agent creation using indicators
        int num_maternal <- int(women_15_49 * maternal_sampling_rate);
        loop i from: 1 to: num_maternal {
            create MaternalAgent with: [
                my_commune: self,
                age: rnd(15, 49),
                ethnicity: sample_ethnicity_weighted(),
                literacy_level: sample_literacy_from_indicators(),
                poverty_level: sample_poverty_from_indicators(),
                mobile_access: sample_mobile_access(),
                distance_to_facility: indicators["avg_distance_health_facility"] + rnd(-2.0, 2.0),
                environmental_risk: indicators["environmental_hazard_score"]
            ];
        }
        
        my_maternal_agents <- MaternalAgent where (each.my_commune = self);
        
        int num_children <- int(children_under_5 * child_sampling_rate);
        loop i from: 1 to: num_children {
            create ChildAgent with: [
                my_commune: self,
                age_months: rnd(0, 59),
                mother_agent: one_of(my_maternal_agents)
            ];
        }
        
        my_child_agents <- ChildAgent where (each.my_commune = self);
    }
    
    string sample_ethnicity_weighted {
        // Use indicator-based ethnicity sampling
        float minority_pct <- indicators["ethnic_minority_pct"];
        float rand_val <- rnd(100.0);
        
        if (rand_val < (100 - minority_pct)) { return "Kinh"; }
        else if (rand_val < (100 - minority_pct + minority_pct * 0.5)) { return "Thai"; }
        else if (rand_val < (100 - minority_pct + minority_pct * 0.8)) { return "Hmong"; }
        else { return "Other"; }
    }
    
    float sample_literacy_from_indicators {
        float base_literacy <- indicators["literacy_rate"] / 100.0;
        return max(0.1, min(0.95, base_literacy + rnd(-0.2, 0.2)));
    }
    
    float sample_poverty_from_indicators {
        float base_poverty <- indicators["multidimensional_poverty_rate"] / 100.0;
        return max(0.0, min(1.0, base_poverty + rnd(-0.15, 0.15)));
    }
    
    bool sample_mobile_access {
        float ownership_rate <- indicators["mobile_ownership_rate"] / 100.0;
        return flip(ownership_rate);
    }
    
    aspect default {
        color <- #gray;
        float size_factor <- simulation_level = "province" ? 0.5 : 1.0;
        draw circle(total_population/1000 * size_factor) color: color border: #black;
    }
}

// Enhanced MaternalAgent with scaling indicators
species MaternalAgent {
    Commune my_commune;
    int age;
    string ethnicity;
    float literacy_level;
    float poverty_level;
    bool mobile_access;
    float distance_to_facility;
    float environmental_risk; // New indicator
    
    // Health status
    bool is_pregnant <- false;
    int weeks_pregnant <- 0;
    int anc_visits <- 0;
    int anc_target <- 4;
    bool has_skilled_birth_attendant <- false;
    int weeks_since_last_birth <- 100;
    
    // Enhanced intervention engagement with digital readiness
    float app_engagement <- 0.0;
    float digital_literacy_score <- 0.0;
    bool received_sms <- false;
    bool chw_contacted <- false;
    
    // Scaling-aware behavioral thresholds
    float care_seeking_threshold;
    float intervention_responsiveness;
    
    init {
        care_seeking_threshold <- calculate_enhanced_care_threshold();
        digital_literacy_score <- calculate_digital_readiness();
        intervention_responsiveness <- calculate_intervention_responsiveness();
        
        if (flip(base_pregnancy_rate)) {
            do become_pregnant;
        }
    }
    
    float calculate_enhanced_care_threshold {
        // Enhanced calculation using scaling indicators
        float base_threshold <- 0.5;
        
        // Individual factors
        float literacy_factor <- -0.2 * literacy_level;
        float poverty_factor <- 0.15 * poverty_level;
        float distance_factor <- 0.1 * min(distance_to_facility / 10, 0.3);
        float ethnicity_factor <- ethnicity_care_seeking_modifiers[ethnicity] != nil ? 
                                 ethnicity_care_seeking_modifiers[ethnicity] : 0.0;
        
        // Environmental factors from scaling indicators
        float hazard_factor <- 0.05 * environmental_risk;
        
        // Community-level factors
        map<string, float> commune_indicators <- my_commune.indicators;
        float community_anc_factor <- -0.1 * (commune_indicators["anc_coverage_rate"] / 100.0);
        
        return max(0.1, min(0.9, base_threshold + literacy_factor + poverty_factor + 
                           distance_factor + ethnicity_factor + hazard_factor + community_anc_factor));
    }
    
    float calculate_digital_readiness {
        // Calculate agent's digital readiness for scaling app interventions
        float base_readiness <- mobile_access ? 0.6 : 0.1;
        float literacy_boost <- 0.3 * literacy_level;
        float age_factor <- age < 35 ? 0.1 : -0.1;
        float urban_rural_factor <- my_commune.indicators["population_density"] > 50 ? 0.1 : -0.05;
        
        return max(0.0, min(1.0, base_readiness + literacy_boost + age_factor + urban_rural_factor));
    }
    
    float calculate_intervention_responsiveness {
        // How responsive agent is to different intervention types
        float base_responsiveness <- 0.5;
        float trust_factor <- ethnicity = "Kinh" ? 0.1 : -0.05; // Cultural trust in health system
        float education_factor <- 0.2 * literacy_level;
        float poverty_constraint <- -0.1 * poverty_level;
        
        return max(0.1, min(0.9, base_responsiveness + trust_factor + education_factor + poverty_constraint));
    }
    
    action become_pregnant {
        is_pregnant <- true;
        weeks_pregnant <- 1;
        anc_visits <- 0;
    }
    
    reflex pregnancy_progression when: is_pregnant {
        weeks_pregnant <- weeks_pregnant + 1;
        
        if (seek_enhanced_anc_care()) {
            anc_visits <- anc_visits + 1;
        }
        
        if (weeks_pregnant >= 40) {
            do give_enhanced_birth;
        }
    }
    
    bool seek_enhanced_anc_care {
        if (anc_visits >= anc_target) { return false; }
        
        // Enhanced ANC seeking with scaling factors
        float base_prob <- min(0.8, 0.1 + 0.02 * weeks_pregnant);
        
        // Intervention effects with scaling
        float intervention_boost <- 0.0;
        
        if (app_based_intervention and digital_literacy_score > 0.5) {
            intervention_boost <- intervention_boost + (0.2 * intervention_responsiveness);
        }
        
        if (sms_outreach_intervention and mobile_access) {
            intervention_boost <- intervention_boost + (0.15 * intervention_responsiveness);
        }
        
        if (chw_visits_intervention) {
            // CHW effectiveness varies by ethnicity and remoteness
            float chw_effectiveness <- ethnicity = "Kinh" ? 0.25 : 0.35; // Higher for minorities
            if (distance_to_facility > 10) { chw_effectiveness <- chw_effectiveness + 0.1; }
            intervention_boost <- intervention_boost + (chw_effectiveness * intervention_responsiveness);
        }
        
        if (incentives_intervention and poverty_level > 0.6) {
            intervention_boost <- intervention_boost + (0.3 * intervention_responsiveness);
        }
        
        // Environmental barriers
        float environmental_barrier <- environmental_risk > 0.6 ? -0.1 : 0.0;
        
        float final_prob <- min(0.95, base_prob + intervention_boost + environmental_barrier);
        
        return flip(final_prob) and flip(1.0 - care_seeking_threshold);
    }
    
    action give_enhanced_birth {
        // Enhanced birth with scaling factors
        float base_prob <- 0.4 + 0.1 * anc_visits;
        float literacy_boost <- 0.2 * literacy_level;
        float poverty_penalty <- -0.15 * poverty_level;
        float distance_penalty <- -0.05 * min(distance_to_facility / 5, 0.4);
        float community_factor <- 0.1 * (my_commune.indicators["anc_coverage_rate"] / 100.0);
        float environmental_penalty <- -0.05 * environmental_risk;
        
        float final_prob <- max(0.1, min(0.95, base_prob + literacy_boost + poverty_penalty + 
                                        distance_penalty + community_factor + environmental_penalty));
        
        has_skilled_birth_attendant <- flip(final_prob);
        
        // Reset and create child
        is_pregnant <- false;
        weeks_pregnant <- 0;
        weeks_since_last_birth <- current_week;
        
        create ChildAgent with: [
            my_commune: my_commune,
            age_months: 0,
            mother_agent: self
        ];
    }
    
    reflex potential_pregnancy when: !is_pregnant {
        if (flip(base_pregnancy_rate) and (current_week - weeks_since_last_birth) > 24) {
            do become_pregnant;
        }
    }
    
    aspect default {
        color <- is_pregnant ? #red : #blue;
        float size_factor <- simulation_level = "province" ? 0.3 : 0.5;
        draw circle(size_factor) color: color;
    }
}

// Enhanced ChildAgent with scaling indicators
species ChildAgent {
    Commune my_commune;
    int age_months;
    MaternalAgent mother_agent;
    
    int immunizations_received <- 0;
    int immunizations_target <- 8;
    int care_seeking_delays <- 0;
    
    init {
        immunizations_received <- min(immunizations_target, age_months div 2);
    }
    
    reflex age_progression {
        if (current_week mod 4 = 0) {
            age_months <- age_months + 1;
            
            if (age_months >= 60) {
                do die;
            }
        }
    }
    
    reflex seek_immunization when: need_immunization() {
        if (receive_enhanced_care()) {
            immunizations_received <- immunizations_received + 1;
        } else {
            care_seeking_delays <- care_seeking_delays + 1;
        }
    }
    
    bool need_immunization {
        int expected_immunizations <- min(immunizations_target, age_months div 2);
        return immunizations_received < expected_immunizations;
    }
    
    bool receive_enhanced_care {
        if (mother_agent = nil) { return false; }
        
        // Enhanced care seeking with scaling factors
        float base_prob <- 0.3;
        float literacy_boost <- 0.2 * mother_agent.literacy_level;
        float poverty_penalty <- -0.1 * mother_agent.poverty_level;
        
        // Community-level factors
        float community_health_factor <- 0.15 * (my_commune.indicators["child_health_index"]);
        
        // Intervention effects
        float intervention_boost <- 0.0;
        if (app_based_intervention and mother_agent.digital_literacy_score > 0.4) {
            intervention_boost <- intervention_boost + 0.15;
        }
        
        if (incentives_intervention and mother_agent.poverty_level > 0.5) {
            intervention_boost <- intervention_boost + 0.25;
        }
        
        float final_prob <- max(0.05, min(0.9, base_prob + literacy_boost + poverty_penalty + 
                                         community_health_factor + intervention_boost));
        
        return flip(final_prob);
    }
    
    aspect default {
        color <- immunizations_received >= immunizations_target ? #green : #orange;
        float size_factor <- simulation_level = "province" ? 0.2 : 0.3;
        draw circle(size_factor) color: color;
    }
}

experiment "Multi-Level Scaling Simulation" type: gui {
    parameter "Simulation Level" var: simulation_level category: "Scaling";
    parameter "District-Province Scaling Factor" var: district_to_province_scaling_factor min: 0.1 max: 2.0 category: "Scaling";
    parameter "Enable Hierarchical Interactions" var: enable_hierarchical_interactions category: "Scaling";
    
    parameter "App-based Intervention" var: app_based_intervention category: "Interventions";
    parameter "SMS Outreach" var: sms_outreach_intervention category: "Interventions";
    parameter "CHW Visits" var: chw_visits_intervention category: "Interventions";
    parameter "Incentives" var: incentives_intervention category: "Interventions";
    
    parameter "Maternal Sampling Rate" var: maternal_sampling_rate min: 0.01 max: 1.0 category: "Population";
    parameter "Child Sampling Rate" var: child_sampling_rate min: 0.01 max: 1.0 category: "Population";
    
    output {
        display "Multi-Level Administrative Map" {
            species District aspect: default;
            species Commune aspect: default;
            species MaternalAgent aspect: default;
            species ChildAgent aspect: default;
        }
        
        display "13-Indicator Dashboard" {
            chart "Key Scaling Indicators" type: series {
                data "Provincial Literacy Rate" value: provincial_indicators["literacy_rate"] color: #blue;
                data "Provincial Poverty Rate" value: provincial_indicators["multidimensional_poverty_rate"] color: #red;
                data "Mobile Ownership Rate" value: provincial_indicators["mobile_ownership_rate"] color: #green;
                data "ANC Coverage Rate" value: provincial_indicators["anc_coverage_rate"] color: #purple;
            }
        }
        
        display "District-Level Aggregation" {
            chart "District Health Outcomes" type: series {
                data "Total Maternal Agents" value: sum(District collect each.total_maternal_agents) color: #blue;
                data "Total Child Agents" value: sum(District collect each.total_child_agents) color: #orange;
                data "Average District ANC Coverage" value: length(District) > 0 ? mean(District collect each.anc_coverage_rate) : 0 color: #purple;
            }
        }
        
        monitor "Simulation Level" value: simulation_level;
        monitor "Current Week" value: current_week;
        monitor "Districts" value: length(District);
        monitor "Communes" value: length(Commune);
        monitor "Provincial Ethnic Minority %" value: provincial_indicators["ethnic_minority_pct"];
        monitor "Provincial Literacy Rate" value: provincial_indicators["literacy_rate"];
        monitor "Provincial Mobile Coverage" value: provincial_indicators["mobile_ownership_rate"];
        monitor "Average Distance to Facility" value: provincial_indicators["avg_distance_health_facility"];
    }
} 