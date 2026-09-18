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
Guillaume Daudin - Laboratoire d’Economie de Dauphine (LEDa) - France\
Béatrice Dedinger - Centre d’histoire de Sciences Po (CHSP) - France \
Youssef Ghallada - Economic History Department LSE - United Kingdom\
MEDIALAB
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
<!-- Je trouve l’ordre bizarre, parce que British Colonies (other) (et toutes les "other") viennent avant colonial area et geographical area GD -->
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
- aggregating non-autonomous entities and localities to their « sovereign »
- splitting trade of groups, geographical and colonial areas

<!-- Sovereign is an ambiguous term. It could mean « France » for « Saint-Louis du Sénégal » instead of « Sénégal » GD-->
<!-- je rajoute localities dans le 2e bp GD-->

---
layout: center
---

# GeoPolHist

Identifies the political status of every geopolitical entity that has existed since 1816  
Based on the lists of states and dependencies developed by [_Correlates of War project_](https://correlatesofwar.org/)

https://medialab.github.io/GeoPolHist/

<small>

Dedinger, Béatrice, and Paul Girard, ‘How Many Countries in the World? The Geopolitical Entities of the World and Their Political Status from 1816 to the Present’, _Historical Methods: A Journal of Quantitative and Interdisciplinary History_, 54.4 (2021), 208–227 <https://doi.org/10.1080/01615440.2021.1939826>

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

A very extensive definition.\
Sufficient political autonomy to <!-- handle trade--> have its own trade statistics.  
Every political status in GeoPolHist but `part of`.
<!-- Il faudrait réfléchir à cette définition "handle trade" ne veut pas dire grand chose. La définition actuelle n’est pas extraordinaire non plus :  "Occupied by" n’a pas beaucoup d’autonomie politique GD-->

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
Definitions are available on the paper and website
-->

---
layout: center
---

# Multilayer networks bridging trade and politics

Build yearly networks which combine

- trade flow edges from **RICardo** dataset
- geopolitical resolutions edges mainly from **GeoPolHist**
<!-- Je mets mainly parce que les resolution edges « localities » et group viennent de Ricardo je pense ? GD-->

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

<!-- Quid des « other » ? GD-->
---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/20260722_Historical_Network_Research/1850_GPH_resolution_gephi_lite.json
scale: 0.5
---

<!--
This is the network of the resolution edges
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

For each non-autonomous entity (source: GPH + Ricardo localities), we traverse resolution edges until finding an autonomous entity.

This method allows to traverse multiple non-autonomous entities until finding the good one like a group containing a part of.

<!-- Je ne comprends pas ce que les groupes ont à voir là dedans. Si c’est un part of ou une locality, ce n’est jamais un group ? Ou bien est-ce que c’est pour le cas où les part of/localities font partie d’un groupe ? GD-->

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

We use geographical or colonial sets which we adapt to the source context, i.e. we remove all theoretical members of the area which are already cited by the reporter and we remove those that would not be part of the trade network otherwise.

<!-- and we remove those that would not be part of the trade network otherwise... Je crois, non ? GD-->

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

<!-- On le fait maintenant je crois ? GD-->

---
layout: center
---

# Trade partner splits with gravity model method

We try to impute flows we couldn't split with the adjacent years method by using a gravity model (Anderson et Van Wincoop 2003).

We use fixed effects on importer and exporters, geographical distance, geopolitical link existence (GeoPolHist) variables (to be extended).

The inferred values are used to compute a ratio which is then applied on the original values.

<small>

Anderson, James E., et Eric Van Wincoop. « Gravity with Gravitas: A Solution to the Border Puzzle ». _American Economic Review_, vol. 93, no 1, February 2003, p. 170‑92. DOI.org (Crossref), [https://doi.org/10.1257/000282803321455214](https://doi.org/10.1257/000282803321455214).

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
<!--Je ne comprends pas « including trade flows and partners we could not solve GD-->

<!--
The effect on the number of trade flows is much larger than on the value of trade flows
-->
---
layout: center
---

# Great! What it is good for?

- Trade quantification in the long run
- Study the effect of colonization: work in progress...
- What we will talk about: Trade block analysis

---
layout: center
---
# Trade block analysis
## Why?

- Between 1830 and 2025, the pattern of bilateral trade flows has been heavily affected by successive waves of globalisation and deglobalisation
	<!-- a pre-1913 wave of globalisation (1830 -1913) (Kevin O'Rourke and Williamson, 2002)
	- dislocation during and between the two World Wars
	- reconstruction of the international economy till the 1970s
	- hyper globalisation till the recent recent tensions-->
- The relationship between globalisation and regionalisation has been ambiguous
<!-- Some episodes when regionalisation negatively linked with globalisation :  1930s, the exit from empire trade in the 1960s-1970s, the current tensions...
Some when the reverse seems to be the case, such as the rise of the European Union
Anderson and Norheim in an old paper (1993) show that generally, regionalisation and globalisation are positively correlated. Is that really the case ? Or is regionalisation a threat to globalisation as it seems to be currently ?-->

<small>
Anderson, Kym, and Hege Norheim. "Is world trade becoming more regionalized?." <i> Review of International Economics,</i> 1.2 (1993): 91-109.
</small>

---
layout: center

---
# Trade block analysis
## Outline
### How to define a block?
### Regionalisation and globalisation
### Determinants of blocks





---
layout: center
---

# How to define a block?
## Pre-given by geography and judgment?
<!-- This is the most common point of view. Anderson and Norheim. Currency blocks, political trade blocs, empires...
This leads to 
- endogeneity issue (you might pick the composition of a block because you see increased inblock trade)
- fixity over time. The relevant block might actually change through time, and you might miss that. Most obvious example : maybe imperial blocks are important in the 1930s and 1950s, but they loose that importance through time. And now continental blocks are important because of regional trade agreements, especially the EU-->

## Let the data speak?
Trade studies : Intramax

Network studies: Louvain ambiguity


<small>

  <p class="csl-entry">Poon, Jessie P. ‘The Cosmopolitanization of Trade Regions: Global Trends and Implications, 1965-1990’. <i>Economic Geography</i>, vol. 73, no. 4, 1997, pp. 390–404. <a href="https://doi.org/10.2307/144560">https://doi.org/10.2307/144560</a>.</p>

  Blondel, Vincent D., Jean-Loup Guillaume, Renaud Lambiotte, and Etienne Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.” <i> Journal of Statistical Mechanics: Theory and Experiment </i> 2008 (10): P10008.

  <p class="csl-entry">Jacomy, Mathieu, et al. «&nbsp;Cluster Ambiguity in Networks as Substantive Knowledge&nbsp;». <i>Computational Humanities Research 2025</i>, édité par Taylor Arnold et al., Anthology of Computers and the Humanities, 2025, p. 119‑30. <i>anthology.ach.org</i>, <a href="https://doi.org/10.63744/f3L9hsFcGqVc">https://doi.org/10.63744/f3L9hsFcGqVc</a>.</p>
  

<!-- Je suis embetté par l’utilisation de Jacomy et al., parce qu’il porte essentiellement sur l’ambiguïté et sa représentation et que ce n’est pas notre sujet. Sauf si... On pourrait considérer que les nodes au positionnement ambigu sont des singletons?-->

</small>
---
layout: center
---
# Anderson and Norheim’s blocks
Western Europe (including Turkey and Yugoslavia)\
Eastern Europe (East of West Germany, including Soviet Central Asia)

North America (excluding Mexico and West Indies)\
Latin America

(Japan)\
Australasia\
Developing Asia

Africa\
Middle East (as far as Iran)

<small>
Finger, Karl-Michael, Hege Norheim, and Kym Anderson. 1993. “Trends in the Regionalization of World Trade, 1928 to 1990.” In <i> Regional Integration and the Global Trading System</i>, by Kim Anderson and Richard Blackhurst. https://www.cabidigitallibrary.org/doi/full/10.5555/19941801183.

</small>
---
layout: center
---

# Intramax

You look at the one pair that is the furthest from a no friction model of bilateral trade prediction. $I_{i,j}$ is (eg) fob exports from country *i* to country *j*

$I’_{i,j}= \frac{\sum_j I_{i,j}}{\sum_{ij}I_{i,j}}.\frac{\sum_i I_{i,j}}{\sum_{ij}I_{i,j}}.\sum_{ij}I_{i,j}=\frac{\sum_j I_{i,j}.\sum_iI_{i,j}}{\sum_{ij}I_{i,j}}$ 

You are looking for countries *i* and *j* that maximise :
$(I_{ij}-I’_{ij})+ (I_{ji}-I’_{ji})$

The issue is that this formula (used by Poon) gives an advantage to large country pairs. 

<small>
 <p class="csl-entry">Poon, Jessie P. ‘The Cosmopolitanization of Trade Regions: Global Trends and Implications, 1965-1990’. <i>Economic Geography</i>, vol. 73, no. 4, 1997, pp. 390–404. <a href="https://doi.org/10.2307/144560">https://doi.org/10.2307/144560</a>.</p>
</small>
 
---
layout: image
image: /images/Intramax.png
backgroundSize: small
---


# Louvain
« The problem of community detection requires the partition of a network into communities of densely connected nodes, with the nodes belonging to different communities being only sparsely connected »

## Measure of distance
## Modularity
<small>
Blondel, Vincent D., Jean-Loup Guillaume, Renaud Lambiotte, and Etienne Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.” <i> Journal of Statistical Mechanics: Theory and Experiment </i> 2008 (10): P10008.
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
