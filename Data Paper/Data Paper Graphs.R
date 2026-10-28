rm(list = ls(all = TRUE))
gc()
library(dplyr)
options(max.print=10000000)
library(tidyverse)
library(readxl)
library(ggplot2)
# Charger le package
library(writexl)
library(tidyr)


setwd('~/Desktop/ricardo_gph_analysis/Data Paper/')




RICardo_trade_flows_deduplicated <- read.csv(
  unz("RICardo_trade_flows_deduplicated.csv.zip", "RICardo_trade_flows_deduplicated.csv")
)


#Duplicated checks
check1<-RICardo_trade_flows_deduplicated[!duplicated(RICardo_trade_flows_deduplicated),]

check2 <- RICardo_trade_flows_deduplicated %>%
  group_by(reporting, partner, year, expimp) %>%
  mutate(idpanelidt = cur_group_id()) %>%
  ungroup()

check2 <- check2 %>%
  group_by(idpanelidt) %>%
  mutate(n_occurrences = n()) %>%
  ungroup()
##Delete 	***NA (duplicates and no partner) and last occurences twice (just unknown and worldundefined)
RICardoclean<-check2[check2$partner!="***NA",]
RICardoclean<-RICardoclean[RICardoclean$partner!="Unknown",]
RICardoclean<-RICardoclean[RICardoclean$n_occurrences!=2,] #OK no change compared to previous line

Partnerunique<-RICardoclean[!duplicated(RICardoclean$partner),]
Reporterunique<-RICardoclean[!duplicated(RICardoclean$reporting),]

#Delete world data
RICardocleannoworld<-RICardoclean[RICardoclean$partner!="World as reported",]
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World as reported2",]
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World estimated",]
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World Federico Tena",] 
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World sum partners",]
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World_best_guess",]
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World undefined",]




#Nb de flux bilatéraux par année (import et export)

RICardocleannoworld <- RICardocleannoworld %>%
  group_by(reporting, partner, expimp) %>%
  mutate(idpanelid = cur_group_id()) %>%
  ungroup()

plot_data <- RICardocleannoworld %>%
  group_by(year) %>%
  summarise(
    Exports = sum(expimp == "Exp"),   # Seulement exportations
    Imports = sum(expimp == "Imp")    # Seulement importations
  ) %>%
  pivot_longer(cols = -year, 
               names_to = "categorie", 
               values_to = "n_observations")

# Créer le graphique
ggplot(plot_data, aes(x = year, y = n_observations, fill = categorie)) +
  geom_col() +
   labs(
    x = "Year",
    y = "Number of observations",
    fill = "Legend"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10), expand = c(0, 0)) +
  scale_fill_manual(values = c( "Exports" = "#316395", 
                               "Imports" = "#b82e2e")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )
#color<-c( "#316395", "#109618" , "#bcbd22" , "#efcccc", "#b82e2e", "#c33333", "#d97f7f", "#663333")

ggsave("Fig 1 Total nb of bilateral flows.png", 
       width = 12, 
       height = 6, 
       dpi = 300)

write.csv(plot_data,"Total nb of bilateral flows.csv", row.names = FALSE)
#Delete pre-1830
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$year>1829,]


#Plot 2
all_years <- data.frame(year = seq(min(RICardocleannoworld$year), max(RICardocleannoworld$year), by = 1))

# Compter les pays uniques par année pour chaque catégorie
plot_data2 <- RICardocleannoworld %>%
  group_by(year) %>%
  summarise(
    "Reportings (also partners)" = n_distinct(reporting[reporting %in% partner]),
     "Reportings (only)" = n_distinct(reporting[!reporting %in% partner]),
    "Partners (only)" = n_distinct(partner[!partner %in% reporting]),
    Total = n_distinct(c(reporting, partner))  # Total unique entities
  ) %>%
  right_join(all_years, by = "year") %>%  # Ajouter toutes les années
  pivot_longer(cols = -year, 
               names_to = "categorie", 
               values_to = "nombre_pays")

# Créer le graphique avec les 4 courbes
ggplot(plot_data2, aes(x = year, y = nombre_pays, color = categorie, group = categorie)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 1.5) +
  labs(
    x = "Year",
    y = "Nb of RIC entities by reporting and partner",
    color = "Category"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, max(plot_data2$nombre_pays, na.rm = TRUE), by = 50), expand = c(0, 0)) +
  scale_color_manual(
    values = c("Reportings (also partners)" = "#bcbd22", 
               "Reportings (only)" = "#109618", 
               "Partners (only)" = "#b82e2e",
               "Total" = "black")
  ) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    legend.position = "bottom"
  )

