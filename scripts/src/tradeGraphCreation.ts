import { DirectedGraph } from "graphology";
import { flatten, max, sum, toPairs, uniq } from "lodash";

import { DB } from "./DB";
import { GPHEntity, GPH_informal_parts, GPH_status, autonomousGPHEntity } from "./GPH";
import { colonialAreasToGeographicalArea, geographicalAreasMembers } from "./areas";
import { findBilateralRatios } from "./bilateralRatios";
import { resolveAutonomous, resolveTradeFlow } from "./graphTraversals";
import {
  EdgeAttributes,
  EntityNodeAttributes,
  GraphAttributes,
  GraphEntityPartiteType,
  GraphType,
  RICentity,
  ResolutionNodeAttributes,
} from "./types";
import { addEdgeLabel, nodeId } from "./utils";

/**
 * Create a year trade graph from RICardo
 * @param year
 * @param RICentities
 * @returns
 */
export async function tradeGraph(year: number, RICentities: Record<string, RICentity>) {
  const promise = new Promise<GraphType>((resolve, reject) => {
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

        const graph = new DirectedGraph<
          EntityNodeAttributes | ResolutionNodeAttributes,
          EdgeAttributes,
          GraphAttributes
        >();
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
            graph.mergeDirectedEdgeWithKey(`${from}->${to}`, from, to, {
              labels: new Set(["REPORTED_TRADE"]),
              // add reported by attribute to trade flows
              [`${r.expimp}ReportedBy`]: reporting.RICname,
              [r.expimp]: (r.flow * r.unit) / (r.rate + 0 || 1),
            });
          } else console.log(`unknown partner ${r.partner}`);
        });

        graph.forEachNode((node) => {
          // add trade value on nodes: weightedDegree (sum of bilateral trade of connected edges)
          if (graph.getNodeAttribute(node, "type") === "entity")
            (graph as GraphEntityPartiteType).setNodeAttribute(
              node,
              "totalBilateralTrade",
              graph.edges(node).reduce((total: number, e) => {
                const tradeValue = graph.getEdgeAttribute(e, "Exp") || graph.getEdgeAttribute(e, "Imp") || 0;
                return total + tradeValue;
              }, 0),
            );
        });

        graph.forEachEdge((edge) => {
          graph.setEdgeAttribute(
            edge,
            "maxExpImp",
            max([graph.getEdgeAttribute(edge, "Exp"), graph.getEdgeAttribute(edge, "Imp")]),
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
        addEdgeLabel(graph, nodeId(RICentity), nodeId(parent), "AGGREGATE_INTO");
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
          (graph as GraphEntityPartiteType).setNodeAttribute(nodeId(part), "cited", true);
          addEdgeLabel(graph, nodeId(RICentity), nodeId(part), "SPLIT");
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
export function aggregateIntoAutonomousEntities(graph: GraphEntityPartiteType) {
  const GphNodes = graph.filterNodes((_, atts) => atts.entityType === "GPH");
  GphNodes.forEach((n) => {
    const {
      entity: targetGPHEntity,
      status: targetStatus,
      autonomous,
    } = autonomousGPHEntity(n, graph.getAttribute("year"));
    //merge node
    (graph as GraphEntityPartiteType).mergeNode(nodeId(targetGPHEntity), {
      label: targetGPHEntity.GPH_name,
      gphStatus: targetStatus,
      entityType: autonomous ? "GPH-AUTONOMOUS" : "GPH",
      type: "entity",
    });
    if (nodeId(targetGPHEntity) !== n) {
      addEdgeLabel(graph, n, nodeId(targetGPHEntity), "AGGREGATE_INTO");
    }
  });
}
/**
 * split areas: (area_entity) -[SPLIT_OTHER]-> (member_entity)
 * @param graph
 * @param RICentities
 * @param GPHEntities
 */
export function splitAreas(
  graph: GraphEntityPartiteType,
  RICentities: Record<string, RICentity>,
  GPHEntities: GPHEntity[],
) {
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

                addEdgeLabel(graph, n, autonomousMember.entity.GPH_code, "SPLIT_OTHER");
              }
            }
          });
      } else console.warn(`colonial area not in geographical translation table: ${atts.label}`);
    });
}

export function splitInformalUnknownEntities(graph: GraphEntityPartiteType) {
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
          if (graph.hasNode(p) && graph.degree(p) > 0) addEdgeLabel(graph, informalNode, p, "SPLIT_OTHER");
        });
      }
      //else console.warn(`no parts for informal ${informalNode} in year ${year}`);
    });
}

/**
 * flag autonomous as cited
 * @param graph
 */
export function flagAutonomousCited(graph: GraphEntityPartiteType) {
  graph.forEachNode((n, atts) => {
    if (atts.type === "entity" && atts.entityType === "GPH-AUTONOMOUS") {
      const entityGraph = graph as GraphEntityPartiteType;
      if (
        atts.cited === true ||
        // grant GPH-AUTONOMOUS-CITED status to sovereign whose one locality is cited
        entityGraph.filterInNeighbors(n, (nb) => {
          return (
            entityGraph.getNodeAttribute(nb, "cited") && graph.getEdgeAttribute(nb, n, "labels").has("AGGREGATE_INTO")
          );
        }).length > 0
      ) {
        entityGraph.setNodeAttribute(n, "entityType", "GPH-AUTONOMOUS-CITED");
      }
    }
  });
}

