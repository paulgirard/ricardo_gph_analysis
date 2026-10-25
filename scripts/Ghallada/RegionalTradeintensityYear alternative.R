rm(list = ls(all = TRUE))
gc()
library(dplyr); library(tidyr); library(ggplot2)

setwd("~/Desktop/ricardo_gph_analysis")

annees_all <- c(1833:1938, 1948:2025)

methodes <- c("blockTibi",
              "blockLouvainMaxobservedtradevalues",
              "blockLouvainTibirescale",
              "blockIntraMax",
              "blockAN")

series <- c("fob_source", "caf_target", "fob_target", "caf_source")   # colonnes de la base

mesures <- list(
  c(univers = "fob", norm = "exp", lbl = "Exports, declared by exporter"),
  c(univers = "caf", norm = "exp", lbl = "Exports, declared by importer"),
  c(univers = "caf", norm = "imp", lbl = "Imports, declared by importer"),
  c(univers = "fob", norm = "imp", lbl = "Imports, declared by exporter")
)

# ---- table Anderson-Norheim ----
BlocselonAN <- read.csv("external data/BlocselonAN.csv", stringsAsFactors = FALSE)
region_map  <- BlocselonAN[, c("GPH_code", "region_AndersonNorheim")]
region_map$GPH_code <- as.character(region_map$GPH_code)
region_map$region_AndersonNorheim <- trimws(region_map$region_AndersonNorheim)
region_map$region_AndersonNorheim[region_map$region_AndersonNorheim == ""] <- NA
region_map <- region_map[!is.na(region_map$region_AndersonNorheim), ]
region_map <- region_map[!duplicated(region_map$GPH_code), ]

# ============================================================
# 1. Base : une ligne par paire non orientee, 4 colonnes de flux
#      fob_source : a -> b, declare par a (exportateur)
#      caf_target : a -> b, declare par b (importateur)
#      fob_target : b -> a, declare par b (exportateur)
#      caf_source : b -> a, declare par a (importateur)
# ============================================================
construire_paires <- function(year) {
  f_bloc <- file.path("results/communities/gph_blocks_by_year", paste0(year, ".csv"))
  f_grav <- file.path("results/gravity", paste0("gravity_", year, ".csv"))
  if (!file.exists(f_bloc) || !file.exists(f_grav)) return(NULL)
  
  b <- read.csv(f_bloc, stringsAsFactors = FALSE)
  b$id <- as.character(b$id)
  
  b <- b %>%
    left_join(region_map, by = c("id" = "GPH_code")) %>%
    mutate(blockAN = ifelse(is.na(blockAN) | blockAN == "",
                            region_AndersonNorheim, as.character(blockAN))) %>%
    select(-region_AndersonNorheim)
  
  g <- read.csv(f_grav, stringsAsFactors = FALSE)
  g <- g[g$status == "ok" & !is.na(g$value), ]
  g$exporterId <- as.character(g$exporterId)
  g$importerId <- as.character(g$importerId)
  
  g$a <- pmin(g$exporterId, g$importerId)
  g$b <- pmax(g$exporterId, g$importerId)
  
  g$serie <- case_when(
    g$exporterId == g$a & g$CafFob == "fob" ~ "fob_source",
    g$exporterId == g$a & g$CafFob == "caf" ~ "caf_target",
    g$exporterId == g$b & g$CafFob == "fob" ~ "fob_target",
    g$exporterId == g$b & g$CafFob == "caf" ~ "caf_source"
  )
  

  flux <- g %>%
    select(a, b, serie, value) %>%
    pivot_wider(names_from = serie, values_from = value)
  
  for (s in series) if (!s %in% names(flux)) flux[[s]] <- NA_real_
  
  p <- as.data.frame(t(combn(sort(b$id), 2)), stringsAsFactors = FALSE)
  names(p) <- c("a", "b")
  p$year <- year
  
  p <- p %>%
    left_join(b %>% select(id, label, all_of(methodes)) %>%
                rename_with(~ paste0(.x, "_a"), all_of(c("label", methodes))),
              by = c("a" = "id")) %>%
    left_join(b %>% select(id, label, all_of(methodes)) %>%
                rename_with(~ paste0(.x, "_b"), all_of(c("label", methodes))),
              by = c("b" = "id")) %>%
    left_join(flux %>% select(a, b, all_of(series)), by = c("a", "b"))
  
  for (m in methodes) {
    p[[paste0("meme_", m)]] <- as.integer(p[[paste0(m, "_a")]] == p[[paste0(m, "_b")]])
  }
  
  p
}

