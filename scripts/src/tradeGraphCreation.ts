import { MultiDirectedGraph } from "graphology";
import { flatten, sum, toPairs, uniq } from "lodash";

import { DB } from "./DB";
import { GPHEntity, GPH_informal_parts, GPH_status, autonomousGPHEntity } from "./GPH";
import { colonialAreasToGeographicalArea, geographicalAreasMembers } from "./areas";
import { findBilateralRatios } from "./bilateralRatios";
import { generateTradeFlow, resolveAutonomous } from "./graphTraversals";
import {
  EntityNodeAttributes,
  GraphAttributes,
  GraphEntityPartiteType,
  GraphResolutionPartiteType,
  GraphType,
  RICentity,
  TradeEdgeAttributes,
} from "./types";
import { addResolutionEdge, hasResolutionEdge, nodeId, setReplacer } from "./utils";

export function tradeEdgeKey(reporter: string, partner: string, direction: "Exp" | "Imp") {
  return `${reporter}${direction === "Exp" ? "->" : "<-"}${partner}`;
}
export function resolutionEdgeKey(source: string, target: string) {
  return `${source}-resolve-into-${target}`;
}

/**
 * Create a year trade graph from RICardo
 * @param year
 * @param RICentities
 * @returns
 */
export async function tradeGraph(year: number, RICentities: Record<string, RICentity>) {
  const promise = new Promise<GraphEntityPartiteType>((resolve, reject) => {
    const db = DB.get();
    db.all(
      `SELECT reporting, reporting_type, reporting_parent_entity, partner, partner_type, partner_parent_entity, flow, unit, rate, expimp 
          FROM flow_joined
          WHERE
            flow is not null and rate is not null AND
            year = ${year} AND
            (partner is not null AND (partner not LIKE 'world%'))
    `,
      function (err, rows) {
        console.log(year);
        if (err) reject(err);

        const graph = new MultiDirectedGraph<EntityNodeAttributes, TradeEdgeAttributes, GraphAttributes>();
        graph.setAttribute("year", year);

        // trade network (baseline)

        // (reporting) -[REPORTED_TRADE]-> (partner)
        rows.forEach((r) => {
          const reporting = RICentities[r.reporting];

          graph.mergeNode(nodeId(reporting), {
            label: reporting.RICname,
            reporting: true,
            ricType: reporting.type,
            cited: true,
            entityType: reporting.type === "GPH_entity" ? "GPH" : "RIC",
            ricParent: reporting.parent_entity,
            type: "entity",
            gphStatus:
              reporting.type === "GPH_entity" && reporting.GPH_code
                ? GPH_status(reporting.GPH_code, graph.getAttribute("year") + "")?.status
                : undefined,
          });
          const partner = RICentities[r.partner];
          if (partner) {
            graph.mergeNode(nodeId(partner), {
              label: partner.RICname,
              ricType: partner.type,
              cited: true,
              entityType: partner.type === "GPH_entity" ? "GPH" : "RIC",
              ricParent: partner.parent_entity,
              type: "entity",
              gphStatus:
                partner.type === "GPH_entity" && partner.GPH_code
                  ? GPH_status(partner.GPH_code, graph.getAttribute("year") + "")?.status
                  : undefined,
            });
            const from = r.expimp === "Exp" ? nodeId(reporting) : nodeId(partner);
            const to = r.expimp === "Imp" ? nodeId(reporting) : nodeId(partner);
            // add trade value on directed edges: bilateral trade
            graph.mergeDirectedEdgeWithKey(tradeEdgeKey(nodeId(reporting), nodeId(partner), r.expimp), from, to, {
              labels: new Set(["REPORTED_TRADE"]),
              // add reported by attribute to trade flows
              reportedBy: nodeId(reporting),
              value: (r.flow * r.unit) / (r.rate + 0 || 1),
              type: "trade",
            });
          } else console.log(`unknown partner ${r.partner}`);
        });

        graph.forEachNode((node) => {
          // add trade value on nodes: weightedDegree (sum of bilateral trade of connected edges)
          if (graph.getNodeAttribute(node, "type") === "entity")
            (graph as GraphEntityPartiteType).setNodeAttribute(
              node,
              "totalBilateralTrade",
              // TODO: do we use exp or imp to calculate total trade
              graph
                .outEdges(node)
                .filter((e) => {
                  // if the node is reporting only use its own reported figures
                  if ((graph as GraphEntityPartiteType).getNodeAttribute(node, "reporting"))
                    return graph.getEdgeAttribute(e, "reportedBy") === node;
                  // else use the mirror values
                  return true;
                })
                .reduce((total: number, e) => {
                  const tradeValue = graph.getEdgeAttribute(e, "value") || 0;
                  return total + tradeValue;
                }, 0),
            );
        });
        resolve(graph);
      },
    );
  });
  return promise;
}