/**
 * compute trade value from trade flow attributes
 */
export function computeTradeValue(atts: EdgeAttributes) {
  //options are:
  // exp first
  // imp first
  // average
  // max
  // Select one side depending on reporter quality

  // exp first OR imp if exp not available
  return max([atts.Exp, atts.Imp]);
}

/**
 * flag trade flows that need treatment
 * @param graph
 */
export function flagFlowsToTreat(graph: GraphEntityPartiteType) {
  graph.forEachEdge((e, atts) => {
    // flag edges to be treated
    if (atts.labels.has("REPORTED_TRADE")) {
      if (
        graph
          .extremities(e)
          .every((n) => (graph as GraphEntityPartiteType).getNodeAttribute(n, "entityType") === "GPH-AUTONOMOUS-CITED")
      )
        graph.setEdgeAttribute(e, "status", "ok");
      else graph.setEdgeAttribute(e, "status", "toTreat");
    }
    // make sure value is the one we want
    graph.setEdgeAttribute(e, "maxExpImp", computeTradeValue(atts));
  });
}

export function resolveOneToOneEntityTransform(graph: GraphEntityPartiteType) {
  graph
    .filterEdges((_, atts) => atts.status === "toTreat")
    .forEach((e) => {
      const autonomousExporters = resolveAutonomous(graph.source(e), graph as GraphEntityPartiteType);
      const autonomousImporters = resolveAutonomous(graph.target(e), graph as GraphEntityPartiteType);

      if (autonomousExporters.autonomousIds.length === 1 && autonomousImporters.autonomousIds.length === 1) {
        // case of simple resolution 1:1
        const newSource = autonomousExporters.autonomousIds[0];
        const newTarget = autonomousImporters.autonomousIds[0];
        resolveTradeFlow(
          graph,
          e,
          newSource,
          newTarget,
          autonomousExporters.traversedLabels.union(autonomousImporters.traversedLabels),
        );
      }
    });
}

