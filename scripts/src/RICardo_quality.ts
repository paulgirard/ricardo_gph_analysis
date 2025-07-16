import { parallelize } from "@ouestware/async";
import { stringify } from "csv/sync";
import fs from "fs";
import { flatten, toPairs, values } from "lodash";

import { DB } from "./DB";
import { EdgeAttributes, FlowValueImputationMethod, GraphType } from "./types";
import { getTradeGraphsByYear } from "./utils";

interface ComputedData {
  year: number;
  bilaterals: Record<FlowStatType, FlowStat>;
  nbReportingFT: number;
  nbGPHAutonomousCited: number;
  worldFT: number;
  worldBilateral: number;
}

const headers: string[] = [
  "year",
  "nbGPHAutonomousCited",
  "nbReportingFT",
  "worldBilateral",
  "worldFT",
  ...flatten(
    [
      "ok",
      "aggregation",
      "split_by_mirror_ratio",
      "split_by_years_ratio",
      "split_to_one",
      "ignore_internal",
      "discard_collision",
      "splitFailedParts",
      "toTreat",
    ].map((s) => [`${s}_flows`, `${s}_value`]),
  ),
];

// TODO : recode form netwtok data
// priority exp on imp on mirror : premier alphabétique

// sum world de FT comparé
// nombre d'entité FT
// nombre GPH autonomous cited
// 1850

interface FlowStat {
  nbFlows: number;
  value: number;
}

type FlowStatType =
  | Exclude<EdgeAttributes["status"], "ignore_resolved" | undefined>
  | FlowValueImputationMethod
  | "splitFailedParts";

function getEdgeValue(edgeAtts: EdgeAttributes) {
  return edgeAtts.Exp || edgeAtts.Imp;
}

async function graphQuality(graph: GraphType): Promise<ComputedData> {
  const year = graph.getAttribute("year");
  //FT world estimation + entities
  const FTPromise = new Promise<{ nbReportingFT: number; worldFT: number }>((resolve, reject) => {
    DB.get().all(
      `SELECT count(reporting) as nbReportingFT, sum(flow*coalesce(unit,1)/rate) as worldFT FROM flow_joined
      WHERE
        flow is not null and rate is not null AND
        year = ${year} AND
        partner = 'World Federico Tena' AND
        expimp  = "Exp"
      GROUP BY year
        `,
      function (err, rows) {
        if (err) reject(err);
        const { nbReportingFT, worldFT } = rows[0];
        resolve({ nbReportingFT, worldFT });
      },
    );
  });
  const { nbReportingFT, worldFT } = await FTPromise;
  // bilateral flows
  const bilaterals: Record<FlowStatType, FlowStat> = {
    ok: { nbFlows: 0, value: 0 },
    toTreat: { nbFlows: 0, value: 0 },
    aggregation: { nbFlows: 0, value: 0 },
    split_to_one: { nbFlows: 0, value: 0 },
    split_by_years_ratio: { nbFlows: 0, value: 0 },
    split_by_mirror_ratio: { nbFlows: 0, value: 0 },
    ignore_internal: { nbFlows: 0, value: 0 },
    discard_collision: { nbFlows: 0, value: 0 },
    splitFailedParts: { nbFlows: 0, value: 0 },
  };
  const sumBilateralWorld = { nbFlows: 0, value: 0 };
  graph.edges().forEach((e) => {
    const edgeAtts = graph.getEdgeAttributes(e);
    const value = getEdgeValue(edgeAtts);
    if ((edgeAtts.labels.has("REPORTED_TRADE") || edgeAtts.labels.has("GENERATED_TRADE")) && edgeAtts.status) {
      if (value && edgeAtts.status !== "ignore_resolved") {
        // if generated_trade track the method used for resolution
        let status: FlowStatType | undefined = edgeAtts.labels.has("GENERATED_TRADE")
          ? edgeAtts.valueGeneratedBy
          : edgeAtts.status;
        // if restoftheworld => status = splitFailedParts
        if (graph.source(e) === "restOfTheWorld" || graph.target(e) === "restOfTheWorld") status = "splitFailedParts";

        if (status !== undefined) {
          bilaterals[status].nbFlows += 1;
          bilaterals[status].value += value;
          // bilateral sum
          if (
            status !== "splitFailedParts" &&
            status !== "toTreat" &&
            status !== "ignore_internal" &&
            status !== "discard_collision"
          ) {
            sumBilateralWorld.nbFlows += 1;
            sumBilateralWorld.value += value;
          }
        }
      }
    }
  });
  const nbGPHAutonomousCited = graph.filterNodes((n, atts) => {
    return atts.type === "entity" && atts.entityType === "GPH-AUTONOMOUS-CITED";
  }).length;
  return {
    year: graph.getAttribute("year"),
    bilaterals,
    nbReportingFT,
    worldFT,
    nbGPHAutonomousCited,
    worldBilateral: sumBilateralWorld.value,
  };
}

async function graphsQuality() {
  //TODO do not load all the graphs at once.
  const tradeGraphsByYear = await getTradeGraphsByYear(true);
  const tasks = values(tradeGraphsByYear).map((graph) => async () => graphQuality(graph));
  const qualityStats = await parallelize(tasks, 5);
  const csvString = stringify(
    qualityStats.map((data) => {
      const bilateralsStats = toPairs(data.bilaterals).reduce((acc, [key, stats]) => {
        return { ...acc, [`${key}_flows`]: stats.nbFlows, [`${key}_value`]: stats.value };
      }, {});

      return {
        year: data.year,
        nbGPHAutonomousCited: data.nbGPHAutonomousCited,
        nbReportingFT: data.nbReportingFT,
        worldBilateral: data.worldBilateral,
        worldFT: data.worldFT,
        ...bilateralsStats,
      };
    }),
    {
      header: true,
      columns: headers,
    },
  );
  fs.writeFileSync("../data/tradeGraphsStats.csv", csvString);
}

graphsQuality().then(() => {
  console.log("done");
  DB.get().close();
});
