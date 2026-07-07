rm(list = ls(all = TRUE))
gc()
library(here)

# coordonnees 
coord <- read.csv(here("GeoPolHist_entities.csv"), stringsAsFactors = FALSE)
coord <- coord[, c("GPH_code", "GPH_name", "lat", "lng")]    # <-- on garde GPH_name
coord$GPH_code <- as.character(coord$GPH_code)

# ---- rassembler TOUS les codes gph de newReporters + newPartners ----
tous_codes <- c()

for (year in 1833:1938) {
  f <- here("Tradeflowsratio", paste0("tradeFlows_", year, "_ratios.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  
  brut <- c(d$newReporters, d$newPartners)
  brut <- brut[!is.na(brut) & brut != ""]
  
  codes <- unlist(strsplit(brut, "|", fixed = TRUE))
  #codes <- trimws(codes) #enlève potentielle espace blanc
  #codes <- codes[codes != ""]
  
  tous_codes <- c(tous_codes, codes)
}

tous_codes <- unique(tous_codes)
tous_codes <- as.character(tous_codes)
cat(length(tous_codes), "codes gph uniques\n")

# ---- joindre coordonnees + nom ----
verif <- data.frame(gph = tous_codes, stringsAsFactors = FALSE)
verif <- merge(verif, coord, by.x = "gph", by.y = "GPH_code", all.x = TRUE)

# ---- les manquants (pas de coordonnees) ----
manquants <- verif[is.na(verif$lat) | is.na(verif$lng), ]
manquants <- manquants[order(manquants$GPH_name), ]

write.csv(manquants,
          here("manquants_ratios.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
