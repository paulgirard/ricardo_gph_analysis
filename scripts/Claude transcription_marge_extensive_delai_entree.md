# Transcription : marge extensive et délai avant le début du commerce

*Conversation du 5 octobre 2026.*

---

## Utilisateur

En économie internationale, quelle est la méthode standard pour modéliser la marge extensive pour analyser économétriquement ses déterminants ?

## Claude

La méthode standard dépend de ce que l'on entend par « marge extensive », mais le cadre de référence est celui des **modèles de gravité avec sélection** et des **modèles de choix discret** (probit/logit) sur la présence d'un flux ou d'une relation commerciale.

## 1. Définir la marge extensive

- **Niveau agrégé (pays-paire)** : le nombre de produits exportés, le nombre d'exportateurs, ou l'existence même d'un flux bilatéral (commerce nul vs positif).
- **Niveau firme** : la décision d'exporter (oui/non), le nombre de destinations, le nombre de produits par firme.
- **Dynamique** : l'entrée/sortie sur un marché, la survie des relations commerciales.

## 2. Les approches économétriques standard

**a) Modèle binaire sur la participation (probit/logit)**
On modélise la probabilité qu'un flux existe : P(X_ij > 0) = Φ(β'Z_ij + effets fixes). Les déterminants typiques sont les coûts fixes (distance, langue, frontière, accords commerciaux) et la taille des marchés. Avec des effets fixes importateur et exportateur, on privilégie souvent un **logit conditionnel** ou un **modèle de probabilité linéaire (LPM)** pour éviter le problème des paramètres incidents du probit.

**b) Modèle de Helpman, Melitz et Rubinstein (2008)**
C'est la référence pour séparer les marges. Il s'agit d'une procédure en deux étapes de type **Heckman** :
1. Un probit estime la probabilité que le pays *i* exporte vers *j*, ce qui fournit un terme de correction de sélection (ratio de Mills inverse) et un terme capturant la proportion d'exportateurs (le terme de biais d'hétérogénéité des firmes).
2. L'équation de gravité sur les flux positifs est estimée en incluant ces termes de correction.

La **restriction d'exclusion** est l'enjeu clé : il faut une variable affectant les coûts fixes d'exportation mais pas les coûts variables (HMR utilisent des mesures de réglementation de l'entrée et de la procédure d'ouverture d'entreprise, ou la religion/langue commune).

**c) PPML (Santos Silva et Tenreyro, 2006)**
Pour traiter conjointement les zéros et l'hétéroscédasticité, on estime le modèle de gravité en niveau par pseudo-maximum de vraisemblance de Poisson. Ce n'est pas à proprement parler un modèle de la marge extensive, mais c'est le standard quand on ne cherche pas à séparer les deux marges avec correction de sélection. Il sert aussi de test de robustesse.

**d) Décomposition de Hummels et Klenow (2005)**
C'est une décomposition *comptable* (non économétrique) du commerce total en marge extensive (variété de produits exportés relativement au benchmark) et marge intensive (volume par produit). On régresse ensuite chaque composante sur les déterminants (PIB, population, etc.). Une alternative proche est celle de Bernard, Jensen, Redding et Schott (2009), qui décomposent le commerce en nombre de firmes, de produits par firme, et valeur moyenne par firme-produit.

**e) Données de firmes**
- Probit/logit de la décision d'exporter, avec productivité, taille, et effets fixes (secteur, année), souvent avec productivité retardée pour limiter l'endogénéité.
- **Modèles de durée** (Cox, logit à temps discret) pour la survie des relations commerciales.
- **Modèles de comptage** (Poisson, binomiale négative) pour le nombre de produits ou de destinations.
- Estimation en **deux étapes de type Wooldridge** ou modèles dynamiques (Roberts et Tybout, 1997) pour les coûts d'entrée irrécupérables et la persistance.

## 3. Points d'attention