ggsave("Fig 4 nb of distinct entities per year.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data2,"nb of distinct entities per year.csv", row.names = FALSE)
# Count unique reporting countries by year and reporting_type
plot_data3 <- RICardocleannoworld %>%
  filter(reporting_type != "colonial_area") %>%
  group_by(year, reporting_type) %>%
  summarise(nb_reporting_unique = n_distinct(reporting), .groups = "drop")

# Create the histogram
ggplot(plot_data3, aes(x = year, y = nb_reporting_unique, fill = reporting_type)) +
  geom_col() +
  labs(
    x = "Year",
    y = "Number of RIC reporting entities",
    fill = "Reporting Type"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10), expand = c(0, 0)) +
  scale_fill_manual(values = c("GPH_entity"        = "#316395",
                               "locality"          = "#b82e2e",
                               "group"             = "#c1d0df",
                               "geographical_area" = "#9fd5a3",
                               "colonial_area"     = "orange")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  )
ggsave("Fig 5 Reporting type over years final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data3,"Reporting type over years final.csv", row.names = FALSE)
# Count unique partner countries by year and rpartner_type
reportings_par_an <- RICardocleannoworld %>% distinct(year, reporting)
plot_data4 <- RICardocleannoworld %>%
  anti_join(reportings_par_an, by = c("year", "partner" = "reporting")) %>%
  group_by(year, partner_type) %>%
  summarise(nb_partner_unique = n_distinct(partner), .groups = "drop")
plot_data4$partner_type[plot_data4$partner_type==""]<-"unknown"

# Create the histogram
ggplot(plot_data4, aes(x = year, y = nb_partner_unique, fill = partner_type)) +
  geom_col() +
  labs(
    x = "Year",
    y = "Number of RIC partners (only)",
    fill = "Partner Type"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10), expand = c(0, 0)) +
  scale_fill_manual(values = c("GPH_entity" = "#316395",    
                               "locality" = "#b82e2e",    
                               "group" =  "#c1d0df",    # Violet
                               "geographical_area" = "#9fd5a3",
                                 "colonial_area" = "orange",
                               "unknown"="grey")) +  
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  )
ggsave("Fig 6 Partner type over years final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data4,"Partner type over years final.csv", row.names = FALSE)
##Totals over time comparison (Worldasreported, World Federico Tena,World_best_guess,World sum partners)


Worldtrade<-RICardoclean[RICardoclean$partner=="World as reported"|RICardoclean$partner=="World_best_guess"|RICardoclean$partner=="World Federico Tena"|RICardoclean$partner=="World sum partners",]
Reporterunique2<-Worldtrade[!duplicated(Worldtrade$reporting),] #ok same nb entities of reporting as usual


Worldtrade$pounds<-(Worldtrade$flow*Worldtrade$unit)/Worldtrade$rate

Worldtrade <- Worldtrade %>% filter(year >= 1830)

# Créer une séquence complète d'années
all_years <- seq(min(Worldtrade$year), max(Worldtrade$year), by = 1)

# Sommer la colonne value par année et par type (import and export)
plot_data5 <- Worldtrade %>%
  group_by(year, partner) %>%
  summarise(total = sum(pounds, na.rm = TRUE), .groups = "drop") %>%
  complete(year = all_years, partner, fill = list(total = NA))

# Calculer le max avant
max_value <- max(plot_data5$total, na.rm = TRUE)

# Créer le graphique
ggplot(plot_data5, aes(x = year, y = total, color = partner, group = partner)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.6) +
  labs(
    x = "Year",
    y = "Total value",
    color = "Totals"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0),
                     breaks = scales::pretty_breaks(n = 10),
                     labels = scales::label_comma())+
  scale_color_manual(values = c("World as reported"   = "#b82e2e",
                                "World Federico Tena" = "#109618",
                                "World sum partners"  = "#316395",
                                "World_best_guess"    = "orange")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    legend.position = "bottom"
  )

