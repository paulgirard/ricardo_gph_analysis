import { flatten, identity, sortBy, uniq } from "lodash";

import { tradeEdgeKey } from "./tradeGraphCreation";
import {
  EntityResolutionLabelType,
  FlowValueImputationMethod,
  GraphEntityPartiteType,
  GraphResolutionPartiteType,
  GraphType,
  ResolutionEdgeAttributes,
} from "./types";

export interface AutonomousResolutionType {
  autonomousIds: string[];
  traversedLabels: Set<EntityResolutionLabelType>;
}

function getEntityAutonomousResolutionEdges(
  entityNodeId: string,
  graph: GraphType,
  limitToResolutionTypes: Set<EntityResolutionLabelType>,
) {
  return (
    graph
      // only traverse aggregate and split edges
      .filterOutboundEdges(
        entityNodeId,
        (_, atts) => atts.type === "resolution" && atts.labels.intersection(limitToResolutionTypes).size > 0,
      )
  );
}

export function resolveAutonomous(
  entityId: string,
  graph: GraphType,
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
        if (limitToResolutionTypes.has(l as EntityResolutionLabelType))
          traversedLabels.add(l as EntityResolutionLabelType);
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

          // TODO: failure
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

export const aggregatedFlowNote = (flow: string, newValue: number, graph: GraphEntityPartiteType) => {
  const flowAttributes = graph.getEdgeAttributes(flow);
  return `${flow} ${newValue !== flowAttributes.value ? `${newValue} (ratio on ${flowAttributes.value})` : flowAttributes.value}`;
};

export function generateTradeFlow(
  graph: GraphEntityPartiteType,
  originalFlow: string,
  newExporter: string,
  newImporter: string,
  entitiesResolutionLabels: Set<EntityResolutionLabelType>,
  newValue: number | undefined,
  valueReportedBy: "importer" | "exporter",
): { newEdgeId: string | null; status: "internal" | "collision" | "created" | "merged" } {
  if (newValue === undefined) throw new Error(`can't generate trade flow from to impute trade flow`);
  if (graph.getEdgeAttribute(originalFlow, "type") !== "trade")
    throw new Error(`trying to apply trade transformation to a resolution edge ${originalFlow}`);
  // internal trade flows case => source = target
  if (newExporter === newImporter) {
    graph.setEdgeAttribute(originalFlow, "status", "ignore_internal");
    return { status: "internal", newEdgeId: null };
  } else {
    const generatedByMethod: FlowValueImputationMethod = entitiesResolutionLabels.has("AGGREGATE_INTO")
      ? "aggregation"
      : "split_by_years_ratio";

    // first check if trade flow does not already exist
    const idEdge = tradeEdgeKey(
      valueReportedBy === "importer" ? newImporter : newExporter,
      valueReportedBy === "importer" ? newExporter : newImporter,
      valueReportedBy === "importer" ? "Imp" : "Exp",
    );
    // collision
    if (graph.hasEdge(idEdge)) {
      const eAtts = graph.getEdgeAttributes(idEdge);
      const labels = graph.getEdgeAttribute(idEdge, "labels");

      if (labels.has("GENERATED_TRADE")) {
        // update value by summing
        graph.updateEdgeAttribute(idEdge, "value", (v) => (v || 0) + newValue);
        // add original reporters
        graph.updateEdgeAttribute(
          idEdge,
          `originalReporters`,
          (v) => new Set([...(v || []), graph.getEdgeAttribute(originalFlow, `reportedBy`)].filter(identity)),
        );

        graph.updateEdgeAttribute(idEdge, `generatedFrom`, (generatedFrom) =>
          sortBy(
            Array.from(
              new Set(
                [
                  ...(generatedFrom ? generatedFrom.split("|") : []),
                  graph.getNodeAttribute(
                    valueReportedBy === "exporter" ? graph.source(originalFlow) : graph.target(originalFlow),
                    "label",
                  ),
                ].filter(identity),
              ),
            ),
          ).join("|"),
        );

        graph.updateEdgeAttribute(idEdge, "valueGeneratedBy", (v) => sortBy(uniq([...(v || []), generatedByMethod])));

        // indicate in the original flow where the information has been merged
        graph.updateEdgeAttribute(originalFlow, "mergedIn", (v) => sortBy(uniq([...(v || []), idEdge])));

        graph.setEdgeAttribute(
          idEdge,
          "labels",
          graph.getEdgeAttribute(idEdge, "labels").union(new Set(["GENERATED_TRADE"])),
        );

        // add reporters in notes
        graph.updateEdgeAttribute(
          idEdge,
          "notes",
          (notes) => `${notes}\n${aggregatedFlowNote(originalFlow, newValue, graph)}`,
        );

        return { status: "merged", newEdgeId: idEdge };
      }

      // COLLISION with reported_trade
      // TODO: should we check that reported_trade is ok?
      if (labels.has("REPORTED_TRADE")) {
        return { status: "collision", newEdgeId: null };
      }
      throw new Error(`merged with wrong edge ${JSON.stringify(eAtts, null, 2)}`);
    } else {
      // create a new edge
      if ((newExporter === "restOfTheWorld" || newImporter === "restOfTheWorld") && !graph.hasNode("restOfTheWorld"))
        graph.addNode("restOfTheWorld", {
          type: "entity",
          label: "Rest Of The World",
          entityType: "ROTW",
          ricType: "geographical_area",
          reporting: false,
        });

      graph.addDirectedEdgeWithKey(idEdge, newExporter, newImporter, {
        // reuse direction and value from original flow
        value: newValue,
        valueGeneratedBy: [generatedByMethod],
        reportedBy: valueReportedBy === "exporter" ? newExporter : newImporter,
        originalReporters: new Set([graph.getEdgeAttribute(originalFlow, `reportedBy`)]),
        generatedFrom: graph.getNodeAttribute(
          valueReportedBy === "exporter" ? graph.source(originalFlow) : graph.target(originalFlow),
          "label",
        ),
        labels: new Set(["GENERATED_TRADE"]),
        notes: aggregatedFlowNote(originalFlow, newValue, graph),
        status: "ok",
        type: "trade",
      });

      // state the edge as resolved
      graph.setEdgeAttribute(originalFlow, "status", "ignore_resolved");
      graph.setEdgeAttribute(originalFlow, "mergedIn", [idEdge]);
      return { status: "created", newEdgeId: idEdge };
    }
  }
}

export function findRelevantTradeFlowToEntity(
  graph: GraphEntityPartiteType,
  reporting: string,
  partners: string[],
  direction: "Export" | "Import",
) {
  const tradeFlows = graph.filterEdges(reporting, (_, attributes) => {
    return (
      // Keep only REPORTED_TRADE and GENERATED_TRADE
      attributes.type === "trade" &&
      (attributes.labels.has("REPORTED_TRADE") || attributes.labels.has("GENERATED_TRADE")) &&
      // tests to make sure we have a reported value discard mirror flow only
      attributes.reportedBy === reporting &&
      attributes.value !== undefined &&
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

export function propagateReporting(
  graph: GraphEntityPartiteType,
  fromReporting: string,
  label: "AGGREGATE_INTO" | "SPLIT",
) {
  const reportingLabel = graph.getNodeAttribute(fromReporting, "label");
  const propagationTargets = graph
    .filterOutEdges(fromReporting, (_, atts) => atts.labels.has(label))
    .map((e) => graph.target(e));
  console.log(`propagate reporting from ${reportingLabel} to ${propagationTargets.join("|")}`);
  propagationTargets.forEach((target) => {
    const targetAtts = graph.getNodeAttributes(target);
    // we propagate reporting status if
    console.log(
      targetAtts,
      graph.filterEdges(
        target,
        (_, atts) =>
          atts.labels.has("GENERATED_TRADE") && // has one generated trade edge
          atts.reportedBy === target,
      ).length,
    );
    if (
      targetAtts.entityType === "GPH-AUTONOMOUS-CITED" &&
      targetAtts.reporting !== true && // not already a normal reporter
      graph.filterEdges(
        target,
        (_, atts) =>
          atts.labels.has("GENERATED_TRADE") && // has one generated trade edge
          atts.reportedBy === target,
      ).length > 0
    ) {
      // which contains some trade value aggregated from the original reporter
      graph.setNodeAttribute(
        target,
        label === "AGGREGATE_INTO" ? "reportingByAggregateInto" : "reportingBySplit",
        true,
      );
    } // traverse one step further
    else propagateReporting(graph, target, label);
  });
}

function isResolutionEdge(_eId: string, ieAtts: ResolutionEdgeAttributes) {
  return (["SPLIT_OTHER", "SPLIT", "AGGREGATE_INTO"] as EntityResolutionLabelType[]).some(
    (resolutionLabel: EntityResolutionLabelType) => ieAtts.labels.has(resolutionLabel),
  );
}

export function resolutionOrigins(toEntityId: string, graph: GraphResolutionPartiteType): string[] {
  return uniq(
    flatten(
      graph.filterInboundEdges(toEntityId, isResolutionEdge).map((e) => {
        // recursivity
        const origins = resolutionOrigins(graph.source(e), graph);
        // we trace all possible origins as we don't know which one could be a duplicate in reported trade
        return [graph.source(e), ...origins];
      }),
    ),
  );
}
/**
 * tradingPartners identified the trading partners of one reporter
 */
export function tradingPartners(entityId: string, graph: GraphEntityPartiteType) {
  return new Set(
    flatten(
      graph
        .filterEdges(
          entityId, //,
          (_, atts) => atts.type === "trade" && atts.labels.has("REPORTED_TRADE") && atts.reportedBy === entityId, // ignore internal trade, i.e. loop
        )
        .map((e) => graph.extremities(e).filter((other) => other !== entityId)),
    ),
  );
}
