import { existsSync } from "fs";
import { readFile } from "fs/promises";
import { MultiDirectedGraph } from "graphology";
import { fromPairs, range } from "lodash";

import { GPHEntity } from "./GPH";
import conf from "./configuration.json";
import { resolutionEdgeKey } from "./tradeGraphCreation";
import {
  EdgeLabelType,
  EntityNodeAttributes,
  EntityResolutionLabelType,
  EntityType,
  GraphResolutionPartiteType,
  GraphType,
  RICentity,
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

export async function getTradeGraphsByYear(ratios?: boolean) {
  const graphFile = (year: number) => `../data/entity_networks/${year}${ratios ? "_ratios" : ""}.json`;
  return fromPairs(
    await Promise.all(
      range(conf.startDate, conf.endDate + 1)
        .filter((year) => existsSync(graphFile(year)))
        .map(async (year) => {
          const graph = new MultiDirectedGraph();
          graph.import(
            JSON.parse((await readFile(graphFile(year))).toString(), (key, value) =>
              key === "labels" ? new Set(value) : value,
            ),
          );

          graph.edges().forEach((e) => {
            graph.updateEdgeAttribute(e, "labels", (l) => new Set(Array.from(l)));
          });
          return [year, graph as GraphType];
        }),
    ),
  );
}

export function setReplacer(_: string, value: unknown) {
  if (value instanceof Set) {
    return Array.from(value);
  } else return value;
}