ggsave("World computed with GPH entity over years final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data5,"World computed with GPH entity over years final.csv", row.names = FALSE)
ggplot(plot_data5, aes(x = year, y = total, color = partner, group = partner)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.6) +
  labs(
    x = "Year",
    y = "Total value",
    color = "Totals"
  ) +
  scale_x_continuous(breaks = seq(1830, 1938, by = 5), expand = c(0, 0)) +
  scale_y_log10(breaks = c(1e8, 3e8, 1e9, 3e9, 1e10),
                labels = scales::label_comma()) +
  annotation_logticks(sides = "l") +
  coord_cartesian(clip = "off") +
  scale_color_manual(values = c("World as reported"   = "#b82e2e",
                                "World Federico Tena" = "#109618",
                                "World sum partners"  = "#316395",
                                "World_best_guess"    = "orange")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    legend.position = "bottom"
  )


ggsave("World computed with GPH entity over years final (log scaled).png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data5,"World computed with GPH entity over years final (log scaled).csv", row.names = FALSE)
# Transformer les valeurs en log
plot_data6 <- plot_data5 %>%
  mutate(total_log = log(total))

# Créer le graphique avec les valeurs transformées
ggplot(plot_data6, aes(x = year, y = total_log, color = partner, group = partner)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.6) +
  labs(
    x = "Year",
    y = "Log(Total value)",
    color = "Totals"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0),
                     breaks = scales::pretty_breaks(n = 10),
                     labels = scales::label_comma())+
  scale_color_manual(values = c("World as reported" = "#b82e2e", 
                                "World Federico Tena" = "#109618", 
                                "World sum partners" =  "#316395",
                                "World_best_guess" = "orange")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    legend.position = "bottom"
  )
ggsave("World computed with GPH entity over years (logy) final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data6,"World computed with GPH entity over years (logy) final.csv", row.names = FALSE)
# Créer une séquence complète d'années
all_years <- seq(min(RICardocleannoworld$year), max(RICardocleannoworld$year), by = 1)

# Calculer le nombre d'entités distinctes par continent et année
plot_data7 <- RICardocleannoworld %>%
  group_by(year, reporting_continent) %>%
  summarise(nb_entities = n_distinct(reporting), .groups = "drop") %>%
  complete(year = all_years, reporting_continent, fill = list(nb_entities = 0))

#Delete World
plot_data7<-plot_data7[plot_data7$reporting_continent!="World",]
# Ajouter la catégorie NA pour toutes les années
na_data <- data.frame(
  year = all_years,
  reporting_continent = "NA",
  nb_entities = 0
)

plot_data7 <- plot_data7 %>%
  bind_rows(na_data) %>%
  group_by(year) %>%
  mutate(
    total_year = sum(nb_entities),
    percentage = if_else(total_year == 0, 
                         if_else(reporting_continent == "NA", 100, 0),
                         (nb_entities / total_year) * 100)
  ) %>%
  ungroup()

#No NA so delete
plot_data7<-plot_data7[plot_data7$reporting_continent!="NA",]

# Vérifier les continents présents
print("Continents in plot_data:")
print(unique(plot_data7$reporting_continent))

# Créer une palette automatique
color_continents_rep <- c("Africa"  = "#d48282",
                          "America" = "#83a1bf",
                          "Asia"    = "#9D4EDD",
                          "Europe"  = "#b7e0ba",
                          "Oceania" = "gold")


# Créer le graphique en aires empilées
ggplot(plot_data7, aes(x = year, y = percentage, fill = reporting_continent)) +
  geom_area(position = "stack", alpha = 0.8)  +
  labs(
    title = "",
    x = "Year",
    y = "Distribution of RIC reportings by continent (per cent)",
    fill = ""
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, 100, by = 10), 
                     expand = c(0, 0),
                     labels = function(x) paste0(x, "%")) +
  scale_fill_manual(values = color_continents_rep) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "bottom"
  )