# ============================================================
# 2. TIBI intra-bloc pondere, une partition et une serie
#    Le sens fixe l orientation de la matrice bloc-bloc.
#    Le type fixe le denominateur : Xi pour fob, Xj pour caf.
# ============================================================
calc_tibi <- function(d, methode, univers, norm) {
  col_a <- paste0(methode, "_a")
  col_b <- paste0(methode, "_b")
  
  dd <- d[!is.na(d[[col_a]]) & !is.na(d[[col_b]]), ]
  if (nrow(dd) == 0) return(c(NA_real_, 0))
  
  # univers fob : les deux sens, declares par l exportateur
  # univers caf : les deux sens, declares par l importateur
  if (univers == "fob") {
    s_ab <- "fob_source"; s_ba <- "fob_target"
  } else {
    s_ab <- "caf_target"; s_ba <- "caf_source"
  }
  
  flux <- rbind(
    data.frame(i = as.character(dd[[col_a]]), j = as.character(dd[[col_b]]),
               value = dd[[s_ab]], stringsAsFactors = FALSE),
    data.frame(i = as.character(dd[[col_b]]), j = as.character(dd[[col_a]]),
               value = dd[[s_ba]], stringsAsFactors = FALSE)
  )
  flux <- flux[!is.na(flux$value), ]
  if (nrow(flux) == 0) return(c(NA_real_, 0))
  
  Xij <- aggregate(value ~ i + j, data = flux, FUN = sum)
  names(Xij)[3] <- "Xij"
  blocs <- sort(unique(c(flux$i, flux$j)))
  
  grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
  grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
  grille$Xij[is.na(grille$Xij)] <- 0
  
  X_tot <- sum(grille$Xij)
  Xi <- tapply(grille$Xij, grille$i, sum)
  Xj <- tapply(grille$Xij, grille$j, sum)
  grille$Xi <- Xi[as.character(grille$i)]
  grille$Xj <- Xj[as.character(grille$j)]
  
  if (norm == "exp")  {
    grille$base <- grille$Xi  # on raisonne en part des exports de i
    grille$s1   <- grille$Xij / grille$Xi # part de i allant vers j
    grille$s2   <- (grille$Xj - grille$Xij) / (X_tot - grille$Xi) # meme part pour le reste du monde
  } else {
    grille$base <- grille$Xj # on raisonne en part des imports de j
    grille$s1   <- grille$Xij / grille$Xj   
    grille$s2   <- (grille$Xi - grille$Xij) / (X_tot - grille$Xj)
  }
  
  I1 <- grille$s1 / grille$s2
  I3 <- (1 - grille$s1) / (1 - grille$s2)
  ratio <- I1 / I3
  grille$TIBI <- (ratio - 1) / (ratio + 1)
  
  grille$TIBI[grille$base == 0] <- NA_real_
  grille$TIBI[grille$base > 0 & grille$Xij == grille$base] <- 1
  grille$TIBI[grille$base > 0 & grille$Xij == 0] <- -1
  
  pb <- unique(rbind(
    data.frame(id = dd$a, bloc = as.character(dd[[col_a]])),
    data.frame(id = dd$b, bloc = as.character(dd[[col_b]]))
  ))
  taille <- table(pb$bloc)
  singletons <- names(taille)[taille == 1]
  
  g2 <- grille[!(grille$i %in% singletons) & !(grille$j %in% singletons), ]
  diag_df <- g2[g2$i == g2$j & is.finite(g2$TIBI), c("i", "TIBI", "base")]
  if (nrow(diag_df) < 1) return(c(NA_real_, 0))
  
  diag_df$w <- diag_df$base / X_tot
  c(sum(diag_df$w * diag_df$TIBI), nrow(diag_df))
}

