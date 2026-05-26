import { SerializedGraphDataset } from "@gephi/gephi-lite-sdk";
import { existsSync, writeFileSync } from "fs";
import { readFile } from "fs/promises";
import { MultiDirectedGraph } from "graphology";
import { circular } from "graphology-layout";
import forceAtlas2 from "graphology-layout-forceatlas2";
import type { EdgePredicate } from "graphology-types";
import { capitalize, fromPairs, groupBy, keys, mapKeys, mapValues, max, omit, range, sortBy } from "lodash";

import { GPHEntity } from "./GPH";
import conf from "./configuration.json";
import gephiLiteTemplate from "./gephi_lite_workspace_template.json";
import { resolutionEdgeKey } from "./tradeGraphCreation";
import {
  EdgeLabelType,
  EntityNodeAttributes,
  EntityResolutionLabelType,
  EntityType,
  GraphEntityPartiteType,
  GraphResolutionPartiteType,
  GraphType,
  RICentity,
  TradeEdgeAttributes,
  TradeVizEdgeAttribute,
  attributesStoredAsSets,
} from "./types";

/**
 * UTILS
 */
export const nodeId = (entity: RICentity | GPHEntity) => {
  if ("RICname" in entity) {
    if (!entity.GPH_code) return entity.RICname;
    else return entity.GPH_code;
  } else return entity.GPH_code;
};

export const statsEntityType = (graph: GraphType) => {
  return {
    nodes: graph
      .filterNodes((_, atts) => {
        atts.type === "entity";
      })
      .reduce((acc: Partial<Record<EntityType, number>>, n) => {
        const atts = graph.getNodeAttributes(n) as EntityNodeAttributes;
        return {
          ...acc,
          [atts.entityType]: (acc[atts.entityType] || 0) + 1,
        };
      }, {}),
    edges: graph.reduceEdges(
      (acc: Partial<Record<EdgeLabelType, number>>, _, atts) => ({
        ...acc,
        ...[...atts.labels].reduce((subacc, l) => ({ ...subacc, [l]: (acc[l] || 0) + 1 }), {}),
      }),
      {},
    ),
  };
};

export const addResolutionEdge = (
  graph: GraphResolutionPartiteType,
  source: string,
  target: string,
  label: EntityResolutionLabelType,
) => {
  const edgeKey = resolutionEdgeKey(source, target);
  const existingResolution = graph.hasEdge(edgeKey);
  if (existingResolution)
    graph.mergeEdgeAttributes(edgeKey, {
      labels: new Set([...(graph.getEdgeAttribute(edgeKey, "labels") || []), label]),
    });
  else
    graph.addDirectedEdgeWithKey(resolutionEdgeKey(source, target), source, target, {
      type: "resolution",
      labels: new Set<EntityResolutionLabelType>([label]),
    });
};

export function hasResolutionEdge(
  graph: GraphResolutionPartiteType,
  source: string,
  target: string,
  label: EntityResolutionLabelType,
) {
  const edgeKey = resolutionEdgeKey(source, target);
  return graph.hasEdge(edgeKey) && graph.getEdgeAttribute(edgeKey, "labels").has(label);
}

export type GraphSerializationType = "raw" | "ratios" | "gravity";

export async function getTradeGraphsByYear(
  graphSerialization: GraphSerializationType = "raw",
): Promise<Record<number, GraphType>> {
  const graphFile = (year: number) =>
    `../data/entity_networks/${year}${graphSerialization !== "raw" ? `_${graphSerialization}` : ""}.json`;
  const GraphMap = fromPairs(
    await Promise.all<Promise<[number, GraphType]>[]>(
      range(conf.startDate, conf.endDate + 1)
        .filter((year) => existsSync(graphFile(year)))
        .map(async (year) => {
          const graph = new MultiDirectedGraph();

          graph.import(
            JSON.parse((await readFile(graphFile(year))).toString(), (key, value) =>
              attributesStoredAsSets.includes(key) ? new Set(value) : value,
            ),
          );

          return [year, graph] as [number, GraphType];
        }),
    ),
  );
  return GraphMap;
}