ggsave("Fig 7 Distribution of reporting (by continent).png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data7,"Distribution of reporting (by continent).csv", row.names = FALSE)

# Créer une séquence complète d'années
all_years <- seq(min(RICardocleannoworld$year), max(RICardocleannoworld$year), by = 1)

# Calculer le nombre d'entités distinctes par continent et année
reportings_par_an <- RICardocleannoworld %>% distinct(year, reporting)

plot_data8 <- RICardocleannoworld %>%
  anti_join(reportings_par_an, by = c("year", "partner" = "reporting")) %>%
  group_by(year, partner_continent) %>%
  summarise(nb_entities = n_distinct(partner), .groups = "drop") %>%
  complete(year = all_years, partner_continent, fill = list(nb_entities = 0))

#keep only continents as reporting
plot_data8<-plot_data8[plot_data8$partner_continent!="World"&plot_data8$partner_continent!="Antarctic"&
                       plot_data8$partner_continent!="Arctic"&plot_data8$partner_continent!="Atlantic"&
                       plot_data8$partner_continent!="Pacific"&plot_data8$partner_continent!="",]
# Ajouter la catégorie NA pour toutes les années
na_data <- data.frame(
  year = all_years,
  partner_continent = "NA",
  nb_entities = 0
)

plot_data8 <- plot_data8 %>%
  bind_rows(na_data) %>%
  group_by(year) %>%
  mutate(
    total_year = sum(nb_entities),
    percentage = if_else(total_year == 0, 
                         if_else(partner_continent == "NA", 100, 0),
                         (nb_entities / total_year) * 100)
  ) %>%
  ungroup()

#No NA so delete
plot_data8<-plot_data8[plot_data8$partner_continent!="NA",]

# Vérifier les continents présents
print("Continents in plot_data:")
print(unique(plot_data8$partner_continent)) #no NA

color_continents_part <- c("Africa"  = "#d48282",
                           "America" = "#83a1bf",
                           "Asia"    = "#9D4EDD",
                           "Europe"  = "#b7e0ba",
                           "Oceania" = "gold")
  

# Créer le graphique en aires empilées
ggplot(plot_data8, aes(x = year, y = percentage, fill = partner_continent)) +
  geom_area(position = "stack", alpha = 0.8)  +
  labs(
    title = "",
    x = "Year",
    y = "Distribution of RIC partners (only) by continent (per cent)",
    fill = ""
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, 100, by = 10), 
                     expand = c(0, 0),
                     labels = function(x) paste0(x, "%")) +
  scale_fill_manual(values = color_continents_part) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "bottom"
  )

ggsave("Fig 8 Distribution of partners (only) (by continent).png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data8,"Distribution of partners (only) (by continent).csv", row.names = FALSE)

# Calculer le nombre d'entités distinctes par source et année
plot_data9 <- RICardocleannoworld %>%
  group_by(year, type) %>%
  summarise(nb_entities = n_distinct(reporting), .groups = "drop") %>%
  complete(year = all_years, type, fill = list(nb_entities = 0))

# Ajouter la catégorie NA pour toutes les années
na_data <- data.frame(
  year = all_years,
  type = "NA",
  nb_entities = 0
)

plot_data9 <- plot_data9 %>%
  bind_rows(na_data) %>%
  group_by(year) %>%
  mutate(
    total_year = sum(nb_entities),
    percentage = if_else(total_year == 0, 
                         if_else(type == "NA", 100, 0),
                         (nb_entities / total_year) * 100)
  ) %>%
  ungroup()
#No NA so delete
plot_data9<-plot_data9[plot_data9$type!="NA",]
# Vérifier les continents présents
print("Type in plot_data:")
print(unique(plot_data9$type))

color_types <- c("estimation"       = "#d48282",
                 "primary"          = "#83a1bf",
                 "primary_yearbook" = "#9D4EDD",
                 "secondary"        = "gold")
  
# Créer le graphique en aires empilées
ggplot(plot_data9, aes(x = year, y = percentage, fill = type)) +
  geom_area(position = "stack") +
  labs(
    title = "",
    x = "Year",
    y = "Distribution of RIC reportings by source type (per cent)",
    fill = ""
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, 100, by = 10), 
                     expand = c(0, 0),
                     labels = function(x) paste0(x, "%")) +
  scale_fill_manual(values = color_types) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "bottom"
  )
ggsave("Fig 9 Distribution of RIC reportings (by source type).png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data9,"Number of RIC reportings (by source type).csv", row.names = FALSE)

### With total and histogram
ggplot(plot_data9, aes(x = year, y = nb_entities, fill = type)) +
  geom_col(position = "stack", width = 0.9) +
  labs(
    x = "Year",
    y = "Number of RIC reportings by source type",
    fill = ""
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10), expand = c(0, 0)) +
  scale_fill_manual(values = color_types) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    legend.position = "bottom"
  )

ggsave("Fig 9bis Number of RIC reportings (by source type).png",
       width = 12, height = 6, dpi = 300)
write.csv(plot_data9,"Number of RIC reportings (by source type) bis.csv", row.names = FALSE)

