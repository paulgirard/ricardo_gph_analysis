---
favicon: "/favicon.ico"
pwa: false
routerMode: hash
fonts:
  # basically the text
  sans: Open Sans
  # use with `font-serif` css class from UnoCSS
  serif: Robot Slab
  # for code blocs, inline code, etc.
  mono: Fira Code
---

# Ties that trade

## Trade blocs over two centuries (1833–2025)

<small>

`Guillaume Daudin - Laboratoire d’Economie de Dauphine (LEDa) - France`\
Béatrice Dedinger - Centre d’histoire de Sciences Po (CHSP) - France \
Youssef Ghallada - Economic History Department LSE - United Kingdom\
Paul Girard - OuestWare - France

<div style="display:flex; gap:1em; align-items: center"> <div>6th Macrohistory Conference <br/>Bonn, Germany</div></div>

</small>

---
layout: center
--- 
# Introduction
### Why?
- The relationship between globalisation and regionalisation has been ambiguous
- - Trade bloc formation has been associated both with phases of de-globalisation (1930s) and globalisation (1990s)


<!-- Some episodes when regionalisation negatively linked with globalisation :  1930s, the exit from empire trade in the 1960s-1970s, the current tensions...
Some when the reverse seems to be the case, such as the rise of the European Union
Anderson and Norheim in an old paper (1993) show that generally, regionalisation and globalisation are positively correlated. Is that really the case ? Or is regionalisation a threat to globalisation as it seems to be currently ?-->

### What is the evolution of trade blocs over two centuries ?
- Composition
- Determinants

### Outline
1. Building the two necessary databases
2. Building yearly coherent bilateral trade matrices
3. Identifying trade blocs
4. Finding the determinants of trade blocs

---
layout: statement
--- 
# I. Two necessary databases
---
layout: center
--- 
<div style="font-size: 70%">

# Two necessary databases (1)
## Building a database of bilateral world trade from 1833

**2004**: exhumation of ‘_Annales du commerce extérieur_’ trade archive
  Birth of the RICardo project (RIC = Research on International Commerce)

**2010**: bilateral trade database covering as many countries (and more...) of the world over the period 1830-1938: 250 000 trade flows + an exchange rate database