export function setReplacer(_: string, value: unknown) {
  if (value instanceof Set) {
    return Array.from(value);
  } else return value;
}

export function exportGephLiteFile(graph: GraphType, graphSerialization: GraphSerializationType) {
  const year = graph.getAttribute("year");
  const graphDataset: SerializedGraphDataset = { ...(gephiLiteTemplate.graphDataset as SerializedGraphDataset) };
  graphDataset.metadata.title = `${year} Ricardo GPH`;

  graphDataset.nodeData = fromPairs(graph.mapNodes((n, atts) => [n, omit(atts, "type")]));

  graphDataset.fullGraph.nodes = graph.nodes().map((n) => ({ key: n }));
  const fullGraphEdges: SerializedGraphDataset["fullGraph"]["edges"] = [];
  // Merging Edges
  const tradeEdgesMerged = groupBy(
    graph.filterEdges((_, atts) => atts.type === "trade"),
    (e) => {
      return `${graph.source(e)}->${graph.target(e)}`;
    },
  );
  const edgeData = mapValues(tradeEdgesMerged, (edgesIds, edgeKey) => {
    //merge edges
    if (edgesIds.length > 2) throw new Error(`merge should not be more than 2 ${edgesIds}`);
    const edges = edgesIds.map((e) => ({ ...(graph as GraphEntityPartiteType).getEdgeAttributes(e), id: e }));
    const importerData = edges.filter((edge) => edge.reportedBy === graph.target(edge.id))[0];
    const exporterData = edges.filter((edge) => edge.reportedBy === graph.source(edge.id))[0];
    const edgeId = importerData?.id || exporterData?.id;
    try {
      fullGraphEdges.push({ source: graph.source(edgeId), target: graph.target(edgeId), key: edgeKey });
    } catch (e) {
      console.log(`${edgesIds} ${JSON.stringify(edgesIds.map((eid) => graph.getEdgeAttributes(eid)))}`);
      throw e;
    }

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
    return edgeData;
  });

  // add resolution edges
  graph
    .filterEdges((_, atts) => atts.type === "resolution")
    .forEach((e) => {
      const newKey = `${graph.source(e)}->${graph.target(e)}`;

      if (edgeData[newKey] !== undefined) {
        // merge labels if collision (i.e. for internal trade cases)
        edgeData[newKey].labels = edgeData[newKey].labels.union(graph.getEdgeAttribute(e, "labels"));
        edgeData[newKey].type = "trade&resolution";
      } else {
        fullGraphEdges.push({ source: graph.source(e), target: graph.target(e), key: newKey });
        edgeData[newKey] = {
          labels: (graph as GraphResolutionPartiteType).getEdgeAttribute(e, "labels"),
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
  circular.assign(graph, { scale: 100 });
  const positions = forceAtlas2(graph, { iterations: 200 });
  graphDataset.layout = positions;
  writeFileSync(
    `../data/entity_networks/${year}_${graphSerialization}_gephi_lite.json`,
    JSON.stringify({ ...gephiLiteTemplate, graphDataset }),
  );
}

export function unMirroredTradeNetworkDensity(
  graph: GraphEntityPartiteType,
  edgeFilter: EdgePredicate<EntityNodeAttributes, TradeEdgeAttributes>,
) {
  const nodes = new Set<string>();
  const edgesGroups = groupBy(graph.filterEdges(edgeFilter), (e) => {
    // group mirrors
    nodes.add(graph.source(e));
    nodes.add(graph.target(e));
    return `${graph.source(e)}->${graph.target(e)}`;
  });
  const nbEdges = keys(edgesGroups).length;
  const nbNodes = nodes.size;

  // directed graph density
  return nbEdges / (nbNodes * (nbNodes - 1));
}
