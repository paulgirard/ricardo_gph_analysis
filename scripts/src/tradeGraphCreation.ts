import { MultiDirectedGraph } from "graphology";
import { flatten, fromPairs, identity, sortBy, sum, toPairs, uniq, values } from "lodash";

import { DB } from "./DB";
import { GPHEntitiesByCode, GPHEntity, GPH_informal_parts, GPH_status, autonomousGPHEntity } from "./GPH";
import { colonialAreasToGeographicalArea, geographicalAreasMembers } from "./areas";
import { findBilateralRatios } from "./bilateralRatios";
import { generateTradeFlow, resolutionOrigins, resolveAutonomous, tradingPartners } from "./graphTraversals";
import {
  EntityNodeAttributes,
  GraphAttributes,
  GraphEntityPartiteType,
  GraphResolutionPartiteType,
  GraphType,
  RICentity,
  TradeEdgeAttributes,
  TradeEdgeStatus,
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
            (partner is not null AND (partner not LIKE 'world%')) AND
            reporting != partner AND
            flow != 0
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
                ? GPH_status(reporting.GPH_code, graph.getAttribute("year") + "")?.GPH_status
                : undefined,
            lat: reporting.GPH_code ? GPHEntitiesByCode[reporting.GPH_code].lat : undefined,
            lng: reporting.GPH_code ? GPHEntitiesByCode[reporting.GPH_code].lng : undefined,
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
                  ? GPH_status(partner.GPH_code, graph.getAttribute("year") + "")?.GPH_status
                  : undefined,
              lat: reporting.GPH_code ? GPHEntitiesByCode[reporting.GPH_code].lat : undefined,
              lng: reporting.GPH_code ? GPHEntitiesByCode[reporting.GPH_code].lng : undefined,
            });
            console.log(reporting, partner, r.expimp);
            const from = r.expimp === "Exp" ? nodeId(reporting) : nodeId(partner);
            const to = r.expimp === "Imp" ? nodeId(reporting) : nodeId(partner);
            // add trade value on directed edges: bilateral trade
            console.log(from, to, reporting, partner, r.expimp);
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
          ? GPH_status(RICentity.GPH_code, graph.getAttribute("year") + "")?.GPH_status
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
      ricType: "GPH_entity",
      type: "entity",
      lat: targetGPHEntity.GPH_code ? GPHEntitiesByCode[targetGPHEntity.GPH_code].lat : undefined,
      lng: targetGPHEntity.GPH_code ? GPHEntitiesByCode[targetGPHEntity.GPH_code].lng : undefined,
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
                memberStatus.GPH_status === "Colony of" &&
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
      else {
        graph.setEdgeAttribute(e, "status", "toTreat");
      }
    }
  });
  // catch cases of reporting part of another reporting
  graph.forEachNode((badReporting, atts) => {
    if (atts.reporting === true && atts.entityType !== "GPH-AUTONOMOUS-CITED") {
      // reporting not autonomous
      // does it need aggregation to a reporting entity
      graph.forEachOutboundEdge(badReporting, (__, eAtts, ___, target) => {
        if (eAtts.labels.has("AGGREGATE_INTO") && graph.getNodeAttribute(target, "reporting") === true) {
          graph
            .filterEdges((_, tradeEdgeAtts) => {
              // find all trade flows from badReporting
              return tradeEdgeAtts.reportedBy === badReporting;
            })
            .forEach((e) => graph.setEdgeAttribute(e, "status", "ignore_duplicate"));
        }
      });
    }
  });
}

/**
 * treatReporters: aggregate/split all flows from non autonomous reporters into their sovereign reporters
 * @param graph
 */
