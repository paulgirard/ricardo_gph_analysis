import { GPHEntity } from "./GPH";
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
      .filterNodes((n, atts) => {
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
