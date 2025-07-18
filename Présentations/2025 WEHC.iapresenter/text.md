# Leveraging geopolitical history to deal with taxonomic diversity of trade partners in RICardo
	Guillaume Daudin, Béatrice Dedinger, Youssef Ghallada, Paul Girard, 
## WEHC 2025
## Session "Disaggregated Bilateral Trade Data, 1870-2024""


---
# The problem


---


/assets/Clipboard.png
size: contain
RICardo is trying to gather a complete bilateral trade database from 1800 to 1938.
RICardo has gathered more than c. 670,000 bilateral trade flows. Without the duplicates and the zero flows, RICardo offers a database and a web interface for c. 570,000 flows. 
As many of you will now, there are no standardization of partner names in trade statistics. Some trade statistics also come from various reporting entities, that can be in some cases only ports.
There are 442 different reporting entities and 2,069 partner entities, to be compared to between 90 and 140 entities in the Federico-Tena World Trade database
In addition, **104 reporters are not partners (Guadeloupe & Guadeloupe Dependencies : 500 flows ; Port Simon 430 flows...)
Among important partners British West Indies (2895 flows), British colonies (other) (2334 flows), French colonies (2080),... Norway&Sweden (1544), Africa (other) (1320), ... Asian Turkey (1099)
I do not think other trade databases tackle that issue, except maybe in non-systematic ways for specific flows.


---
### The different situations (both for partners and reporting)
	- Groups (eg. Norway & Seweden -- 1544 flows, partner)
	- Localities (eg Port Simon -- 430 flows, reporter)
	- Parts of (eg Asian Turkey -- 1099 flows, partner)
	- Geographical areas (eg Africa (other) 1320 flows, partner)
	- Colonial areas (eg British West Indies, 2895 flows, partner)
	- Informal (eg "Germany" before 1870)
---
# The solution
First, we must decide what are we interested in.
Most trade databases are about trade between autonomous geopolitical entities.
"GPH identifies any form of human social
community or territory that has been involved in an
international or intra-national conflict during the
post-Napoleonic period and is also geographically
based.

---

/assets/Clipboard 1.png
size: contain
The database GeoPolHist, extending the list of states and dependencies developped by the Correlate of War project, lists all geopolitical entities that have existed since 1816.

---


/assets/Clipboard 2.png
size: contain

It also provides us with the way to identify colonies, dependants, parts of, etc

---
## Algorithm
	- keep existing trade flows between GPH autonomous cited
	- generate missing flows by aggregating existing flows
	- *generate missing flows by splitting existing flows*
	- discard internal flows
	- discard all other flows (to entities which are not autonomous or to multiple entities we couldn't split)
Here are the steps of the algorithm. The one in italics is the only one that necessitate an hypothesis : we take the chronologically nearest split in a 21 years window (+/- 10 years)

---
# Preliminary results


---


/assets/FTComparison.png
size: contain


---
# Conclusion