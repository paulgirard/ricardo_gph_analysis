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
RICardocleannoworld<-RICardocleannoworld[RICardocleannoworld$partner!="World sum partners",]



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
  scale_y_continuous(breaks = seq(0, 20000, by = 1000), expand = c(0, 0)) +
  scale_fill_manual(values = c( "Exports" = "#316395", 
                               "Imports" = "#b82e2e")) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )
color<-c( "#316395", "#109618" , "#bcbd22" , "#efcccc", "#b82e2e", "#c33333", "#d97f7f", "#663333")

ggsave("Fig 1 Total nb of bilateral flows.png", 
       width = 12, 
       height = 6, 
       dpi = 300)


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

ggsave("Fig 2 nb of distinct entities per year.png", 
       width = 12, 
       height = 6, 
       dpi = 300)

# Count unique reporting countries by year and reporting_type
plot_data3 <- RICardocleannoworld %>%
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
  scale_y_continuous(breaks = seq(0, 150, by = 10), expand = c(0, 0)) +
  scale_fill_manual(values = c("GPH_entity" = "#316395",    
                               "locality" = "#b82e2e",    # Bleu clair #b82e2e
                               "group" = "#c1d0df",    # Violet
                               "geographical_area" = "#bcbd22"))+   # Vert"#109618
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  )
ggsave("Fig 4a Reporting type over years final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)

# Count unique partner countries by year and rpartner_type
plot_data4 <- RICardocleannoworld %>%
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
  scale_y_continuous(breaks = seq(0, 600, by = 50),expand = c(0, 0)) +
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
ggsave("Fig 4b Partner type over years final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)

##Totals over time comparison (Worldasreported,World estimated,World Federico Tena,World_best_guess,World sum partners, World undefined)

Worldtrade<-RICardoclean[RICardoclean$partner=="World as reported"|RICardoclean$partner=="World_best_guess"|RICardoclean$partner=="World Federico Tena"|RICardoclean$partner=="World sum partners",]
Reporterunique2<-Worldtrade[!duplicated(Worldtrade$reporting),] #ok same nb entities of reporting as usual


Worldtrade$pounds<-(Worldtrade$flow*Worldtrade$unit)/Worldtrade$rate


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

# Transformer les valeurs en log
plot_data6 <- plot_data5 %>%
  mutate(total_log = log(total))

# Créer le graphique avec les valeurs transformées
ggplot(plot_data6, aes(x = year, y = total_log, color = partner, group = partner)) +
  geom_line(size = 0.5) +
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
continents_list <- unique(plot_data7$reporting_continent)
color_values <- c("#d48282", "#83a1bf", "#9D4EDD", "#b7e0ba", "gold")
names(color_values) <- continents_list[1:min(length(continents_list), 8)]

# Forcer NA à être gris
color_values["NA"] <- "gray80"


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
  scale_fill_manual(values = color_values) +
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


# Créer une séquence complète d'années
all_years <- seq(min(RICardocleannoworld$year), max(RICardocleannoworld$year), by = 1)

# Calculer le nombre d'entités distinctes par continent et année
plot_data8 <- RICardocleannoworld %>%
  group_by(year, partner_continent) %>%
  summarise(nb_entities =n_distinct(partner[!partner %in% reporting]), .groups = "drop") %>%
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

# Créer une palette automatique
continents_list <- unique(plot_data8$partner_continent)
color_values <- c("#d48282", "#83a1bf", "#9D4EDD", "#b7e0ba", "gold")
names(color_values) <- continents_list[1:min(length(continents_list), 8)]

# Forcer NA à être gris
color_values["NA"] <- "gray80"
  

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
  scale_fill_manual(values = color_values) +
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

# Créer une palette automatique
type_list <- unique(plot_data9$type)
color_values <- c("#d48282", "#83a1bf", "#9D4EDD", "gold",  "gray")
names(color_values) <- type_list[1:min(length(type_list), 8)]

# Forcer NA à être gris
color_values["NA"] <- "gray80"
  
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
  scale_fill_manual(values = color_values) +
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
  scale_fill_manual(values = color_values) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    legend.position = "bottom"
  )

ggsave("Fig 9bis Number of RIC reportings (by source type).png",
       width = 12, height = 6, dpi = 300)


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



#NB de partners by reporting over years
plot_data_avg1 <- RICardocleannoworld %>%
  group_by(year, reporting) %>%
  summarise(nb_partners = n_distinct(partner), .groups = "drop") %>%
  group_by(year) %>%
  summarise(
    mean_partners = mean(nb_partners),
    sd_partners = sd(nb_partners),
    n = n(),
    se = sd_partners / sqrt(n),
    ci_lower = mean_partners - 1.96 * se,  # IC à 95%
    ci_upper = mean_partners + 1.96 * se,
    .groups = "drop"
  )

# Créer le graphique
ggplot(plot_data_avg1, aes(x = year, y = mean_partners)) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), 
              fill = "#9D4EDD", alpha = 0.3) +
  geom_line(color = "#9D4EDD", size = 0.5) +
  geom_point(color = "#9D4EDD", size = 0.8) +
  labs(
    title = "",
    x = "Year",
    y = "Average number of partners per reporting entity"
  ) +
  scale_x_continuous(breaks = seq(1830, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, max(plot_data_avg1$ci_upper, na.rm = TRUE) + 10, by = 10))  +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  )

