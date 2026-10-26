# Trade that ties: Trade communities over two centuries (1833–2025)

	*Guillaume Daudin - Laboratoire d’Economie de Dauphine (LEDa) - Université Paris Dauphine-PSL - France*
	Béatrice Dedinger - Centre d’histoire de Sciences Po (CHSP) - France\
	
	Youssef Ghallada - Economic History Department LSE - United Kingdom\
	
	Paul Girard - OuestWare - France

	**Geneva Trade and Development Workshop, Octobre 27th, 2026**

Do not forget to introduce co-authors
---

# Introduction
## Caveat emptor
This is a work in progress. We are still in the garden of forking paths.
## What do we call trade communities?
Trade blocs, trade regions... groups of countries that trade more with one another than with the rest of the world according to some metric

---
## Trade communities play a role in world trade
	Gopinath et al. (2025), Bonadio et al. (2026), Anderson and Norheim (1993)
https://doi.org/10.1016/j.jinteco.2024.104042 ; Gopinath, Gita, et al. "Changing global linkages: A new Cold War?." Journal of International Economics 153 (2025): 104042.

https://doi.org/10.1016/j.jinteco.2025.104204 ; Bonadio, Barthélémy, et al. "Playing with blocs: Quantifying decoupling." Journal of International Economics (2026): 104204.


Current rising international tensions have increased the interest for securing supply chains through trade fragmentation by geopolitical lines. Studies show the rise of friend-shoring, near-shoring and decoupling by trading more with geopolitical friends. 

This is probably bad for global trade. It does not need to be so. Anderson and Norheim in an old paper (1993) even show that generally, regionalisation and globalisation are positively correlated. And the story of "hyperglobalisation" from the 1980s to the 2000s, around the rise of the European Union, NAFTA, and Factory Asia can lead to a positive view of the formation of trade blocs. The 1930s, with decoupling between trade blocs organised around formal and informal empires, gives less reason for optimism. 

We look at this phenomenon, with historical depth, which allows to show if the current period is unusual.


---
## We look for trade communities with network science
	Fagiolo et al. (2010) De Benedictis & Tajoli (2011), Piccardi & Tajoli (2012), Iapadre & Tajoli (2014)

We do not pre-impose trade blocs

It is not only that countries trade with friends. It is also that you want to become friends with the countries you trade with. So trade communities arising from the ground are interesting to study. 

Blocs might arise from reasons that are not linked to geopolitical tensions, and the contrast between different periods is interesting.
In the early 1990s, it was not obvious with whom Eastern Europe would trade more. You could argue that trade created the community rather than the reverse. 

---
## Trade communities have economic consequences.
	Lesger (2006), Miller (2012), Rauch (1999, 2001), Rauch & Trindade (2002), Combes, Lafourcade & Mayer (2005), Chaney (2014)

But then you have an issue. The creation of trade communities is important because it has consequences for trade. It might encourage more trade, but of course that relationship is deeply endogenous to the creation of communities. 
Except for the extensive margin.
Look at the story of Amsterdam in the 16th and 17th centuries (Lesger 2006). From an actual entrepôt for goods to an information entrepôt that encouraged the formation of direct links between the Baltic and Western Europe for naval stores, grain, and various raw materials.
We argue this happened because of the creation of trade communities of people. 
Ethnic work, eg. Greif’s work on the Maghribi traders of the 10th-11th century
Double entendre 
European expansion created intercontinental networks of business and administrative people that encouraged the formation of trade 
Shared business and financial networks give access to shared information through intermediaries.


---

## What are the composition, determinants and effects of trade communities over two centuries ?
---
## Outline
	1. Data
	2. Identifying trade communities
	3. Finding the determinants of trade communities
	4. Finding the effect of trade communities

---

# I. Data

---

# Data (1)
## Besides well known IMF data from 1948

## A database of bilateral world trade 1833-1938
	RICardo project since 2004. 690,000 trade flows
	https://ricardo.medialab.sciences-po.fr/