- **Endogénéité** : utiliser des variables retardées ou des instruments, notamment pour les accords commerciaux.
- **Effets fixes multidimensionnels** : importateur-année, exportateur-année, paire (avec la librairie `ppmlhdfe` ou `reghdfe` sous Stata).
- **Gestion des zéros** : distinguer zéros « vrais » et zéros liés à l'agrégation ou à la mesure.
- **Restriction d'exclusion** pour l'approche HMR : sa crédibilité est souvent discutée.

## En résumé

La méthode canonique est le **HMR (2008)** (probit de sélection puis gravité corrigée) lorsqu'on veut modéliser explicitement la marge extensive à partir de flux bilatéraux agrégés, ou un **probit/logit/LPM avec effets fixes** sur la présence d'un flux. À l'échelle de la firme, on emploie des modèles de choix discret et de durée. Le **PPML** reste la méthode de robustesse standard pour la gravité en présence de zéros.

Si vous précisez votre niveau de données (agrégé, produit, firme) et votre question de recherche, je peux détailler la spécification et les variables d'exclusion adaptées.

---

## Utilisateur

Je veux étudier cela en dynamique : le commerce de certaines paires comment plus ou moins tôt. Quels sont les déterminants du délai avant le début du commerce ?

## Claude

Pour étudier le **délai avant le premier échange**, le cadre naturel est l'**analyse de durée (survie)** : on modélise le *taux d'entrée* (hazard) d'une paire, c'est-à-dire la probabilité de commencer à commercer l'année *t* sachant qu'elle ne le faisait pas encore. C'est la contrepartie « entrée » de la littérature sur la survie des relations commerciales (Besedeš et Prusa, 2006 ; Nitsch, 2009), qui traite surtout de la sortie.

## 1. Construire les données

- **Unité** : la paire (exportateur-importateur), éventuellement par produit ou secteur.
- **Événement** : le premier flux positif (ou supérieur à un seuil, pour limiter le bruit de mesure).
- **Population à risque** : toutes les paires sans commerce à la date *t*. Une paire sort de l'échantillon dès le premier flux.
- **Date d'origine** : c'est un choix crucial. Il peut s'agir de l'indépendance ou de la création de l'un des pays, du début des données, ou de l'entrée dans le système commercial (adhésion à l'OMC, ouverture).
- **Censure** : les paires qui n'ont toujours pas commercé à la fin de la période sont censurées à droite. Les paires qui commercent déjà au début des données sont censurées à gauche, et on les exclut ou on les traite à part.

## 2. Modèles d'estimation

**a) Modèle de Cox à risques proportionnels** : h(t | X) = h₀(t)·exp(β'X). Il ne suppose aucune forme pour la dépendance temporelle (le hazard de base), ce qui est un avantage. Il gère mal les égalités de dates (ties), très fréquentes avec des données annuelles.

**b) Modèles de durée à temps discret (cloglog ou logit)**, souvent préférés avec des données annuelles. On empile les observations paire-année dans la population à risque et on estime la probabilité d'entrée avec des dummies de durée (ou un polynôme de la durée). Le cloglog correspond à un modèle à risques proportionnels en temps continu groupé (Prentice et Gloeckler, 1978 ; Jenkins, 1995). Cette approche permet aussi les covariables variant dans le temps et les effets fixes.

**c) Modèles paramétriques (Weibull, log-logistique, AFT)** : utiles si l'on veut interpréter directement l'effet sur la durée ou si l'on a une hypothèse théorique sur la forme du hazard.

**d) Hétérogénéité non observée** : un terme de fragilité (frailty) par exportateur, importateur ou région est important, car de nombreuses paires partagent des caractéristiques inobservées. On peut aussi clusteriser les erreurs au niveau de la paire ou du pays.

**e) Modèles à fraction « guérie » (split-population)** : certaines paires *ne commerceront jamais* (coûts prohibitifs), ce qui n'est pas la même chose qu'un délai long. Un modèle de mélange sépare la probabilité de ne jamais entrer et le délai pour celles qui entrent.

