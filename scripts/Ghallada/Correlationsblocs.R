rm(list = ls(all = TRUE))
gc()
library(dplyr)
options(max.print=10000000)
library(tidyverse)
library(readxl)
library(ggplot2)
library(writexl)
library(igraph)
library(here)


library(dplyr); library(tidyr); library(ggplot2)
setwd("~/Desktop/ricardo_gph_analysis")

annees_all <- c(1833:1938, 1948:2025)
methodes <- c("blockTibi",
              "blockLouvainMaxobservedtradevalues",
              "blockLouvainTibirescale",
              "blockIntraMax",
              "blockAN")

paires_meth <- combn(methodes, 2, simplify = FALSE)

res <- list()

for (year in annees_all) {
  f <- file.path("results/bloc_study/TIBI/paires", paste0("paires_", year, ".csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  p <- read.csv(f, stringsAsFactors = FALSE)
  
  for (pm in paires_meth) {
    c1 <- paste0("meme_", pm[1]); c2 <- paste0("meme_", pm[2])
    d <- p[!is.na(p[[c1]]) & !is.na(p[[c2]]), ]
    if (sd(d[[c1]]) == 0 || sd(d[[c2]]) == 0) next
    
    ct <- cor.test(d[[c1]], d[[c2]])
    res[[length(res) + 1]] <- data.frame(
      year = year, m1 = pm[1], m2 = pm[2],
      cor = ct$estimate, ic_bas = ct$conf.int[1], ic_haut = ct$conf.int[2],
      n = nrow(d))
  }
  message(year, " : ", nrow(p), " paires")
}

cor_blocs <- bind_rows(res)
dir.create("results/bloc_study/correlations", recursive = TRUE, showWarnings = FALSE)
write.csv(cor_blocs, "results/bloc_study/correlations/cor_entre_partitions.csv",
          row.names = FALSE)

# ---- graphe ----
libelles <- c(blockTibi = "LouvainTibi",
              blockLouvainMaxobservedtradevalues = "Louvain_maxobs",
              blockLouvainTibirescale = "Louvain_tibiresc",
              blockIntraMax = "Intramax",
              blockAN = "AndersonNorheim")

cor_blocs <- cor_blocs %>%
  mutate(couple = paste(libelles[m1], libelles[m2], sep = " / ")) %>%
  complete(couple, year = 1833:2025)

p_cor <- ggplot(cor_blocs, aes(year, cor)) +
  geom_ribbon(aes(ymin = ic_bas, ymax = ic_haut), fill = "grey80", alpha = 0.5) +
  geom_line(linewidth = 0.5) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  facet_wrap(~ couple, ncol = 2) +
  coord_cartesian(ylim = c(-0.2, 1)) +
  scale_x_continuous(breaks = seq(1840, 2020, 40)) +
  labs(x = "year", y = "Correlation between block indicators",
       title = "Correlation between partition methods") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 7),
        plot.title = element_text(hjust = 0.5))

print(p_cor)

ggsave("results/bloc_study/correlations/cor_entre_partitions.png",
       plot = p_cor, width = 11, height = 10, dpi = 150)