All started with the discovery of the "Annales du Commerce Extérieur", an annual French source from the 1830s that reported bilateral trade statistics from numerous foreign countries
	Girard, Paul, et al. « **RICardo Project : Exploring XIX Century International Trade** ». _Digital Humanities 2016: Conference Abstracts_ [Agiellonian University & Pedagogical University, Kraków, Poland], 2016, p. 208‑10, http://dh2016.adho.org/abstracts/177.

---

/assets/Ricardo Website.png
size: contain


---


# Data (2)

/assets/tableau_generale_Belgique_1850.png
size: contain


## Issue with the sources: Heterogeneity of trade entities in trade archives
	_Tableau général du commerce avec les pays étrangers_ (Belgique, 1850)\
	Missing from the picture:\
	Cuba et Porto-Rico\
	Possessions anglaises

---

# Data (3)
	Trying to be faithful to the sources
/assets/faithful_source_ricardo_tradehist.png
size: contain

Les Îles Ioniennes sont un protectorat britannique jusqu’aux années 1860

---

# Data (4)
## Standardization of names (including translation): From c. 10,000 names to c. 2.500 names (COW : 1,200)
| **COW code** | **COW name** | **ISO code** | **ISO name** |
|:-:|--|:-:|:-:|
| 7501 | Andaman and Nicobar Is. | - | - |
| 242 | Anhalt Cothen | - | - |
| 5813 | Anjouan | - | - |
| 8152 | Annam | - | - |
| 7588 | Baluchistan (Kalat) | - | - |
| 80 | Belize (British Honduras) | BLZ | Belize |
| 434 | Benin (Dahomey) | BEN | Benin |
| 42 | Dominican Republic (Santo Domingo) | DOM | Dominican Republic |
| 404 | Guinea-Bissau (Portuguese Guinea) | GNB | Guinea-Bissau |
	

---

# Data (5)
## There are very different geopolitical denominations in the sources
|   **RIC type**    | **All entities** | **Reporting** | **Partner** | **Examples**                                          |
| :---------------: | :--------------: | :-----------: | :---------: | :---------------------------------------------------- |
|   Trade actors    |   530 (22.7%)    |      286      |     483     | Bulgaria, Gambia, Singapore, Queensland…              |
|     Locality      |   707 (30.2%)    |      120      |     571     | Asian Russia, Bahia, France (Atlantic Coast)…         |
|       Group       |   860 (36.8%)    |      37       |     797     | Altona & Holstein, Trinidad & United Kingdom…         |
|   Colonial area   |    130 (5.6%)    |       0       |     120     | British Africa, Portuguese Asia, Spanish West Indies… |
| Geographical area |    112 (4.8%)    |       4       |     94      | Central America, Eastern Africa, Persian Gulf...      |
|     **Total**     |     **2339**     |    **447**    |  **2065**   |                                                       |

To identify "British Africa" we need to know what are the British African colonies in a given year.
---

# Data (6)
## A database of geopolitical entities of the world since 1816
	GeoPolHist https://medialab.github.io/GeoPolHist/#/GeoPolHist/

	Dedinger, Béatrice, and Paul Girard, **‘How Many Countries in the World? The Geopolitical Entities of the World and Their Political Status from 1816 to the Present’**, _Historical Methods: A Journal of Quantitative and Interdisciplinary History_, 54.4 (2021), 208–227 <https://doi.org/10.1080/01615440.2021.1939826>

---
# Data (7)
## The GeoPolHist dataset
| **GPH code** | **GPH name** | **Start year** | **End year** | **GPH Status**           | **GPH sovereign code** |
| :----------: | :----------: | :------------: | :----------: | :----------------------- | :--------------------: |
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

---

## GeoPolHist: Italy (325)
/assets/Italian GPH page.png
size: contain


