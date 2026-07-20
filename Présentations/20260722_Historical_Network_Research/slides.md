---
favicon: "/favicon.ico"
pwa: build
---

# Harmonizing Historical Trade Using Geopolitical Data

## A Multilayer Network Approach to Bilateral Flows

## 1830–1938

<small>

_Paul Girard_ - OuestWare - France  
Béatrice Dedinger - Centre d’histoire de Sciences Po (CHSP) - France  
Guillaume Daudin - Laboratoire d’Economie de Dauphine (LEDa) - France  
Youssef Ghallada - Economic History Department LSE - London

</small>

---

# RICardo

## International bilateral trade c. 1830-1938

Trade statistics sources:

- **Primary**: customs statistics published by national authorities
- **Secondary**: compilations of primary sources published by national or international authorities
- **Estimations**: trade estimated by scholars

RICardo also provides an exchange rate to Pound Sterling dataset to homogenize values.

https://ricardo.medialab.sciences-po.fr

<small>
Girard, Paul, et al. « RICardo Project : Exploring XIX Century International Trade ». <i>Digital Humanities 2016: Conference Abstracts</i> [agiellonian University & Pedagogical University, Kraków, Poland], 2016, p. 208‑10, http://dh2016.adho.org/abstracts/177.
</small>

---
layout: iframe
url: https://ricardo.medialab.sciences-po.fr/
scale: 0.8
---

---

# Bilateral trade data model

![Bilateral trade data model](/images/Bilateral%20Trade%20Data%20model.svg)

---
layout: statement
---

# Sources are not the data we expect them to be!

Not yet...

---
layout: image
image: /images/sweden_1840_table_12.png
backgroundSize: contain
---

---
layout: image
image: /images/USA_export_1831_1832.png
backgroundSize: contain
---

---

# Trade partners heterogeneity

<small>

| Partners’ type    |  % Total value   | % flow number | examples                                                         |
| ----------------- | :--------------: | :-----------: | :--------------------------------------------------------------- |
| GPH_entity        |      87.18       |     81.24     | _United Kingdom, Sierra Leone, Belgium..._                       |
| group             |       6.45       |     5.14      | _Fiume & Republic of St. Mark & Trieste, Belgium & Luxemburg..._ |
| locality          |       4.57       |     6.47      | _Conakry, Sumatra, British Colonies (other)..._                  |
| colonial_area     |       1.39       |     4.97      | _French Colonies, Portuguese Colonies, British West Indies..._   |
| geographical_area |       0.41       |     2.18      | _America, Arabia, Borneo, Africa..._                             |
| Total             | £480,756,915,469 |    468448     |                                                                  |

</small>

---

# Trade reporters heterogeneity

<small>

| Reporters' type   |  % Total value   | % flow number | examples                                                                   |
| ----------------- | :--------------: | :-----------: | :------------------------------------------------------------------------- |
| GPH_entity        |      96.98       |     95.59     | _Gambia, Singapore, Penang, Malacca..._                                    |
| group             |       1.42       |     1.79      | _Fiume & Republic of St. Mark & Trieste, Belgium & Luxemburg..._           |
| geographical_area |       0.94       |     0.06      | _Levant_                                                                   |
| locality          |       0.64       |     2.51      | _Saint-Louis (Senegal), Kaliningrad (Königsberg), Bahia, Rio de Janeiro.._ |
| colonial_area     |       0.01       |     0.06      | _British Northern America..._                                              |
| Total             | £480,756,915,469 |    468448     |                                                                            |

</small>

---

# Let's reduce trade data heterogeneity with GeoPolitical data

Our goal is to reduce trading entities heterogeneity by:

- identifying non-autonomous or informal entities
- aggregating non-autonomous entities to their sovereign
- splitting trade of groups, geographical and colonial areas

---

# GeoPolHist

