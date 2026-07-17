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

# Reduce trade statistics heterogeneity with GeoPolotical data

Our goal is to reduce trading entities heterogeneity by:

- aggregating non-autonomous entities to their sovereign
- splitting trade of groups, geographical and colonial areas

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

- one by year
- data model schema

---

# Harmonization process

1. Geopolitical resolutions
1. Aggregating trade
1. Splitting trade
1. Reporters special cases
1. At last rely on Gravity model

---

# Geopolitical resolutions

---

# Aggregating trade

---

# Splitting trade

- years ratios method

---

# Reporters aggregations

---

# Reporters split

We don't do that. Yet.

---

# Gravity model

- theoritical régression (anderson and van wincoop  2003)
- effets fixes importateurs exportateur
- distance à vol d'oiseau
- lien géopolitique

- geolocation variable
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