export function treatReporters(graph: GraphType) {
  const tradeFlowStatusToKeep: TradeEdgeStatus[] = ["ok", "toTreat", "split_failed_no_ratio", "split_only_partial"];
  graph
    .filterNodes((_, atts) => atts.reporting && atts.entityType !== "GPH-AUTONOMOUS-CITED")
    .forEach((badReporter) => {
      const autonomousReporters = resolveAutonomous(badReporter, graph as GraphEntityPartiteType);
      const allreportedFlows = (graph as GraphEntityPartiteType).filterEdges(badReporter, (_, eAtts) => {
        // we consider both reported_trade and generated_trade but discard the ignore ones
        return (
          eAtts.type === "trade" &&
          eAtts.reportedBy === badReporter &&
          eAtts.status !== undefined &&
          tradeFlowStatusToKeep.includes(eAtts.status)
        );
      });

      if (autonomousReporters.autonomousIds.length === 1) {
        const autonomousReporter = autonomousReporters.autonomousIds[0];
        // check if autonomousReporter is not already reporting
        if (graph.getNodeAttribute(autonomousReporter, "reporting") === true) {
          //mark all trade flows as to ignore_duplicate as the autonomous already reports trade
          allreportedFlows.forEach((e) => {
            (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "ignore_duplicate");
          });
          return;
        }
        // move all reported trade flows from badReporter to autonomousReporter
        allreportedFlows.forEach((edgeToTreat) => {
          const edgeToTreatAtts = (graph as GraphEntityPartiteType).getEdgeAttributes(edgeToTreat);

          const originalPartner =
            graph.source(edgeToTreat) === badReporter ? graph.target(edgeToTreat) : graph.source(edgeToTreat);
          // finding the partners depends on trad status
          let partnerIds = [originalPartner];
          switch (edgeToTreatAtts.status) {
            case "split_failed_no_ratio":
            case "split_only_partial":
              if (edgeToTreatAtts.newPartners) partnerIds = edgeToTreatAtts.newPartners?.split("|");
              break;
            case "toTreat":
              partnerIds = resolveAutonomous(originalPartner, graph as GraphEntityPartiteType).autonomousIds;
              break;
            // default just use the value defined before switch block
          }
          if (partnerIds.length === 1) {
            // easy case just reroute trade flow
            const newPartner = partnerIds[0];
            generateTradeFlow(
              graph as GraphEntityPartiteType,
              edgeToTreat,
              graph.source(edgeToTreat) === badReporter ? autonomousReporter : newPartner,
              graph.target(edgeToTreat) === badReporter ? autonomousReporter : newPartner,
              new Set(["AGGREGATE_INTO"]),
              edgeToTreatAtts.value,
              badReporter === graph.source(edgeToTreat) ? "exporter" : "importer",
            );

            // TODO: whould we check generateTradeFlow result.status?
            (graph as GraphEntityPartiteType).setEdgeAttribute(edgeToTreat, "status", "ignore_resolved");
          } else {
            // here we have a failed split to handle with a reporter aggregation on top
            // our solve attempt is to look for ratio by looking at other part of reporter for the same reporter which would report trade to:
            // - all partners directly
            // - some partners directly but no one with unsolved trade figures
            const siblingAggregationReporters = graph
              .filterInboundEdges(
                autonomousReporter,
                (_, inEdgeAtts, source) =>
                  // filter incoming AGGREGATE_INTO edges coming from reporters
                  inEdgeAtts.labels.has("AGGREGATE_INTO") &&
                  graph.getNodeAttribute(source, "reporting") &&
                  source !== badReporter,
                // keep the reporter
              )
              .map((e) => graph.source(e));

            // TODO : should we consider cases of SPLIT of one?
            const tradeValuesByPartnersIdList = siblingAggregationReporters
              .map((siblingReporter) => {
                const okTradePartners = new Set(
                  graph
                    .filterEdges(siblingReporter, (_, eAtts) => {
                      return (
                        eAtts.type === "trade" &&
                        eAtts.labels.has("REPORTED_TRADE") &&
                        eAtts.reportedBy === siblingReporter
                      );
                    })
                    .map((e) => graph.extremities(e).filter((n) => n !== siblingReporter)[0]),
                );
                const unsolvedTradePartners = new Set(
                  flatten(
                    graph
                      .filterEdges(siblingReporter, (_, eAtts) => {
                        return (
                          eAtts.type === "trade" &&
                          eAtts.status !== "ok" &&
                          !eAtts.status?.startsWith("ignore") &&
                          eAtts.reportedBy === siblingReporter
                        );
                      })
                      .map((e) => (graph as GraphEntityPartiteType).getEdgeAttribute(e, "newPartners")?.split("|"))
                      .filter(identity),
                  ),
                );
                console.log(siblingReporter, "ok", okTradePartners, "unsolved", unsolvedTradePartners);
                // We can compute a ratio if we have some ok flows BUT non unsolved flows.
                if (
                  partnerIds.some((p) => okTradePartners.has(p)) &&
                  !partnerIds.some((p) => unsolvedTradePartners.has(p))
                ) {
                  const tradeValuesByPartnersId: Record<string, number> = fromPairs(
                    partnerIds.map((p) => {
                      const edgeKey = tradeEdgeKey(
                        siblingReporter,
                        p,
                        graph.source(edgeToTreat) === badReporter ? "Exp" : "Imp",
                      );

                      if (graph.hasEdge(edgeKey)) {
                        return [p, (graph as GraphEntityPartiteType).getEdgeAttribute(edgeKey, "value") || 0];
                      }
                      // we assume that unreported trade is of negligible value i.e. count as 0
                      else return [p, 0];
                    }),
                  );
                  return tradeValuesByPartnersId;
                }
                return null;
              })
              .filter((r) => r !== null);
            console.log(tradeValuesByPartnersIdList);
            if (tradeValuesByPartnersIdList.length > 0) {
              //weighted average ratio among partners
              const sibblingReportersTradeToPartnersTotals = tradeValuesByPartnersIdList.map((valuesForOneReporter) =>
                sum(values(valuesForOneReporter)),
              );
              const totalShareTradeOfSibblings = sum(sibblingReportersTradeToPartnersTotals);
              const ratios = fromPairs(
                partnerIds.map((p) => {
                  return [
                    p,
                    sum(tradeValuesByPartnersIdList.map((tradeValuesByPartnersId) => tradeValuesByPartnersId[p])) /
                      totalShareTradeOfSibblings,
                  ];
                }),
              );
              // split the trade flow
              partnerIds.forEach((newPartner) => {
                console.log(
                  `ratio for reporter ${badReporter}-${newPartner} value ${(edgeToTreatAtts.value || 0) * ratios[newPartner]}`,
                );
                generateTradeFlow(
                  graph as GraphEntityPartiteType,
                  edgeToTreat,
                  graph.source(edgeToTreat) === badReporter ? autonomousReporter : newPartner,
                  graph.target(edgeToTreat) === badReporter ? autonomousReporter : newPartner,
                  new Set(["AGGREGATE_INTO"]),
                  (edgeToTreatAtts.value || 0) * ratios[newPartner],
                  badReporter === graph.source(edgeToTreat) ? "exporter" : "importer",
                );
              });
              // TODO: whould we check generateTradeFlow result.status?
              (graph as GraphEntityPartiteType).setEdgeAttribute(edgeToTreat, "status", "ignore_resolved");
            } else {
              // change toTreat to split_failed
              if (edgeToTreatAtts.status === "toTreat") {
                (graph as GraphEntityPartiteType).setEdgeAttribute(edgeToTreat, "status", "split_failed_no_ratio");
                // add partner list
                (graph as GraphEntityPartiteType).setEdgeAttribute(edgeToTreat, "newPartners", partnerIds.join("|"));
              }
              // we can't split the flow let's flag it as a future aggregation to reporter
              (graph as GraphEntityPartiteType).updateEdgeAttribute(edgeToTreat, "labels", (labels) => {
                return (labels || new Set()).add("TRADE_FROM_TO_AGGREGATE_REPORTER");
              });
            }
          }

          // if (result.newEdgeId !== null) {
          //   if (autonomousPartners.autonomousIds.length > 1) {
          //     // mark the new flow as to_treat if the many partners to treat
          //     (graph as GraphEntityPartiteType).setEdgeAttribute(result.newEdgeId, "status", "toTreat");
          //   }
          //   (graph as GraphEntityPartiteType).updateEdgeAttribute(
          //     result.newEdgeId,
          //     "labels",
          //     (labels) => new Set([...(labels || []), "GENERATED_TRADE_FROM_AGGREGATED_REPORTER"]),
          //   );
          // }
          // switch (result.status) {
          //   case "internal":
          //     (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "ignore_internal");
          //     break;
          //   default:
          //     (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "ignore_resolved");
          // }
        });
      } else {
        // multiple reporters destination we can't treat those cases if areas but could work for straight flows in ratio
      }
    });
}

