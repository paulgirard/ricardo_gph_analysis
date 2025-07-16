import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { writeFile } from "fs/promises";
import { DirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { groupBy, keyBy, range, sortedUniq } from "lodash";

import { GPHEntities } from "./GPH";
import conf from "./configuration.json";
import {
  aggregateIntoAutonomousEntities,
  flagAutonomousCited,
  flagFlowsToTreat,
  resolveOneToManyEntityTransform,
  resolveOneToOneEntityTransform,
  ricEntityToGPHEntity,
  splitAreas,
  splitInformalUnknownEntities,
  tradeGraph,
} from "./tradeGraphCreation";
import { GraphEntityPartiteType, RICentity } from "./types";
import { getTradeGraphsByYear, statsEntityType } from "./utils";

export const entitesTransformationGraph = async (startYear: number, endYear: number) => {
  const RICentities: Record<string, RICentity> = keyBy<RICentity>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities.csv`), { columns: true }),
    (r) => r.RICname,
  );

  const RICgroups = groupBy<{ RICname_group: string; RICname_part: string }>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities_groups.csv`), { columns: true }),
    (r) => r.RICname_group,
  );

  const yearTradeGraphs = (
    await Promise.all(
      range(startYear, endYear, 1).map(async (year) => {
        try {
          const graph = await tradeGraph(year, RICentities);
          console.log("step 0:", JSON.stringify(statsEntityType(graph), null, 2));

          //STEP 1 RIC => GPH (but areas)
          const notGphRicNodes = (graph as GraphEntityPartiteType).filterNodes((_, atts) => atts.entityType === "RIC");
          notGphRicNodes.forEach((n) => {
            ricEntityToGPHEntity(n, graph, RICentities, RICgroups);
          });
          console.log("step 1:", JSON.stringify(statsEntityType(graph), null, 2));

          // STEP 2 GPH => GPH autonomous
          // (subEntity) -[AGGREGATE_INTO]-> (autonomous_entity)
          aggregateIntoAutonomousEntities(graph as GraphEntityPartiteType);
          console.log("step 2:", JSON.stringify(statsEntityType(graph), null, 2));

          // STEP 3 OTHERs

          // for all areas
          // (area_entity) -[SPLIT_OTHER]-> (member_entity)
          splitAreas(graph as GraphEntityPartiteType, RICentities, GPHEntities);
          splitInformalUnknownEntities(graph as GraphEntityPartiteType);

          // Detect GPH Autonomous cited
          flagAutonomousCited(graph as GraphEntityPartiteType);
          // flag flows as toTreat or ok
          flagFlowsToTreat(graph as GraphEntityPartiteType);

          // STEP 4 treat trade data
          resolveOneToOneEntityTransform(graph as GraphEntityPartiteType);
          // GEXF preparation/generation
          graph.forEachEdge((e, atts) => {
            // simplify label for Gephi Lite
            graph.setEdgeAttribute(e, "label", sortedUniq([...atts.labels]).join("|"));
          });
          // TODO layout

          await writeFile(`../data/entity_networks/${year}.gexf`, gexf.write(graph), "utf8");
          return graph;
        } catch (error) {
          console.log(`error in ${year}`);
          console.log(error);
          return null;
        }
      }),
    )
  ).filter((g): g is GraphEntityPartiteType => g !== null);

  // await applyRatioMethod(
  //   1833,
  //   1834,
  //   keyBy(yearTradeGraphs, (g) => g.getAttribute("year")),
  // ).catch((e) => console.log(e));
};

const applyRatioMethod = async (
  startYear: number,
  endYear: number,
  _tradeGraphsByYear?: Record<string, DirectedGraph>,
  edgeKey?: string,
) => {
  const tradeGraphsByYear = _tradeGraphsByYear ? _tradeGraphsByYear : await getTradeGraphsByYear();
  range(startYear, endYear).forEach((year) => {
    console.log(`****** Compute ratio for ${year}`);
    try {
      const new_graph = resolveOneToManyEntityTransform(+year, tradeGraphsByYear, edgeKey);
      console.log(`writing gexf for ${year}`);
      writeFileSync(`../data/entity_networks/${year}_ratios.gexf`, gexf.write(new_graph), "utf8");
    } catch (e) {
      console.log(e);
    }
  });
};

