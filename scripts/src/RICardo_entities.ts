import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { writeFile } from "fs/promises";
import { DirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { groupBy, keyBy, max, range, sortedUniq } from "lodash";

import { GPHEntities } from "./GPH";
import conf from "./configuration.json";
import { propagateReporting } from "./graphTraversals";
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
      const new_graph = resolveOneToManyEntityTransform(+year, tradeGraphsByYear, edgeKey);
      console.log(`writing gexf for ${year}`);

      // flag partial aggregations
      new_graph.forEachEdge((e, atts, src, tgt, srcAtts, tgtAtts) => {
        // create the maxExpImp attribute
        new_graph.setEdgeAttribute(e, "maxExpImp", max([atts.Exp, atts.Imp]));
        // flag incomplete Imp or Exp
        if (atts.labels.has("GENERATED_TRADE") && atts.valueGeneratedBy === "aggregation") {
          //TODO: refacto to use same code form Exp/Imp
          // in case of aggregation we check only the non reporter end
          if (!srcAtts.reporting && atts.Exp !== undefined) {
            // check that aggregation covers all aggregated_into declarations
            const aggregatedExporters = atts.aggregatedExp?.split("|") || [];
            const exportersToAggregate = new_graph
              .filterEdges((_, atts, __, exporter) => {
                return exporter === src && atts.labels.has("AGGREGATE_INTO");
              })
              .map((e) => new_graph.getNodeAttribute(new_graph.source(e), "label"));
            if (aggregatedExporters.length > 0 && aggregatedExporters.length !== exportersToAggregate.length) {
              // partial issue report
              const missingAggregations = exportersToAggregate.filter((ita) => !aggregatedExporters.includes(ita));
              const unexpectedAggregations = aggregatedExporters.filter((ita) => !exportersToAggregate.includes(ita));
              new_graph.setEdgeAttribute(
                e,
                "partialExp",
                `${missingAggregations.length > 1 ? `missing ${missingAggregations.join("|")}` : ""}${unexpectedAggregations.length > 1 ? ` unexpected: ${unexpectedAggregations.join("|")}` : ""}`,
              );
            }
          }

          if (!tgtAtts.reporting && atts.Imp !== undefined) {
            // check that aggregation covers all aggregated_into declarations
            const aggregatedImporters = atts.aggregatedImp?.split("|") || [];
            const importersToAggregate = new_graph
              .filterEdges((_, atts, __, importer) => {
                return importer === tgt && atts.labels.has("AGGREGATE_INTO");
              })
              .map((e) => new_graph.getNodeAttribute(new_graph.source(e), "label"));
            if (aggregatedImporters.length > 0 && aggregatedImporters.length !== importersToAggregate.length) {
              // partial issue report
              const missingAggregations = importersToAggregate.filter((ita) => !aggregatedImporters.includes(ita));
              const unexpectedAggregations = aggregatedImporters.filter((ita) => !importersToAggregate.includes(ita));
              new_graph.setEdgeAttribute(
                e,
                "partialImp",
                `${missingAggregations.length > 1 ? `missing ${missingAggregations.join("|")}` : ""}${unexpectedAggregations.length > 1 ? ` unexpected: ${unexpectedAggregations.join("|")}` : ""}`,
              );
            }
          }
        }
      });

      // flag reporters created by aggregations/split
      new_graph
        .filterNodes((n, atts) => atts.reporting)
        .forEach((n) => {
          propagateReporting(new_graph, n, "AGGREGATE_INTO");
          propagateReporting(new_graph, n, "SPLIT");
        });

      writeFileSync(`../data/entity_networks/${year}_ratios.gexf`, gexf.write(new_graph), "utf8");
    } catch (e) {
      console.log(e);
    }
  });
};

entitesTransformationGraph(conf.startDate, conf.endDate + 1)
  .catch((e) => console.log(e))
  .then(() => applyRatioMethod(conf.startDate, conf.endDate + 1));
