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
url: https://ricardo.medialab.sciences-po.fr
scale: 0.8
---

---

# Bilateral trade data model

![Bilateral trade data model](./images/Bilateral%20Trade%20Data%20model.svg)

---

# RICentities heterogeneity

- TODO: RICentities type and numbers
- TODO: Source anomalies (Italy, Germany ??)

---

# Reduce trade data heterogeneity with GeoPolitical data

Our goal is to reduce trading entities heterogeneity by:

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
layout: image
image: ./images/multilayer_data_model_1.png
backgroundSize: contain
---

---
layout: image
image: ./images/multilayer_data_model_2.png
backgroundSize: contain
---

---
layout: image
image: ./images/multilayer_data_model_3.png
backgroundSize: contain
---

---

# Harmonization process

1. Trade partner aggregation
1. Trade partner splits with year ratio method
1. Reporters aggregation
1. Gravity model

---

# Aggregating trade

Simple task: sum the trade figure to build the new trade edge.

But #1: do not overwrite an existing reported trade flow

But #2: do not create internal trade flows, discard trade flows between part of and its parent

---

# Splitting trade

Difficult task: how to decide the ratios to split one trade value into many?

We look into adjacent years (+/- 10-years window) network for split trade flows with the same set of partners for the same reporter.

If we find one, we calculate split ratios for that year and reapply those on the original trade value.

But #1: partial ratios
But #2: special case of areas

---

# Reporters aggregations

---

# Reporters split

We don't do that. Yet.

---

# Gravity model

- theoritical régression (anderson and van wincoop 2003)
- effets fixes importateurs exportateur
- distance à vol d'oiseau
- lien géopolitique

- geolocalisation variable
- infer missing ratios to use on the source value

---

# An example from 1850

Figure 2

---

# evaluation

Figure 3

---

# What for?

- quantification in the long run
- trade block analysis
- effect of colonization
