import { flatten, uniq } from "lodash";

import { GraphEntityPartiteType, GraphType } from "./RICardo_entities";

export function resolveAutonomous(entityId: string, graph: GraphType): string[] {
  if ((graph as GraphEntityPartiteType).getNodeAttribute(entityId, "entityType") === "GPH-AUTONOMOUS-CITED")
    return [entityId];
  const autonomousEntities = uniq(
    flatten(
      graph
        // only traverse aggregate and split edges
        .filterOutboundEdges(
          entityId,
          (_, atts) => atts.labels.has("AGGREGATE_INTO") || atts.labels.has("SPLIT") || atts.labels.has("SPLIT_OTHER"),
        )
        .map((e) => {
          const n = graph.target(e);

          // Flag resolution with aggregate
          if (
            graph.getNodeAttribute(n, "type") === "entity" &&
            (graph as GraphEntityPartiteType).getNodeAttribute(n, "entityType") === "GPH-AUTONOMOUS-CITED"
          ) {
            return n;
          } else {
            if (graph.outDegree(n) > 0) return resolveAutonomous(n, graph);
            // dead-end not resolved: should we send it to rest of the world?
            else {
              console.log(`${n} is not GPH-AUTONOMOUS-CITED but does not have any outNeighbors -> rest of the World`);
              if (!graph.hasNode("restOfTheWorld"))
                (graph as GraphEntityPartiteType).addNode("restOfTheWorld", {
                  type: "entity",
                  label: "Rest Of The World",
                  entityType: "ROTW",
                  ricType: "geographical_area",
                  reporting: false,
                });
              return "restOfTheWorld";
            }
          }
        }),
    ),
  );
  if (autonomousEntities.length === 0) console.log(`could not find autonomous for ${entityId}`);
  return autonomousEntities;
}

export function resolveTradeFlow(
  graph: GraphType,
  flow: string,
  newExporter: string,
  newImporter: string,
  tradeDirection: "Exp" | "Imp",
) {
  // internal trade flows case => source = target
  if (newExporter === newImporter) {
    graph.setEdgeAttribute(flow, "status", "ignore_internal");
    return;
  } else {
    // first check if trade flow does not already exist
    if (graph.hasDirectedEdge(newExporter, newImporter)) {
      const e = graph.edge(newExporter, newImporter);
      const labels = graph.getEdgeAttribute(e, "labels");

      if (labels.has("REPORTED_TRADE") || labels.has("GENERATED_TRADE")) {
        // we already have a direct reported figure
        // flag and see later
        // erreur de type de collision
        // dans beaucoup de cas il s'agit d'aggrégation de locality
        // comment détecter et traiter ces cas ?

        if (graph.getEdgeAttribute(e, tradeDirection) !== undefined) {
          // collision
          graph.updateEdgeAttribute(e, tradeDirection, (v) => (v || 0) + (graph.getEdgeAttribute(flow, "value") || 0));
          graph.updateEdgeAttribute(e, "collision", (collision) => {
            return collision ? collision.add(tradeDirection) : new Set([tradeDirection]);
          });
          graph.setEdgeAttribute(e, "status", "ok_with_collision");
          graph.setEdgeAttribute(flow, "status", "collision");
        } else {
          // update mirror value
          graph.setEdgeAttribute(e, tradeDirection, graph.getEdgeAttribute(flow, "value"));
          graph.setEdgeAttribute(flow, "status", "ignore_resolved");
        }
      } else {
        throw new Error(
          `${newExporter}->${newImporter} can't be created as a ${[...labels].join(", ")} edge already exists`,
        );
      }
    } else {
      // re-route the edge
      graph.addDirectedEdge(newExporter, newImporter, {
        ...graph.getEdgeAttributes(flow),
        labels: new Set(["GENERATED_TRADE"]),
      });
    }
    // state the edge as resolved
    graph.setEdgeAttribute(flow, "status", "ignore_resolved");
    return;
  }
}
