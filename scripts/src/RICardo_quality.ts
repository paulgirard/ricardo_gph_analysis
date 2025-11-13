import { parallelize } from "@ouestware/async";
import { stringify } from "csv/sync";
import fs from "fs";
import { difference, flatten, sortBy, toPairs, uniq, values } from "lodash";

import { DB } from "./DB";
import { EdgeAttributes, FlowValueImputationMethod, GraphEntityPartiteType, GraphType } from "./types";
import { getTradeGraphsByYear } from "./utils";

interface FlowDataPoint {
  year: number;
  importerId: string;
  importerLabel: string;
  importerType: string;
  importerReporting: boolean;
  importerReportingByAggregateInto?: boolean;
  importerReportingBySplit?: boolean;
  exporterId: string;
  exporterLabel: string;
  exporterType: string;
  exporterReporting: boolean;
  exporterReportingByAggregateInto?: boolean;
  exporterReportingBySplit?: boolean;
  valueFromImporter?: number;
  partialImp?: string;
  valueFromExporter?: number;
  partialExp?: string;
  ExpReportedBy?: string;
  ImpReportedBy?: string;
  status: EdgeAttributes["status"];
  notes?: string;
}

interface ComputedData {
  year: number;
  bilaterals: Record<FlowStatType, FlowStat>;
  nbReportingFT: number;
  nbGPHAutonomousCited: number;
  GPHAutonomousCited: { id: string; label: string }[];
  worldFT: number;
  worldBilateral: number;
  inFTNotInBilateral: string[];
  inBilateralNotInFT: string[];
  flowData: FlowDataPoint[];
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
  "inFTNotInBilateral",
  "inBilateralNotInFT",
] as const;

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
  console.log(year);
  //FT world estimation + entities
  const FTPromise = new Promise<{ nbReportingFT: number; worldFT: number; reportingsFT: string[] }>(
    (resolve, reject) => {
      DB.get().all(
        `SELECT count(distinct reporting) as nbReportingFT, group_concat(reporting, '|') as reportingsFT,  sum(flow*coalesce(unit,1)/rate) as worldFT FROM flow_joined
      WHERE
        flow is not null and rate is not null AND
        year = ${year} AND
        partner = 'World Federico Tena' AND
        expimp  = "Exp"
      GROUP BY year
        `,
        function (err, rows) {
          if (err) reject(err);
          const { nbReportingFT, worldFT, reportingsFT } = rows[0];
          resolve({ nbReportingFT, worldFT, reportingsFT: sortBy(uniq(reportingsFT.split("|"))) });
        },
      );
    },
  );
  const { nbReportingFT, worldFT, reportingsFT } = await FTPromise;
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
    split_only_partial: { nbFlows: 0, value: 0 },
    split_failed_no_ratio: { nbFlows: 0, value: 0 },
    split_failed_error: { nbFlows: 0, value: 0 },
  };
  const sumBilateralWorld = { nbFlows: 0, value: 0 };
  const flowData: FlowDataPoint[] = [];
  graph.edges().forEach((e) => {
    const edgeAtts = graph.getEdgeAttributes(e);
    const value = getEdgeValue(edgeAtts);
    if ((edgeAtts.labels.has("REPORTED_TRADE") || edgeAtts.labels.has("GENERATED_TRADE")) && edgeAtts.status) {
      if (value && edgeAtts.status !== "ignore_resolved") {
        // if generated_trade track the method used for resolution
        const ok =
          edgeAtts.status === "ok" && graph.source(e) !== "restOfTheWorld" && graph.target(e) !== "restOfTheWorld";
        let status: FlowStatType | undefined = edgeAtts.labels.has("GENERATED_TRADE")
          ? edgeAtts.valueGeneratedBy
          : edgeAtts.status;
        // if restoftheworld => status = splitFailedParts
        if (graph.source(e) === "restOfTheWorld" || graph.target(e) === "restOfTheWorld") status = "splitFailedParts";

        if (status !== undefined) {
          bilaterals[status].nbFlows += 1;
          bilaterals[status].value += value;

          // bilateral sum
          if (ok) {
            sumBilateralWorld.nbFlows += 1;
            sumBilateralWorld.value += value;
          }
        }
      }
      const importer = (graph as GraphEntityPartiteType).getTargetAttributes(e);
      const exporter = (graph as GraphEntityPartiteType).getSourceAttributes(e);

      flowData.push({
        year,
        importerId: graph.target(e),
        importerLabel: importer.label,
        importerType: importer.entityType,
        importerReporting: importer.reporting,
        importerReportingByAggregateInto: importer.reportingByAggregateInto,
        importerReportingBySplit: importer.reportingBySplit,

        exporterId: graph.source(e),
        exporterLabel: exporter.label,
        exporterType: exporter.entityType,
        exporterReporting: exporter.reporting,
        exporterReportingByAggregateInto: exporter.reportingByAggregateInto,
        exporterReportingBySplit: exporter.reportingBySplit,

        valueFromExporter: edgeAtts.Exp,
        partialExp: edgeAtts.partialExp,
        valueFromImporter: edgeAtts.Imp,
        partialImp: edgeAtts.partialImp,
        status: edgeAtts.status,
        notes: edgeAtts.notes,
        ExpReportedBy: edgeAtts.ExpReportedBy,
        ImpReportedBy: edgeAtts.ImpReportedBy,
      });
    }
  });
  const GPHAutonomousCited = sortBy(
    graph
      .filterNodes((_, atts) => {
        return atts.type === "entity" && atts.entityType === "GPH-AUTONOMOUS-CITED";
      })
      .map((id) => ({ id, label: graph.getNodeAttribute(id, "label") })),
  );
  const nbGPHAutonomousCited = GPHAutonomousCited.length;

  const GPHAutonomousCitedLabels = GPHAutonomousCited.map((e) => e.label);
  const inFTNotInBilateral = difference(reportingsFT, GPHAutonomousCitedLabels);
  const inBilateralNotInFT = difference(GPHAutonomousCitedLabels, reportingsFT);

  return {
    year: graph.getAttribute("year"),
    bilaterals,
    nbReportingFT,
    worldFT,
    nbGPHAutonomousCited,
    worldBilateral: sumBilateralWorld.value,
    inFTNotInBilateral,
    inBilateralNotInFT,
    GPHAutonomousCited,
    flowData,
  };
}

