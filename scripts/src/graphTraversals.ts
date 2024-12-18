import { flatten, pick, uniq } from "lodash";

import { EntityResolutionLabelType, GraphEntityPartiteType, GraphType } from "./RICardo_entities";

export interface AutonomousResolutionType {
  autonomousIds: string[];
  traversedLabels: Set<EntityResolutionLabelType>;
}

export function resolveAutonomous(entityId: string, graph: GraphType): AutonomousResolutionType {
  if ((graph as GraphEntityPartiteType).getNodeAttribute(entityId, "entityType") === "GPH-AUTONOMOUS-CITED")
    return { autonomousIds: [entityId], traversedLabels: new Set() };
  const traversedLabels = new Set<EntityResolutionLabelType>();
  const autonomousEntities = flatten(
    graph
      // only traverse aggregate and split edges
      .filterOutboundEdges(
        entityId,
        (_, atts) => atts.labels.has("AGGREGATE_INTO") || atts.labels.has("SPLIT") || atts.labels.has("SPLIT_OTHER"),
      )
      .map((e) => {
        // track traversed labels
        graph.getEdgeAttribute(e, "labels").forEach((l) => {
          if (l === "AGGREGATE_INTO" || l === "SPLIT" || l === "SPLIT_OTHER") traversedLabels.add(l);
        });

        const n = graph.target(e);

        // Flag resolution with aggregate
        if (
          graph.getNodeAttribute(n, "type") === "entity" &&
          (graph as GraphEntityPartiteType).getNodeAttribute(n, "entityType") === "GPH-AUTONOMOUS-CITED"
        ) {
          return { autonomousIds: [n], traversedLabels };
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
            return { autonomousIds: ["restOfTheWorld"], traversedLabels };
          }
        }
      }),
    // reduce the result of recursion to merge all ids and labels into one result object
  ).reduce<AutonomousResolutionType>(
    (acc, result) => {
      return {
        autonomousIds: uniq([...acc.autonomousIds, ...result.autonomousIds]),
        traversedLabels: result.traversedLabels
          ? acc.traversedLabels.union(result.traversedLabels)
          : acc.traversedLabels,
      };
    },
    { autonomousIds: [], traversedLabels },
  );
  if (autonomousEntities.autonomousIds.length === 0) console.log(`could not find autonomous for ${entityId}`);
  return autonomousEntities;
}

const aggregatedFlowNote = (flow: string, graph: GraphType) => {
  const flowAttributes = graph.getEdgeAttributes(flow);
  const exporter = graph.getNodeAttribute(graph.source(flow), "label");
  const importer = graph.getNodeAttribute(graph.target(flow), "label");
  return `${exporter}${flowAttributes.ExpReportedBy === exporter ? " (REP) " : ""} -> ${importer} ${flowAttributes.ImpReportedBy === importer ? " (REP) " : ""} : ${graph.getEdgeAttribute(flow, "value")}`;
};

export function resolveTradeFlow(
  graph: GraphType,
  flow: string,
  newExporter: string,
  newImporter: string,
  entitiesResolutionLabels: Set<EntityResolutionLabelType>,
) {
  // internal trade flows case => source = target
  if (newExporter === newImporter) {
    graph.setEdgeAttribute(flow, "status", "ignore_internal");
    return;
  } else {
    const generatedByMethod = entitiesResolutionLabels.has("AGGREGATE_INTO") ? "aggregation" : "split_to_one";

    // first check if trade flow does not already exist
    if (graph.hasDirectedEdge(newExporter, newImporter)) {
      const e = graph.edge(newExporter, newImporter) as string;
      const labels = graph.getEdgeAttribute(e, "labels");

      if (
        (labels.has("GENERATED_TRADE") && graph.getEdgeAttribute(e, `valueGeneratedBy`) === generatedByMethod) ||
        (labels.has("REPORTED_TRADE") && graph.getEdgeAttribute(e, "value") === undefined)
      ) {
        // should we restrict to aggregation method?
        // update value by summing
        graph.updateEdgeAttribute(e, "value", (v) => (v || 0) + (graph.getEdgeAttribute(flow, "value") || 0));
        graph.setEdgeAttribute(flow, "status", "ignore_resolved");
        graph.setEdgeAttribute(flow, "aggregatedIn", e);
        graph.setEdgeAttribute(e, "labels", graph.getEdgeAttribute(e, "labels").union(new Set(["GENERATED_TRADE"])));
        // add reporters in notes
        graph.updateEdgeAttribute(e, "notes", (notes) => `${notes}\n${aggregatedFlowNote(flow, graph)}`);
      }

      // COLLISION with reported_trade
      // should we check that reported_trade is ok?
      if (labels.has("REPORTED_TRADE") && graph.getEdgeAttribute(e, "value") !== undefined) {
        // collision: we keep the reported trade and discard the incoming flow
        graph.setEdgeAttribute(flow, "status", "discard_collision");
        graph.setEdgeAttribute(flow, "notes", aggregatedFlowNote(e, graph));
        // Do we need to aggregate flows to build a mirror view?
      }
      // throw new Error(
      //   `${newExporter}->${newImporter} can't be created as a ${[...labels].join(", ")} edge already exists`,
      // );
    } else {
      // re-route the edge

      graph.addDirectedEdge(newExporter, newImporter, {
        // reuse direction and value from original flow
        ...pick(graph.getEdgeAttributes(flow), ["Exp", "Imp", "value", "ExpReportedBy", "ImpReportedBy"]),
        valueGeneratedBy: generatedByMethod,
        labels: new Set(["GENERATED_TRADE"]),
        notes: aggregatedFlowNote(flow, graph),
      });
      // state the edge as resolved
      graph.setEdgeAttribute(flow, "status", "ignore_resolved");
    }
    return;
  }
}
