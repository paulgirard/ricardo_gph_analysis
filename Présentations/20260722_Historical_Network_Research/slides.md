---
favicon: "/favicon.ico"
pwa: false
fonts:
  # basically the text
  sans: Open Sans
  # use with `font-serif` css class from UnoCSS
  serif: Robot Slab
  # for code blocks, inline code, etc.
  mono: Fira Code
---

# Harmonizing Historical Trade Using Geopolitical Data

## A Multilayer Network Approach to Bilateral Flows

## 1830–1938

<small>

_Paul Girard_ - OuestWare - France  
Béatrice Dedinger - Centre d’histoire de Sciences Po (CHSP) - France  
Guillaume Daudin - Laboratoire d’Economie de Dauphine (LEDa) - France  
Youssef Ghallada - Economic History Department LSE - United Kingdom

<div style="display:flex; gap:1em; align-items: center"><img src="/images/hnr2026_logo.png" style="height:80px"/> <div>Historical Network Research 2026 <br/>Torino, Italia</div></div>

</small>

---

# RICardo

## International bilateral trade c. 1830-1938

Trade statistics sources:

- **Primary**: customs statistics published by national authorities
- **Primary yearbook**: statistical yearbooks
- **Secondary**: compilations of primary sources published by national or international authorities

Includes exchange rates to Pound Sterling to homogenize values.

https://ricardo.medialab.sciences-po.fr

<small>

Girard, Paul, et al. « RICardo Project : Exploring XIX Century International Trade ». <i>Digital Humanities 2016: Conference Abstracts</i> [Agiellonian University & Pedagogical University, Kraków, Poland], 2016, p. 208‑10, http://dh2016.adho.org/abstracts/177.

</small>

---
layout: iframe
url: https://ricardo.medialab.sciences-po.fr/
scale: 0.8
---

---
layout: center
---

# Bilateral trade data model

![Bilateral trade data model](/images/Bilateral%20Trade%20Data%20model.svg)

<!--
Note that we have trade between reporters but also between reporter and partners, i.e. entity citing in sources but for which we don't have extensive source
-->

---
layout: statement
---

# Sources are not the data we would like them to be!

Not yet...

---
layout: image
image: /images/sweden_1840_table_12.png
backgroundSize: contain
---

<!--
Swedish source edited in 1840
Among trade partners we find Italy all along the 1830s
But as you may know, Italy was not a unique political entity at that time.
-->

---
layout: image
image: /images/USA_export_1831_1832.png
backgroundSize: contain
---

<!--
USA source edited in 1833
Among trade partners we find Italy again but that time with Malta AND with Sicily on a separate line!
As you can see, each reporter decided to shape his statistics as they like not as you would like nowadays to be.
-->

---
layout: center
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
| Total             | £480,756,915,469 |    468,448    |                                                                  |

</small>

<!--
Our main challenge is to cope with partner heterogeneity. We want to keep this richness but make it compatible with quantification.
In RICardo dataset we decided to keep this richness to let each scholar decide how to use this material.
Here are the categories we use to describe trading entities.
merely 13% of total trade value (19% of flows) are reported with miscellaneous entities
Note that even in the GPH_entity category we find flows to Italy before its existence...
-->

---
layout: center
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

<!--
This is also true on the reporter side but for a very smaller extend
-->

---
layout: center
---

# Our goal: to reduce trading entities heterogeneity with GeoPolitical data

- identifying non-autonomous or informal entities
- aggregating non-autonomous entities to their sovereign
- splitting trade of groups, geographical and colonial areas

---
layout: center
---

# GeoPolHist

