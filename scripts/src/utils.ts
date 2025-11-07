import { existsSync } from "fs";
import { readFile } from "fs/promises";
import { DirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { fromPairs, range } from "lodash";

import { GPHEntity } from "./GPH";
import conf from "./configuration.json";
import { EdgeLabelType, EntityNodeAttributes, EntityType, GraphType, RICentity } from "./types";

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

export const addEdgeLabel = (graph: GraphType, source: string, target: string, label: EdgeLabelType) => {
  graph.updateDirectedEdge(source, target, (atts) => ({
    ...atts,
    labels: new Set([...(atts.labels || []), label]),
  }));
};

export async function getTradeGraphsByYear(ratios?: boolean) {
  const graphFile = (year: number) => `../data/entity_networks/${year}${ratios ? "_ratios" : ""}.gexf`;
  return fromPairs(
    await Promise.all(
      range(conf.startDate, conf.endDate + 1)
        .filter((year) => existsSync(graphFile(year)))
        .map(async (year) => {
          const graph = gexf.parse(DirectedGraph, await readFile(graphFile(year), "utf8"));
          graph.edges().forEach((e) => {
            graph.updateEdgeAttribute(e, "labels", (l) => new Set(l));
          });
          return [year, graph as GraphType];
        }),
    ),
  );
}
