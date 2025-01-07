import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { DirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { groupBy, keyBy, range, sortedUniq, sum } from "lodash";

import { DB } from "./DB";
import { GPHEntities, GPHEntity, GPHStatusType, GPH_informal_parts, GPH_status, autonomousGPHEntity } from "./GPH";
import { colonialAreasToGeographicalArea, geographicalAreasMembers } from "./areas";
import conf from "./configuration.json";
import { resolveAutonomous, resolveTradeFlow } from "./graphTraversals";

// function targetEntity(ricname:string, rictype:string) {

//   if (rictype === "GPH")

// }
type RICType = "GPH_entity" | "group" | "locality" | "geographical_area" | "colonial_area";

interface RICentity {
  RICname: string;
  type: RICType;
  parent_entity?: string;
  GPH_code?: string;
}

type EntityType = "RIC" | "GPH" | "GPH-AUTONOMOUS" | "GPH-AUTONOMOUS-CITED" | "ROTW";

interface EntityNodeAttributes {
  label: string;
  reporting: boolean;
  ricType: RICType;
  entityType: EntityType;
  cited?: boolean;
  gphStatus?: GPHStatusType;
  ricParent?: string;
  totalBilateralTrade?: number;
  type: "entity";
}
interface ResolutionNodeAttributes {
  label: string;
  type: "resolution";
  value?: number;
}

export type EntityResolutionLabelType = "AGGREGATE_INTO" | "SPLIT" | "SPLIT_OTHER";
type TradeLabelType = "REPORTED_TRADE" | "GENERATED_TRADE" | "RESOLVE";

export type EdgeLabelType = TradeLabelType | EntityResolutionLabelType;

export type FlowValueImputationMethod =
  | "aggregation"
  | "split_to_one"
  | "split_by_years_ratio"
  | "split_by_mirror_ratio";
export interface EdgeAttributes {
  labels: Set<EdgeLabelType>;
  label?: string;
  Exp?: number;
  Imp?: number;
  valueGeneratedBy?: FlowValueImputationMethod;
  ExpReportedBy?: string;
  ImpReportedBy?: string;
  status?: "toTreat" | "ok" | "ignore_internal" | "ignore_resolved" | "discard_collision";
  value?: number;
  notes?: string;
  aggregatedIn?: string;
}
export type GraphType = DirectedGraph<EntityNodeAttributes | ResolutionNodeAttributes, EdgeAttributes>;
export type GraphEntityPartiteType = DirectedGraph<EntityNodeAttributes, EdgeAttributes>;
export type GraphResolutionPartiteType = DirectedGraph<ResolutionNodeAttributes, EdgeAttributes>;

/**
 * UTILS
 */
const nodeId = (entity: RICentity | GPHEntity) => {
  if ("RICname" in entity) {
    if (!entity.GPH_code) return entity.RICname;
    else return entity.GPH_code;
  } else return entity.GPH_code;
};

const statsEntityType = (graph: GraphType) => {
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

const addEdgeLabel = (graph: GraphType, source: string, target: string, label: EdgeLabelType) => {
  graph.updateDirectedEdge(source, target, (atts) => ({
    ...atts,
    labels: new Set([...(atts.labels || []), label]),
  }));
};

export const entitesTransformationGraph = (startYear: number, endYear: number) => {
  const RICentities = keyBy<RICentity>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities.csv`), { columns: true }),
    (r) => r.RICname,
  );

  const RICgroups = groupBy<{ RICname_group: string; RICname_part: string }>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities_groups.csv`), { columns: true }),
    (r) => r.RICname_group,
  );

  const ricToGPH = (RICname: string, graph: GraphType) => {
    const RICentity = RICentities[RICname];
    // make sur the entity is in the graph
    if (!graph.hasNode(nodeId(RICentity))) {
      graph.addNode(nodeId(RICentity), {
        label: RICentity.RICname,
        reporting: false, // TODO: should we give reporting status to entity created from transforming a reporting ?
        cited: false,
        ricType: RICentity.type,
        entityType: RICentity.type === "GPH_entity" ? "GPH" : "RIC",
        type: "entity",
      });
    }

    switch (RICentity.type) {
      case "locality":
        // (locality) -[AGGREGATE_INTO]-> (parent)
        if (RICentity.parent_entity) {
          const parent = RICentities[RICentity.parent_entity];
          if (!graph.hasNode(parent)) {
            // recursion on this new parent
            ricToGPH(parent.RICname, graph);
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
            if (!graph.hasNode(nodeId(part))) ricToGPH(part.RICname, graph);
            // for now we store all transformation steps, no shortcut to final (after recursion) solution
            graph.addDirectedEdge(nodeId(RICentity), nodeId(part), { labels: new Set(["SPLIT"]) });
          });
        else console.log(`UNKNOWN GROUP ${RICname}`);
        break;
      default:
      // anothing to do: areas will be done later, GPH are good as is
    }
  };

  const db = DB.get();
  Promise.all(
    range(startYear, endYear, 1).map((year) => {
      const promise = new Promise<void>((resolve, reject) => {
        try {
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

              const graph = new DirectedGraph<EntityNodeAttributes | ResolutionNodeAttributes, EdgeAttributes>();

              // trade network (baseline)
              // (reporting) -[REPORTED_TRADE]-> (partner)
              rows.forEach((r) => {
                // TODO: decide how to combine RICname and GPH_code for node id?

                const reporting = RICentities[r.reporting];

                graph.mergeNode(nodeId(reporting), {
                  label: reporting.RICname,
                  reporting: true,
                  ricType: r.reporting_type,
                  cited: true,
                  entityType: r.reporting_type === "GPH_entity" ? "GPH" : "RIC",
                  ricParent: r.reporting_parent_entity,
                  type: "entity",
                });
                const partner = RICentities[r.partner];
                graph.mergeNode(nodeId(partner), {
                  label: partner.RICname,
                  ricType: r.partner_type,
                  cited: true,
                  entityType: r.partner_type === "GPH_entity" ? "GPH" : "RIC",
                  ricParent: r.partner_parent_entity,
                  type: "entity",
                });
                const from = r.expimp === "Exp" ? nodeId(reporting) : nodeId(partner);
                const to = r.expimp === "Imp" ? nodeId(reporting) : nodeId(partner);
                // add trade value on directed edges: bilateral trade
                graph.mergeDirectedEdge(from, to, {
                  labels: new Set(["REPORTED_TRADE"]),
                  // add reported by attribute to trade flows
                  [`${r.expimp}ReportedBy`]: reporting.RICname,
                  [r.expimp]: (r.flow * r.unit) / (r.rate + 0 || 1),
                });
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

              console.log("step 0:", JSON.stringify(statsEntityType(graph), null, 2));
              //STEP 1 RIC => GPH (but areas)
              const notGphRicNodes = (graph as GraphEntityPartiteType).filterNodes(
                (_, atts) => atts.entityType === "RIC",
              );
              notGphRicNodes.forEach((n) => {
                ricToGPH(n, graph);
              });

              console.log("step 1:", JSON.stringify(statsEntityType(graph), null, 2));

              // STEP 2 GPH => GPH autonomous
              const GphNodes = (graph as GraphEntityPartiteType).filterNodes((_, atts) => atts.entityType === "GPH");
              GphNodes.forEach((n) => {
                const { entity: targetGPHEntity, status: targetStatus, autonomous } = autonomousGPHEntity(n, year);
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

              console.log("step 2:", JSON.stringify(statsEntityType(graph), null, 2));

              // STEP 3 OTHERs

              // for all areas
              // (area_entity) -[SPLIT_OTHER]-> (member_entity)
              graph
                .filterNodes(
                  (_, atts) => atts.type === "entity" && ["geographical_area", "colonial_area"].includes(atts.ricType),
                )
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
                    let ms: Pick<GPHEntity, "GPH_code" | "GPH_name" | "continent">[] =
                      geographicalAreasMembers[geographical];
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
                            graph.hasNode(autonomousMember.entity.GPH_code) &&
                            graph.degree(autonomousMember.entity.GPH_code) > 0
                          )
                            addEdgeLabel(graph, n, autonomousMember.entity.GPH_code, "SPLIT_OTHER");
                        }
                      });
                  } else console.warn(`colonial area not in geographical translation table: ${atts.label}`);
                });

              // treat informal and no Known GPH status cases
              graph
                // todo : apply to all undefined GPH status
                .filterNodes(
                  (_, atts) =>
                    atts.type === "entity" &&
                    atts.entityType === "GPH" &&
                    (atts.gphStatus === "Informal" || atts.gphStatus === undefined),
                )
                .forEach((informalNode) => {
                  //console.log("treating informal", informalNode, atts);
                  const parts = GPH_informal_parts(informalNode, year);
                  //console.log(`found ${parts.length} parts`);
                  if (parts.length > 0) {
                    parts.forEach((p) => {
                      // TODO: remove from those the one which have a political link to another entity the year studied
                      // not easy to do lot of false negative, the in graph filter might suffice.
                      //console.log(p, graph.hasNode(p) && graph.degree(p));
                      if (graph.hasNode(p) && graph.degree(p) > 0) addEdgeLabel(graph, informalNode, p, "SPLIT_OTHER");
                    });
                  } else console.warn(`no parts for informal ${informalNode} in year ${year}`);
                });

              //bug in gexf export with set as attributes
              //graph.mapDirectedEdges((_, atts) => ({ ...atts, labels: [...atts.labels].join("|") }));

              // Detect GPH Autonomous cited
              graph.forEachNode((n, atts) => {
                if (atts.type === "entity" && atts.entityType === "GPH-AUTONOMOUS") {
                  const entityGraph = graph as GraphEntityPartiteType;
                  if (
                    atts.cited === true
                    // grant GPH-AUTONOMOUS-CITED status to sovereign whose one locality is cited
                    // || entityGraph.filterInNeighbors(n, (nb) => {
                    //   return (
                    //     entityGraph.getNodeAttribute(nb, "cited") &&
                    //     graph.getEdgeAttribute(nb, n, "labels").has("AGGREGATE_INTO")
                    //   );
                    // }).length > 0
                  ) {
                    entityGraph.setNodeAttribute(n, "entityType", "GPH-AUTONOMOUS-CITED");
                  }
                }
              });

              graph.forEachEdge((e, atts) => {
                // flag edges to be treated
                if (atts.labels.has("REPORTED_TRADE")) {
                  if (
                    graph
                      .extremities(e)
                      .every(
                        (n) =>
                          (graph as GraphEntityPartiteType).getNodeAttribute(n, "entityType") ===
                          "GPH-AUTONOMOUS-CITED",
                      )
                  )
                    graph.setEdgeAttribute(e, "status", "ok");
                  else graph.setEdgeAttribute(e, "status", "toTreat");
                }
                // average import/export
                const values = [];
                if (atts.Exp) values.push(atts.Exp);
                if (atts.Imp) values.push(atts.Imp);
                if (values.length > 0) graph.setEdgeAttribute(e, "value", sum(values) / values.length);
              });

              // STEP 4 treat trade data
              graph
                .filterEdges((_, atts) => atts.status === "toTreat")
                .forEach((e) => {
                  const autonomousExporters = resolveAutonomous(graph.source(e), graph as GraphEntityPartiteType);
                  const autonomousImporters = resolveAutonomous(graph.target(e), graph as GraphEntityPartiteType);

                  if (
                    autonomousExporters.autonomousIds.length === 1 &&
                    autonomousImporters.autonomousIds.length === 1
                  ) {
                    // case of simple resolution 1:1
                    // TODO: créer une méthode
                    const newSource = autonomousExporters.autonomousIds[0];
                    const newTarget = autonomousImporters.autonomousIds[0];
                    resolveTradeFlow(
                      graph,
                      e,
                      newSource,
                      newTarget,
                      autonomousExporters.traversedLabels.union(autonomousImporters.traversedLabels),
                    );
                  } else {
                    console.log(
                      ` ${graph.source(e)} transform to ${autonomousExporters.autonomousIds.length} ${graph.target(e)} transform to ${autonomousImporters.autonomousIds.length}`,
                    );
                    // we create one RESOLUTION node to inspect cases
                    (graph as GraphResolutionPartiteType).addNode(e, {
                      type: "resolution",
                      label: graph
                        .extremities(e)
                        .map((n) => graph.getNodeAttribute(n, "label"))
                        .join("->"),
                      value: graph.getEdgeAttribute(e, "value"),
                    });

                    autonomousExporters.autonomousIds.forEach((exporter) => {
                      addEdgeLabel(graph, exporter, e, "RESOLVE");
                    });
                    autonomousImporters.autonomousIds.forEach((importer) => {
                      addEdgeLabel(graph, importer, e, "RESOLVE");
                    });

                    //

                    // 1 -> n  or n -> 1 case
                    // parcourir les 1- a puis 1 -> b et pour chacun d'eux
                    // il faut à minima vérifier si on n'a pas déjà un flux
                    // n -> n case
                    // cas en attente de clef
                    // (newexporters) -- (RESOLUTION 1 type resolution : aggregate, split les deux, value flux d'origine) --> (newImporter)
                    // comment représenter les dead-ends resolutions impossible
                    // générer les flux 1:1
                    // flaggue le noeud résolution avec colision ou pas
                  }
                });

              // Tâches à faire en regardant les résolutions
              // déterminer si les cas de résolution vaut la peine
              // déterminer la clef de répartition de la valeur des flux
              // déterminer comment résoudre les collisions avec le flux de commerce existant (somme, ajout miroire, ignorer...)

              // trade edges we want to keep as is
              // trade between two cited GPH autonomous

              // we could start by reporting which are locality cause simple to handle

              // to be treated:
              // - not cited: at least one of the node is GPH autonomous but not cited
              // - not autonomous: at least one of the node is GPH not autonomous
              // - not GPH: at least one of the node is not GPH

              // general idea:
              // - follow edges recursively (AGGREGATE_INTO SPLIT_INTO ...) till the first GPH autonomous entity (cited or not)
              // - we want to remove internal flows
              // - find a way to transform the existing trade edge into the one or many new edges to GPH autonomous
              // - some trade flow (or part of existing flow) will be redirected to a "rest of the world" entity
              // - Not cited autonomous entity are not kept. Trade to not cited autonomous entities are merged to the 'Rest of the world' entity.

              // - cited autonomous reporting entity trade with not interested (real partners) which we transform into a list of autonomous cited (ideal partners)
              // - we must ignore the ideal partners which are already reported by the cited autonomous reporting
              // - we should split the trade (to be defined later) into the ideal partner filtered list

              // method which resolve one not wanted entity into a list of relevant GPH autonomous cited (recursive) + list of to-be-merged-into-rest-of-world entities
              // method which filters out this list to make sure not to generate duplicated/superfluous flows (...)

              // rule locality + parent are reporting: remove locality node + all flows reported by it
              // rule Group :
              // - split trade value with new partner part of group (see work by Béatrice and Paul to be rediscussed)
              // -

              // (entity) -[GENERATED_TRADE]-> (entity)

              // /!\ for SPLIT_OTHER
              // - remove reporting from entities
              // - remove entities which are already cited in reporting trade

              // GEXF preparation/generation
              graph.forEachEdge((e, atts) => {
                // simplify label for Gephi Lite
                graph.setEdgeAttribute(e, "label", sortedUniq([...atts.labels]).join("|"));
              });

              writeFileSync(`../data/entity_networks/${year}.gexf`, gexf.write(graph), "utf8");
              resolve();
            },
          );
        } catch (error) {
          reject(error);
        }
      });
      return promise;
    }),
  );
};

entitesTransformationGraph(conf.startDate, conf.endDate + 1);