/**
 * Transform RICentities to GPHEntities
 * @param RICname
 * @param graph
 */
export const ricEntityToGPHEntity = (
  RICname: string,
  graph: GraphType,
  RICentities: Record<string, RICentity>,
  RICgroups: Record<
    string,
    {
      RICname_group: string;
      RICname_part: string;
    }[]
  >,
) => {
  const RICentity = RICentities[RICname];
  // make sur the entity is in the graph
  if (!graph.hasNode(nodeId(RICentity))) {
    graph.addNode(nodeId(RICentity), {
      label: RICentity.RICname,
      reporting: false,
      cited: false,
      ricType: RICentity.type,
      entityType: RICentity.type === "GPH_entity" ? "GPH" : "RIC",
      ricParent: RICentity.parent_entity,
      type: "entity",
      gphStatus:
        RICentity.type === "GPH_entity" && RICentity.GPH_code
          ? GPH_status(RICentity.GPH_code, graph.getAttribute("year") + "")?.status
          : undefined,
    });
  }

  switch (RICentity.type) {
    case "locality":
      // (locality) -[AGGREGATE_INTO]-> (parent)
      if (RICentity.parent_entity) {
        const parent = RICentities[RICentity.parent_entity];
        if (!graph.hasNode(parent)) {
          // recursion on this new parent
          ricEntityToGPHEntity(parent.RICname, graph, RICentities, RICgroups);
        }
        // for now we store all transformation steps, no shortcut to final (after recursion) solution
        addResolutionEdge(graph as GraphResolutionPartiteType, nodeId(RICentity), nodeId(parent), "AGGREGATE_INTO");
      } else console.warn(`${RICname} is locality without parent`);
      break;
    case "group":
      // (entity) -[SPLIT]-> (entity)
      if (RICgroups[RICname])
        RICgroups[RICname].forEach((group_part) => {
          const part = RICentities[group_part.RICname_part];
          // treat group part by recursion if not already seen
          if (!graph.hasNode(nodeId(part))) ricEntityToGPHEntity(part.RICname, graph, RICentities, RICgroups);
          // for now we store all transformation steps, no shortcut to final (after recursion) solution
          // consider group parts as cited
          graph.setNodeAttribute(nodeId(part), "cited", true);
          addResolutionEdge(graph as GraphResolutionPartiteType, nodeId(RICentity), nodeId(part), "SPLIT");
        });
      else console.log(`UNKNOWN GROUP ${RICname}`);
      break;
    default:
    // anothing to do: areas will be done later, GPH are good as is
  }
};

/**
 * aggregate GPH entities into their autonomous parent
 * @param graph
 */
export function aggregateIntoAutonomousEntities(graph: GraphType) {
  const GphNodes = graph.filterNodes((_, atts) => atts.entityType === "GPH");
  GphNodes.forEach((n) => {
    const {
      entity: targetGPHEntity,
      status: targetStatus,
      autonomous,
    } = autonomousGPHEntity(n, graph.getAttribute("year"));
    //merge node
    graph.mergeNode(nodeId(targetGPHEntity), {
      label: targetGPHEntity.GPH_name,
      gphStatus: targetStatus,
      entityType: autonomous ? "GPH-AUTONOMOUS" : "GPH",
      type: "entity",
    });
    if (nodeId(targetGPHEntity) !== n) {
      addResolutionEdge(graph as GraphResolutionPartiteType, n, nodeId(targetGPHEntity), "AGGREGATE_INTO");
    }
  });
}
/**
 * split areas: (area_entity) -[SPLIT_OTHER]-> (member_entity)
 * @param graph
 * @param RICentities
 * @param GPHEntities
 */