// we create one RESOLUTION node to inspect cases
// temporary solution to be replace by either a real resolution or Rest Of The world
// (graph as GraphResolutionPartiteType).addNode(e, {
//   type: "resolution",
//   label: graph
//     .extremities(e)
//     .map((n) => graph.getNodeAttribute(n, "label"))
//     .join("->"),
//   value: graph.getEdgeAttribute(e, "value"),
// });

// autonomousExporters.autonomousIds.forEach((exporter) => {
//   addEdgeLabel(graph, exporter, e, "RESOLVE");
// });
// autonomousImporters.autonomousIds.forEach((importer) => {
//   addEdgeLabel(graph, importer, e, "RESOLVE");
// });
//

// 1 -> n  or n -> 1 case
// parcourir les 1- a puis 1 -> b et pour chacun d'eux
// il faut à minima vérifier si on n'a pas déjà un flux
// n -> n case
// cas en attente de clef
// (newexporters) -- (RESOLUTION 1 type resolution : aggregate, split les deux, value flux d'origine) --> (newImporter)
// comment représenter les dead-ends resolutions impossible
// générer les flux 1:1
// flaggue le noeud résolution avec colision ou pas

// Tâches à faire en regardant les résolutions
// déterminer si les cas de résolution vaut la peine
// déterminer la clef de répartition de la valeur des flux
// déterminer comment résoudre les collisions avec le flux de commerce existant (somme, ajout miroire, ignorer...)

// trade edges we want to keep as is
// trade between two cited GPH autonomous

// we could start by reporting which are locality cause simple to handle

// to be treated:
// - not cited: at least one of the node is GPH autonomous but not cited
// - not autonomous: at least one of the node is GPH not autonomous
// - not GPH: at least one of the node is not GPH

// general idea:
// - follow edges recursively (AGGREGATE_INTO SPLIT_INTO ...) till the first GPH autonomous entity (cited or not)
// - we want to remove internal flows
// - find a way to transform the existing trade edge into the one or many new edges to GPH autonomous
// - some trade flow (or part of existing flow) will be redirected to a "rest of the world" entity
// - Not cited autonomous entity are not kept. Trade to not cited autonomous entities are merged to the 'Rest of the world' entity.

// - cited autonomous reporting entity trade with not interested (real partners) which we transform into a list of autonomous cited (ideal partners)
// - we must ignore the ideal partners which are already reported by the cited autonomous reporting
// - we should split the trade (to be defined later) into the ideal partner filtered list

// method which resolve one not wanted entity into a list of relevant GPH autonomous cited (recursive) + list of to-be-merged-into-rest-of-world entities
// method which filters out this list to make sure not to generate duplicated/superfluous flows (...)

// rule locality + parent are reporting: remove locality node + all flows reported by it
// rule Group :
// - split trade value with new partner part of group (see work by Béatrice and Paul to be rediscussed)
// -

// (entity) -[GENERATED_TRADE]-> (entity)

// /!\ for SPLIT_OTHER
// - remove reporting from entities
// - remove entities which are already cited in reporting trade

entitesTransformationGraph(conf.startDate, conf.endDate + 1)
  .catch((e) => console.log(e))
  .then(() => applyRatioMethod(conf.startDate, conf.endDate + 1));
// Poland "2903->290"

// "901->British East Indies" Problem with sovereign resolution British East Indies in 1833 should yield Straits Settlements
// "Cape Colony (Cape of Good Hope) & Mauritius->220" ratio decomposition should nt consider flow not with same reporter

// TODO
// log gph without status: log GPH entities sans status

// tradeTotal entity : Imp + Export et mirror si besoin
// duplicate application
// export au format Gephi lite:
