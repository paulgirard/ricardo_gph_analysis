rm(list = ls(all = TRUE))
gc()
library(dplyr); library(tidyr); library(ggplot2); library(maps); library(magick)

setwd("~/Desktop/ricardo_gph_analysis")

annees_all <- c(1833:1938, 1948:2025)
series     <- c("fob_source", "caf_target", "fob_target", "caf_source")

methodes <- c(blockTibi = "LouvainTibi",
              blockLouvainMaxobservedtradevalues = "Louvain_maxobservedtrade",
              blockLouvainTibirescale = "Louvain_tibirescale",
              blockIntraMax = "Intramax",
              blockAN = "AndersonNorheim")

monde <- map_data("world")
coord <- read.csv("external data/GeoPolHist_entities.csv", stringsAsFactors = FALSE)
coord <- coord[, c("GPH_code", "lat", "lng")]
coord$GPH_code <- as.character(coord$GPH_code)

# ============================================================
# 1a. Volume declare par entite : ne depend pas de la partition
# ============================================================
volume_annee <- function(p) {
  bind_rows(
    p %>% transmute(gph = a, v = fob_source),   # a exporte vers b, a declare
    p %>% transmute(gph = a, v = caf_source),   # a importe de b,   a declare
    p %>% transmute(gph = b, v = fob_target),   # b exporte vers a, b declare
    p %>% transmute(gph = b, v = caf_target)    # b importe de a,   b declare
  ) %>%
    filter(!is.na(v)) %>%
    mutate(gph = as.character(gph)) %>%
    group_by(gph) %>% summarise(total = sum(v), .groups = "drop")
}

# ============================================================
# 1b. Entite -> bloc, pour une partition donnee
# ============================================================
pays_bloc_annee <- function(p, methode, vol) {
  ca <- paste0(methode, "_a"); cb <- paste0(methode, "_b")
  
  bind_rows(
    p %>% select(gph = a, pays = label_a, bloc = all_of(ca)),
    p %>% select(gph = b, pays = label_b, bloc = all_of(cb))
  ) %>%
    filter(!is.na(bloc)) %>%
    distinct(gph, .keep_all = TRUE) %>%
    mutate(gph = as.character(gph), bloc = as.character(bloc)) %>%
    left_join(vol, by = "gph") %>%
    mutate(total = coalesce(total, 0))
}