#Uniqueestimationric
Uniqueestimationric<-RICardocleannoworld[RICardocleannoworld$type=="estimation",c(2,3,5,11,12)]
Uniqueestimationric<-Uniqueestimationric[!duplicated(Uniqueestimationric),]
write.csv(Uniqueestimationric, "RICentitiesyearEstimation.csv", row.names = FALSE)

# Serie over time by source
plot_data10 <- RICardocleannoworld %>%
  group_by(year, type) %>%
  summarise(nb_flows = n(), .groups = "drop") %>%  # n() compte les lignes = flux
  complete(year = all_years, type, fill = list(nb_flows = 0))


ggplot(plot_data10, aes(x = year, y = nb_flows, fill = type)) +
  geom_col(position = "stack", width = 0.9) +
  labs(
    x = "Year",
    y = "Number of flows",
    fill = "Source type"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10),
                     expand = c(0, 0),
                     labels = scales::label_comma()) +
  scale_fill_manual(values = c("estimation"       = "#d48282",
                               "primary"          = "#83a1bf",
                               "primary_yearbook" = "#9D4EDD",
                               "secondary"        = "gold")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    legend.position = "bottom"
  )

ggsave("Fig 10 Number of flows (by source type) histogram.png",
       width = 12, height = 6, dpi = 300)

write.csv(plot_data10,"Number of flows (by source type) histogram.csv", row.names = FALSE)

#NB de partners by reporting over years
plot_data_avg1 <- RICardocleannoworld %>%
  filter(year >= 1830) %>%
  group_by(year, reporting) %>%
  summarise(nb_partners = n_distinct(partner), .groups = "drop") %>%
  group_by(year) %>%
  summarise(
    mean_partners = mean(nb_partners),
    sd_partners = sd(nb_partners),
    n = n(),
    se = sd_partners / sqrt(n),
    ci_lower = mean_partners - 1.96 * se,
    ci_upper = mean_partners + 1.96 * se,
    .groups = "drop"
  )

ggplot(plot_data_avg1, aes(x = year)) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper, fill = "Average partners"), alpha = 0.3) +
  geom_line(aes(y = mean_partners, colour = "Average partners"), linewidth = 0.5) +
  geom_point(aes(y = mean_partners, colour = "Average partners"), size = 0.8) +
  geom_line(aes(y = n, colour = "Nb of reportings"), linewidth = 0.5) +
  geom_point(aes(y = n, colour = "Nb of reportings"), size = 0.8) +
  labs(x = "Year", y = "", colour = "", fill = "") +
  scale_x_continuous(breaks = seq(1830, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(
    breaks = seq(0, ceiling(max(c(plot_data_avg1$ci_upper, plot_data_avg1$n), na.rm = TRUE)/10)*10, by = 10)
  ) +
  scale_colour_manual(values = c("Average partners" = "#9D4EDD", "Nb of reportings" = "#316395")) +
  scale_fill_manual(values = c("Average partners" = "#9D4EDD"), guide = "none") +
  theme_classic() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
        legend.position = "bottom")


ggsave("Fig 2 Avg nb of partners per reporting.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data_avg1,"Avg nb of partners per reporting.csv", row.names = FALSE)


# Sans distinction exp/imp
plot_data_total <- RICardocleannoworld %>%
  filter(year >= 1830) %>%
  group_by(year, reporting) %>%
  summarise(nb_partners = n_distinct(partner), .groups = "drop") %>%
  group_by(year) %>%
  summarise(
    mean_partners = mean(nb_partners),
    sd_partners = sd(nb_partners),
    n = n(),
    se = sd_partners / sqrt(n),
    ci_lower = mean_partners - 1.96 * se,
    ci_upper = mean_partners + 1.96 * se,
    .groups = "drop"
  ) %>%
  mutate(flow_type = "Total")

# Avec distinction exp/imp
plot_data_by_flow <- RICardocleannoworld %>%
  filter(year >= 1830) %>%
  group_by(year, reporting, expimp) %>%
  summarise(nb_partners = n_distinct(partner), .groups = "drop") %>%
  group_by(year, expimp) %>%
  summarise(
    mean_partners = mean(nb_partners),
    sd_partners = sd(nb_partners),
    n = n(),
    se = sd_partners / sqrt(n),
    ci_lower = mean_partners - 1.96 * se,
    ci_upper = mean_partners + 1.96 * se,
    .groups = "drop"
  ) %>%
  rename(flow_type = expimp)

plot_data_avg <- bind_rows(plot_data_total, plot_data_by_flow)

ggplot(plot_data_avg, aes(x = year, y = mean_partners, color = flow_type, fill = flow_type)) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, color = NA) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.8) +
  labs(
    x = "Year",
    y = "Average number of partners per reporting entity",
    color = "Flow type",
    fill = "Flow type"
  ) +
  scale_x_continuous(breaks = seq(1830, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, ceiling(max(plot_data_avg$ci_upper, na.rm = TRUE)/10)*10, by = 10)) +
  scale_color_manual(
    values = c("Exp" = "#d48282", "Imp" = "#83a1bf", "Total" = "#9D4EDD"),
    labels = c("Exp" = "Export", "Imp" = "Import", "Total" = "All flows")
  ) +
  scale_fill_manual(
    values = c("Exp" = "#d48282", "Imp" = "#83a1bf", "Total" = "#9D4EDD"),
    labels = c("Exp" = "Export", "Imp" = "Import", "Total" = "All flows")
  ) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    legend.position = "bottom",
    legend.title = element_text(face = "bold")
  )