**f) Risques concurrents** : si l'on distingue des types d'entrée (par exemple commerce via un pays tiers, ou premier flux dans un sens ou dans l'autre), on utilise un modèle à risques concurrents.

## 3. Déterminants à tester

| Famille | Variables typiques |
|---|---|
| **Coûts de commerce / coûts fixes** | distance, contiguïté, langue commune, passé colonial, qualité des infrastructures, coûts administratifs d'exportation et d'importation |
| **Taille et développement** | PIB (ou PIB par habitant) des deux pays, population, croissance, capacité productive |
| **Politiques et institutions** | accord commercial, adhésion à l'OMC, droits de douane, qualité institutionnelle, stabilité politique, conflits |
| **Réseaux et information** | diasporas, liens ethniques (Rauch et Watson, 2003), ambassades, commerce avec des partenaires voisins ou similaires, commerce de l'exportateur avec d'autres pays |
| **Structure productive** | similarité des structures d'exportation, avantage comparatif, diversification de l'exportateur |
| **Dépendance temporelle** | forme du hazard (effet du temps écoulé), cycle mondial |

Les variables de **réseau et de commerce avec des tiers** (« contagion commerciale ») sont souvent les plus informatives pour expliquer l'*ordre* d'entrée : un pays tend à commercer d'abord avec des partenaires proches de ceux avec qui il commerce déjà.

## 4. Problèmes d'identification

- **Endogénéité** : les accords commerciaux sont signés entre partenaires qui commercent déjà ou vont commercer. Il faut des instruments, des variables retardées, ou une approche en événement (event study) autour de l'entrée en vigueur.
- **Censure à gauche et choix de l'origine** : ils biaisent le hazard de base.
- **Seuil et mesure** : des petits flux erratiques, des erreurs de déclaration, des données miroir asymétriques peuvent créer de fausses entrées. Tester plusieurs seuils et utiliser les données des deux pays déclarants.
- **Entrées répétées** : si un flux apparaît, disparaît, puis réapparaît, on peut modéliser des spells multiples (stratifiés) ou se limiter au premier.
- **Hypothèse des risques proportionnels** : à vérifier (résidus de Schoenfeld) ; sinon on stratifie ou on interagit avec le temps.

## 5. Mise en œuvre

- **Stata** : `stset` puis `stcox` / `streg` ; `cloglog` ou `logit` sur données empilées avec dummies de durée ; `stcox ... , shared()` pour la fragilité ; `stcrreg` pour les risques concurrents.
- **R** : `survival` (`coxph`), `coxme` pour les effets aléatoires, `cmprsk` pour les risques concurrents.

## En pratique

Pour des données annuelles de paires, je recommande de partir d'un **cloglog à temps discret** sur la population à risque, avec dummies de durée, covariables gravitaires et variables de réseau, et effets fixes ou erreurs clusterisées par pays. Le Cox sert de vérification, et le modèle à fraction guérie traite la question des paires qui n'entrent jamais. Si votre question porte sur l'effet d'une politique (par exemple un accord), l'ajout d'une stratégie d'identification quasi expérimentale compte plus que le choix du modèle de durée.

Pouvez-vous me dire à quel niveau vous travaillez (pays-pays agrégé, produit, firme) et quelle période et source de données vous envisagez ? Cela me permettrait de préciser l'origine du temps et la population à risque.

---

## Utilisateur

pays-pays agrégé

## Claude

Au niveau pays-pays agrégé, l'essentiel se joue sur trois choix : l'origine du temps, la définition de l'entrée et la population à risque. Voici une spécification de départ.

## 1. Données et définition de l'événement

**Sources.** Le choix dépend de l'horizon :
- **BACI (CEPII)**, 1995-présent, flux harmonisés à partir des déclarations miroirs. C'est la source standard, mais elle déclenche vite un problème de censure à gauche (beaucoup de paires commercent déjà en 1995).
- **TRADHIST (Fouquin et Hugot, CEPII)**, 1827-2014, adaptée si vous voulez de vrais délais d'entrée sur longue période.
- **FMI DOTS** ou **COMTRADE** pour un compromis couverture/profondeur.

**Événement.** Le premier flux bilatéral positif. Deux précautions :
- Utiliser les **données miroirs** (par exemple le maximum des deux déclarations) pour limiter les faux zéros.
- Tester un **seuil** (par exemple > 10 000 USD, ou un nombre minimal de produits HS6 échangés) pour écarter les flux erratiques.

**Paire non dirigée ou dirigée.** Pour un « début du commerce », la paire non dirigée (flux dans un sens ou dans l'autre) est plus naturelle. Si la question porte sur la direction, passez aux paires dirigées avec des risques concurrents.

## 2. Origine du temps et population à risque

C'est le choix le plus structurant :

- **Origine** : l'année où les deux pays existent comme entités et où les données sont disponibles, soit max(indépendance *i*, indépendance *j*, première année des données). Les indépendances sont dans le CEPII GeoDist/Gravity ou Correlates of War.
- **Population à risque** : les paires sans commerce à *t*. Elle sort de l'échantillon à la première entrée.
- **Censure à gauche** : les paires déjà actives à l'origine ne sont pas informatives sur le délai. Il faut les exclure et le dire explicitement.
- **Conséquence pratique** : avec BACI, l'échantillon informatif est surtout composé de paires impliquant des petites économies, des États nouveaux (ex-URSS, ex-Yougoslavie, Soudan du Sud, Timor-Leste, etc.) ou des pays en développement. Cela limite la généralisation mais donne une identification crédible.

## 3. Spécification de base : cloglog à temps discret

Sur la population à risque empilée (paire-année) :

Pr(entrée_ijt = 1 | pas d'entrée avant t) = 1 − exp(−exp(α(d_ijt) + β'X_ij,t−1 + μ_i + μ_j + λ_t))

où :
- **α(d)** : le hazard de base, estimé par dummies de durée ou polynôme de la durée *d* depuis l'origine.
- **X_ij,t−1** : covariables retardées d'un an (contre la causalité inverse).
- **μ_i, μ_j** : effets fixes exportateur et importateur invariants dans le temps (ou régionaux si le nombre de paramètres pose problème).
	- **λ_t** : effets fixes année, pour les chocs mondiaux.mi
Variante robuste : un **LPM** sur la même population (`reghdfe`), qui accepte des effets fixes pays-année sans problème de paramètres incidents. Les effets marginaux sont comparables, mais le LPM n'impose pas la structure de hazard.

## 4. Les variables qui expliquent l'ordre d'entrée

**Gravité de base** : log(PIB_i × PIB_j), PIB par habitant, distance, contiguïté, langue commune, passé colonial commun.

**Coûts fixes et institutions** : accord commercial régional ou adhésion OMC des deux pays, monnaie commune, qualité institutionnelle, conflit (Correlates of War), différence de régime politique.

**Réseaux et information** (souvent le plus discriminant pour le *timing*) :
- **Diasporas** : stocks bilatéraux de migrants (Banque mondiale, UN DESA).
- **Degré de connexion** : nombre de partenaires commerciaux actuels de *i* et de *j*. Un pays déjà inséré dans les réseaux d'échange entre plus vite dans de nouvelles relations.
- **Contagion triadique** : part de *j*-voisins ou *j*-similaires avec lesquels *i* commerce déjà (par exemple le commerce de *i* avec les voisins ou la région de *j*, et réciproquement).
- **Similarité** des structures d'exportation, ou complémentarité exportations de *i*/importations de *j*.

Attention à l'endogénéité mécanique : les variables de réseau sont construites à partir du commerce lui-même, donc il faut les retarder et exclure la paire *ij* du calcul.

## 5. Inférence

- **Erreurs standard** : clusteriser au niveau de la paire est un minimum. Les observations dyadiques partageant un pays sont corrélées, donc privilégiez un **clustering dyadique** ou à deux dimensions (exportateur et importateur).
- **Hypothèse des risques proportionnels** : tester par interactions avec le temps.
- **Endogénéité des accords commerciaux** : lagger l'indicateur, tester la signature avant l'entrée en vigueur (anticipations), ou instrumenter (par exemple par la proportion de partenaires déjà liés à l'accord).

## 6. Robustesse

1. **Cox** (avec correction d'Efron pour les ex aequo) pour comparer les coefficients.
2. **Weibull ou log-logistique** pour tester la forme du hazard.
3. **Modèle à fraction guérie** pour les paires qui n'entreront jamais.
4. **Fragilité** par pays pour l'hétérogénéité non observée.
5. **Seuils alternatifs** et sources alternatives (miroir/déclarant seul).
6. **Exclusion des paires avec États nouveaux** ou, inversement, restriction à eux seuls.

## Squelette Stata

```stata
* données empilées paire-année, déjà restreintes à la population à risque
gen entree = (flux_ijt > seuil)
* dummies de durée
xi: cloglog entree i.duree ln_pib_prod ln_dist contig langue colonie ///
    rta omc_both diaspora_l1 degre_i_l1 degre_j_l1 triadique_l1 ///
    i.annee i.pays_i i.pays_j, vce(cluster paire)

* variante LPM avec effets fixes pays-année
reghdfe entree ln_pib_prod rta diaspora_l1 triadique_l1, ///
    absorb(i#annee j#annee duree) vce(cluster pays_i pays_j)
```

Les noms de variables sont des placeholders, bien entendu. Pour un clustering dyadique rigoureux, regardez les implémentations de Aronow, Samii et Assenova (2015).

Dites-moi si vous visez plutôt la période récente (BACI) ou une perspective historique longue (TRADHIST) : l'origine du temps et la population à risque diffèrent beaucoup, et je pourrais détailler l'échantillon informatif attendu.

---

## Utilisateur

Sur le long terme à la tradehist

## Claude

Sur 1827-2014, vous avez de vrais délais d'entrée, mais les problèmes de mesure deviennent plus importants que le choix du modèle. Je détaille les points qui changent par rapport à BACI. Pour les noms exacts de variables et la couverture par période, vérifiez la documentation du CEPII (Fouquin et Hugot, 2016, WP CEPII 2016-14), car je ne les cite pas de mémoire avec certitude.

## 1. Le problème central : zéro, flux manquant et non-déclaration

Dans les sources historiques, un flux absent est très souvent un flux **non observé**, pas un vrai zéro. Avant 1870 environ, peu de pays déclarent leur commerce, et la couverture du commerce colonial est inégale. Si vous codez « première observation positive » comme entrée, vous mesurez en partie l'entrée dans les statistiques.

Plusieurs précautions s'imposent :

- **Population à risque** restreinte aux paires-années où au moins un des deux pays déclare effectivement ses flux bilatéraux (donc où un zéro est observable via les données miroirs). Les paires où aucun des deux ne déclare sont exclues de l'ensemble à risque, et non codées comme « pas encore d'entrée ».
- **Indicateur de capacité statistique** en contrôle : année d'entrée du pays dans les séries de déclaration, nombre de partenaires déclarés par pays.
- **Seuil déflaté** : les flux sont en dollars courants, un seuil fixe n'a donc pas de sens sur deux siècles. Utilisez un seuil en dollars constants, ou un seuil relatif (part du commerce total du déclarant).
- **Test de falsification** : si les déterminants de l'entrée sont les mêmes que ceux de la *première déclaration*, vos résultats captent la mesure.

## 2. Origine du temps et entités politiques

- **Origine** : max(1827, date d'existence des deux entités comme unités commerciales distinctes). Les colonies posent problème, car leur commerce est souvent agrégé à celui de la métropole ou d'un empire. Définissez l'origine d'une colonie à la date où ses flux apparaissent séparément **et** où elle est une entité douanière distincte.
- **Changements de frontières** (Allemagne, URSS, Yougoslavie, Empire ottoman, Autriche-Hongrie) : traitez le successeur comme une nouvelle entité avec sa propre origine, plutôt que de raccorder les séries.
- **Censure à gauche massive** : la plupart des paires européennes et atlantiques commercent déjà en 1827. L'échantillon informatif est dominé par l'Asie, l'Afrique, l'Océanie, l'Amérique latine et les États nouveaux. Avec cet échantillon, vos résultats portent sur l'**intégration de la périphérie**, ce qu'il faut dire d'emblée.

## 3. Pas de temps et ruptures

- **Années ou périodes** : les premières décennies sont bruitées, et un pas de 5 ans (avec un cloglog ajusté à la longueur d'intervalle) réduit le bruit.
- **Interruptions** : les guerres mondiales coupent des relations existantes, donc les **entrées multiples** (spells) sont fréquentes. Deux choix : le **premier spell** seulement (plus propre pour la question posée), ou des spells multiples avec stratification par numéro de spell, en distinguant ré-entrée et première entrée.
- **Hazard de base non stationnaire** : durée depuis l'origine et année calendaire ne sont plus substituables. Avec plusieurs siècles, incluez des effets fixes d'ère (avant 1870, 1870-1914, entre-deux-guerres, 1945-1990, après 1990) *et* une fonction de la durée. L'identification vient de la variation des origines entre paires.

## 4. Déterminants propres à la perspective historique

**Technologie de transport et information** (les plus intéressants pour le timing) :
- Date de connexion de chaque pays au **télégraphe** et aux câbles sous-marins.
- Ouverture du **canal de Suez** (1869) et de Panama (1914), vapeur, réseaux ferroviaires.
- Réduction des coûts de fret (séries de Mohammed et Williamson, ou North, à adapter).

**Régimes de politique commerciale et monétaire** :
- **Étalon-or** (Lopez-Córdova et Meissner, 2003) et monnaie commune.
- Traités de commerce, clause de la nation la plus favorisée, GATT/OMC, accords régionaux.
- Tarifs douaniers quand disponibles (couverture très partielle avant 1914).

**Empire et géopolitique** :
- **Appartenance à un même empire** ou à une même zone d'influence : un lien colonial peut accélérer l'entrée, mais aussi la fausser (commerce non déclaré séparément).
- **Relations diplomatiques** (Correlates of War, base *Diplomatic Exchange*) : proxy de coûts fixes et de reconnaissance mutuelle.
- **Guerres et alliances** (COW).

**Réseaux** (comme précédemment) : degré de connexion de *i* et de *j*, commerce avec les voisins ou la région du partenaire, similarité des structures. Attention : tout ce qui est construit à partir du commerce historique hérite de ses lacunes de mesure, donc retardez et excluez la paire *ij*.

**Gravité** : PIB et population (Maddison/Bolt et van Zanden, à compléter pour les États nouveaux), distance, contiguïté, langue, passé colonial.

## 5. Endogénéité spécifique

- **Reconnaissance et indépendance** : l'entrée dans le système international peut coïncider avec les premiers échanges. Utilisez les dates de reconnaissance diplomatique comme jalon plutôt que l'indépendance seule.
- **Traités de commerce** : signés après des contacts informels, donc retardez et testez les anticipations. En l'absence d'instrument, l'event study autour de l'entrée en vigueur est plus crédible qu'un coefficient de hazard.
- **Colonisation** : décidée en partie en fonction du potentiel commercial. Soyez prudent sur l'interprétation causale.

## 6. Spécification de départ

Sur la population à risque (paire-période, première entrée) :

Pr(entrée_ijt = 1 | pas d'entrée avant t) = 1 − exp(−exp(α(d_ijt) + θ_ère(t) + β'X_ij,t−1 + μ_i + μ_j))

avec effets fixes pays (ou régionaux) en plus des effets d'ère ou d'année, et clustering dyadique.

```stata
* paires-périodes, restreintes aux cas où un zéro est observable
gen entree = (flux_miroir_def > seuil_reel)
cloglog entree i.duree ln_pib_prod ln_dist contig langue empire_commun ///
    telegraphe_both etalon_or_both diplo_l1 degre_i_l1 degre_j_l1 triadique_l1 ///
    capacite_stat_i capacite_stat_j i.ere i.pays_i i.pays_j, ///
    vce(cluster pays_i pays_j)
```

Robustesses utiles :
1. Plusieurs **seuils** et la restriction à l'échantillon « bien déclaré » (après 1870, ou paires entre grands déclarants).
2. **Cox** et **Weibull** pour comparer.
3. **Modèle à fraction guérie** : sur deux siècles, certaines paires restent sans commerce pour des raisons structurelles (très petites économies isolées).
4. **Sous-échantillons par ère**, pour voir si les déterminants changent (la distance et le réseau pèsent-ils moins après le télégraphe ?).
5. Exclusion des **entités coloniales** ou des paires impliquant un changement de frontières.

## Ce que cela permet de dire

La question qui se prête bien à ces données est le **rôle des technologies de communication et des réseaux dans le timing d'entrée sur la première mondialisation**. Elle est plus identifiable que l'effet d'un accord, et elle tire parti de la variation historique des dates de connexion.

Souhaitez-vous que je détaille le codage de la population à risque à partir des indicateurs de déclaration de TRADHIST, ou la construction des variables de réseau sans fuite mécanique ?

---

## Utilisateur

Comment exporter cette discussion dans un document extérieur?

## Claude

Le plus simple est que je produise moi-même le document ici : je peux compiler l'ensemble de la discussion (ou une version synthétisée et structurée) dans un fichier que vous téléchargez directement. Les formats possibles :

- **Word (.docx)**, pratique si vous voulez retravailler le texte ou l'intégrer à un article ou à un mémoire.
- **PDF**, pour une lecture ou un partage figés.
- **Markdown (.md)**, léger et facile à convertir (Pandoc, Obsidian, Notion, etc.).

Je peux aussi choisir entre une **transcription fidèle** des échanges et une **fiche de synthèse** qui regrouperait les points clés (méthode HMR, modèles de durée, spécification cloglog, spécificités TRADHIST, squelettes Stata). La seconde est généralement plus utile pour un travail de recherche, puisqu'elle supprime les répétitions entre les réponses.

À défaut, vous pouvez copier-coller les réponses depuis l'interface. Il existe aussi, dans les paramètres du compte, une option d'export global de vos données, mais elle concerne toutes vos conversations et non celle-ci seule. Pour les détails de cette option, je vous conseille de consulter le centre d'aide d'Anthropic (support.claude.com).

Quel format souhaitez-vous, et préférez-vous la transcription ou la synthèse ?

---

## Utilisateur

Markdown et transcription fidèle



## There is no single canonical trade reference for cloglog. The usual approach is to cite the statistical source for the model and a trade paper that applies discrete-time hazards. I'm giving these from memory, so please check the details before citing.

**Methodological foundations (the actual justification for cloglog)**
- **Prentice and Gloeckler (1978), *Biometrics***: shows that grouped data from a proportional hazards model leads to a cloglog specification.
- **Jenkins (1995), *Oxford Bulletin of Economics and Statistics***, "Easy estimation methods for discrete-time duration models": the standard applied reference for economists. His lecture notes on survival analysis, and his Stata tools such as `pgmhaz8`, are also widely used.
- **Allison (1982), *Sociological Methodology***: an early reference on discrete-time event history analysis.

**Trade applications (mostly on survival/exit)**
- **Hess and Persson (2012), *Empirical Economics***, "The duration of trade revisited": probably the closest to a trade-specific justification. They argue for discrete-time models over Cox when data are annual, because of the many tied durations. This is the reference I would check first.
- **Besedeš and Prusa (2006)**, the foundational duration-of-trade papers, rely mainly on Kaplan-Meier and Cox. They are useful for context but are not a cloglog reference.
- **Nitsch (2009)** and **Fugazza and Molina (2011)** are other survival studies worth checking for their estimation choices. I don't recall precisely which models they used.

Most of this literature models the **exit** of trade relationships, not first entry. For your entry question, you will probably cite the trade survival papers for the framing and Jenkins (1995) and Prentice and Gloeckler (1978) for the estimator. A search on "discrete-time hazard" with "export survival" or "trade relationships" should turn up more recent applications. I can run that search if you like.