# ============================================================
# 3. Boucle
# ============================================================
dir.create("results/bloc_study/TIBI/paires", recursive = TRUE, showWarnings = FALSE)

res <- list()

for (year in annees_all) {
  p <- construire_paires(year)
  if (is.null(p)) { message(year, " : fichier absent"); next }
  
  write.csv(p, file.path("results/bloc_study/TIBI/paires", paste0("paires_", year, ".csv")),
            row.names = FALSE)
  
  for (m in methodes) for (ms in mesures) {
    v <- calc_tibi(p, m, ms[["univers"]], ms[["norm"]])
    res[[length(res) + 1]] <- data.frame(year = year, methode = m,
                                         serie = ms[["lbl"]],
                                         moyenne = v[1], n_blocs = v[2])
  }
  
  message(year, " : ", nrow(p), " paires | ",
          paste(sapply(series, function(s) paste0(s, " ", sum(!is.na(p[[s]])))),
                collapse = " | "))
}

tibi <- bind_rows(res)
write.csv(tibi, "results/bloc_study/TIBI/tibi_cinq_methodes_quatre_series.csv", row.names = FALSE)

# ============================================================
# 4. Graphe
# ============================================================
libelles <- c(blockTibi = "LouvainTibi",
              blockLouvainMaxobservedtradevalues = "Louvain_maxobservedtrade",
              blockLouvainTibirescale = "Louvain_tibirescale",
              blockIntraMax = "Intramax",
              blockAN = "Anderson-Norheim")

tibi$methode_lbl <- libelles[tibi$methode]

p_combine <- ggplot(tibi %>% complete(methode_lbl, serie, year = 1833:2025),
                    aes(year, moyenne, colour = methode_lbl)) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 0.7) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  facet_wrap(~ serie, ncol = 2) +
  coord_cartesian(ylim = c(-1, 1)) +
  scale_x_continuous(breaks = seq(1840, 2020, 20)) +
  scale_colour_manual(values = c("LouvainTibi" = "purple",
                                 "Louvain_maxobservedtrade" = "#CF142B",
                                 "Louvain_tibirescale" = "#F2A623",
                                 "Intramax" = "#0055A4",
                                 "Anderson-Norheim" = "#2E8B57")) +
  labs(x = "year", y = "Average intra-bloc TIBI (weighted)",
       title = "Average intra-bloc trade: five partitions, four flow series",
       colour = "Method") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(hjust = 0.5))

print(p_combine)

ggsave("results/bloc_study/TIBI/tibi_cinq_methodes_quatre_series.png",
       plot = p_combine, width = 12, height = 8, dpi = 150)


# ============================================================
# 5. Graphe : maximum sur les quatre series
# ============================================================
tibi_max <- tibi %>%
  filter(!is.na(moyenne)) %>%
  group_by(year, methode, methode_lbl) %>%
  slice_max(moyenne, n = 1, with_ties = FALSE) %>%
  ungroup()

write.csv(tibi_max, "results/bloc_study/TIBI/tibi_max_quatre_series.csv", row.names = FALSE)

p_max <- ggplot(tibi_max %>% complete(methode_lbl, year = 1833:2025),
                aes(year, moyenne, colour = methode_lbl)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  coord_cartesian(ylim = c(-1, 1)) +
  scale_x_continuous(breaks = seq(1835, 2025, 10)) +
  scale_colour_manual(values = c("LouvainTibi" = "purple",
                                 "Louvain_maxobservedtrade" = "#CF142B",
                                 "Louvain_tibirescale" = "#F2A623",
                                 "Intramax" = "#0055A4",
                                 "Anderson-Norheim" = "#2E8B57")) +
  labs(x = "year", y = "Average intra-bloc TIBI (maximum across the four series)",
       title = "Average intra-bloc trade: maximum of the four flow series",
       colour = "Method") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(hjust = 0.5))

print(p_max)

ggsave("results/bloc_study/TIBI/tibi_max_quatre_series.png",
       plot = p_max, width = 11, height = 6, dpi = 150)