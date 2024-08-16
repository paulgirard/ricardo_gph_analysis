import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { DirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { groupBy, keyBy } from "lodash";

import { DB } from "./DB";
import { GPHEntities, GPHEntitiesByCode, GPHEntity, GPH_status } from "./GPH";
import { colonialAreasToGeographicalArea, geographicalAreasMembers } from "./areas";
import conf from "./configuration.json";

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

type EntityType = "RIC" | "GPH" | "GPH-AUTONOMOUS" | "GPH-AUTONOMOUS-CITED";

interface NodeAttributes {
  label: string;
  reporting: boolean;
  ricType: RICType;
  entityType: EntityType;
  cited?: boolean;
  gphStatus?: string;
  ricParent?: string;
}

type EdgeLabelType = "REPORTED_TRADE" | "GENERATED_TRADE" | "AGGREGATE_INTO" | "SPLIT" | "SPLIT_OTHER";
interface EdgeAttribues {
  labels: Set<EdgeLabelType>;
  labelsStr?: string;
}
type GraphType = DirectedGraph<NodeAttributes, EdgeAttribues>;

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
    nodes: graph.reduceNodes(
      (acc: Partial<Record<EntityType, number>>, _, atts) => ({
        ...acc,
        [atts.entityType]: (acc[atts.entityType] || 0) + 1,
      }),
      {},
    ),
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

export const entitesTransformationGraph = (year: number) => {
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
        RICgroups[RICname].forEach((group_part) => {
          const part = RICentities[group_part.RICname_part];
          // treat group part by recursion if not already seen
          if (!graph.hasNode(nodeId(part))) ricToGPH(part.RICname, graph);
          // for now we store all transformation steps, no shortcut to final (after recursion) solution
          graph.addDirectedEdge(nodeId(RICentity), nodeId(part), { labels: new Set(["SPLIT"]) });
        });
        break;
      default:
      // anothing to do: areas will be done later, GPH are good as is
    }
  };

  const gphToGPHAutonomous = (gphCode: string, graph: GraphType): string | null => {
    //TODO: replace by GPH dictionary
    const entity = GPHEntitiesByCode[gphCode];
    if (!entity) {
      throw new Error(`${gphCode} is not a known GPH code`);
    } else {
      const status = GPH_status(gphCode, year + "", true);
      switch (status?.status) {
        case undefined:
          console.warn(`${entity.GPH_name} (${gphCode}) has no known status in ${year}`);
          return nodeId(entity);
        case "Sovereign":
        case "Associated state of":
        case "Sovereign (limited)":
        case "Sovereign (unrecognized)":
        case "Colony of":
        case "Dependency of":
        case "Protectorate of":
          graph.mergeNode(nodeId(entity), {
            label: entity.GPH_name,
            gphStatus: status.status,
            entityType: "GPH-AUTONOMOUS",
          });
          return nodeId(entity);
        case "Discovered":
        case "Unknown":
        case "Informal":
          console.warn(`${entity.GPH_name} (${gphCode}) not treated yet. TODO`);
          // to be treated as geographical area later
          return nodeId(entity);
        default: {
          if (status?.sovereign) {
            const sovereign = GPHEntitiesByCode[status.sovereign];
            graph.mergeNode(nodeId(sovereign), {
              label: sovereign.GPH_name,

              entityType: "GPH",
            });
            return gphToGPHAutonomous(status?.sovereign, graph) || sovereign.GPH_code;
          } else {
            graph.mergeNode(nodeId(entity), {
              label: entity.GPH_name,
              gphStatus: status?.status,
            });
            console.warn(
              `GPH_code ${gphCode} of status ${status?.status} does not have any sovereign ${status?.sovereign}`,
            );
            return nodeId(entity);
          }
        }
      }
    }
  };

  const db = DB.get();
  db.all(
    `SELECT reporting, reporting_type, reporting_parent_entity, partner, partner_type, partner_parent_entity FROM flow_joined
    WHERE
      flow is not null and rate is not null AND
      year = ${year} AND
      (partner is not null AND (partner not LIKE 'world%'))
      GROUP BY reporting, partner
      `,
    function (err, rows) {
      console.log(year);
      if (err) throw err;

      const graph = new DirectedGraph<NodeAttributes, EdgeAttribues>();

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
        });
        const partner = RICentities[r.partner];
        graph.mergeNode(nodeId(partner), {
          label: partner.RICname,
          ricType: r.partner_type,
          cited: true,
          entityType: r.partner_type === "GPH_entity" ? "GPH" : "RIC",
          ricParent: r.partner_parent_entity,
        });
        graph.addDirectedEdge(reporting.GPH_code || reporting.RICname, partner.GPH_code || partner.RICname, {
          labels: new Set(["REPORTED_TRADE"]),
        });
      });
      console.log("step 0:", JSON.stringify(statsEntityType(graph), null, 2));
      //STEP 1 RIC => GPH (but areas)
      const notGphRicNodes = graph.filterNodes((_, atts) => atts.entityType === "RIC");
      notGphRicNodes.forEach((n) => {
        ricToGPH(n, graph);
      });

      console.log("step 1:", JSON.stringify(statsEntityType(graph), null, 2));

      // STEP 2 GPH => GPH*
      const GphNodes = graph.filterNodes((_, atts) => atts.entityType === "GPH");
      GphNodes.forEach((n) => {
        const target = gphToGPHAutonomous(n, graph);
        if (target !== null && target !== n) {
          addEdgeLabel(graph, n, target, "AGGREGATE_INTO");
        }
      });

      // HERE GPH** =  GPH* AND cited == true
      graph.mapNodes((_, atts) => ({
        ...atts,
        entityType: atts.entityType === "GPH-AUTONOMOUS" && atts.cited ? "GPH-AUTONOMOUS-CITED" : atts.entityType,
      }));

      console.log("step 2:", JSON.stringify(statsEntityType(graph), null, 2));

      // STEP 3 OTHERs

      // for all areas
      // (area_entity) -[SPLIT_OTHER]-> (member_entity)
      graph
        .filterNodes((_, atts) => ["geographical_area", "colonial_area"].includes(atts.ricType))
        .forEach((n) => {
          const atts = graph.getNodeAttributes(n);
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
                  const autonomousMember = gphToGPHAutonomous(member.GPH_code, graph);
                  if (
                    autonomousMember &&
                    autonomousMember !== n &&
                    graph.hasNode(autonomousMember) &&
                    graph.degree(autonomousMember) > 0
                  )
                    addEdgeLabel(graph, n, autonomousMember, "SPLIT_OTHER");
                }
              });
          } else console.warn(`colonial area not in geographical translation table: ${atts.label}`);
        });

      // TODO treat informal cases
      // get all entities which are 'part of' or 'dissolved into' the informal
      // remove from those the one which have a political link to another entity the year studied

      // STEP 4 treat trade data
      // (entity) -[GENERATED_TRADE]-> (entity)

      // /!\ for SPLIT_OTHER
      // - remove reporting from entities
      // - remove entities which are already cited in reporting trade

      //bug in gexf export with set as attributes
      //graph.mapDirectedEdges((_, atts) => ({ ...atts, labels: [...atts.labels].join("|") }));
      graph.edges().forEach((e) => {
        const atts = graph.getEdgeAttributes(e);
        graph.setEdgeAttribute(e, "labelsStr", [...atts.labels].join("|"));
      });

      writeFileSync(`../data/entity_networks/${year}.gexf`, gexf.write(graph), "utf8");
    },
  );
};

entitesTransformationGraph(1833);