export function resolveOneToOneEntityTransform(graph: GraphEntityPartiteType) {
  graph
    .filterEdges(
      (_, atts) =>
        atts.status === "toTreat" && graph.getNodeAttribute(atts.reportedBy, "entityType") === "GPH-AUTONOMOUS-CITED",
    )
    .forEach((e) => {
      const edgeToTreatAtts = graph.getEdgeAttributes(e);
      // we only treat partner side
      const originalPartner = edgeToTreatAtts.reportedBy === graph.source(e) ? graph.target(e) : graph.source(e);
      const autonomousPartners = resolveAutonomous(originalPartner, graph as GraphEntityPartiteType);

      if (autonomousPartners.autonomousIds.length === 1) {
        generateTradeFlow(
          graph,
          e,
          edgeToTreatAtts.reportedBy === graph.source(e)
            ? edgeToTreatAtts.reportedBy
            : autonomousPartners.autonomousIds[0],
          edgeToTreatAtts.reportedBy === graph.target(e)
            ? edgeToTreatAtts.reportedBy
            : autonomousPartners.autonomousIds[0],
          autonomousPartners.traversedLabels,
          edgeToTreatAtts.value,
          edgeToTreatAtts.reportedBy === graph.source(e) ? "exporter" : "importer",
        );

        graph.setEdgeAttribute(e, "status", "ignore_resolved");
      }
    });
}