# ============================================================
# 2. Palette commune
# ============================================================
tous_pays <- c()
for (year in annees_all) {
  f <- file.path("results/bloc_study/TIBI/paires", paste0("paires_", year, ".csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  tous_pays <- c(tous_pays, d$label_a, d$label_b)
}
tous_pays <- sort(unique(tous_pays))

style <- tribble(
  ~pays, ~couleur, ~forme,
  # --- rang 1 a 20 : cercle plein ---
  "United States of America",                 "#0A3161",        8,
  "United Kingdom",                           "#CC0000",        3,
  "France",                                   "#0055A4",        16,
  "Germany (Zollverein)",                     "#000000",        16,
  "Russia (USSR)",                            "deepskyblue",    16,
  "Japan",                                    "#F032E6",        16,
  "Netherlands",                              "#FF8C00",        16,
  "People's Republic of China (China)",       "#BFEF45",        16,
  "Argentina (La Plata)",                     "#6CACE4",        16,
  "Italy",                                    "#008C45",        16,
  "Brazil",                                   "gold",           16,
  "Iran (Persia)",                            "#469990",        16,
  "Sweden",                                   "#800000",        16,
  "Saudi Arabia (Emirate of Nejd) (Emirate of Diriyah)", "#AAFFC3", 16,
  "Canada (Province of Canada)",              "#A38E6F",        16,
  "Egypt Arab Republic (Egypt)",              "#9A6324",        16,
  "South Africa",                             "#DCBEFF",        16,
  "Portugal",                                 "#717910",        16,
  "Hamburg",                                  "#000000",         15,
  
  # --- rang 21 a 40 : triangle ---
  "Chile",                                    "purple",         17,
  "Spain",                                    "#f6b511",        17,
  "Algeria (Regency of Algiers)",             "#E6194B",        17,
  "Hong Kong",                                "#3CB44B",        17,
  "Belgium",                                  "#FFFF00",        17,
  "Austria-Hungary (Austrian Empire)",        "coral",          17,
  "Nigeria",                                  "#4363D8",        17,
  "Australia",                                "#F58231",        17,
  "Mexico",                                   "#006847",        17,
  "Cape Colony (Cape of Good Hope)",          "#42D4F4",        17,
  "Poland",                                   "#F032E6",        17,
  "Switzerland",                              "#BFEF45",        17,
  "Aden",                                     "#469990",        17,
  "Finland",                                  "#003580",         3,
  "New South Wales",                          "#800000",        17,
  "Singapore",                                "#AAFFC3",        17,
  "Venezuela",                                "#000075",        17,
  "South Korea (Republic of South Korea)",    "#00CED1",        17,
  "Turkey (Ottoman Empire)",                  "#A91101",        17,
  "Victoria",                                 "#DCBEFF",        17,
  
  # --- rang 41 a 60 : carre ---
  "India",                                    "#CD5C5C",        15,
  "Cuba",                                     "#CF142B",        16,
  "Iraq (Mesopotamia)",                       "#3CB44B",        15,
  "Romania",                                  "#FFE119",        15,
  "Israel",                                   "#4363D8",        15,
  "Greece",                                   "#F58231",        15,
  "Peru",                                     "#911EB4",        15,
  "United Arab Emirates (Trucial Oman)",      "#42D4F4",        15,
  "Zimbabwe (Rhodesia) (Southern Rhodesia)",  "#F032E6",        15,
  "Czechoslovakia",                           "#BFEF45",        15,
  "Djibouti (Afar and Issas) (French Somaliland)", "#FABED4",   15,
  "Indonesia (Dutch East Indies)",            "#469990",        15,
  "Libya",                                    "#DCBEFF",        15,
  "Denmark",                                  "#9A6324",        15,
  "Kingdom of Sardinia",                      "#800000",        15,
  "Syria",                                    "#AAFFC3",        15,
  "Uruguay",                                  "#000075",        15,
  "Austria",                                  "#A9A9A9",        15,
  "Straits Settlements",                      "#00CED1",        15,
  "Ghana (Gold Coast)",                       "#FF8C69",        15,
  "Jamaica",                                  "#4B0082",        15,
  
  # --- rang 61 a 80 : losange ---
  "Prussia",                                  "#E6194B",        18,
  "Windward Is.",                             "#3CB44B",        18,
  "Guyana (British Guiana)",                  "#FFE119",        18,
  "Lagos",                                    "#4363D8",        18,
  "Lebanon",                                  "#F58231",        18,
  "Palestine",                                "#911EB4",        18,
  "Trinidad",                                 "#42D4F4",        18,
  "Tuscany",                                  "#F032E6",        18,
  "Angola",                                   "#BFEF45",        18,
  "Belize (British Honduras)",                "#FABED4",        18,
  "Bremen",                                   "#469990",        18,
  "Democratic Republic of the Congo (Zaire) (Kinshasa) (Belgian Congo) (Congo Free State)", "#DCBEFF", 18,
  "Ethiopia (Abyssinia)",                     "#9A6324",        18,
  "Jordan (Transjordan)",                     "#800000",        18,
  "Moldavia",                                 "#AAFFC3",        18,
  "Sierra Leone",                             "#000075",        18,
  "Tanzania (Tanganyika)",                    "#A9A9A9",        18,
  "Thailand (Siam)",                          "#00CED1",        18,
  "Vietnam",                                  "#FF8C69",        18,
  "Yugoslavia (Kingdom of Serbs, Croats and Slovenes)", "#4B0082", 18,
  
  # --- rang 81 a 96 : etoile ---
  "Bangladesh",                               "#E6194B",         8,
  "Buenos Aires",                             "#FF8C69",         8,
  "Bulgaria",                                 "#FFE119",         8,
  "French Indochina",                         "#4363D8",         8,
  "French West Africa",                       "#F58231",         8,
  "Guadeloupe",                               "#911EB4",         8,
  "Guatemala",                                "#42D4F4",         8,
  "Kuwait",                                   "#F032E6",         8,
  "Newfoundland and Labrador (Newfoundland)", "#BFEF45",         8,
  "Puerto Rico",                              "#FABED4",         8,
  "Qatar",                                    "#469990",         8,
  "Southern Nigeria (Niger Coast Protectorate)", "#DCBEFF",      8,
  "Sudan (Anglo-Egyptian Sudan) (Mahdist State)", "#9A6324",     8,
  "Transvaal (South African Republic)",       "#800000",         8,
  "Yemen People's Republic (South Yemen)",    "#AAFFC3",         8,
  "Zanzibar",                                 "#FF1493",         8,
  
  # --- cas particuliers ---
  "Colombia (New Granada) (Gran Colombia)",   "darkslategray1",  16,
  "single-country bloc",                      "darkgray",         16
)

# filet de securite : toute etiquette non prevue sort en gris clair
autres <- setdiff(tous_pays, style$pays)
if (length(autres) > 0) {
  message("etiquettes sans style : ", paste(autres, collapse = ", "))
  style <- bind_rows(style, data.frame(pays = autres, couleur = "grey70", forme = 1))
}


couleur_pays <- setNames(style$couleur, style$pays)
forme_pays   <- setNames(style$forme,   style$pays)

# ---- couleurs fixes pour les regions Anderson-Norheim ----
BlocselonAN <- read.csv("external data/BlocselonAN.csv", stringsAsFactors = FALSE)
regions_an  <- sort(unique(trimws(BlocselonAN$region_AndersonNorheim)))
regions_an  <- regions_an[regions_an != "" & !is.na(regions_an)]
print(regions_an)

style_an <- data.frame(
  pays    = regions_an,
  couleur = c("#0055A4", "#CF142B", "#008C45", "#F58231", "#911EB4",
              "#42D4F4", "#9A6324", "#000000", "#BFEF45", "#F032E6",
              "#469990", "#800000")[seq_along(regions_an)],
  forme   = 16,
  stringsAsFactors = FALSE
)

style        <- bind_rows(style, style_an)
couleur_pays <- setNames(style$couleur, style$pays)
forme_pays   <- setNames(style$forme,   style$pays)

# ============================================================
# ============================================================
# 2bis. Qui donne son nom a un bloc, et combien de fois
# ============================================================
# etiquettes <- list()
# 
# for (year in annees_all) {
#   f <- file.path("results/bloc_study/TIBI/paires", paste0("paires_", year, ".csv"))
#   if (!file.exists(f) || file.info(f)$size == 0) next
#   p <- read.csv(f, stringsAsFactors = FALSE)
#   vol <- volume_annee(p)
#   
#   for (m in names(methodes)) {
#     pb <- pays_bloc_annee(p, m, vol)
#     if (nrow(pb) == 0) next
#     
#     etiquettes[[length(etiquettes) + 1]] <- pb %>%
#       group_by(bloc) %>%
#       filter(n() > 1) %>%                      # on ignore les blocs d un seul pays
#       slice_max(total, n = 1, with_ties = FALSE) %>%
#       ungroup() %>%
#       transmute(year = year, methode = methodes[[m]], pays, gph, total)
#   }
# }
# 
# eti <- bind_rows(etiquettes)
# 
# # ---- liste complete, triee par frequence ----
# recap <- eti %>%
#   dplyr::count(pays, gph, sort = TRUE) %>%
#   mutate(deja_coloree = pays %in% style$pays,
#          pct = round(100 * n / sum(n), 1))
# 
# print(as.data.frame(recap), max = 1000)
# 
# # ---- celles qu il reste a colorer ----
# recap %>% filter(!deja_coloree) %>% head(40) %>% as.data.frame()
# 
# # ---- par periode, pour voir l apres-1948 ----
# eti %>%
#   mutate(periode = ifelse(year < 1940, "1833-1938", "1948-2025")) %>%
#   dplyr::count(periode, pays, sort = TRUE) %>%
#   group_by(periode) %>% slice_head(n = 25) %>% as.data.frame()
# 
# write.csv(recap, "results/bloc_study/TIBI/etiquettes_blocs.csv", row.names = FALSE)
# ============================================================
# 3. Cartes : une lecture par annee, cinq methodes dessus
# ============================================================
for (m in names(methodes)) {
  dir.create(file.path("cartes", methodes[[m]]), recursive = TRUE, showWarnings = FALSE)
}

for (year in annees_all) {
  f <- file.path("results/bloc_study/TIBI/paires", paste0("paires_", year, ".csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  p <- read.csv(f, stringsAsFactors = FALSE)
  
  vol <- volume_annee(p)
  
  for (m in names(methodes)) {
    dossier <- file.path("cartes", methodes[[m]])
    
    pb <- pays_bloc_annee(p, m, vol)
    if (nrow(pb) == 0) next
    
    if (m == "blockAN") {
      pb$gros_pays <- pb$bloc
    } else {
      pb <- pb %>%
        group_by(bloc) %>%
        mutate(gros_pays = pays[which.max(total)],
               singleton = n() == 1) %>%
        ungroup() %>%
        mutate(gros_pays = ifelse(singleton, "single-country bloc", gros_pays))
    }
    
    carte <- pb %>%
      left_join(coord, by = c("gph" = "GPH_code")) %>%
      filter(!is.na(lat), !is.na(lng))
    if (nrow(carte) == 0) next
    
    carte$gros_pays <- factor(carte$gros_pays)
    niv <- levels(carte$gros_pays)
    couleurs <- couleur_pays[niv]; names(couleurs) <- niv
    formes   <- forme_pays[niv];   names(formes)   <- niv
    
    g <- ggplot() +
      geom_polygon(data = monde, aes(long, lat, group = group), fill = "grey93", colour = NA) +
      geom_point(data = carte, aes(lng, lat, colour = gros_pays, shape = gros_pays), size = 2.5) +
      geom_text(data = carte, aes(lng, lat, label = pays), size = 1.6, vjust = -0.8,
                show.legend = FALSE) +
      scale_colour_manual(values = couleurs,
                          name = if (m == "blockAN") "Region" else "Bloc (largest member)") +
      scale_shape_manual(values  = formes,
                         name = if (m == "blockAN") "Region" else "Bloc (largest member)") +
      coord_quickmap() +
      theme_void() +
      theme(legend.position = "right",
            legend.text  = element_text(size = 6),
            legend.title = element_text(size = 7)) +
      labs(title = paste0(methodes[[m]], " — ", year))
    
    ggsave(file.path(dossier, paste0("carte_", year, ".png")),
           plot = g, width = 13, height = 7, dpi = 150)
  }
  
  message(year, " : cartes generees")
}

# ============================================================
# 4. Diaporama et gif par methode
# ============================================================
for (m in names(methodes)) {
  dossier <- file.path("cartes", methodes[[m]])
  an <- annees_all[file.exists(file.path(dossier, paste0("carte_", annees_all, ".png")))]
  if (length(an) == 0) next
  
  html <- paste0(
    '<html><body style="text-align:center;font-family:sans-serif">',
    '<input type="range" min="0" max="', length(an) - 1,
    '" value="0" id="s" style="width:80%"> <span id="y">', an[1], '</span><br>',
    '<img id="img" src="carte_', an[1], '.png" style="max-width:95%">',
    '<script>var A=[', paste(an, collapse = ','), '];',
    'var s=document.getElementById("s");s.oninput=function(){',
    'document.getElementById("y").innerText=A[s.value];',
    'document.getElementById("img").src="carte_"+A[s.value]+".png";}</script>',
    '</body></html>')
  writeLines(html, file.path(dossier, "diaporama.html"))
  
  img  <- image_read(file.path(dossier, paste0("carte_", an, ".png")))
  anim <- image_animate(image_join(img), fps = 2)
  image_write(anim, file.path(dossier, "animation.gif"))
  
  message(methodes[[m]], " : ", length(an), " cartes")
}