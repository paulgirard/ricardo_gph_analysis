import { parse } from "csv/sync";
import { readFileSync, writeFileSync } from "fs";
import { DirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { groupBy, keyBy, values } from "lodash";

import { DB } from "./DB";
import { GPH_status } from "./GPH";
import conf from "./configuration.json";

// function targetEntity(ricname:string, rictype:string) {

//   if (rictype === "GPH")

// }
type RICType = "GPH_entity" | "group" | "city/part_of" | "geographical_area" | "colonial_area";

interface RICentity {
  RICname: string;
  type: RICType;
  part_of_GPH_entity?: string;
  GPH_code?: string;
}

interface NodeAttributes {
  label: string;
  reporting: boolean;
  ricType: RICType;
  entityType: "RIC" | "GPH" | "GPH-OK";
  cited?: boolean;
  gphStatus?: string;
  ricPartOf?: string;
}
interface EdgeAttribues {
  label: "REPORTED_TRADE" | "GENERATED_TRADE" | "AGGREGATE_INTO" | "SPLIT" | "SPLIT_OTHER";
}
type GraphType = DirectedGraph<NodeAttributes, EdgeAttribues>;

const nodeId = (entity: RICentity) => {
  return entity.GPH_code || entity.RICname;
};

export const entitesTransformationGraph = (year: number) => {
  const RICentities = keyBy<RICentity>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities.csv`), { columns: true }),
    (r) => r.RICname,
  );

  const RICentitiesByGPHCode = keyBy<RICentity & { GPH_code: string }>(
    values(RICentities).filter((r): r is RICentity & { GPH_code: string } => r.GPH_code !== undefined),
    (r) => r.GPH_code,
  );
  const RICgroups = groupBy<{ RICname_group: string; RICname_part: string }>(
    parse(readFileSync(`${conf["pathToRICardoData"]}/data/RICentities_groups.csv`), { columns: true }),
    (r) => r.RICname_group,
  );

  const ricToGPH = (RICname: string, graph: GraphType) => {
    const RICentity = RICentities[RICname];
    switch (RICentity.type) {
      case "city/part_of":
        // (entity) -[AGGREGATE_INTO]-> (entity)
        if (RICentity.part_of_GPH_entity) {
          const parent = RICentities[RICentity.part_of_GPH_entity];
          graph.updateNode(nodeId(parent), (atts) => ({
            label: parent.RICname,
            reporting: false,
            ricType: parent.type,
            entityType: "GPH",
            ...atts,
          }));
          graph.addDirectedEdge(nodeId(RICentity), nodeId(parent), { label: "AGGREGATE_INTO" });
        } else throw new Error(`${RICname} is city/part_of without part of`);
        break;
      case "group":
        // (entity) -[SPLIT]-> (entity)
        RICgroups[RICname].forEach((group_part) => {
          const part = RICentities[group_part.RICname_part];
          // treat group part by recursion if not already seen
          if (!graph.hasNode(nodeId(part))) ricToGPH(part.RICname, graph);
          graph.addDirectedEdge(nodeId(RICentity), nodeId(part), { label: "SPLIT" });
        });
        break;
      default:
        // add without treatment, areas will be done later, GPH are good as is
        graph.updateNode(nodeId(RICentity), (atts) => ({
          reporting: false,
          label: RICentity.RICname,
          ricType: RICentity.type,
          entityType: RICentity.type === "GPH_entity" ? "GPH" : "RIC",
          ...atts,
        }));
        break;
    }
  };

  const ricGphToSovCol = (gphCode: string, graph: GraphType): string => {
    //TODO: replace by GPH dictionary
    const entity = RICentitiesByGPHCode[gphCode];
    if (!entity.GPH_code || entity?.type !== "GPH_entity") {
      throw new Error(`${entity.RICname} is not a GPH with a GPH code`);
    } else {
      const status = GPH_status(gphCode, year + "", true);
      switch (status?.status) {
        case undefined:
          throw new Error(`unknown GPH ${gphCode}`);
        case "sovereign":
        case "colony_of":
          graph.mergeNode(nodeId(entity), {
            label: entity.RICname,
            gphStatus: status.status,
            entityType: "GPH-OK",
          });
          return entity.RICname;
        case "informal":
          //TODO
          return entity.RICname;
        default: {
          if (status?.sovereign) {
            //TODO: get sovereign name it might not be in RICentity
            const sovereignName = "REPLACE...";
            graph.mergeNode(status?.sovereign, {
              label: sovereignName,
              entityType: "GPH",
            });
            return ricGphToSovCol(status?.sovereign, graph);
          } else
            throw new Error(
              `GPH_code ${gphCode} of status ${status?.status} does not have any sovereign ${status?.sovereign}`,
            );
        }
      }
    }
  };

  const db = DB.get();
  db.all(
    `SELECT reporting, reporting_type, reporting_part_of_GPH_entity, partner, partner_type, partner_part_of_GPH_entity FROM flow_aggregated
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

        graph.mergeNode(reporting.GPH_code || reporting.RICname, {
          label: reporting.RICname,
          reporting: true,
          ricType: r.reporting_type,
          cited: true,
          entityType: r.reporting_type === "GPH" ? "GPH-OK" : "RIC",
          ricPartOf: r.reporting_part_of_GPH_entity,
        });
        console.log(r.partner);
        const partner = RICentities[r.partner];
        graph.mergeNode(partner.GPH_code || partner.RICname, {
          label: partner.RICname,
          ricType: r.partner_type,
          cited: true,
          entityType: r.partner_type === "GPH" ? "GPH-OK" : "RIC",
          ricPartOf: r.partner_part_of_GPH_entity,
        });
        graph.addDirectedEdge(reporting.GPH_code || reporting.RICname, partner.GPH_code || partner.RICname, {
          label: "REPORTED_TRADE",
        });
      });

      //STEP 1 RIC => GPH (but areas)
      const notGphRicNodes = graph.filterNodes((_, atts) => atts.entityType === "RIC");
      notGphRicNodes.forEach((n) => {
        ricToGPH(n, graph);
      });

      // STEP 2 GPH => GPH*
      const GphNodes = graph.filterNodes((_, atts) => atts.entityType === "GPH");
      GphNodes.forEach((n) => {
        const target = ricGphToSovCol(n, graph);
        if (target !== n) {
          graph.addDirectedEdge(n, target, { label: "AGGREGATE_INTO" });
        }
      });

      // STEP 3 OTHERs
      // (entity) -[SPLIT_OTHER]-> (entity)

      // STEP 4 treat trade data
      // (entity) -[GENERATED_TRADE]-> (entity)

      writeFileSync(`../data/entity_networks/${year}.gexf`, gexf.write(graph), "utf8");
    },
  );
};

entitesTransformationGraph(1833);