ggsave("Fig 3 Average partners per reporting by flow type with total and CI.png",
       width = 12, height = 6, dpi = 300)
write.csv(plot_data_avg,"Average partners per reporting by flow type with total and CI.csv", row.names = FALSE)
# Serie over time by continent
plot_data11 <- RICardocleannoworld %>%
  group_by(year, reporting_continent) %>%
  summarise(nb_flows = n(), .groups = "drop") %>%  # n() compte les lignes = flux
  complete(year = all_years, reporting_continent, fill = list(nb_flows = 0))

plot_data11<-plot_data11[plot_data11$reporting_continent!="World",]
ggplot(plot_data11, aes(x = year, y = nb_flows, color = reporting_continent, group = reporting_continent)) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 0.6) +
  labs(
    x = "Year",
    y = "Number of flows",
    color = "reporting continent"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_color_manual(values = c("Africa" = "#d48282", 
                                "America" = "#83a1bf", 
                                "Asia" ="#9D4EDD",
                                "Europe"="#b7e0ba",
                                "Oceania" = "gold")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    legend.position = "bottom"
  )

ggsave("Number of flows (by reporting continent) final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)
write.csv(plot_data11,"Number of flows (by reporting continent) final.csv", row.names = FALSE)
 
###GPH geopolhist by continent
GeoPolHist_entities_status_over_time <- read.csv("~/Desktop/ricardo_gph_analysis/Data Paper/GeoPolHist_entities_status_over_time.csv")
Geopolhist<-GeoPolHist_entities_status_over_time[GeoPolHist_entities_status_over_time$GPH_status!="International",]
Geopolhist<-Geopolhist[Geopolhist$GPH_status!="Part of",]

library(dplyr); library(tidyr)

Geopolhist_long <- Geopolhist %>%
  filter(start_year != "?", end_year != "?") %>%
  mutate(start_year = as.integer(start_year),
         end_year   = as.integer(end_year)) %>%
  filter(end_year >= start_year) %>%
  rowwise() %>%
  mutate(year = list(seq(start_year, end_year))) %>%
  ungroup() %>%
  unnest(year) %>%
  select(GPH_code, GPH_name, year, GPH_status, sovereign_GPH_code, continent)

Geopolhist_long<-Geopolhist_long[Geopolhist_long$year<1939,]
dim(Geopolhist_long)

# Calculer le nombre d'entités distinctes par continent et année
plot_datagph <- Geopolhist_long %>%
  group_by(year, continent) %>%
  summarise(nb_entities = n_distinct(GPH_code), .groups = "drop") %>%
  complete(year = all_years, continent, fill = list(nb_entities = 0))


# Ajouter la catégorie NA pour toutes les années
na_data <- data.frame(
  year = all_years,
  continent = "NA",
  nb_entities = 0
)

plot_datagph <- plot_datagph %>%
  bind_rows(na_data) %>%
  group_by(year) %>%
  mutate(
    total_year = sum(nb_entities),
    percentage = if_else(total_year == 0, 
                         if_else(continent == "NA", 100, 0),
                         (nb_entities / total_year) * 100)
  ) %>%
  ungroup()

#No NA so delete
plot_datagph<-plot_datagph[plot_datagph$continent!="NA",]

# Vérifier les continents présents
print("Continents in plot_data:")
print(unique(plot_datagph$continent))

# Créer une palette automatique
color_continents_rep <- c("Africa"  = "#d48282",
                          "America" = "#83a1bf",
                          "Asia"    = "#9D4EDD",
                          "Europe"  = "#b7e0ba",
                          "Oceania" = "gold")


# Créer le graphique en aires empilées
ggplot(plot_datagph, aes(x = year, y = percentage, fill = continent)) +
  geom_area(position = "stack", alpha = 0.8)  +
  labs(
    title = "",
    x = "Year",
    y = "Distribution of GeoPolHist entities by continent (per cent)",
    fill = ""
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, 100, by = 10), 
                     expand = c(0, 0),
                     labels = function(x) paste0(x, "%")) +
  scale_fill_manual(values = color_continents_rep) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "bottom"
  )

