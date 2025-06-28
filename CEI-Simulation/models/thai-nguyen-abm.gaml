/**
 * MATERNAL & CHILD HEALTH ABM - THAI NGUYEN PROVINCE, VIETNAM
 */

model ThaiNguyenHealthABM

global {
    int current_week <- 0;
    int current_year <- 2019;
    
    // Population rates
    float maternal_sampling_rate <- 0.1;
    float child_sampling_rate <- 0.1;
    float base_pregnancy_rate <- 0.008;
    float mobile_penetration <- 0.65;
    
    // Weekly health counters
    int total_pregnancies <- 0;
    int total_anc_visits <- 0;
    int total_births <- 0;
    int skilled_births <- 0;
    int total_immunizations <- 0;
    
    // Interventions
    bool app_based_intervention <- false;
    bool sms_outreach_intervention <- false;
    bool chw_visits_intervention <- false;
    bool incentives_intervention <- false;
    
    // Data
    matrix demographic_matrix;
    list<map> commune_data;
    string demographic_data_path <- "/Users/tranlehai/Desktop/CEI-Simulation/data/demographics/demographics_thai_nguyen.csv";
    map<string, map<int, float>> literacy_rates;
    map<string, map<int, float>> poverty_rates;
    
    init {
        write "=== INITIALIZING THAI NGUYEN HEALTH ABM ===";
        
        do load_real_data;
        do load_communes;
        
        ask Commune {
            do create_agents;
        }
        
        write "=== SIMULATION READY ===";
        write "Maternal agents: " + length(MaternalAgent);
        write "Child agents: " + length(ChildAgent);
    }
    
    action load_real_data {
        // Real literacy rates - Thai Nguyen province
        map<int, float> thai_nguyen_literacy <- map([
            2019 :: 0.982, 2020 :: 0.979, 2021 :: 0.983, 2022 :: 0.982, 
            2023 :: 0.985, 2024 :: 0.987
        ]);
        literacy_rates["Thai Nguyen"] <- thai_nguyen_literacy;
        
        // Real poverty rates - Thai Nguyen province  
        map<int, float> thai_nguyen_poverty <- map([
            2019 :: 0.0245, 2020 :: 0.0198, 2021 :: 0.0156, 2022 :: 0.0124,
            2023 :: 0.0098, 2024 :: 0.0078
        ]);
        poverty_rates["Thai Nguyen"] <- thai_nguyen_poverty;
    }
    
    action load_communes {
        demographic_matrix <- matrix(csv_file(demographic_data_path, ",", true));
        commune_data <- [];
        
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
            }
        }
        
        loop commune_info over: commune_data {
            create Commune with: [
                commune_name: string(commune_info["commune"]),
                district_name: string(commune_info["district"]),
                total_population: int(commune_info["total_population"]),
                women_15_49: int(commune_info["women_15_49"]),
                children_under_5: int(commune_info["children_under_5"]),
                distance_to_hospital: rnd(2.0, 15.0),
                poverty_rate: 0.0245,
                literacy_rate: 0.982
            ];
        }
    }
    
    float get_literacy_rate(string province, int year) {
        if (literacy_rates contains_key province and literacy_rates[province] contains_key year) {
            return literacy_rates[province][year];
        }
        return 0.982; // Default Thai Nguyen 2019
    }
    
    float get_poverty_rate(string province, int year) {
        if (poverty_rates contains_key province and poverty_rates[province] contains_key year) {
            return poverty_rates[province][year];
        }
        return 0.0245; // Default Thai Nguyen 2019
    }
    
    reflex weekly_update {
        current_week <- current_week + 1;
        
        if (current_week mod 52 = 0) {
            current_year <- current_year + 1;
            write "=== YEAR " + current_year + " ===";
        }
    }
    
    reflex reset_counters {
        total_pregnancies <- 0;
        total_anc_visits <- 0;
        total_births <- 0;
        skilled_births <- 0;
        total_immunizations <- 0;
    }
    
    reflex weekly_report when: current_week mod 4 = 0 {
        write "Week " + current_week + " - Maternal: " + length(MaternalAgent where (!dead(each))) + 
              ", Children U5: " + length(ChildAgent where (!dead(each) and each.age_months < 60)) +
              ", Youth 5-15: " + length(ChildAgent where (!dead(each) and each.age_months >= 60));
    }
}