Identifies the political status of every geopolitical entity that has existed since 1816  
Based on the lists of states and dependencies developed by [_Correlates of War project_](https://correlatesofwar.org/)

https://medialab.github.io/GeoPolHist/

<small>

Dedinger, Béatrice, and Paul Girard, ‘How Many Countries in the World? The Geopolitical Entities of the World and Their Political Status from 1816 to the Present’, _Historical Methods: A Journal of Quantitative and Interdisciplinary History_, 0.0 (2021), 1–20 <https://doi.org/10.1080/01615440.2021.1939826>

</small>

---
layout: iframe
url: https://medialab.github.io/GeoPolHist/#/GeoPolHist/country/325
scale: 0.8
---

---
layout: two-cols-header
---

## Autonomous definition

Sufficient political autonomy to handle trade.  
In short, every political status but `part of`.

::left::

Sovereign  
Associated state of  
Sovereign (limited)  
Sovereign (unrecognized)  
Colony of  
Dependency of  
Possession of  
Protectorate of

::right::

Leased to  
Mandated to  
Occupied by  
Vassal of  
Claimed by  
Neutral or demilitarized zone of

---

# Multilayer networks bridging trade and politics

Build yearly network which combine trade flow edges with geopolitical resolutions edges.

By using the GeoPolHist dataset:

- Identify non-autonomous trading entities
- Add Geopolitical resolutions edges (aggregate into, split into)

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/20260722_Historical_Network_Research/1850_GPH_resolution_gephi_lite.json
scale: 0.5
---

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/20260722_Historical_Network_Research/1850_trade_gephi_lite.json
scale: 0.5
---

---
layout: image
image: /images/multilayer_data_model_1.png
backgroundSize: contain
---

---
layout: image
image: /images/multilayer_data_model_2.png
backgroundSize: contain
---

---
layout: image
image: /images/multilayer_data_model_3.png
backgroundSize: contain
---

---

# Harmonization process

1. Trade partner aggregation
1. Trade partner splits with year ratio method
1. Reporters aggregation
1. Gravity model

---

# Aggregating trade partners

Simple task: sum the trade figure to build the new trade edge.

But #1: do not overwrite an existing reported trade flow

But #2: do not create internal trade flows, discard trade flows between part of and its parent

---

# Splitting trade partners

Difficult task: how to decide the ratios to split one trade value into many?

We look into **adjacent years** (+/- 10-years window) networks  
for _dissociated_ trade flows with the **same set of partners** for the same reporter.

If we find one compatible year, we calculate **split ratios** for that year and reapply those **on the original trade value**.

This process support partial split.  
If a set of partners from a group is found as one + another group, the one found will be split, the rest will stay as a group.

---

# Special cases: Areas

Areas (geographical or colonial) are implicit groups.

The composition of the group is to be defined.

We use geographical or colonial sets which we adapt to the source context, i.e. we remove all theoretical members of the area which are already cited by the reporter.

---

# Aggregating trade reporters

Because of the importance of reporter context, we need to make sure reporters are aggregated before we can split their partners.

---

# Splitting trade reporters

We don't do that, yet.

---

# Gravity model

We try to impute flows we couldn't split with the adjacent years method by using a gravity model (Anderson et Van Wincoop 2003).

We use fixed effects on importer and exporters, geographical distance, geopolitical link existence (GeoPolHist) variables.

The inferred values are used to compute a ratio which is then applied on the original values.

<small>
Anderson, James E., et Eric Van Wincoop. « Gravity with Gravitas: A Solution to the Border Puzzle ». _American Economic Review_, vol. 93, no 1, février 2003, p. 170‑92. DOI.org (Crossref), [https://doi.org/10.1257/000282803321455214](https://doi.org/10.1257/000282803321455214).
</small>

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/20260722_Historical_Network_Research/1850_examples_gephi_lite.json
scale: 0.5
---

---

# How much trade do we normalize?

<ShareTotalReportedValue />

---

# Which method had the most impact?

<ShareGeneratedTradeValue />

---

# Trade Network density gain!

<TradeNetworkDensity />

---

# Great! But what was that for?

- Trade quantification in the long run
- Trade block analysis
- Study the effect of colonization