[Open the GeoPolHist page for Italy](https://medialab.github.io/GeoPolHist/#/GeoPolHist/country/325)

For each entity, we list their political status along with time and their links to sovereign parent entities.


---

# Data (8)
## To build coherent bilateral trade matrices, one needs to reduce trading entities heterogeneity thanks to GeoPolHist data
	1. identify non-polities, groups... informal entities.
	2. aggregate non-polities entities (localities, part-of...) to their polities.
	3. split trade of groups, geographical and colonial areas


---
# Data (9)
## Method: Multilayer networks combining trade and politics
Build yearly networks that combine:
trade flow edges from **RICardo** dataset
geopolitical resolutions edges mainly from **GeoPolHist** dataset (« localities » , eg Bilabo, come from **RICardo**)

Our proposal is to merge those two dataset RICardo for trade, GeoPolHist into one multilayer network.

// Je mets mainly parce que les resolution edges « localities » et group viennent de Ricardo je pense ? GD
// oui le mainly c'est bien. c'est un détail pas important ici et j'ai pas du tout envie de rentrer dans le débat de oui mais une localité peut changer dans le temps...Et surtout j'explique en détail slide 18

---

## The 1850 trade network
/assets/1850 trade network.png
size: contain


[Open the 1850 trade network in Gephi Lite](https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_trade_gephi_lite.json)

This is the original 1850 trade network


---

## The 1850 resolution network
/assets/1850 resolution network.png
size: contain


[Open the 1850 resolution edges network in Gephi Lite](https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_GPH_resolution_gephi_lite.json)

This is the network of the resolution edges

Zoom to malta

mention Gephi lite



---
# Data (10)
## Harmonization process
	1. Polities resolution
	2. Trade reporters aggregation/split
	3. Trade partners aggregation
	4. Trade partners splits with year ratio method
	5. Trade reporters & partners splits with gravity model method

Bilateral trade data model
===/assets/trade data model.png
size: contain


Note that we have trade between reporters but also between reporter and partners, i.e. entity citing in sources but for which we don't have extensive source

Add Geopolitical resolution edges

From RICardo:


cypher
(Locality)-[:AGGREGATE_INTO]->(parent entity)
(Group)-[:SPLIT_INTO]->(members)


From additional data edited for this paper:


cypher
(Geographical Area)-[:SPLIT_INTO]->(members)
(Informal)-[:SPLIT_INTO]->(members)


From GeoPolHist:

cypher
(`Part of` GPH entity)-[:AGGREGATE_INTO]->(sovereign)
(Colonial Area)-[:SPLIT_INTO]->(colonies)


For colonial area we combine geographical area data table with GPH data.

// Quid des « other » ? GD
// Ce sont des locality RICardo





===/assets/multilayer_data_model_1.png
size: contain






===/assets/multilayer_data_model_2.png
size: contain



===/assets/multilayer_data_model_3.ain





Polity resolution

For each non-polity entity (source: GPH + Ricardo localities), we traverse resolution edges until finding an polity.

This method allows to traverse multiple non-polity entities until finding the good one like a group containing a part of:

cypher
(D)<-[:SPLIT]-(D & part of A)-[:SPLIT]->(part of A)-[:AGGREGATE_INTO]->(A)


Polities of **D & part of A** are **D** and **A**.

// Je ne comprends pas ce que les groupes ont à voir là dedans. Si c’est un part of ou une locality, ce n’est jamais un group ? Ou bien est-ce que c’est pour le cas où les part of/localities font partie d’un groupe ? GD
// Je ne comprends pas ce que tu ne comprends pas. On suit tous les liens de résolutions qq soit la raison pour laquelle on a créé le lien. J'ajoute un schéma symbolique PG

Trade reporters aggregation/split

Reporters needs to be treated before the partners as areas desagregations needs a stable reporter scope.

Moreover we need to treat cases of reporters overlaps. It happens that a set of reporters report part of the same trade from different perspectives.

PS: we don't split reporters trade at this step, we prepare the work for the gravity model

Trade partner aggregation

Simple task: sum the trade figure to build the new trade edge.

PS #1: do not overwrite an existing reported trade flow\
PS #2: do not create internal trade flows, discard trade flows between part of and its parent

---
# Trade partner splits with year ratio method
	Difficult task: how to decide the ratios to split one trade value into many?
	We look into **adjacent years** (+/- 10-years window) networks\
for _dissociated_ trade flows with the **same set of partners** for the same reporter.

If we find one compatible year, we calculate **split ratios** for that year and reapply those **on the original trade value**.
This process support partial split.\
If a set of partners from a group is found as one + another group, the one found will be split, the rest will stay as a group.

Special cases: Areas

Areas (geographical or colonial) are implicit groups.

The composition of the group is not explicit in the source.

We use geographical or colonial sets which we adapt to the source context:

we remove all theoretical members of the area which are already cited by the reporter
we remove those that would not be part of the trade network otherwise (not directly cited by another source)

# Trade partner/reporter splits with gravity model method
	We try to impute flows we couldn't split with the adjacent years method by using a ppml gravity model (Anderson et Van Wincoop (2003), Santos Silva & Tenreyro (2006)).
	We do this cross-section. Very far from a balanced panel
We use fixed effects on importer and exporters, geographical distance, geopolitical link existence (GeoPolHist) variables (to be extended).
The inferred values are used to compute a ratio which is then applied on the original values.
Anderson, James E., et Eric Van Wincoop. « Gravity with Gravitas: A Solution to the Border Puzzle ». _American Economic Review_, vol. 93, no 1, February 2003, p. 170‑92. DOI.org (Crossref), [https://doi.org/10.1257/000282803321455214](https://doi.org/10.1257/000282803321455214).


---
# Data (11)
## Control variables
	- distance (Centroids from Wikidata, not time varying)
	- contiguity (Correlates of War + our own work)
	- common empire (GeoPolHist up to 2022)
	- alliance (inherited from sovereign) (Alliance Treaty Obligations and Provisions (ATOP) up to 2018)
	- conflict (inherited from sovereign) (Militarized Interstate Disputes (MID) up to 2014)
	- Trade agreements (Pahre (2008)’s data up to 1913 )

---

/assets/ln_distance_fob.png
size: contain


/assets/contig12_fob.png
size: contain


/assets/common_empire_fob.png
size: contain


/assets/TA_fob.png
size: contain




/assets/atop_allie_fob.png
size: contain


/assets/mid_n_fob.png
size: contain

---

/assets/ln_distance_fob.png
size: contain

---
/assets/contig12_fob.png
size: contain
---

/assets/common_empire_fob.png
size: contain

---
/assets/TA_fob.png
size: contain

---


/assets/atop_allie_fob.png
size: contain
---

/assets/mid_n_fob.png
size: contain

---


## Examples of resolution around Malta, 1850
/assets/Malta1850.png
size: contain


[Open the 1850 examples in Gephi Lite](https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_examples_gephi_lite.json)

This is an extract around Malta in 1850 that illustrate the diversity of resolution


---

## The 1850 trade network after the gravity step
/assets/1850 post-gravity.png
size: contain


[Open the 1850 post-gravity trade network in Gephi Lite](https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_trade_gephi_lite_post_gravity.json)



---

## The 1850 trade network
/assets/1850 trade network.png
size: contain

[Open the 1850 trade network in Gephi Lite](https://lite.gephi.org/v1.0.2/?file=https://raw.githubusercontent.com/paulgirard/ricardo_gph_analysis/refs/heads/main/Pr%C3%A9sentations/2026_Turin_Paris_Bonn/1850_trade_gephi_lite.json)

// Slidev showed this as a live Gephi Lite iframe (scale 0.8). iA Presenter cannot embed web pages: add a screenshot here.

---
### How much trade do we normalise? Value
/assets/value_share_method.png
size: contain
---
### How much trade do we normalise? Flows
/assets/flows_share_method.png
size: contain


Keep it mind that we are working with the fringe of the trade networks, ou problematic flows are numerous but with smaller values on average
For the study of the extensive margin, flows are very important

The effect on the number of trade flows is much larger than on the value of trade flows



---


/assets/trade_actors.png

---


/assets/trade_flows_nbr.png


---

/assets/trade_flows_share.png


---

# II. Identifying trade communities

---

# Identifying trade communities (1)
	> « The problem of community detection requires the partition of a network into communities of densely connected nodes, with the nodes belonging to different communities being only sparsely connected »
## Trade studies: Either exogenous, or ad hoc method, such as IntraMax
	Poon (1997)
Poon, Jessie P. ‘The Cosmopolitanization of Trade Regions: Global Trends and Implications, 1965-1990’. _Economic Geography_, vol. 73, no. 4, 1997, pp. 390–404. [https://doi.org/10.2307/144560](https://doi.org/10.2307/144560).
## Network community has worked a lot on the subject
	Blondel et al. (2008) : Louvain


Network studies: Louvain

Blondel, Vincent D., Jean-Loup Guillaume, Renaud Lambiotte, and Etienne Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.” _Journal of Statistical Mechanics: Theory and Experiment_ 2008 (10): P10008.

---

## Anderson and Norheim (1993)’s blocs as a reference
/assets/carte_AN2025.png
size: contain


Western Europe (including Turkey and Yugoslavia)\
Eastern Europe (East of West Germany, including Soviet Central Asia)

North America (excluding Mexico and West Indies)\
Latin America


(Japan)\
Australasia\
Developing Asia

Africa\
Middle East (as far as Iran)
Anderson, Kym, and Hege Norheim. "Is world trade becoming more regionalized?." _Review of International Economics,_ 1.2 (1993): 91-109.


Finger, Karl-Michael, Hege Norheim, and Kym Anderson. 1993. “Trends in the Regionalization of World Trade, 1928 to 1990.” In _Regional Integration and the Global Trading System_, by Kim Anderson and Richard Blackhurst. https://www.cabidigitallibrary.org/doi/full/10.5555/19941801183.

This is the most common point of view. Anderson and Norheim. Currency blocs, political trade communities, empires...

This leads to an endogeneity issue (you might pick the composition of a bloc because you see increased inbloc trade).

It also leads to fixity over time. The relevant bloc might actually change through time, and you might miss that. Most obvious example : maybe imperial blocs are important in the 1930s and 1950s, but they loose that importance through time. And now continental blocs are important because of regional trade agreements, especially the EU.

---

# Identifying trade communities (3)
## Two issues:
	1. What is the algorithm that creates the communities
	2. What is the weight/proximity mesure to use?
---
# Identifying trade communities -- Algorithms (4)
## Intramax algorithm:
	1. Computes all proximities between actors/groups
	2. Regroup the closest pair
	3. Repeat till the regrouping increases internal trade in the group by more than 10% of world trade
## Louvain algorithm:
	Louvain adds a global measure grouping quality "modularity" (Newman (2006)
	$$Q=\frac{1}{2m}.\sum_{i,j}\left({A_{i,j}}.\frac{k_i.k_j}{2m}.\delta(c_i,c_j)\right)$$
	$$Q \in[-0.5,1]$$
	Which is the ratio between the weight of links inside groups compared to random links 

$A_{i,j}$ is the weight of the link (or proximity) between polities _i_ and _j_ that we just defined
$k_i= \sum_{i}{A_{i,j}}$ is total weight of a polity’s links (it might be different from one)
$m= \frac{1}{2}.\sum_{i,j}{A_{i,j}}$ is the sum of all weights in the trade network divided by two
$c_i$ and $c_j$ are the blocs of polities _i_ and _j_. The $\delta$-function $\delta(u,v)$ is 1 if $u=v$ and 0 otherwise

M. E. J. Newman, « Modularity and community structure in networks », _Proc. Natl. Acad. Sci_. USA, vol. 103, no 23, 2006, p. 8577–8582 https://dx.doi.org/10.1073%2Fpnas.0601602103
---
/assets/Louvain_algorithm.png
size: contain
	Blondel et al.


1. All polities are put in their own bloc
2. We examine all trade partners _j_ of a polity _i_ and we assign _i_ in _j_’s bloc, where _j_’s bloc provides the largest gain in modularity. If there are no positive gains, _i_ stays in its bloc. Once all polities have been considered once, we examine them again in the same order and they can moved from bloc to bloc.
3. When all positive gain-grouping have been made, we re-create the network with the new blocs as units, considering internal trade as a self-loop. Proximity between blocs is the sum of proximity of each pair of polities. And we iterate (2 and 3) till no change in grouping is made in phase 2.
4. The result depends on the order in which polities are examined. We run it multiple time and aggregate the results.

Blondel, Vincent D., Jean-Loup Guillaume, Renaud Lambiotte, and Etienne Lefebvre. 2008. “Fast Unfolding of Communities in Large Networks.” _Journal of Statistical Mechanics: Theory and Experiment_ 2008 (10): P10008.


---
# Identifying trade communities -- weight/proximity (4)
## We can have up to four flows by pair.
	But we cannot simply look at exports or imports because of the large number of missing observations 
	In all cases, we compute 1 to 4 proximities and we take the max
	$$Max \left(P^X_{ij}; P^X_{ji}; P^M_{ij}; P^M_{ji}\right)=A_{ij}=A_{ji}$$
## 1. We can just take raw trade
## 2. Intramax proximity
	One looks for the polity/bloc pair that is the furthest from a random model of bilateral trade.\
	$X_{ij}$ is (eg) fob exports from polity/bloc _i_ to polity/bloc _j_\
	$X'_{ij}$ is counterfactual, random, no friction trade, defined as:
	$$X'_{ij}= \frac{X_{i.}}{X}\frac{X_{.j}}{X}X=\frac{X_{i.}X_{.j}}{X}$$
	Weight/Proximity: $(X_{ij}-X'_{ij})+ (X_{ji}-X'_{ji}) [+ (M_{ij}-M'_{ij})+ (M_{ji}-M'_{ji})]$

X is world exports, Xi. is polity/bloc i’s exports. X.j is exports going to  polity/bloc j.

----

	- Poon’s maximisation objective is in monetary terms, and as such gives an advantage to large polity pairs.
		- We believe if a small polity does 100% of its trade with a big one, even if this trade is small in monetary terms, they must be in the same bloc. So we normalise. Kohl & Brouwer (2014)
	Proximity =$\frac{X_{ij}-X'_{ij}}{X_{i.}},  \frac{X_{ji}-X'_{ji}}{X_{j.}}, \frac{M_{ij}-M'_{ij}}{M_{.j}} and \frac{M_{ji}-M'_{ji}}{M_{.I}}$


Kohl, Tristan, and Aleid E. Brouwer. 2014. “The Development of Trade Blocs in an Era of Globalisation.” _Environment and Planning A: Economy and Space_ 46 (7): 1535–53. https://doi.org/10.1068/a46261.


---
## 3. TIBI (Trade Intensity Bilateral Index)
	Poon’s maximisation objective can also be expressed as a ratio as in Balassa (1965)’s index of comparative advantage:
	$X_{ij}/X'_{ij}=(X_{ij}/X_{i.})/(X_{.j}/X)) \in[-1,X/X_{.j}]$.
	CEPII’s Relative Export Intensity. Eg Gaulier and Ünal-Kesenci (2004)
CEPII’s "Relative bilateral intensity of exports" Deutsch and Savage (1960), Drysdale and Garnet (1982), Freudenberg, Gaulier and Ûnal-Kensenci (1998), pp.66-68
	Iapadre (2006), Daudin et al. (2011)  mention three issues:
### Solving range variability
The maximum value of the index depends on the size of $X_{.j}
	Solution: $I¹_{ij}=(X_{ij}/X_{i.})/(X_{rj}/X)) \in[0,+\infty[$
## Solving range asymmetry
The range is not symmetric around neutrality. I1 ranges from 0 to 1 if trade is less important than expected and from 1 to infinity if trade is more important than expected. To solve that issue, we use the following index, which varies between -1 and 1 and has neutrality at 0 rather than 1:
	Solution: $I²_{ij}=(I¹_{ij}-1)/(I¹_{ij}+1) \in[-1,1]$
## Solving dynamic ambiguity
A change in the index might be in the same direction as the change in the complementary index measuring the intensity of trade between region i and all non-j regions.
	Solution: $TIBI_{ij}=(I¹_{ij}/I³_{ij}-1)/(I¹_{ij}/I³_{ij}+1) \in[-1,1]$
	Where: $I³=(1-(X_{ij}/X_{i.}))/(1-(X_{rj}/X))\in[-1,1]$


Daudin, Guillaume, Christine Rifflart, and Danielle Schweisguth. 2011. “Who Produces for Whom in the World Economy?” _Canadian Journal of Economics/Revue Canadienne d’économique_ 44 (4): 1403–37. https://doi.org/10.1111/j.1540-5982.2011.01679.x.

Iapadre, Lelio. 2006. “Regional Integration Agreements and the Geography of World Trade.” _Assessment And Measurement of Regional Integration_, 65–85.

---

## Identifying trade communities (5)

---


---

## Identifying trade communities (6)

---



/assets/carte_comm_1850.png



---



/assets/Intra-block%20trade%20share.png



---



/assets/Modularity.png



---



/assets/tibi_comparaison_avec_diff_nblocs.png



---

# IV. Determinants of trade communities

---

	Logit regression on GPH-pairs each year, on variables:

---
	- distance (Centroids from Wikidata, not time varying)
	- contiguity (Correlates of War + our own work)
	- common empire (GeoPolHist up to 2022)
	- alliance (inherited from sovereign) (Alliance Treaty Obligations and Provisions (ATOP) up to 2018)
	- conflict (inherited from sovereign) (Militarized Interstate Disputes (MID) up to 2014)

	No causality, obviously\
	We compute the incremental R² (but we need a better idea)

---



/assets/mid_n_louvain_fob.png



---



/assets/contig12_louvain_fob.png



---



/assets/atop_allie_louvain_fob.png



---



/assets/common_empire_louvain_fob.png



---



/assets/ln_dist_louvain_fob.png



---

# V. Effects of trade communities

---

## Effects of trade communities (1)

	Importance of the extensive margin

	Basic model in the trade duration litterature: Cox model with proportional hazard

	Method : cloglog. Said to be preferable to Cox model in discrete time (but still proportional hazards)

	Or even log (weakly proportional hazards) or probit?

“Proportional hazards” means that covariates multiply a shared baseline risk by a constant factor, so the ratio of risks between any two individuals never changes over time.

	Besedeš, Tibor, and Thomas J. Prusa. 2006. “Product Differentiation and Duration of US Import Trade.” _Journal of International Economics_ 70 (2): 339–58.

	Hess, Wolfgang, and Maria Persson. 2012. “The Duration of Trade Revisited: Continuous-Time versus Discrete-Time Hazards.” _Empirical Economics_ 43 (3): 1083–107.

---



/assets/trade_actors_fob.png



---



/assets/trade_flows_nbr_fob.png



---



/assets/trade_flows_share_fob.png



---



/assets/trade_share_distribution_fob.png



---



/assets/tradingobservations.png



---



/assets/tradingpairs.png



---

	- cloglog model
	- Without small flows and failed splits
	- *Duration 1* : years of directed pair existence before first trade
	- (Duration 2 : time since appearance Duration 3 : time since imputedzero (or very small trade in the n_fs case)

---



/assets/cloglogreg1.jpg



---



/assets/logit%20dur1.png



---



/assets/probit%20dur1.png



---



/assets/xtlogit%20dur1.jpg



---

# Conclusion

---

## Conclusion (1)

---
### Outline

	1. Building the two necessary databases
	2. Building yearly coherent bilateral trade matrices
	3. Identifying trade communities
	4. Finding the determinants of trade communities
	5. Finding the effects of trade communities

---
### Tentative findings

	1. The importance of trade communities has been stable pre-1913 and post-1945, The strong decline in the inter-war period has never been recovered. Source effect?
	2. But trade bloc correlates have changed
---
		- Empires were important when the existed
		- Alliances have become very important post-45 (except 1970s-1980s)
		- The effect of distance has been increasing continuously since the 1850s
	3. Trade communities are indeed important as a determinant of trade link formation

---

# Conclusion (2)

---
## Pat on the back

	Interdisciplinary work between history, economics and network science

---
## Improvements?

---
	- More primary sources on trade statistics (and a poney)
	- Change the proximity measure (TIBI would solve range variability, range asymmetry, dynamic ambiguity)
	- Distinguish unknown but non-zero trade flows and zero trade flows
	- Take ambiguity in Louvain into account
	- Progress on bloc determinants: at least, we need a trade agreement database

// One day we take that into account

---

# Any questions?

	_Slides:_ https://paulgirard.github.io/ricardo_gph_analysis/LEDa_2026/ (?)

	_Code & Data:_ https://github.com/paulgirard/ricardo_gph_analysis

	_Sources:_

---
	- RICardo: https://ricardo.medialab.sciences-po.fr
	- GeoPolHist: https://medialab.github.io/GeoPolHist

---

# Additional slides

---

// Je suis embetté par l’utilisation de Jacomy et al., parce qu’il porte essentiellement sur l’ambiguïté et sa représentation et que ce n’est pas notre sujet. Sauf si... On pourrait considérer que les nodes au positionnement ambigu sont des singletons?

	Jacomy, Mathieu, et al. « Cluster Ambiguity in Networks as Substantive Knowledge ». _Computational Humanities Research 2025_, édité par Taylor Arnold et al., Anthology of Computers and the Humanities, 2025, p. 119‑30. _anthology.ach.org_, [https://doi.org/10.63744/f3L9hsFcGqVc](https://doi.org/10.63744/f3L9hsFcGqVc).

---

# RICentities types

| **RIC type** | **Reporting % value** | **Reporting % flows** | **Partner % value** | **Partner % flows** |
|:-:|:-:|:-:|:-:|:-:|
| GPH entity | 97.3 | 95.6 | 87.2 | 81.2 |
| Locality | 0.6 | 2.5 | 4.6 | 6.5 |
| Group | 2.4 | 1.8 | 6.5 | 5.1 |
| Colonial area | 0.0 | 0.1 | 1.4 | 5.0 |
| Geographical area | - | - | 0.4 | 2.2 |

---

## Polity definition

	A very extensive definition.\
	Sufficient political autonomy to have its own trade statistics.\
	Every political status in GeoPolHist but `part of`.

	Sovereign\
	Associated state of\
	Sovereign (limited)\
	Sovereign (unrecognized)\
	Colony of\
	Dependency of\
	Possession of\
	Protectorate of

	Leased to\
	Mandated to\
	Occupied by\
	Vassal of\
	Claimed by\
	Neutral or demilitarized zone of

Definitions are available on the paper and website

// Il faudrait réfléchir à cette définition "handle trade" ne veut pas dire grand chose. La définition actuelle n’est pas extraordinaire non plus : "Occupied by" n’a pas beaucoup d’autonomie politique GD
// oui, est ce que la définition n'est pas plutôt la négation de ça a été dissout, i.e. tout ce qui n'est pas part of

---



/assets/carte_blocs_1850.png



---

# Regionalisation and globalisation

	TIBI is a measure of bilateral trade intensity that solves:

---



/assets/mid_n_intramax_fob.png



---



/assets/contig12_intramax_fob.png



---



/assets/atop_allie_intramax_fob.png



---



/assets/common_empire_intramax_fob.png



---



/assets/ln_dist_intramax_fob.png