export function splitAreas(graph: GraphType, RICentities: Record<string, RICentity>, GPHEntities: GPHEntity[]) {
  const year = graph.getAttribute("year");
  graph
    .filterNodes((_, atts) => atts.type === "entity" && ["geographical_area", "colonial_area"].includes(atts.ricType))
    .forEach((n) => {
      const entityGraph = graph as GraphEntityPartiteType;
      const atts = entityGraph.getNodeAttributes(n);
      // find geographical areas members (combine the two tables)
      const colonialEmpire =
        atts.ricParent && RICentities[atts.ricParent] ? RICentities[atts.ricParent].GPH_code : undefined;
      // geographical area if not colony
      let geographical = atts.label;
      // this area can be a continent or world
      let continental = [
        "Adriatic",
        "Africa",
        "America",
        "Antarctic",
        "Arctic",
        "Asia",
        "Atlantic",
        "Baltic",
        "Europe",
        "Mediterranean",
        "Oceania",
        "Pacific",
        "Red Sea",
      ].includes(geographical);

      const translationToGeo = colonialAreasToGeographicalArea[atts.label];
      if (atts.ricType === "colonial_area" && translationToGeo) {
        geographical = translationToGeo.geographical_area;
        // WORLD and continent special cases
        continental = translationToGeo.continental === "yes";
      }
      const world = geographical === "World";

      if (geographical) {
        // retrieve members of the geographical area
        let ms: Pick<GPHEntity, "GPH_code" | "GPH_name" | "continent">[] = geographicalAreasMembers[geographical];
        // for continental and World we have to list from GPH
        if (continental || world) {
          //list all GPH for the continent
          ms = world ? GPHEntities : GPHEntities.filter((entity) => entity.continent === geographical);
        }
        if (ms)
          ms.forEach((member) => {
            const memberStatus = GPH_status(member.GPH_code, year + "", true);

            // filter geographical areas members with
            // - colony of (only for colonial areas)
            if (
              atts.ricType === "geographical_area" ||
              (memberStatus !== null &&
                memberStatus.status === "Colony of" &&
                memberStatus.sovereign === colonialEmpire)
            ) {
              // /!\ Could Danish Europe contain Danemark?
              // add member to the graph as autonomous resolution
              const autonomousMember = autonomousGPHEntity(member.GPH_code, year);
              if (
                autonomousMember.entity.GPH_code !== n &&
                autonomousMember.status !== undefined
                // opened question : should we restrict to autonomous or filter out discovered/unknown status
                //autonomousMember.autonomous === true
                //graph.degree(autonomousMember.entity.GPH_code) > 0
              ) {
                if (!graph.hasNode(autonomousMember.entity.GPH_code)) {
                  graph.addNode(nodeId(autonomousMember.entity), {
                    type: "entity",
                    entityType: autonomousMember.autonomous ? "GPH-AUTONOMOUS" : "GPH",
                    gphStatus: autonomousMember.status,
                    label: autonomousMember.entity.GPH_name,
                    reporting: false,
                    ricType: "GPH_entity",
                  });
                }

                addResolutionEdge(
                  graph as GraphResolutionPartiteType,
                  n,
                  autonomousMember.entity.GPH_code,
                  "SPLIT_OTHER",
                );
              }
            }
          });
      } else console.warn(`colonial area not in geographical translation table: ${atts.label}`);
    });
}

export function splitInformalUnknownEntities(graph: GraphType) {
  // treat informal and no Known GPH status cases
  const year = graph.getAttribute("year");
  graph
    // todo : apply to all undefined GPH status
    .filterNodes((_, atts) => atts.type === "entity" && atts.entityType === "GPH" && atts.gphStatus === "Informal")
    .forEach((informalNode) => {
      //console.log("treating informal", informalNode, atts);
      const parts = GPH_informal_parts(informalNode, year);
      console.log(`found ${parts.length} parts for ${informalNode}`, parts);
      if (parts.length > 0) {
        parts.forEach((p) => {
          // TODO: remove from those the one which have a political link to another entity the year studied
          // not easy to do lot of false negative, the in graph filter might suffice.
          //console.log(p, graph.hasNode(p) && graph.degree(p));
          if (graph.hasNode(p) && graph.degree(p) > 0)
            addResolutionEdge(graph as GraphResolutionPartiteType, informalNode, p, "SPLIT_OTHER");
        });
      }
      //else console.warn(`no parts for informal ${informalNode} in year ${year}`);
    });
}

