import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { writeFile } from "fs/promises";
import { DirectedGraph } from "graphology";
import { groupBy, keyBy, range } from "lodash";

import { GPHEntities } from "./GPH";
import conf from "./configuration.json";
import { propagateReporting } from "./graphTraversals";
import {
  aggregateIntoAutonomousEntities,
  flagAutonomousCited,
  flagFlowsToTreat,
  resolveEntityTransform,
  resolveOneToOneEntityTransform,
  ricEntityToGPHEntity,
  splitAreas,
  splitInformalUnknownEntities,
  tradeGraph,
} from "./tradeGraphCreation";
import { GraphEntityPartiteType, RICentity } from "./types";
import { exportGephLiteFile, getTradeGraphsByYear, setReplacer, statsEntityType } from "./utils";

export const entitesTransformationGraph = async (startYear: number, endYear: number) => {
  const RICentities: Record<string, RICentity> = keyBy<RICentity>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities.csv`), { columns: true }),
    (r) => r.RICname,
  );

  const RICgroups = groupBy<{ RICname_group: string; RICname_part: string }>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities_groups.csv`), { columns: true }),
    (r) => r.RICname_group,
  );

  await Promise.all(
    range(startYear, endYear, 1).map(async (year) => {
      try {
        const graph = await tradeGraph(year, RICentities);

        console.log("step 0:", JSON.stringify(statsEntityType(graph), null, 2));

        //STEP 1 RIC => GPH (but areas)
        const notGphRicNodes = graph.filterNodes((_, atts) => atts.entityType === "RIC");
        notGphRicNodes.forEach((n) => {
          ricEntityToGPHEntity(n, graph, RICentities, RICgroups);
        });
        console.log("step 1:", JSON.stringify(statsEntityType(graph), null, 2));

        // STEP 2 GPH => GPH autonomous
        // (subEntity) -[AGGREGATE_INTO]-> (autonomous_entity)
        aggregateIntoAutonomousEntities(graph);
        console.log("step 2:", JSON.stringify(statsEntityType(graph), null, 2));

        // STEP 3 OTHERs

        // for all areas
        // (area_entity) -[SPLIT_OTHER]-> (member_entity)
        splitAreas(graph, RICentities, GPHEntities);
        splitInformalUnknownEntities(graph);

        // Detect GPH Autonomous cited
        flagAutonomousCited(graph);
        // flag flows as toTreat or ok
        flagFlowsToTreat(graph);

        // TODO: STEP 3 AGGREGATION ?

        // STEP 4 treat trade data
        resolveOneToOneEntityTransform(graph as GraphEntityPartiteType);

        await writeFile(`../data/entity_networks/${year}.json`, JSON.stringify(graph.export(), setReplacer, 2), "utf8");
        return graph;
      } catch (error) {
        console.log(`error in ${year}`);
        console.log(error);
        return null;
      }
    }),
  );
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
      const new_graph = resolveEntityTransform(+year, tradeGraphsByYear, edgeKey);
      console.log(`writing gexf for ${year}`);

      // flag partial aggregations
      (new_graph as GraphEntityPartiteType).forEachEdge((e, atts) => {
        // flag incomplete aggregations
        if (
          atts.type === "trade" &&
          atts.labels.has("GENERATED_TRADE") &&
          atts.valueGeneratedBy?.includes("aggregation")
        ) {
          const reporter = atts.reportedBy;
          const aggregatedPartners = atts.generatedFrom?.split("|") || [];
          const partnersToAggregate = new_graph
            .filterEdges((_, atts, __, aggregateDestination) => {
              return (
                atts.type === "resolution" && aggregateDestination === reporter && atts.labels.has("AGGREGATE_INTO")
              );
            })
            .map((e) => new_graph.getNodeAttribute(new_graph.source(e), "label"));
          if (aggregatedPartners.length > 0 && aggregatedPartners.length !== partnersToAggregate.length) {
            // partial issue report
            const missingAggregations = partnersToAggregate.filter((ita) => !aggregatedPartners.includes(ita));
            const unexpectedAggregations = aggregatedPartners.filter((ita) => !partnersToAggregate.includes(ita));
            (new_graph as GraphEntityPartiteType).setEdgeAttribute(
              e,
              "partial",
              `${missingAggregations.length > 1 ? `missing ${missingAggregations.join("|")}` : ""}${unexpectedAggregations.length > 1 ? ` unexpected: ${unexpectedAggregations.join("|")}` : ""}`,
            );
          }
        }
      });

      // flag reporters created by aggregations/split
      new_graph
        .filterNodes((_, atts) => atts.reporting)
        .forEach((n) => {
          propagateReporting(new_graph as GraphEntityPartiteType, n, "AGGREGATE_INTO");
          propagateReporting(new_graph as GraphEntityPartiteType, n, "SPLIT");
        });

      // export graph in graphology
      writeFileSync(
        `../data/entity_networks/${year}_ratios.json`,
        JSON.stringify(new_graph.export(), setReplacer, 2),
        "utf8",
      );

      exportGephLiteFile(new_graph, "ratios");
    } catch (e) {
      console.log(e);
    }
  });
};

entitesTransformationGraph(conf.startDate, conf.endDate + 1)
  .catch((e) => console.log(e))
  .then(() => applyRatioMethod(conf.startDate, conf.endDate + 1));
//applyRatioMethod(1833, 1834);