species Commune {
    string commune_name;
    string district_name;
    int total_population;
    int women_15_49;
    int children_under_5;
    float distance_to_hospital;
    float poverty_rate;
    float literacy_rate;
    
    action create_agents {
        // Create maternal agents
        int num_maternal <- int(women_15_49 * maternal_sampling_rate);
        loop i from: 1 to: num_maternal {
            create MaternalAgent with: [
                my_commune: self,
                age: sample_maternal_age(),
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
                age_months: sample_child_age(),
                mother_agent: one_of(MaternalAgent where (each.my_commune = self))
            ];
        }
    }
    
    string sample_ethnicity {
        float rand_val <- rnd(1.0);
        if (rand_val < 0.8) { return "Kinh"; }
        else if (rand_val < 0.9) { return "Tay"; }
        else if (rand_val < 0.95) { return "Nung"; }
        else { return "Other"; }
    }
    
    float sample_literacy {
        float base_rate <- 0.982;
        return max(0.1, min(0.95, base_rate + rnd(-0.05, 0.05)));
    }
    
    float sample_poverty {
        float base_rate <- 0.0245;
        return max(0.0, min(1.0, base_rate + rnd(-0.01, 0.02)));
    }
    
    int sample_maternal_age {
        float age_float <- gauss(27.0, 6.0);
        return int(max(15, min(49, age_float)));
    }
    
    int sample_child_age {
        // Gaussian distribution centered at 30 months (2.5 years) with std dev of 18 months
        // This creates realistic age distribution: more younger children, fewer older ones
        float age_months_float <- gauss(30.0, 18.0);
        
        // Constrain to 0-59 months (under-5 years)
        int age_result <- int(max(0, min(59, age_months_float)));
        
        return age_result;
    }
    
    aspect default {
        draw circle(total_population/1000) color: #gray border: #black;
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
    
    bool is_pregnant <- false;
    int weeks_pregnant <- 0;
    int anc_visits <- 0;
    int anc_target <- 4;
    bool has_skilled_birth_attendant <- false;
    int weeks_since_last_birth <- -60;
    int total_children <- 0;
    
    float app_engagement <- 0.0;
    bool received_sms <- false;
    bool chw_contacted <- false;
    float care_seeking_threshold;
    
    init {
        care_seeking_threshold <- calculate_threshold();
        
        if (flip(base_pregnancy_rate / 4)) {
            do become_pregnant;
        }
    }
    
    float calculate_threshold {
        float base <- 0.5;
        float literacy_factor <- -0.2 * literacy_level;
        float poverty_factor <- 0.15 * poverty_level;
        float distance_factor <- 0.1 * min(distance_to_facility / 10, 0.3);
        float ethnicity_factor <- (ethnicity = "Kinh") ? 0.0 : 0.1;
        
        return max(0.1, min(0.9, base + literacy_factor + poverty_factor + distance_factor + ethnicity_factor));
    }
    
    action become_pregnant {
        is_pregnant <- true;
        weeks_pregnant <- 1;
        anc_visits <- 0;
        total_pregnancies <- total_pregnancies + 1;
    }
    
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
    
    action give_birth {
        // Calculate skilled birth probability
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
        
        // Create new child
        create ChildAgent with: [
            my_commune: my_commune,
            age_months: 0,
            mother_agent: self,
            gender: flip(0.5) ? "female" : "male"
        ];
        
        // Reset pregnancy status
        is_pregnant <- false;
        weeks_pregnant <- 0;
        weeks_since_last_birth <- current_week;
        
        if (age >= 50) {
            do die;
        }
    }
    
    reflex check_pregnancy when: !is_pregnant and (current_week - weeks_since_last_birth) > 52 and total_children < 3 {
        if (flip(base_pregnancy_rate)) {
            do become_pregnant;
        }
    }
    
    reflex age_yearly when: current_week mod 52 = 0 {
        age <- age + 1;
        
        if (age >= 50) {
            do die;
        }
    }
    
    aspect default {
        color <- is_pregnant ? #red : #blue;
        draw circle(0.5) color: color;
    }
}

species ChildAgent {
    Commune my_commune;
    int age_months;
    MaternalAgent mother_agent;
    string gender;
    int immunizations_received <- 0;
    int immunizations_target <- 8;
    int last_immunization_week <- 0;
    
    init {
        gender <- flip(0.5) ? "female" : "male";
        immunizations_received <- min(immunizations_target, age_months div 6);
    }
    
    reflex age_progression {
        if (current_week mod 4 = 0) {
            age_months <- age_months + 1;
            
            if (age_months >= 180) {
                if (mother_agent != nil and !dead(mother_agent)) {
                    mother_agent.total_children <- mother_agent.total_children - 1;
                }
                
                if (gender = "female") {
                    create MaternalAgent with: [
                        my_commune: my_commune,
                        age: 15,
                        ethnicity: my_commune.sample_ethnicity(),
                        literacy_level: my_commune.sample_literacy(),
                        poverty_level: my_commune.sample_poverty(),
                        mobile_access: flip(mobile_penetration),
                        distance_to_facility: my_commune.distance_to_hospital + rnd(-2.0, 2.0),
                        weeks_since_last_birth: -60
                    ];
                }
                
                do die;
            }
        }
    }
    
    reflex seek_immunization when: age_months < 60 and need_immunization() and can_seek_immunization() {
        if (receive_care()) {
            immunizations_received <- immunizations_received + 1;
            total_immunizations <- total_immunizations + 1;
            last_immunization_week <- current_week;
        }
    }
    
    bool need_immunization {
        int expected <- min(immunizations_target, age_months div 6);
        return immunizations_received < expected;
    }
    
    bool can_seek_immunization {
        return (current_week - last_immunization_week) >= 8;
    }
    
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
    
    aspect default {
        color <- immunizations_received >= immunizations_target ? #green : #orange;
        draw circle(0.3) color: color;
    }
}

experiment "Main Simulation" type: gui {
    parameter "App Intervention" var: app_based_intervention category: "Interventions";
    parameter "SMS Outreach" var: sms_outreach_intervention category: "Interventions";
    parameter "CHW Visits" var: chw_visits_intervention category: "Interventions";
    parameter "Incentives" var: incentives_intervention category: "Interventions";
    
    output {
        display "Population Map" {
            species Commune aspect: default;
            species MaternalAgent aspect: default;
            species ChildAgent aspect: default;
        }
        
        display "Health Metrics" {
            chart "Weekly Health" type: series {
                data "Pregnancies" value: total_pregnancies color: #red;
                data "ANC Visits" value: total_anc_visits color: #blue;
                data "Births" value: total_births color: #green;
                data "Immunizations" value: total_immunizations color: #orange;
            }
        }
        
        display "Population" {
            chart "Agent Counts" type: series {
                data "Maternal" value: length(MaternalAgent where (!dead(each))) color: #blue;
                data "Pregnant" value: length(MaternalAgent where (!dead(each) and each.is_pregnant)) color: #red;
                data "Children U5" value: length(ChildAgent where (!dead(each) and each.age_months < 60)) color: #orange;
                data "Youth 5-15" value: length(ChildAgent where (!dead(each) and each.age_months >= 60)) color: #purple;
            }
        }
        
        monitor "Week" value: current_week;
        monitor "Year" value: current_year;
        monitor "Maternal Agents" value: length(MaternalAgent where (!dead(each)));
        monitor "Children U5" value: length(ChildAgent where (!dead(each) and each.age_months < 60));
        monitor "Youth 5-15" value: length(ChildAgent where (!dead(each) and each.age_months >= 60));
        monitor "Pregnant" value: length(MaternalAgent where (!dead(each) and each.is_pregnant));
        monitor "Avg ANC Visits" value: length(MaternalAgent where (!dead(each))) > 0 ? mean(MaternalAgent where (!dead(each)) collect each.anc_visits) : 0;
        monitor "Skilled Birth %" value: total_births > 0 ? (skilled_births / total_births * 100) : 0;
        monitor "Avg Maternal Age" value: length(MaternalAgent where (!dead(each))) > 0 ? mean(MaternalAgent where (!dead(each)) collect each.age) : 0;
    }
}


