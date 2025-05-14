import { flatten, identity, pick, uniq } from "lodash";

import { EntityResolutionLabelType, FlowValueImputationMethod, GraphEntityPartiteType, GraphType } from "./types";

export interface AutonomousResolutionType {
  autonomousIds: string[];
  traversedLabels: Set<EntityResolutionLabelType>;
}

function getEntityAutonomousResolutionEdges(
  entityNodeId: string,
  graph: GraphEntityPartiteType,
  limitToResolutionTypes: Set<EntityResolutionLabelType>,
) {
  return (
    graph
      // only traverse aggregate and split edges
      .filterOutboundEdges(entityNodeId, (_, atts) => atts.labels.intersection(limitToResolutionTypes).size > 0)
  );
}

export function resolveAutonomous(
  entityId: string,
  graph: GraphEntityPartiteType,
  limitToResolutionTypes: Set<EntityResolutionLabelType> = new Set(["AGGREGATE_INTO", "SPLIT", "SPLIT_OTHER"]),
): AutonomousResolutionType {
  if (graph.getNodeAttribute(entityId, "entityType") === "GPH-AUTONOMOUS-CITED")
    return { autonomousIds: [entityId], traversedLabels: new Set() };
  const traversedLabels = new Set<EntityResolutionLabelType>();
  const autonomousEntities = flatten(
    // only traverse aggregate and split edges
    getEntityAutonomousResolutionEdges(entityId, graph, limitToResolutionTypes).map((e) => {
      // track traversed labels
      graph.getEdgeAttribute(e, "labels").forEach((l) => {
        if (limitToResolutionTypes.has(l)) traversedLabels.add(l);
      });

      const n = graph.target(e);

      // Flag resolution with aggregate
      if (
        graph.getNodeAttribute(n, "type") === "entity" &&
        ["GPH-AUTONOMOUS-CITED", "GPH-AUTONOMOUS"].includes(graph.getNodeAttribute(n, "entityType"))
      ) {
        return { autonomousIds: [n], traversedLabels };
      } else {
        if (getEntityAutonomousResolutionEdges(n, graph, limitToResolutionTypes).length > 0)
          return resolveAutonomous(n, graph, limitToResolutionTypes);
        // dead-end not resolved: should we send it to rest of the world?
        else {
          // if (!graph.hasNode("restOfTheWorld"))
          //   graph.addNode("restOfTheWorld", {
          //     type: "entity",
          //     label: "Rest Of The World",
          //     entityType: "ROTW",
          //     ricType: "geographical_area",
          //     reporting: false,
          //   });
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
  ratio: number = 1,
) {
  // internal trade flows case => source = target
  if (newExporter === newImporter) {
    graph.setEdgeAttribute(flow, "status", "ignore_internal");
    return;
  } else {
    const generatedByMethod: FlowValueImputationMethod = entitiesResolutionLabels.has("AGGREGATE_INTO")
      ? "aggregation"
      : "split_by_years_ratio";
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
        const exp = graph.getEdgeAttribute(flow, "Exp");
        graph.updateEdgeAttribute(e, "Exp", (v) => (exp ? (v || 0) + exp * ratio : v));
        graph.updateEdgeAttribute(e, "ExpReportedBy", (v) =>
          Array.from(
            new Set([...(v ? v.split("|") : []), graph.getEdgeAttribute(flow, "ExpReportedBy")].filter(identity)),
          ).join("|"),
        );
        const imp = graph.getEdgeAttribute(flow, "Imp");
        graph.updateEdgeAttribute(e, "Imp", (v) => (imp ? (v || 0) + imp * ratio : v)) || undefined;
        graph.updateEdgeAttribute(e, "ImpReportedBy", (v) =>
          Array.from(
            new Set([...(v ? v.split("|") : []), graph.getEdgeAttribute(flow, "ImpReportedBy")].filter(identity)),
          ).join("|"),
        );
        // TODO: value should be generated at the end of the process
        graph.updateEdgeAttribute(
          e,
          "value",
          (v) => (v as number) + (graph.getEdgeAttribute(flow, "value") as number) * ratio,
        ) || undefined;

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
        // add mirror value into existing edge
        graph.updateEdgeAttribute(e, "Exp", (v) =>
          v !== undefined ? v : (graph.getEdgeAttribute(flow, "Exp") as number) * ratio || undefined,
        );
        graph.updateEdgeAttribute(e, "ExpReportedBy", (v) =>
          Array.from(
            new Set([...(v ? v.split("|") : []), graph.getEdgeAttribute(flow, "ExpReportedBy")].filter(identity)),
          ).join("|"),
        );
        graph.updateEdgeAttribute(e, "Imp", (v) =>
          v !== undefined ? v : (graph.getEdgeAttribute(flow, "Imp") as number) * ratio || undefined,
        );
        graph.updateEdgeAttribute(e, "ImpReportedBy", (v) =>
          Array.from(
            new Set([...(v ? v.split("|") : []), graph.getEdgeAttribute(flow, "ImpReportedBy")].filter(identity)),
          ).join("|"),
        );
      }
      // throw new Error(
      //   `${newExporter}->${newImporter} can't be created as a ${[...labels].join(", ")} edge already exists`,
      // );
    } else {
      // re-route the edge
      if ((newExporter === "restOfTheWorld" || newImporter === "restOfTheWorld") && !graph.hasNode("restOfTheWorld"))
        graph.addNode("restOfTheWorld", {
          type: "entity",
          label: "Rest Of The World",
          entityType: "ROTW",
          ricType: "geographical_area",
          reporting: false,
        });
      const atts = graph.getEdgeAttributes(flow);
      graph.addDirectedEdgeWithKey(`${newExporter}->${newImporter}`, newExporter, newImporter, {
        // reuse direction and value from original flow
        ...pick(atts, ["ExpReportedBy", "ImpReportedBy"]),
        // one the two should be undefined, if we have to redirect the edge there should be no mirror
        Exp: atts.Exp ? atts.Exp * ratio : undefined,
        Imp: atts.Imp ? atts.Imp * ratio : undefined,
        // TODO: value should be generated at the end of the process
        value: atts.value ? atts.value * ratio : undefined,
        valueGeneratedBy: generatedByMethod,
        labels: new Set(["GENERATED_TRADE"]),
        notes: aggregatedFlowNote(flow, graph),
        status: "ok",
      });
      // state the edge as resolved
      graph.setEdgeAttribute(flow, "status", "ignore_resolved");
    }
    return;
  }
}

export function findRelevantTradeFlowToEntity(
  graph: GraphEntityPartiteType,
  reporting: string,
  partners: string[],
  direction: "Export" | "Import",
) {
  const tradeFlows = graph.filterEdges(reporting, (_, attributes, source, target) => {
    return (
      // Keep only REPORTED_TRADE and GENERATED_TRADE
      (attributes.labels.has("REPORTED_TRADE") || attributes.labels.has("GENERATED_TRADE")) &&
      // tests to make sure we have a reported value discard mirror flow only
      (direction === "Export" ? source : target) === reporting &&
      (direction === "Export" ? attributes.Exp !== undefined : attributes.Imp !== undefined) &&
      // keep only status
      (attributes.status === "ok" || attributes.status === "toTreat")
    );
  });

  // for each trade flows of the reporting we look for the requested partners
  return tradeFlows.reduce<Record<string, Set<string>>>((acc, tf) => {
    const neighbor = direction === "Export" ? graph.target(tf) : graph.source(tf);
    // does this trade Flows directly connect the requested partner: ideal case
    if (partners.includes(neighbor)) return { ...acc, [tf]: new Set([...(acc[tf] || []), neighbor]) };

    // this trade flow can indirectly concern some partners which are the autonomous behind the declared partner
    // So we resolve the declared partner to autonomous entities

    // limit to SPLIT OTHER
    const autonomous = resolveAutonomous(neighbor, graph, new Set(["SPLIT", "SPLIT_OTHER"]));

    // And look for our partners in this list. If all of the autonomous are the searched partners we keep that flow to compute ratio.
    // if the autonomous ids does not all resolved to our partner list we must discard it as we can't use this to compute a ratio.
    // we need the set to exactly match
    if (autonomous.autonomousIds.length > 0 && autonomous.autonomousIds.every((id) => partners.includes(id)))
      return { ...acc, [tf]: new Set([...(acc[tf] || []), ...autonomous.autonomousIds]) };
    else return acc;
  }, {});
}