Identifies the political status of every geopolitical entity that has existed since 1816  
Based on the lists of states and dependencies developed by [_Correlates of War project_](https://correlatesofwar.org/)

https://medialab.github.io/GeoPolHist/

<small>

Dedinger, Béatrice, and Paul Girard, ‘How Many Countries in the World? The Geopolitical Entities of the World and Their Political Status from 1816 to the Present’, _Historical Methods: A Journal of Quantitative and Interdisciplinary History_, 0.0 (2021), 1–20 <https://doi.org/10.1080/01615440.2021.1939826>

</small>

<!--
Facing this challenge we built with Béatrice a dataset based on Correlates of War project in order to try to answer  a question that is not as simple as it seems : How many countries in the World in the 19s century?
-->

---
layout: iframe
url: https://medialab.github.io/GeoPolHist/#/GeoPolHist/country/325
scale: 0.8
---

<!--
For each entity, we list their political status along time and their links to sovereign parent entities.
-->

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

<!--
Definitions are avialable on the paper and website
-->

---
layout: center
---

# Multilayer networks bridging trade and politics

Build yearly networks which combine

- trade flow edges from **RICardo** dataset
- geopolitical resolutions edges from **GeoPolHist**

<!--
Our proposal is to merge those two dataset RICardo for trade, GeoPolHist into one multilayer network.
-->

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/20260722_Historical_Network_Research/1850_trade_gephi_lite.json
scale: 0.5
---

<!--
This is the original 1850 trade network
-->

---
layout: center
---

# Add Geopolitical resolution edges

From RICardo:

- Locality -[ **AGGREGATE_INTO** ]-> parent entity
- Group -[ **SPLIT_INTO** ]-> members

From additional data edited for this paper:

- Geographical Area -[ **SPLIT_INTO** ]-> members

From GeoPolHist:

- `Part of` GPH entity -[ **AGGREGATE_INTO** ]-> sovereign
- Colonial Area -[ **SPLIT_INTO** ]-> colonies  
  _(reusing geographical area data table)_

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/20260722_Historical_Network_Research/1850_GPH_resolution_gephi_lite.json
scale: 0.5
---

<!--
Zoom to malta
mention Gephi lite
-->

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
layout: center
---

# Harmonization process

1. Autonomous trade entity resolution
1. Trade partner aggregation
1. Trade partner splits with year ratio method
1. Reporters aggregation
1. Trade partner splits with gravity model method

---
layout: center
---

# Autonomous trade entity resolution

For each non-autonomous entity (source: GPH), we traverse resolution edges until finding an autonomous entity.

This method allows to traverse multiple non-autonomous entities until finding the good one like a group containing a part of.

---
layout: center
---

# Trade partner aggregation

Simple task: sum the trade figure to build the new trade edge.

<small>

PS #1: do not overwrite an existing reported trade flow  
PS #2: do not create internal trade flows, discard trade flows between part of and its parent

</small>

---
layout: center
---

# Trade partner splits with year ratio method

Difficult task: how to decide the ratios to split one trade value into many?

We look into **adjacent years** (+/- 10-years window) networks  
for _dissociated_ trade flows with the **same set of partners** for the same reporter.

If we find one compatible year, we calculate **split ratios** for that year and reapply those **on the original trade value**.

This process support partial split.  
If a set of partners from a group is found as one + another group, the one found will be split, the rest will stay as a group.

---
layout: center
---

# Special cases: Areas

Areas (geographical or colonial) are implicit groups.

The composition of the group is to be defined.

We use geographical or colonial sets which we adapt to the source context, i.e. we remove all theoretical members of the area which are already cited by the reporter.

---
layout: center
---

# Reporters aggregation

Because of the importance of reporter context, we need to make sure reporters are aggregated before we can split their partners.

---
layout: center
---

# Trade reporters splits

We don't do that, yet.

---
layout: center
---

# Trade partner splits with gravity model method

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

<!--
This is an extract around Malta in 1850 that illustrate the diversity of resolution
-->

---
layout: center
---

# How much trade do we normalize?

<ShareTotalReportedValue />

We convert into bilateral flows between countries or colonies 75% of the bilateral flows corresponding to exchanges involving at least one miscellaneous entity (cities, groups of countries, areas), which accounts for 19.4% on average of the total value of bilateral flows over the period.

<!--
Keep it mind that we are working with the fringe of the trade networks, ou problematic flows are numerous but with smaller values on average
-->

---
layout: center
---

# Which method has the most impact?

<ShareGeneratedTradeValue />

The ”aggregation”, ”split by ratio in adjacent years” and ”gravity” methods solved
13%, 2.7% and 3.6% of the cases respectively.

---
layout: center
---

# Trade Network density gain!

<TradeNetworkDensity />

Our method yields an average 156% increase in trade network density across the period. The
average density grows from 1.6% to 4.3%, including trade flows and partners we could not
solve.

---
layout: center
---

# Great! What it is good for?

- Trade quantification in the long run
- Trade block analysis: on going work comparing Louvain ambiguity (Jacomy et al. 2025) and intramax (Poon 1997) methods
- Study the effect of colonization: work in progress...

<small>
  <p class="csl-entry">Jacomy, Mathieu, et al. «&nbsp;Cluster Ambiguity in Networks as Substantive Knowledge&nbsp;». <i>Computational Humanities Research 2025</i>, édité par Taylor Arnold et al., Anthology of Computers and the Humanities, 2025, p. 119‑30. <i>anthology.ach.org</i>, <a href="https://doi.org/10.63744/f3L9hsFcGqVc">https://doi.org/10.63744/f3L9hsFcGqVc</a>.</p>
  <span class="Z3988" title="url_ver=Z39.88-2004&amp;ctx_ver=Z39.88-2004&amp;rfr_id=info%3Asid%2Fzotero.org%3A2&amp;rft_id=info%3Adoi%2F10.63744%2Ff3L9hsFcGqVc&amp;rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&amp;rft.genre=proceeding&amp;rft.atitle=Cluster%20Ambiguity%20in%20Networks%20as%20Substantive%20Knowledge&amp;rft.btitle=Computational%20Humanities%20Research%202025&amp;rft.publisher=Anthology%20of%20Computers%20and%20the%20Humanities&amp;rft.aufirst=Mathieu&amp;rft.aulast=Jacomy&amp;rft.au=Mathieu%20Jacomy&amp;rft.au=Tommaso%20Elli&amp;rft.au=Andrea%20Benedetti&amp;rft.au=Guillaume%20Plique&amp;rft.au=Benjamin%20Ooghe-Tabanou&amp;rft.au=Paul%20Girard&amp;rft.au=Alexis%20Jacomy&amp;rft.au=Taylor%20Arnold&amp;rft.au=Margherita%20Fantoli&amp;rft.au=Ruben%20Ros&amp;rft.date=2025&amp;rft.pages=119-130&amp;rft.spage=119&amp;rft.epage=130&amp;rft.issn=3070-8931&amp;rft.language=en"></span>

  <p class="csl-entry">Poon, Jessie P. ‘The Cosmopolitanization of Trade Regions: Global Trends and Implications, 1965-1990’. <i>Economic Geography</i>, vol. 73, no. 4, 1997, pp. 390–404. <i>JSTOR</i>, <a href="https://doi.org/10.2307/144560">https://doi.org/10.2307/144560</a>.</p>
  <span class="Z3988" title="url_ver=Z39.88-2004&amp;ctx_ver=Z39.88-2004&amp;rfr_id=info%3Asid%2Fzotero.org%3A2&amp;rft_id=info%3Adoi%2F10.2307%2F144560&amp;rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal&amp;rft.genre=article&amp;rft.atitle=The%20Cosmopolitanization%20of%20Trade%20Regions%3A%20Global%20Trends%20and%20Implications%2C%201965-1990&amp;rft.jtitle=Economic%20Geography&amp;rft.volume=73&amp;rft.issue=4&amp;rft.aufirst=Jessie%20P.&amp;rft.aulast=Poon&amp;rft.au=Jessie%20P.%20Poon&amp;rft.date=1997&amp;rft.pages=390-404&amp;rft.spage=390&amp;rft.epage=404&amp;rft.issn=0013-0095"></span>

</small>

---
layout: center
---

# Great?

Our hypothesis:

- Reported sources are exhaustive: unreported trade flows are not significant enough and thus can be considered 0
- Trade partner ratios for one reporter are _stable_ in a 10-years window
- Minimalist theory-gravity models are reliable
- our sources are reliable (home-brewed)

Possible improvements:

- find a way to include unsolvable trade flows values into quantification
- we need more trade statistics primary sources

---
layout: center
---

# Any questions?

_Slides:_ https://paulgirard.github.io/ricardo_gph_analysis/HNR_2026/

_Code & Data:_ https://github.com/paulgirard/ricardo_gph_analysis

_Sources:_

- RICardo: https://ricardo.medialab.sciences-po.fr
- GeoPolHist: https://medialab.github.io/GeoPolHist