export function resolveOneToManyEntityTransform(
  year: number,
  tradeGraphsByYear: Record<string, GraphEntityPartiteType>,
  edgeKey?: string,
) {
  const graph = tradeGraphsByYear[year].copy();
  if (!graph) {
    throw new Error(`No trade graph available for year ${year}`);
  } else {
    graph
      .filterEdges((e, atts) => (edgeKey ? e === edgeKey : atts.status === "toTreat"))
      .forEach((e) => {
        const edgeToTreatAtts = graph.getEdgeAttributes(e);
        console.log(
          `treating flow (${graph.source(e)}: ${graph.getNodeAttribute(graph.source(e), "label")})->(${graph.target(e)}:${graph.getNodeAttribute(graph.target(e), "label")})`,
        );

        const autonomousExporters = resolveAutonomous(graph.source(e), graph as GraphEntityPartiteType);
        const autonomousImporters = resolveAutonomous(graph.target(e), graph as GraphEntityPartiteType);

        if (
          (autonomousExporters.autonomousIds.length === 1 && autonomousImporters.autonomousIds.length > 0) ||
          (autonomousImporters.autonomousIds.length === 1 && autonomousExporters.autonomousIds.length > 0)
        ) {
          // case 1->1
          if (autonomousExporters.autonomousIds.length === 1 && autonomousImporters.autonomousIds.length === 1) {
            resolveTradeFlow(
              graph,
              e,
              autonomousExporters.autonomousIds[0],
              autonomousImporters.autonomousIds[0],
              // TODO: check that's ok...
              // split resolving to 1-1 is considered an aggregation
              new Set(["AGGREGATE_INTO"]),
              1,
            );

            return;
          }

          // case 1->n
          // theoretically the 1 side should be the reporter
          const oneEndEntity =
            autonomousImporters.autonomousIds.length === 1
              ? autonomousImporters.autonomousIds[0]
              : autonomousExporters.autonomousIds[0];
          const splitSide = autonomousImporters.autonomousIds.length === 1 ? "Import" : "Export";
          let entitiesToSplitInto =
            autonomousImporters.autonomousIds.length === 1
              ? autonomousExporters.autonomousIds
              : autonomousImporters.autonomousIds;

          // remove entities from split destination which are already reported by reporting
          const reportedPartners = new Set(
            flatten(
              graph
                .filterEdges(oneEndEntity, (_, atts) => atts.labels.has("REPORTED_TRADE"))
                .map((e) => graph.extremities(e).filter((other) => other !== oneEndEntity)),
            ),
          );
          //remove also the reporter
          entitiesToSplitInto = entitiesToSplitInto.filter((e) => !reportedPartners.has(e) && e !== oneEndEntity);

          const oneEndEntityLabel = graph.getNodeAttribute(oneEndEntity, "label");

          const valueToSplit = splitSide === "Export" ? edgeToTreatAtts.Exp : edgeToTreatAtts.Imp;

          if (valueToSplit !== undefined) {
            console.log(
              `looking for ratios for ${year} ${oneEndEntityLabel} ${oneEndEntity} ${valueToSplit} to/from ${entitiesToSplitInto}`,
            );
            // we need to find the percentages to split the value of the flow among the destinations
            const ratios = findBilateralRatios(year, oneEndEntity, entitiesToSplitInto, splitSide, tradeGraphsByYear);

            // redirect
            const solved = toPairs(ratios).filter(([_, { status, ratio }]) => status === "ok" && ratio !== undefined);
            let solvedRatio = 0;
            if (solved.length > 0)
              solved.forEach(([partner, { ratio }]) => {
                if (ratio !== undefined) {
                  solvedRatio += ratio;
                  resolveTradeFlow(
                    graph,
                    e,
                    splitSide === "Export" ? oneEndEntity : partner,
                    splitSide === "Export" ? partner : oneEndEntity,
                    new Set(["SPLIT"]),
                    ratio,
                  );
                }
              });

            const toROW = toPairs(ratios).filter(([_, { status, ratio }]) => status !== "ok" || ratio === undefined);
            // check data coherence: ratio in groups should be the same as the remaining ratio after solved cases
            // group ratio are actually duplicated by partner by the findBilateralRatios method. We need to deduplicate them before summing.
            // We could also just do not check and just use 1-solvedRatio
            const rowRatio = Number(sum(uniq(toROW.map(([_, { ratio }]) => ratio || 0))).toFixed(2));
            // we dont create flows to rest of the world for now
            // instead we indicate the destinations to try to impute missing flow from gravity model

            if (toROW.length === 1) {
              const newPartner = toROW[0][0];
              resolveTradeFlow(
                graph,
                e,
                splitSide === "Export" ? oneEndEntity : newPartner,
                splitSide === "Export" ? newPartner : oneEndEntity,
                new Set(["SPLIT"]),
                Number((1 - solvedRatio).toFixed(2)),
              );
            }
            if (toROW.length > 1) {
              graph.setEdgeAttribute(e, "splitToGPHCodes", toROW.map((r) => r[0]).join("|"));
              graph.setEdgeAttribute(e, "valueToSplit", Number((1 - solvedRatio).toFixed(2)) * valueToSplit);
            }
            // redirect to rest of the world will be moved later in the part where we import gravity model results
            // resolveTradeFlow(
            //   graph,
            //   e,
            //   splitSide === "Export" ? oneEndEntity : "restOfTheWorld",
            //   splitSide === "Export" ? "restOfTheWorld" : oneEndEntity,
            //   new Set(["SPLIT"]),
            //   Number((1 - solvedRatio).toFixed(2)),
            // );
            if (solved.length > 0 && Number((1 - solvedRatio).toFixed(2)) !== rowRatio) {
              console.log(
                `error in calculating the remaining SPLIT ratios to send to restOfTheWorld`,
                rowRatio,
                toROW.map(([_, { ratio }]) => ratio),
                uniq(toROW.map(([_, { ratio }]) => ratio)),
              );
            }
            // flag flow if failed or partial split
            if (solvedRatio === 0) graph.setEdgeAttribute(e, "status", "split_failed_no_ratio");
            if (solved.length > 0 && solved.length < entitiesToSplitInto.length)
              graph.setEdgeAttribute(e, "status", "split_only_partial");
          } else {
            console.log(
              `1->n where 1- entity ${oneEndEntity}-[${splitSide}]-${oneEndEntityLabel} is not reporting. ${JSON.stringify(edgeToTreatAtts)}`,
            );
            graph.setEdgeAttribute(
              e,
              "notes",
              `1->n where 1- entity ${oneEndEntity}-[${splitSide}]-${oneEndEntityLabel} is not reporting. ${JSON.stringify(edgeToTreatAtts)}`,
            );
            // flag flow as error is done below
            graph.setEdgeAttribute(e, "status", "split_failed_error");
          }
        } else {
          // case 1 -> 0
          if (autonomousImporters.autonomousIds.length === 0 || autonomousExporters.autonomousIds.length === 0) {
            graph.setEdgeAttribute(
              e,
              "notes",
              `Couldn't resolve ${autonomousImporters.autonomousIds.length === 0 ? `importer ${graph.getNodeAttribute(graph.target(e), "label")}` : `exporter ${graph.getNodeAttribute(graph.source(e), "label")}`}`,
            );
            console.log(`Can"t resolve one partner`);
          } else {
            // case n -> n
            const message = `n->n case: ${graph.source(e)} transform to ${autonomousExporters.autonomousIds.length} ${graph.target(e)} transform to ${autonomousImporters.autonomousIds.length}`;
            console.log(message);
            graph.setEdgeAttribute(e, "notes", message);
          }
          // end of error logging, flag flow as couldn't split
          graph.setEdgeAttribute(e, "status", "split_failed_error");
        }
      });
  }
  return graph;
}
