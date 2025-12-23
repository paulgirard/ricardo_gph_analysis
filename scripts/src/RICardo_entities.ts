import type { SerializedGraphDataset } from "@gephi/gephi-lite-sdk";
import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { writeFile } from "fs/promises";
import { DirectedGraph } from "graphology";
import { circular } from "graphology-layout";
import forceAtlas2 from "graphology-layout-forceatlas2";
import { capitalize, fromPairs, groupBy, keyBy, mapKeys, mapValues, max, omit, range, sortBy } from "lodash";

import { GPHEntities } from "./GPH";
import conf from "./configuration.json";
import gephiLiteTemplate from "./gephi_lite_workspace_template.json";
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
import {
  EdgeLabelType,
  EntityResolutionLabelType,
  GraphEntityPartiteType,
  GraphResolutionPartiteType,
  RICentity,
  TradeVizEdgeAttribute,
} from "./types";
import { getTradeGraphsByYear, setReplacer, statsEntityType } from "./utils";

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

      //TODO prepare graph for vizualisation
      const graphDataset: SerializedGraphDataset = { ...(gephiLiteTemplate.graphDataset as SerializedGraphDataset) };
      graphDataset.metadata.title = `${year} Ricardo GPH`;

      graphDataset.nodeData = fromPairs(new_graph.mapNodes((n, atts) => [n, omit(atts, "type")]));
      // TODO layout
      graphDataset.fullGraph.nodes = new_graph.nodes().map((n) => ({ key: n }));
      const fullGraphEdges: SerializedGraphDataset["fullGraph"]["edges"] = [];
      // Merging Edges
      const tradeEdgesMerged = groupBy(
        new_graph.filterEdges((_, atts) => atts.type === "trade"),
        (e) => {
          return `${new_graph.source(e)}->${new_graph.target(e)}`;
        },
      );
      const edgeData = mapValues(tradeEdgesMerged, (edgesIds, edgeKey) => {
        //merge edges
        if (edgesIds.length > 2) throw new Error(`merge should not be more than 2 ${edgesIds}`);
        const edges = edgesIds.map((e) => ({ ...(new_graph as GraphEntityPartiteType).getEdgeAttributes(e), id: e }));
        const importerData = edges.filter((edge) => edge.reportedBy === new_graph.target(edge.id))[0];
        const exporterData = edges.filter((edge) => edge.reportedBy === new_graph.source(edge.id))[0];
        const edgeId = importerData?.id || exporterData?.id;
        fullGraphEdges.push({ source: new_graph.source(edgeId), target: new_graph.target(edgeId), key: edgeKey });
        const edgeData = {
          labels: edges
            .map((e) => e.labels)
            .reduce((l, ll) => l.union(ll), new Set<EntityResolutionLabelType | EdgeLabelType>()),
          status: new Set(edges.map((e) => e.status)),
          ...(importerData ? mapKeys(omit(importerData, ["id"]), (_, k) => `importer${capitalize(k as string)}`) : {}),
          ...(exporterData ? mapKeys(omit(exporterData, ["id"]), (_, k) => `exporter${capitalize(k as string)}`) : {}),
          maxExpImp: max([importerData?.value, exporterData?.value]),
          type: "trade",
        } as TradeVizEdgeAttribute;
        if (edgeData.labels.has("GENERATED_TRADE")) console.log(edges, edgeData);
        return edgeData;
      });

      // add resolution edges
      new_graph
        .filterEdges((_, atts) => atts.type === "resolution")
        .forEach((e) => {
          const newKey = `${new_graph.source(e)}->${new_graph.target(e)}`;

          if (edgeData[newKey] !== undefined) {
            // merge labels if collision (i.e. for internal trade cases)
            edgeData[newKey].labels = edgeData[newKey].labels.union(new_graph.getEdgeAttribute(e, "labels"));
            edgeData[newKey].type = "trade&resolution";
          } else {
            fullGraphEdges.push({ source: new_graph.source(e), target: new_graph.target(e), key: newKey });
            edgeData[newKey] = {
              labels: (new_graph as GraphResolutionPartiteType).getEdgeAttribute(e, "labels"),
              type: "resolution",
            };
          }
        });

      graphDataset.edgeData = mapValues(edgeData, (attributes) =>
        mapValues(attributes, (v) => {
          // transform set and list into Gephi Lite keywords form
          if (v instanceof Set || Array.isArray(v)) {
            return sortBy(Array.from(v)).join("|");
          }
          return v;
        }),
      );
      graphDataset.fullGraph.edges = fullGraphEdges;
      circular.assign(new_graph, { scale: 100 });
      const positions = forceAtlas2(new_graph, { iterations: 200 });
      graphDataset.layout = positions;
      writeFileSync(
        `../data/entity_networks/${year}_ratios_gephi_lite.json`,
        JSON.stringify({ ...gephiLiteTemplate, graphDataset }),
      );
    } catch (e) {
      console.log(e);
    }
  });
};

entitesTransformationGraph(conf.startDate, conf.endDate + 1)
  .catch((e) => console.log(e))
  .then(() => applyRatioMethod(conf.startDate, conf.endDate + 1));
//applyRatioMethod(1833, 1834);