ggsave("Fig Distribution of GeoPolHist entities (by continent).png", 
       width = 12, 
       height = 6, 
       dpi = 300)

write.csv(plot_datagph,"Geopolhistbycontinent.csv", row.names = FALSE)

library(dplyr); library(tidyr)

# ---- Etape 1 : nettoyer les annees ----
e1 <- GeoPolHist_entities_status_over_time %>%
  filter(start_year != "?", end_year != "?") %>%
  mutate(start_year = as.integer(start_year),
         end_year   = as.integer(end_year)) %>%
  filter(!is.na(start_year), !is.na(end_year), end_year >= start_year)

cat("Etape 1 :", nrow(GeoPolHist_entities_status_over_time), "->", nrow(e1), "lignes\n")
cat("  entites :", n_distinct(e1$GPH_code), "\n")


# ---- Etape 2 : trier et reperer la derniere periode de chaque entite ----
e2 <- e1 %>%
  arrange(GPH_code, start_year) %>%
  group_by(GPH_code) %>%
  mutate(rang       = row_number(),
         n_periodes = n(),
         derniere   = rang == n_periodes,
         un_an      = end_year == start_year) %>%
  ungroup()

cat("\nEtape 2 :\n")
cat("  periodes d un an :", sum(e2$un_an), "\n")
cat("  dont non dernieres :", sum(e2$un_an & !e2$derniere), "\n")
print(e2 %>% dplyr::count(n_periodes) %>% head(10))


# ---- Etape 3 : calculer la fin corrigee ----
e3 <- e2 %>%
  mutate(fin = ifelse(derniere | un_an, end_year, end_year - 1))

cat("\nEtape 3 : exemples de correction\n")
print(e3 %>% filter(!derniere, !un_an) %>%
        select(GPH_code, GPH_name, start_year, end_year, fin, GPH_status) %>%
        head(10) %>% as.data.frame())


# ---- Etape 4 : deplier en annees ----
e4 <- e3 %>%
  rowwise() %>%
  mutate(year = list(seq(start_year, fin))) %>%
  ungroup() %>%
  unnest(year)

cat("\nEtape 4 :", nrow(e3), "periodes ->", nrow(e4), "lignes entite-annee\n")
cat("  annees couvertes :", min(e4$year), "-", max(e4$year), "\n")


# ---- Etape 5 : controler les doublons ----
doublons <- e4 %>%
  distinct(GPH_code, year, GPH_status) %>%
  dplyr::count(GPH_code, year) %>%
  filter(n > 1)

cat("\nEtape 5 :", nrow(doublons), "couples entite-annee en double\n")
if (nrow(doublons) > 0) {
  print(e4 %>% semi_join(doublons, by = c("GPH_code", "year")) %>%
          select(GPH_code, GPH_name, year, start_year, end_year, GPH_status) %>%
          arrange(GPH_code, year) %>% head(20) %>% as.data.frame())
}


# ---- Etape 6 : compter par statut et par annee ----
e6 <- e4 %>%
  distinct(GPH_code, year, GPH_status) %>%
  dplyr::count(GPH_status, year)

cat("\nEtape 6 :", n_distinct(e6$GPH_status), "statuts distincts\n")
print(e6 %>% group_by(GPH_status) %>%
        summarise(total = sum(n), annees = n(), .groups = "drop") %>%
        arrange(desc(total)) %>% as.data.frame())

cat("\n  Nombre d entites par annee, quelques reperes :\n")
print(e6 %>% group_by(year) %>% summarise(n_ent = sum(n), .groups = "drop") %>%
        filter(year %in% c(1816, 1850, 1900, 1938, 1960, 2000, 2020)) %>%
        as.data.frame())