/**
 * flag autonomous as cited
 * @param graph
 */
export function flagAutonomousCited(graph: GraphType) {
  graph.forEachNode((n, atts) => {
    if (atts.type === "entity" && atts.entityType === "GPH-AUTONOMOUS") {
      if (
        atts.cited === true ||
        // grant GPH-AUTONOMOUS-CITED status to sovereign whose one locality is cited
        graph.filterInNeighbors(n, (nb) => {
          return (
            graph.getNodeAttribute(nb, "cited") &&
            hasResolutionEdge(graph as GraphResolutionPartiteType, nb, n, "AGGREGATE_INTO")
          );
        }).length > 0
      ) {
        graph.setNodeAttribute(n, "entityType", "GPH-AUTONOMOUS-CITED");
      }
    }
  });
}

/**
 * flag trade flows that need treatment
 * @param graph
 */
export function flagFlowsToTreat(graph: GraphEntityPartiteType) {
  graph.forEachEdge((e, atts) => {
    // flag edges to be treated
    if (atts.type === "trade" && atts.labels.has("REPORTED_TRADE")) {
      if (graph.extremities(e).every((n) => graph.getNodeAttribute(n, "entityType") === "GPH-AUTONOMOUS-CITED"))
        graph.setEdgeAttribute(e, "status", "ok");
      else graph.setEdgeAttribute(e, "status", "toTreat");
    }
  });
}

export function resolveOneToOneEntityTransform(graph: GraphEntityPartiteType) {
  graph
    .filterEdges((_, atts) => atts.status === "toTreat")
    .forEach((e) => {
      const edgeToTreatAtts = graph.getEdgeAttributes(e);
      const autonomousExporters = resolveAutonomous(graph.source(e), graph as GraphEntityPartiteType);
      const autonomousImporters = resolveAutonomous(graph.target(e), graph as GraphEntityPartiteType);

      if (autonomousExporters.autonomousIds.length === 1 && autonomousImporters.autonomousIds.length === 1) {
        // case of simple resolution 1:1

        generateTradeFlow(
          graph,
          e,
          autonomousExporters.autonomousIds[0],
          autonomousImporters.autonomousIds[0],
          autonomousExporters.traversedLabels.union(autonomousImporters.traversedLabels),
          edgeToTreatAtts.value,
          edgeToTreatAtts.reportedBy === graph.source(e) ? "exporter" : "importer",
        );

        graph.setEdgeAttribute(e, "status", "ignore_resolved");
      }
    });
}