ggsave("Avg nb of partners per reporting final.png", 
       width = 12, 
       height = 6, 
       dpi = 300)


# Calculer le nombre moyen de partners par reporting et année SANS distinction exp/imp
plot_data_total <- RICardocleannoworld %>%
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

# Calculer le nombre moyen de partners par reporting, année AVEC distinction exp/imp
plot_data_by_flow <- RICardocleannoworld %>%
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

# Combiner les deux datasets
plot_data_avg <- bind_rows(plot_data_total, plot_data_by_flow)

# Créer le graphique avec trois lignes
ggplot(plot_data_avg, aes(x = year, y = mean_partners, color = flow_type, fill = flow_type)) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, color = NA) +
  geom_line(size = 0.5) +
  geom_point(size = 0.8) +
  labs(
    title = "",
    x = "Year",
    y = "Average number of partners per reporting entity",
    color = "Flow type",
    fill = "Flow type"
  ) +
  scale_x_continuous(breaks = seq(1785, 1938, by = 5), expand = c(0, 0)) +
  scale_y_continuous(breaks = seq(0, max(plot_data_avg$ci_upper, na.rm = TRUE) + 10, by = 10)) +
  scale_color_manual(
    values = c("Exp" = "#d48282", "Imp" = "#83a1bf", "Total" = "#9D4EDD"),
    labels = c("Exp" = "Export", "Imp" = "Import", "Total" = "Total (Exp + Imp)")
  ) +
  scale_fill_manual(
    values = c("Exp" = "#d48282", "Imp" = "#83a1bf", "Total" = "#9D4EDD"),
    labels = c("Exp" = "Export", "Imp" = "Import", "Total" = "Total (Exp + Imp)")
  ) +
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold")
  )

ggsave("Average partners per reporting by flow type with total and CI.png", 
       width = 12, 
       height = 6, 
       dpi = 300)

# Serie over time by continent
plot_data11 <- RICardocleannoworld %>%
  group_by(year, reporting_continent) %>%
  summarise(nb_flows = n(), .groups = "drop") %>%  # n() compte les lignes = flux
  complete(year = all_years, reporting_continent, fill = list(nb_flows = 0))

plot_data11<-plot_data11[plot_data11$reporting_continent!="World",]
ggplot(plot_data11, aes(x = year, y = nb_flows, color = reporting_continent, group = reporting_continent)) +
  geom_line(size = 0.5) +
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