# ---- Etape 7 : format large ----
GPH_status_over_time <- e6 %>%
  arrange(year) %>%
  pivot_wider(names_from = year, values_from = n, values_fill = 0) %>%
  arrange(GPH_status)

cat("\nEtape 7 :", nrow(GPH_status_over_time), "lignes x",
    ncol(GPH_status_over_time), "colonnes\n")
print(names(GPH_status_over_time)[1:8])
print(GPH_status_over_time[, 1:6])

write.csv(GPH_status_over_time,
          "GPH_status_over_timenew.csv", row.names = FALSE)




library(dplyr); library(tidyr)


###Table type of partner/reporting

rep_ent <- RICardocleannoworld %>%
  distinct(entity = reporting, type = reporting_type) %>%
  mutate(role_rep = TRUE)

par_ent <- RICardocleannoworld %>%
  distinct(entity = partner, type = partner_type) %>%
  mutate(type = ifelse(type == "" | is.na(type), "unknown", type),
         role_par = TRUE)

entites <- full_join(rep_ent, par_ent, by = c("entity", "type")) %>%
  mutate(role_rep = coalesce(role_rep, FALSE),
         role_par = coalesce(role_par, FALSE),
         role = case_when(
           role_rep & !role_par ~ "Reporting (only)",
           role_rep &  role_par ~ "Reporting (also partner)",
           !role_rep & role_par ~ "Partner (only)"
         ))

# controles
cat("entites a plusieurs types :",
    entites %>% dplyr::count(entity) %>% filter(n > 1) %>% nrow(), "\n")
cat("types rencontres :", paste(sort(unique(entites$type)), collapse = ", "), "\n")

libelles_type <- c(GPH_entity        = "GPH entity",
                   locality          = "Locality",
                   group             = "Group",
                   colonial_area     = "Colonial area",
                   geographical_area = "Geographical area")

tableau <- entites %>%
  mutate(type = factor(libelles_type[type], levels = libelles_type)) %>%
  dplyr::count(type, role) %>%
  pivot_wider(names_from = role, values_from = n, values_fill = 0) %>%
  mutate(`All entities` = `Reporting (only)` + `Reporting (also partner)` +
           `Partner (only)`) %>%
  arrange(type) %>%
  select(`RIC type` = type, `Reporting (only)`, `Reporting (also partner)`,
         `Partner (only)`, `All entities`)

tableau <- bind_rows(
  tableau %>% mutate(`RIC type` = as.character(`RIC type`)),
  tableau %>% summarise(across(where(is.numeric), sum)) %>%
    mutate(`RIC type` = "Total")
)

print(as.data.frame(tableau))

write.csv(tableau, "Table entity type by role.csv", row.names = FALSE)


###les RIC entities par continent et par type
# ---- une ligne par entite-role, avec son type et son continent ----
rep_ent <- RICardocleannoworld %>%
  distinct(entity = reporting, type = reporting_type, continent = reporting_continent) %>%
  mutate(role = "Reporting (all)")

par_ent <- RICardocleannoworld %>%
  distinct(entity = partner, type = partner_type, continent = partner_continent) %>%
  mutate(type = ifelse(type == "" | is.na(type), "unknown", type),
         role = "Partner (all)")

ent2 <- bind_rows(rep_ent, par_ent)

# ---- controles ----
cat("continents rencontres :", paste(sort(unique(ent2$continent)), collapse = ", "), "\n")
cat("types rencontres      :", paste(sort(unique(ent2$type)), collapse = ", "), "\n")

# ---- le tableau ----
exclus <- c("World", "Antarctic", "Arctic", "Atlantic", "Pacific", "")

libelles_type <- c(GPH_entity        = "GPH entity",
                   locality          = "Locality",
                   group             = "Group",
                   colonial_area     = "Colonial area",
                   geographical_area = "Geographical area")

ttab_cont <- ent2 %>%
  filter(!continent %in% exclus, !is.na(continent)) %>%
  mutate(type = factor(libelles_type[type], levels = libelles_type),
         role = factor(role, levels = c("Reporting (all)", "Partner (all)"))) %>%
  filter(!is.na(type)) %>%
  dplyr::count(continent, role, type) %>%
  arrange(role, type) %>%
  pivot_wider(names_from = c(role, type), values_from = n,
              values_fill = 0, names_sep = " / ") %>%
  arrange(continent)

print(as.data.frame(ttab_cont))

write.csv(tab_cont, "Table entity type by continent and role.csv", row.names = FALSE)