export function resolveEntityTransform(
  year: number,
  tradeGraphsByYear: Record<number, GraphEntityPartiteType>,
  edgeKey?: string,
) {
  const graph = tradeGraphsByYear[year].copy() as GraphType;
  if (!graph) {
    throw new Error(`No trade graph available for year ${year}`);
  } else {
    (graph as GraphEntityPartiteType)
      .filterEdges((e, atts) => (edgeKey ? e === edgeKey : atts.type === "trade" && atts.status === "toTreat"))
      .forEach((e) => {
        const edgeToTreatAtts = (graph as GraphEntityPartiteType).getEdgeAttributes(e);

        const reporterId = edgeToTreatAtts.reportedBy;
        const valueReportedBy = reporterId === graph.source(e) ? "exporter" : "importer";
        const originalPartner = reporterId === graph.source(e) ? graph.target(e) : graph.source(e);
        const autonomousPartners = resolveAutonomous(originalPartner, graph as GraphEntityPartiteType);

        // early exit condition : we don't treat reporting aggregation
        if (autonomousPartners.autonomousIds.length === 1 && originalPartner === autonomousPartners.autonomousIds[0]) {
          // nothing to do on partner side
          return;
        }

        console.log(
          `treating flow (${graph.source(e)}: ${graph.getNodeAttribute(graph.source(e), "label")})->(${graph.target(e)}:${graph.getNodeAttribute(graph.target(e), "label")})`,
        );

        // remove entities from split destination which are already reported by reporting
        const reportedPartners = tradingPartners(reporterId, graph as GraphEntityPartiteType);

        //remove also the reporter
        const autonomousPartnersIds = autonomousPartners.autonomousIds
          // remove partners which are already reported or which are the reporter itself
          .filter((partnerId) => !reportedPartners.has(partnerId) && partnerId !== reporterId)
          // remove partners which are indirect duplicates as included in more than one partner area for that reporting for that year
          // (reporting)-[:REPORTED_TRADE]->(area1)-[:SPLIT_OTHER]->(partner1)
          // (reporting)-[:REPORTED_TRADE]->(area2)-[:SPLIT_OTHER]->(partner1)
          .filter((partnerId) => {
            //if (!autonomousPartners.traversedLabels.has("SPLIT_OTHER")) return true;
            const origins = resolutionOrigins(partnerId, graph as GraphResolutionPartiteType)
              // filter origins by the ones which are reported in the reporter trade
              .filter((o) => reportedPartners.has(o));
            // if only one origin we don't have a duplication issue
            if (origins.length === 1) return true;
            else {
              //to deduplicate sort origins by area size
              const originsByIncreasingAreaSize = sortBy(
                origins,
                (o) => resolveAutonomous(o, graph).autonomousIds.length,
              );
              //check that the original partner is the smallest one
              // if the smallest (first) area is the original partner of the reported flow
              return originsByIncreasingAreaSize[0] === originalPartner;
            }
          });

        const reporterLabel = graph.getNodeAttribute(reporterId, "label");

        if (autonomousPartnersIds.length > 0) {
          // case 1->1 : normally it should already be done
          if (autonomousPartnersIds.length === 1) {
            generateTradeFlow(
              graph as GraphEntityPartiteType,
              e,
              valueReportedBy === "exporter" ? reporterId : autonomousPartnersIds[0],
              valueReportedBy === "importer" ? reporterId : autonomousPartnersIds[0],
              autonomousPartners.traversedLabels,
              edgeToTreatAtts.value,
              valueReportedBy,
            );

            (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "ignore_resolved");
            return;
          }

          // case 1->n

          // check the 1 side is the reporter side
          if (edgeToTreatAtts.value !== undefined && autonomousPartnersIds.length > 1) {
            console.log(
              `looking for ratios for ${year} ${reporterLabel} ${reporterId} ${edgeToTreatAtts.value} to/from ${autonomousPartnersIds}`,
            );
            // we need to find the percentages to split the value of the flow among the destinations
            const ratios = findBilateralRatios(
              year,
              reporterId,
              autonomousPartnersIds,
              valueReportedBy === "exporter" ? "Import" : "Export",
              tradeGraphsByYear,
            );

            // redirect
            const solved = toPairs(ratios).filter(([_, { status, ratio }]) => status === "ok" && ratio !== undefined);
            let solvedRatio = 0;
            if (solved.length > 0)
              solved.forEach(([partner, { ratio }]) => {
                if (ratio !== undefined) {
                  solvedRatio += ratio;
                  generateTradeFlow(
                    graph as GraphEntityPartiteType,
                    e,
                    valueReportedBy === "exporter" ? reporterId : partner,
                    valueReportedBy === "exporter" ? partner : reporterId,
                    new Set(["SPLIT"]),
                    ratio * (edgeToTreatAtts.value || 0),
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

            if (failed.length === 1) {
              const newPartner = failed[0][0];
              generateTradeFlow(
                graph as GraphEntityPartiteType,
                e,
                valueReportedBy === "exporter" ? reporterId : newPartner,
                valueReportedBy === "exporter" ? newPartner : reporterId,
                new Set(["SPLIT"]),
                (1 - solvedRatio) * (edgeToTreatAtts.value || 0),
                valueReportedBy,
              );
              // mark flow as solved
              (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "ignore_resolved");
            }

            failed
              // TODO: decide what to do with ROW partner
              .filter(([newPartner]) => newPartner !== "restOfTheWorld")
              .forEach(([newPartner, _]) => {
                const newEdgeKey = tradeEdgeKey(reporterId, newPartner, valueReportedBy === "exporter" ? "Exp" : "Imp");
                if (graph.hasEdge(newEdgeKey)) {
                  // Let's make sure we don't have any duplicates in our future imputations
                  throw new Error(
                    `${newEdgeKey} already exist but should be imputed from ${JSON.stringify({ id: e, ...edgeToTreatAtts }, setReplacer, 2)} ${JSON.stringify(graph.getEdgeAttributes(newEdgeKey), setReplacer, 2)}`,
                  );
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
            if (failed.length >= 1) {
              // flag flow if failed or partial split
              (graph as GraphEntityPartiteType).setEdgeAttribute(
                e,
                "valueToSplit",
                (edgeToTreatAtts.value || 0) * (1 - solvedRatio),
              );
              //(graph as GraphEntityPartiteType).setEdgeAttribute(e, "newReporter", reporterId);
              (graph as GraphEntityPartiteType).setEdgeAttribute(e, "newPartners", failed.map((f) => f[0]).join("|"));

              if (solved.length === 0)
                (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "split_failed_no_ratio");
              if (solved.length > 0 && solved.length < autonomousPartnersIds.length) {
                (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "split_only_partial");
              }
            }
          } else {
            throw new Error(`empty value for flow ${e}`);
            // console.log(
            //   `1->n where 1- entity ${reporterId}-[${splitSide}]-${reporterLabel} is not reporting. ${JSON.stringify(edgeToTreatAtts)}`,
            // );
            // (graph as GraphEntityPartiteType).setEdgeAttribute(
            //   e,
            //   "notes",
            //   `1->n where 1- entity ${reporterId}-[${splitSide}]-${reporterLabel} is not reporting. ${JSON.stringify(edgeToTreatAtts)}`,
            // );
            // // flag flow as error is done below
            // (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "split_failed_error");
          }
        } else {
          // case 1 -> 0

          // Cases :
          // - resolution du partner qui entre en collision avec un autre partner
          // - GPH n'a pas trouvé d'entité autonome

          // TODO : decide what to do with those cases?

          console.log(
            `couldn't find autonomous partners for ${edgeToTreatAtts.reportedBy === graph.source(e) ? graph.target(e) : graph.source(e)}. Original partners ${autonomousPartners.autonomousIds} but after filtering ${autonomousPartnersIds}`,
          );
          (graph as GraphEntityPartiteType).setEdgeAttribute(e, "status", "split_failed_error");
          //throw new Error(`Empty partner lists`);
        }
      });
  }
  return graph as GraphType;
}