export function resolveEntityTransform(
  year: number,
  tradeGraphsByYear: Record<string, GraphEntityPartiteType>,
  edgeKey?: string,
) {
  const graph = tradeGraphsByYear[year].copy() as GraphEntityPartiteType;
  if (!graph) {
    throw new Error(`No trade graph available for year ${year}`);
  } else {
    (graph as GraphEntityPartiteType)
      .filterEdges((e, atts) => (edgeKey ? e === edgeKey : atts.type === "trade" && atts.status === "toTreat"))
      .forEach((e) => {
        const edgeToTreatAtts = graph.getEdgeAttributes(e);
        const valueReportedBy = edgeToTreatAtts.reportedBy === graph.source(e) ? "exporter" : "importer";
        console.log(
          `treating flow (${graph.source(e)}: ${graph.getNodeAttribute(graph.source(e), "label")})->(${graph.target(e)}:${graph.getNodeAttribute(graph.target(e), "label")})`,
        );

        const autonomousExporters = resolveAutonomous(graph.source(e), graph as GraphEntityPartiteType);
        const autonomousImporters = resolveAutonomous(graph.target(e), graph as GraphEntityPartiteType);

        // remove entities from split destination which are already reported by reporting
        const reportedPartners = new Set(
          flatten(
            graph
              .filterEdges(
                edgeToTreatAtts.reportedBy,
                (_, atts) =>
                  atts.type === "trade" &&
                  atts.labels.has("REPORTED_TRADE") &&
                  atts.reportedBy === edgeToTreatAtts.reportedBy,
              )
              .map((e) => graph.extremities(e).filter((other) => other !== edgeToTreatAtts.reportedBy)),
          ),
        );
        //remove also the reporter
        const autonomousPartnersIds = (
          edgeToTreatAtts.reportedBy === graph.source(e)
            ? autonomousImporters.autonomousIds
            : autonomousExporters.autonomousIds
        ).filter((e) => !reportedPartners.has(e) && e !== edgeToTreatAtts.reportedBy);
        const autonomousReporterIds =
          edgeToTreatAtts.reportedBy === graph.source(e)
            ? autonomousExporters.autonomousIds
            : autonomousImporters.autonomousIds;

        if (autonomousReporterIds.length !== 1) {
          // we can't split reporting side
          graph.setEdgeAttribute(e, "status", "split_failed_error");
          console.log(
            `we can't split reporting side for reporter ${graph.getNodeAttribute(edgeToTreatAtts.reportedBy, "label")} ${autonomousReporterIds}`,
          );
          return;
          //  const message = `n->n or 0->0 case: ${graph.source(e)} transform to ${autonomousExporters.autonomousIds.length} ${graph.target(e)} transform to ${autonomousImporters.autonomousIds.length}`;
          //   console.log(message);
          //   graph.setEdgeAttribute(e, "notes", message);
        }
        const reporterId = autonomousReporterIds[0];
        const reporterLabel = graph.getNodeAttribute(reporterId, "label");

        if (autonomousPartnersIds.length > 0) {
          // case 1->1
          if (autonomousPartnersIds.length === 1) {
            generateTradeFlow(
              graph,
              e,
              autonomousExporters.autonomousIds[0],
              autonomousImporters.autonomousIds[0],
              autonomousExporters.traversedLabels.union(autonomousImporters.traversedLabels),
              edgeToTreatAtts.value,
              valueReportedBy,
            );

            graph.setEdgeAttribute(e, "status", "ignore_resolved");
            return;
          }

          // case 1->n

          const splitSide = autonomousImporters.autonomousIds.length === 1 ? "Import" : "Export";

          const valueToSplit = edgeToTreatAtts.value;

          // check the 1 side is the reporter side
          if (
            valueToSplit !== undefined &&
            ((valueReportedBy === "importer" && autonomousImporters.autonomousIds.length === 1) ||
              (valueReportedBy === "exporter" && autonomousExporters.autonomousIds.length === 1))
          ) {
            console.log(
              `looking for ratios for ${year} ${reporterLabel} ${reporterId} ${valueToSplit} to/from ${autonomousPartnersIds}`,
            );
            // we need to find the percentages to split the value of the flow among the destinations
            const ratios = findBilateralRatios(year, reporterId, autonomousPartnersIds, splitSide, tradeGraphsByYear);

            // redirect
            const solved = toPairs(ratios).filter(([_, { status, ratio }]) => status === "ok" && ratio !== undefined);
            let solvedRatio = 0;
            if (solved.length > 0)
              solved.forEach(([partner, { ratio }]) => {
                if (ratio !== undefined) {
                  solvedRatio += ratio;
                  generateTradeFlow(
                    graph,
                    e,
                    splitSide === "Export" ? reporterId : partner,
                    splitSide === "Export" ? partner : reporterId,
                    new Set(["SPLIT"]),
                    ratio * valueToSplit,
                    valueReportedBy,
                  );
                }
              });

            const failed = toPairs(ratios).filter(([_, { status, ratio }]) => status !== "ok" || ratio === undefined);
            // check data coherence: ratio in groups should be the same as the remaining ratio after solved cases
            // group ratio are actually duplicated by partner by the findBilateralRatios method. We need to deduplicate them before summing.
            // We could also just do not check and just use 1-solvedRatio
            //TODO: failedRatio calculus is bad
            const failedRatio = Number(sum(uniq(failed.map(([_, { ratio }]) => ratio || 0))).toFixed(2));
            // we dont create flows to rest of the world for now
            // instead we indicate the destinations to try to impute missing flow from gravity model
            if (failed.length === 1) {
              const newPartner = failed[0][0];
              generateTradeFlow(
                graph,
                e,
                splitSide === "Export" ? reporterId : newPartner,
                splitSide === "Export" ? newPartner : reporterId,
                new Set(["SPLIT"]),
                (1 - solvedRatio) * valueToSplit,
                valueReportedBy,
              );
              // mark flow as solved
              graph.setEdgeAttribute(e, "status", "ignore_resolved");
              return;
            }
            //create flow trade to be imputed by gravity model
            failed
              // TODO: decide what to do with ROW partner
              .filter(([newPartner]) => newPartner !== "restOfTheWorld")
              .forEach(([newPartner, _]) => {
                const source = splitSide === "Export" ? reporterId : newPartner;
                const target = splitSide === "Export" ? newPartner : reporterId;

                const newEdgeKey = tradeEdgeKey(reporterId, newPartner, splitSide === "Export" ? "Exp" : "Imp");
                if (graph.hasEdge(newEdgeKey)) {
                  if (
                    graph.getEdgeAttribute(newEdgeKey, "type") === "trade" &&
                    (graph.getEdgeAttribute(newEdgeKey, "labels").has("REPORTED_TRADE") ||
                      graph.getEdgeAttribute(newEdgeKey, "labels").has("GENERATED_TRADE") ||
                      graph.getEdgeAttribute(newEdgeKey, "labels").has("TO_IMPUTE"))
                  )
                    // ignore to impute as trade already exists
                    return;
                  else
                    throw new Error(
                      `${newEdgeKey} already exist but should be imputed from ${JSON.stringify({ id: e, ...edgeToTreatAtts }, setReplacer, 2)} ${JSON.stringify(graph.getEdgeAttributes(newEdgeKey), setReplacer, 2)}`,
                    );
                } else {
                  graph.addDirectedEdgeWithKey(newEdgeKey, source, target, {
                    labels: new Set(["TO_IMPUTE"]),
                    status: "to_impute",
                    reportedBy: valueReportedBy === "importer" ? target : source,
                    originalReporters: new Set([edgeToTreatAtts.reportedBy]),
                    value: undefined,
                    valueToSplit: valueToSplit * (1 - solvedRatio),
                    originalReportedTradeFlowId: e,
                    type: "trade",
                  });
                }
              });

            if (solved.length > 0 && Number((1 - solvedRatio).toFixed(2)) !== failedRatio) {
              console.log(
                `error in calculating the remaining SPLIT ratios to send to restOfTheWorld`,
                failedRatio,
                failed.map(([_, { ratio }]) => ratio),
                uniq(failed.map(([_, { ratio }]) => ratio)),
              );
            }

            // flag flow if failed or partial split
            if (solved.length === 0) graph.setEdgeAttribute(e, "status", "split_failed_no_ratio");
            if (solved.length > 0 && solved.length < autonomousPartnersIds.length)
              graph.setEdgeAttribute(e, "status", "split_only_partial");
          } else {
            console.log(
              `1->n where 1- entity ${reporterId}-[${splitSide}]-${reporterLabel} is not reporting. ${JSON.stringify(edgeToTreatAtts)}`,
            );
            graph.setEdgeAttribute(
              e,
              "notes",
              `1->n where 1- entity ${reporterId}-[${splitSide}]-${reporterLabel} is not reporting. ${JSON.stringify(edgeToTreatAtts)}`,
            );
            // flag flow as error is done below
            graph.setEdgeAttribute(e, "status", "split_failed_error");
          }
        } else {
          // case 1 -> 0

          // redirect to rest of the world

          generateTradeFlow(
            graph,
            e,
            autonomousReporterIds[0],
            "restOfTheWorld",
            new Set(["SPLIT"]),
            edgeToTreatAtts.value,
            valueReportedBy,
          );

          graph.setEdgeAttribute(e, "status", "ignore_resolved");
        }
      });
  }
  return graph as GraphType;
}