**2016**: RICardo website (https://ricardo.medialab.sciences-po.fr/), 2017 version of the database (350 000 trade flows)

**2026**: 690 000 trade flows

</div>

<small>

Girard, Paul, et al. « **RICardo Project : Exploring XIX Century International Trade** ». _Digital Humanities 2016: Conference Abstracts_ [Agiellonian University & Pedagogical University, Kraków, Poland], 2016, p. 208‑10, http://dh2016.adho.org/abstracts/177.

</small>

---
layout: image-left
image: /images/tableau_generale_Belgique_1850.png
backgroundSize: contain
---
# Two necessary databases (2)
## Damn sources: Heterogeneity of<br/> trade entities<br/>in trade archives


_Tableau général du commerce avec les pays étrangers_ (Belgique, 1850)\
Missing from the picture:\
Cuba et Porto-Rico\
Possessions anglaises

---

<small>

## Two necessary databases (3)
### Trying to be faithful to the sources

</small>

<img src="/images/faithful_source_ricardo_tradehist.png" alt="Trade history" width= "750">

---
layout : center
---

# Two necessary databases (4)
## Standardization 

<div style="font-size:50%">

| **COW code** | **COW name**                       | **ISO code** |    **ISO name**    |
| :----------: | ---------------------------------- | :----------: | :----------------: |
|     7501     | Andaman and Nicobar Is.            |      -       |         -          |
|     242      | Anhalt Cothen                      |      -       |         -          |
|     5813     | Anjouan                            |      -       |         -          |
|     8152     | Annam                              |      -       |         -          |
|     7588     | Baluchistan (Kalat)                |      -       |         -          |
|      80      | Belize (British Honduras)          |     BLZ      |       Belize       |
|     434      | Benin (Dahomey)                    |     BEN      |       Benin        |
|      42      | Dominican Republic (Santo Domingo) |     DOM      | Dominican Republic |
|     404      | Guinea-Bissau (Portuguese Guinea)  |     GNB      |   Guinea-Bissau    |

</div>

COW : 1,200 names. RICnames : from 10k to c. 2.5k


---

# Two necessary databases (5)
## How to make sense of different types?

<div style="font-size:50%">

|   **RIC type**    | **All entities** | **Reporting** | **Partner** | **Examples**                                          |
| :---------------: | :--------------: | :-----------: | :---------: | ----------------------------------------------------- |
|    GPH entity     |   530 (22.7 %)   |      286      |     483     | Bulgaria, Gambia, Singapore, Queensland…              |
|     Locality      |   707 (30.2 %)   |      120      |     571     | Asian Russia, Bahia, France (Atlantic Coast)…         |
|       Group       |   860 (36.8 %)   |      37       |     797     | Altona & Holstein, Trinidad & United Kingdom…         |
|   Colonial area   |   130 (5.6 %)    |       0       |     120     | British Africa, Portuguese Asia, Spanish West Indies… |
| Geographical area |   112 (4.8 %)    |       4       |     94      | Central America, Eastern Africa, Persian Gulf...      |
|     **Total**     |     **2339**     |    **447**    |  **2065**   |                                                       |

</div>

---
layout : center
---
# Two necessary databases (6)
**2023**: extension to a political dimension of the RICardo project \
GeoPolHist, a database and digital tool (https://medialab.github.io/GeoPolHist/#/GeoPolHist/)
  to quantify the geopolitical entities of the world since 1816

<small>

Dedinger, Béatrice, and Paul Girard, **‘How Many Countries in the World? The Geopolitical Entities of the World and Their Political Status from 1816 to the Present’**, _Historical Methods: A Journal of Quantitative and Interdisciplinary History_, 54.4 (2021), 208–227 <https://doi.org/10.1080/01615440.2021.1939826>

</small>

---


# Two necessary databases (7) 
## The GeoPolHist dataset

<div style="font-size:45%">

| **GPH code** | **GPH name** | **Start year** | **End year** | **GPH Status**           | **GPH sovereign code** |
| :----------: | :----------: | :------------: | :----------: | ------------------------ | :--------------------: |
|     325      |    Italy     |      1816      |     1861     | Informal                 |                        |
|     325      |    Italy     |      1861      |     2022     | Sovereign                |                        |
|     325      |    Italy     |      1943      |     1946     | Occupied by              |           2            |
|     325      |    Italy     |      1943      |     1945     | Occupied by              |          255           |
|     326      |   Trieste    |      1816      |     1918     | Part of                  |          300           |
|     326      |   Trieste    |      1918      |     1943     | Part of                  |          325           |
|     326      |   Trieste    |      1943      |     1947     | Occupied by              |           2            |
|     326      |   Trieste    |      1947      |     1954     | Mandated to              |           1            |
|     326      |   Trieste    |      1954      |     2022     | Part of                  |          325           |
|     327      | Papal States |      1816      |     1861     | Sovereign                |                        |
|     327      | Papal States |      1861      |     1870     | Part of                  |          325           |
|     327      | Papal States |      1870      |     1870     | Dissolved into           |          328           |
|     328      | Vatican City |      1816      |     1870     | Part of                  |          327           |
|     328      | Vatican City |      1870      |     1929     | Part of                  |          325           |
|     328      | Vatican City |      1929      |     1964     | Sovereign (unrecognized) |                        |
|     328      | Vatican City |      1964      |     2022     | Sovereign                |                        |
|     329      | Two Sicilies |      1816      |     1860     | Sovereign                |                        |
|     329      | Two Sicilies |      1860      |     1861     | Part of                  |          324           |
|     329      | Two Sicilies |      1861      |     1861     | Dissolved into           |          325           |

</div>

---
layout: iframe
url: https://medialab.github.io/GeoPolHist/#/GeoPolHist/country/325
scale: 1
---

<!--
For each entity, we list their political status along time and their links to sovereign parent entities.
-->

---
layout: statement
---

# II. Building yearly coherent bilateral trade matrices

---
layout: center
---

# Building coherent bilateral trade matrices (1)
## Reduce trading entities heterogeneity thanks to GeoPolHist data

- identifying non-polities or informal entities
- aggregating non-polities entities and localities to the polities they are part of.
- splitting trade of groups, geographical and colonial areas


---
layout: center
---

# Building coherent bilateral trade matrices (2)
## Method: Multilayer networks bridging trade and politics

Build yearly networks that combine:

1. trade flow edges from **RICardo** dataset
2. geopolitical resolutions edges mainly from **GeoPolHist** dataset

<!-- Je mets mainly parce que les resolution edges « localities » et group viennent de Ricardo je pense ? GD-->
<!-- oui le mainly c'est bien. c'est un détail pas important ici et j'ai pas du tout envie de rentrer dans le débat de oui mais une localité peut changer dans le temps...Et surtout j'explique en détail slide 18-->

<!--
Our proposal is to merge those two dataset RICardo for trade, GeoPolHist into one multilayer network.
-->

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_trade_gephi_lite.json
scale: 0.8
---

<!--
This is the original 1850 trade network
-->



---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_GPH_resolution_gephi_lite.json
scale: 0.8
---

<!--
This is the network of the resolution edges
Zoom to malta
mention Gephi lite
-->

---
layout: center
---

# Building coherent bilateral trade matrices (3) 
## Harmonization process

1. Polities resolution
1. Trade reporters aggregation/split
1. Trade partners aggregation
1. Trade partners splits with year ratio method
1. Trade reporters & partners splits with gravity model method


---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_examples_gephi_lite.json
	scale: 1
---

<!--
This is an extract around Malta in 1850 that illustrate the diversity of resolution
-->

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_trade_gephi_lite_post_gravity.json
scale: 1
---

---
layout: iframe
url: https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_trade_gephi_lite.json
scale: 0.8
---

---
layout: center
---

## Building coherent bilateral trade matrices (4)
### How much trade do we normalize?

<ShareTotalReportedValue />

We convert into bilateral flows between polities 87% of the bilateral flows involving non-polities (cities, groups of countries, areas), which accounts for 17.5% on average of the total value of bilateral flows over the period.

<!--
Keep it mind that we are working with the fringe of the trade networks, ou problematic flows are numerous but with smaller values on average
-->

---
layout: center
---

## Building coherent bilateral trade matrices (5)
### Which method has the most impact?

<ShareGeneratedTradeValue />

The ”aggregation”, ”split by ratio in adjacent years” and ”gravity” methods solved
12%, 4.6% and 26.19% of the trade flows (in number) respectively.

---
layout: center
---

## Building coherent bilateral trade matrices (6)
### Trade Network density gain!

<TradeNetworkDensity />

Our method yields an average 216% increase in trade network density across the period. The average density grows from 1.8pp to 8.9pp, including trade flows and partners we could not solve.
<!--Je ne comprends pas « including trade flows and partners we could not solve GD-->

<!--
The effect on the number of trade flows is much larger than on the value of trade flows
-->


---
layout: statement
---

# III. Identifying trade blocs


---
layout: center
---

# Identifying trade blocs (1)

## Pre-given by geography and judgment?

<!-- This is the most common point of view. Anderson and Norheim. Currency blocs, political trade blocs, empires...
This leads to
- endogeneity issue (you might pick the composition of a bloc because you see increased inbloc trade)
- fixity over time. The relevant bloc might actually change through time, and you might miss that. Most obvious example : maybe imperial blocs are important in the 1930s and 1950s, but they loose that importance through time. And now continental blocs are important because of regional trade agreements, especially the EU-->

## Let the data speak?

« The problem of community detection requires the partition of a network into communities of densely connected nodes, with the nodes belonging to different communities being only sparsely connected »

Trade studies : Intramax

Network studies: Louvain

<small>
Blondel, Vincent D., Jean-Loup Guillaume, Renaud Lambiotte, and Etienne Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.” <i> Journal of Statistical Mechanics: Theory and Experiment </i> 2008 (10): P10008.

</small>

---
layout: two-cols-header
---
# Identifying trade blocs (2)
## Anderson and Norheim’s blocs

::left::

Western Europe (including Turkey and Yugoslavia)\
Eastern Europe (East of West Germany, including Soviet Central Asia)

North America (excluding Mexico and West Indies)\
Latin America

<small>

Anderson, Kym, and Hege Norheim. "Is world trade becoming more regionalized?." <i> Review of International Economics,</i> 1.2 (1993): 91-109.

</small>

::right::
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

# Identifying trade blocs (3)
## Distance measure (from Intramax)

One looks for the polity/bloc pair that is the furthest from a random model of bilateral trade.\
$I_{i,j}$ is (eg) fob exports from polity/bloc _i_ to polity/bloc _j_\
$I’_{i,j}$ is counterfactual, random, no friction trade, defined as:

 <center>

$I’_{i,j}= \frac{\sum_j I_{i,j}}{\sum_{ij}I_{i,j}}.\frac{\sum_i I_{i,j}}{\sum_{ij}I_{i,j}}.\sum_{ij}I_{i,j}=\frac{\sum_j I_{i,j}.\sum_iI_{i,j}}{\sum_{ij}I_{i,j}}$

 </center>
 
 <small>
 <p class="csl-entry">Poon, Jessie P. ‘The Cosmopolitanization of Trade Regions: Global Trends and Implications, 1965-1990’. <i>Economic Geography</i>, vol. 73, no. 4, 1997, pp. 390–404. <a href="https://doi.org/10.2307/144560">https://doi.org/10.2307/144560</a>.</p>
</small>

---
layout: center
---
# Identifying trade blocs (4)
## Adapting the distance measure

You are looking for the polities/blocs pair (_i_,_j_) that maximises:

 <center>

$(I_{ij}-I’_{ij})+ (I_{ji}-I’_{ji})$

 </center>
 
 We have issues:

- We often miss one of $I_{ij}$ or $I_{ji}$ : use of the mean?
- Poon’s maximisation objective is in monetary terms, and as such gives an advantage to large polity pairs
- We believe if a small polity does 100% of its trade with a big one, even if this trade is small in monetary terms, they must be in the same bloc.
  So we use rather:

 <center>

$Max (\frac{(I_{ij}-I’_{ij})}{\sum_{i}I_{i,j}}; \frac{(I_{ji}-I’_{ji})}{\sum_{j}I_{j,i}})=A_{i,j}$

 </center>


 <!-- Without a stopping rule, all polities would be put in a single bloc... -->



---
layout: center
---

## Identifying trade blocs (5)
### Louvain: moving from a local measure to a global objective function

$Q=\frac{1}{2m}.\sum_{i,j}\left({A_{i,j}}.\frac{k_i.k_j}{2m}.\delta(c_i,c_j)\right)$ is the ratio between the weight of links inside blocs compared to random links ($\in[-0.5,1]$)

<small>

- $A_{i,j}$ is the weight of the link (or proximity) between polities _i_ and _j_ that we just defined
- $k_i= \sum_{i}{A_{i,j}}$ is total weight of a polity’s links (it might be different from one)
- $m= \frac{1}{2}.\sum_{i,j}{A_{i,j}}$ is the sum of all weights in the trade network divided by two
- $c_i$ and $c_j$ are the blocs of polities _i_ and _j_. The $\delta$-function $\delta(u,v)$ is 1 if $u=v$ and 0 otherwise

</small>
<small>

M. E. J. Newman, « Modularity and community structure in networks », _Proc. Natl. Acad. Sci_. USA, vol. 103, no 23, 2006, p. 8577–8582 https://dx.doi.org/10.1073%2Fpnas.0601602103

</small>

---
layout: center
---

## Identifying trade blocs (6)
### Louvain’s algorithm

<small>

1. All polities are put in its own bloc
2. We examine all trade partners _j_ of a polity _i_ and we assign _i_ in _j_’s bloc, where _j_’s bloc provides the largest gain in modularity. If there are no positive gains, _i_ stays in its bloc. Once all polities have been considered once, we examine them again in the same order and they can moved from bloc to bloc.
3. When all positive gain-grouping have been made, we re-create the network with the new blocs as units, considering internal trade as a self-loop. Proximity between blocs is the sum of proximity of each pair of polities.\
   And we iterate (2 and 3) till no change in grouping is made in phase 2.
4. The result depends on the order in which polities are examined. We run it multiple time and aggregate the results.

</small>


<small>
Blondel, Vincent D., Jean-Loup Guillaume, Renaud Lambiotte, and Etienne Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.” <i> Journal of Statistical Mechanics: Theory and Experiment </i> 2008 (10): P10008.
</small>

---
layout: image
image: /images/Louvain_algorithm.png
backgroundSize: contain
---

## Blondel et al.


---
layout: image
image: /images/carte_comm_1850.png
backgroundSize: contain
---

---
layout: image
image: /images/Intra-block trade share.png
backgroundSize: contain
---

---
layout: image
image: /images/tibi_comparaison_avec_diff_nblocs.png
backgroundSize: contain
---


---
layout: image
image: /images/Modularity.png
backgroundSize: contain
---

---
layout: statement
---

# IV. Determinants of trade blocs

---
layout: center
---

Logit regression on GPH-pairs each year, on variables:

- distance (Centroids from Wikidata, not time varying)
- contiguity (Correlates of War + our own work)
- common empire (GeoPolHist up to 2022)
- alliance (inherited from sovereign) (Alliance Treaty Obligations and Provisions (ATOP) up to 2018)
- conflict (inherited from sovereign) (Militarized Interstate
Disputes (MID) up to 2014)

No causality, obviously\
We compute the incremental R² (but we need a better idea)

---
layout: image
image: /images/mid_n_louvain_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/contig12_louvain_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/atop_allie_louvain_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/common_empire_louvain_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/ln_dist_louvain_fob.png
backgroundSize: contain
---

---
layout: statement
---

# Conclusion

---
layout: center
---

## Conclusion (1)

###  Outline

1. Building the two necessary databases
2. Building yearly coherent bilateral trade matrices
3. Identifying trade blocs
4. Finding the determinants of trade blocs

### Tentative findings
1. The importance of trade blocs has been stable pre-1913 and post-1945, The strong decline in the inter-war period has never been recovered. Source effect?
2. But trade bloc correlates have changed
	- Empires were important when the existed 
	- Alliances have become very important post-45 (except 1970s-1980s)
	- The effect of distance has been increasing continuously since the 1850s

---
layout: center
---

# Conclusion (2)

## Pat on the back

Interdisciplinary work between history, economics and network science

## Improvements?

- More primary sources on trade statistics (and a poney)
- Change the proximity measure (TIBI would solve range variability, range asymmetry, dynamic ambiguity)
- Distinguish unknown but non-zero trade flows and zero trade flows
- Take ambiguity in Louvain into account
- Progress on bloc determinants: at least, we need a trade agreement database

<!-- One day we take that into account
-->


---
layout: center
---

# Any questions?

_Slides:_ https://paulgirard.github.io/ricardo_gph_analysis/bonn_2026/

_Code & Data:_ https://github.com/paulgirard/ricardo_gph_analysis

_Sources:_

- RICardo: https://ricardo.medialab.sciences-po.fr
- GeoPolHist: https://medialab.github.io/GeoPolHist



---
layout: center
---

# Additional slides

---
layout: center
---

<!-- Je suis embetté par l’utilisation de Jacomy et al., parce qu’il porte essentiellement sur l’ambiguïté et sa représentation et que ce n’est pas notre sujet. Sauf si... On pourrait considérer que les nodes au positionnement ambigu sont des singletons?-->

 <small>

  <p class="csl-entry">Jacomy, Mathieu, et al. «&nbsp;Cluster Ambiguity in Networks as Substantive Knowledge&nbsp;». <i>Computational Humanities Research 2025</i>, édité par Taylor Arnold et al., Anthology of Computers and the Humanities, 2025, p. 119‑30. <i>anthology.ach.org</i>, <a href="https://doi.org/10.63744/f3L9hsFcGqVc">https://doi.org/10.63744/f3L9hsFcGqVc</a>.</p>
  </small>

---
layout: center
---

# RICentities types

<div style="font-size:50%">

|   **RIC type**    | **Reporting % value** | **Reporting % flows** | **Partner % value** | **Partner % flows** |
| :---------------: | :-------------------: | :-------------------: | :-----------------: | :-----------------: |
|    GPH entity     |         97.3          |         95.6          |        87.2         |        81.2         |
|     Locality      |          0.6          |          2.5          |         4.6         |         6.5         |
|       Group       |          2.4          |          1.8          |         6.5         |         5.1         |
|   Colonial area   |          0.0          |          0.1          |         1.4         |         5.0         |
| Geographical area |           -           |           -           |         0.4         |         2.2         |

</div>

---
layout: two-cols-header
---

## Polity definition

A very extensive definition.\
Sufficient political autonomy to have its own trade statistics.  
Every political status in GeoPolHist but `part of`.
<!-- Il faudrait réfléchir à cette définition "handle trade" ne veut pas dire grand chose. La définition actuelle n’est pas extraordinaire non plus :  "Occupied by" n’a pas beaucoup d’autonomie politique GD-->
<!-- oui, est ce que la définition n'est pas plutôt la négation de ça a été dissout, i.e. tout ce qui n'est pas part of-->

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

# Bilateral trade data model

![Bilateral trade data model](/images/Bilateral%20Trade%20Data%20model.svg)

<!--
Note that we have trade between reporters but also between reporter and partners, i.e. entity citing in sources but for which we don't have extensive source
-->

---
layout: center
---

# Add Geopolitical resolution edges

From RICardo:

```cypher
(Locality)-[:AGGREGATE_INTO]->(parent entity)
(Group)-[:SPLIT_INTO]->(members)
```

From additional data edited for this paper:

```cypher
(Geographical Area)-[:SPLIT_INTO]->(members)
(Informal)-[:SPLIT_INTO]->(members)
```

From GeoPolHist:

```cypher
(`Part of` GPH entity)-[:AGGREGATE_INTO]->(sovereign)
(Colonial Area)-[:SPLIT_INTO]->(colonies)
```

For colonial area we combine geographical area data table with GPH data.

<!--
Quid des « other » ? GD
Ce sont des locality RICardo
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

# Polity resolution

For each non-polity entity (source: GPH + Ricardo localities), we traverse resolution edges until finding an polity.

This method allows to traverse multiple non-polity entities until finding the good one like a group containing a part of:

```cypher
(D)<-[:SPLIT]-(D & part of A)-[:SPLIT]->(part of A)-[:AGGREGATE_INTO]->(A)
```

Polities of **D & part of A** are **D** and **A**.

<!--
Je ne comprends pas ce que les groupes ont à voir là dedans. Si c’est un part of ou une locality, ce n’est jamais un group ? Ou bien est-ce que c’est pour le cas où les part of/localities font partie d’un groupe ? GD

Je ne comprends pas ce que tu ne comprends pas. On suit tous les liens de résolutions qq soit la raison pour laquelle on a créé le lien. J'ajoute un schéma symbolique PG
-->

---
layout: center
---

# Trade reporters aggregation/split

Reporters needs to be treated before the partners as areas desagregations needs a stable reporter scope.

Moreover we need to treat cases of reporters overlaps. It happens that a set of reporters report part of the same trade from different perspectives.

<small>

PS: we don't split reporters trade at this step, we prepare the work for the gravity model

</small>

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

The composition of the group is not explicit in the source.

We use geographical or colonial sets which we adapt to the source context:

- we remove all theoretical members of the area which are already cited by the reporter
- we remove those that would not be part of the trade network otherwise (not directly cited by another source)

---
layout: center
---

# Trade partner/reporter splits with gravity model method

We try to impute flows we couldn't split with the adjacent years method by using a gravity model (Anderson et Van Wincoop 2003).

We use fixed effects on importer and exporters, geographical distance, geopolitical link existence (GeoPolHist) variables (to be extended).

The inferred values are used to compute a ratio which is then applied on the original values.

<small>

Anderson, James E., et Eric Van Wincoop. « Gravity with Gravitas: A Solution to the Border Puzzle ». _American Economic Review_, vol. 93, no 1, February 2003, p. 170‑92. DOI.org (Crossref), [https://doi.org/10.1257/000282803321455214](https://doi.org/10.1257/000282803321455214).

</small>



---
layout: center
---

# Intramax (3)

We have issues:

- Poon’s maximisation objective is in monetary terms, and as such gives an advantage to large polity pairs
- Often we are missing one direction of trade
- We believe if a small polity does 100% of its trade with a big one, even if this trade is small in monetary terms, they must be in the same bloc.
  So we use rather:

 <center>

$Max (\frac{(I_{ij}-I’_{ij})}{\sum_{i}I_{i,j}}; \frac{(I_{ji}-I’_{ji})}{\sum_{j}I_{j,i}})=A_{i,j}$

 </center>

 <small>

Kohl, Tristan, and Aleid E. Brouwer. 2014. “The Development of Trade Blocs in an Era of Globalisation.” _Environment and Planning A: Economy and Space_ 46 (7): 1535–53. https://doi.org/10.1068/a46261.

</small>

---
layout: image
image: /images/carte_blocs_1850.png
backgroundSize: contain
---

---
layout: center
---

# Regionalisation and globalisation

TIBI is a measure of bilateral trade intensity that solves - range variability - range asymmetry - dynamic ambiguity

 <small>

Daudin, Guillaume, Christine Rifflart, and Danielle Schweisguth. 2011. “Who Produces for Whom in the World Economy?” _Canadian Journal of Economics/Revue Canadienne d’économique_ 44 (4): 1403–37. https://doi.org/10.1111/j.1540-5982.2011.01679.x.

Iapadre, Lelio. 2006. “Regional Integration Agreements and the Geography of World Trade.” _Assessment And Measurement of Regional Integration_, 65–85.

 </small>


---
layout: image
image: /images/mid_n_intramax_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/contig12_intramax_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/atop_allie_intramax_fob.png
backgroundSize: contain
---

---
layout: image
image: /images/common_empire_intramax_fob.png
backgroundSize: contain
---


---
layout: image
image: /images/ln_dist_intramax_fob.png
backgroundSize: contain
---
