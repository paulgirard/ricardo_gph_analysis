import { flatten, uniq } from "lodash";

import { GraphType } from "./RICardo_entities";

export function resolveAutonomous(entityId: string, graph: GraphType): string[] {
  return uniq(
    flatten(
      graph.outNeighbors(entityId).map((n) => {
        // TODO : ne pas prendre les liens de commerce

        // AGGREAGATE_INTO SPLIT_INTO...
        // Flag resolution with aggregate
        if (graph.getNodeAttribute(n, "entityType") === "GPH-AUTONOMOUS-CITED") {
          return n;
        } else {
          if (graph.outDegree(n) > 0) return resolveAutonomous(n, graph);
          // dead-end not resolved: should we send it to rest of the world?
          else throw new Error(`${n} is not GPH-AUTONOMOUS-CITED but does not have any outNeighbors`);
        }
      }),
    ),
  );
}