async function graphsQuality() {
  //TODO do not load all the graphs at once.
  const tradeGraphsByYear = await getTradeGraphsByYear(true);
  // prepare out streams
  const GPHAutonomousCited: Record<string, { id: string; label: string; years: number[] }> = {};
  const statsStream = fs.createWriteStream("../data/tradeGraphsStats.csv", { flags: "w" });
  const flowStream = fs.createWriteStream("../data/tradeFlows.csv", { flags: "w" });
  let firstLine = true;

  const tasks = values(tradeGraphsByYear).map((graph) => async () => {
    const qualityStats = await graphQuality(graph);
    // BilateralStats
    const bilateralsStats = toPairs(qualityStats.bilaterals).reduce((acc, [key, stats]) => {
      return { ...acc, [`${key}_flows`]: stats.nbFlows, [`${key}_value`]: stats.value };
    }, {});

    const stats = {
      year: qualityStats.year,
      nbGPHAutonomousCited: qualityStats.nbGPHAutonomousCited,
      nbReportingFT: qualityStats.nbReportingFT,
      worldBilateral: qualityStats.worldBilateral,
      worldFT: qualityStats.worldFT,
      ...bilateralsStats,
      inFTNotInBilateral: qualityStats.inFTNotInBilateral.join("|"),
      inBilateralNotInFT: qualityStats.inBilateralNotInFT.join("|"),
    };
    statsStream.write(
      stringify([stats], {
        header: firstLine,
        columns: headers,
      }),
    );

    flowStream.write(
      stringify(qualityStats.flowData, {
        header: firstLine,
        columns: [
          "year",
          "importerId",
          "importerLabel",
          "importerType",
          "importerReporting",
          "importerReportingByAggregateInto",
          "importerReportingBySplit",
          "exporterId",
          "exporterLabel",
          "exporterType",
          "exporterReporting",
          "exporterReportingByAggregateInto",
          "exporterReportingBySplit",
          "valueFromImporter",
          "partialImp",
          "ImpReportedBy",
          "valueFromExporter",
          "partialExp",
          "ExprReportedBy",
          "status",
          "notes",
        ],
      }),
    );

    // GPHAutonomousCited list
    qualityStats.GPHAutonomousCited.forEach((GPH) => {
      GPHAutonomousCited[GPH.id] = {
        ...GPH,
        years: sortBy([...(GPHAutonomousCited[GPH.id] ? GPHAutonomousCited[GPH.id].years : []), qualityStats.year]),
      };
    });

    firstLine = false;
  });
  await parallelize(tasks, 5);
  statsStream.end();
  flowStream.end();

  fs.writeFileSync(
    "../data/GPHAutonomousCited.csv",
    stringify(
      toPairs(GPHAutonomousCited).reduce<{ GPH_code: string; label: string; years: string }[]>(
        (acc, [GPH, { label, years }]) => [...acc, { GPH_code: GPH, label, years: years.join("|") }],
        [],
      ),
      { header: true, columns: ["GPH_code", "label", "years"] },
    ),
  );
}

graphsQuality().then(() => {
  console.log("done");
  DB.get().close();
});
