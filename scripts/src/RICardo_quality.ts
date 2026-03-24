import { parallelize } from "@ouestware/async";
import { stringify } from "csv/sync";
import fs from "fs";
import { difference, flatten, keys, omit, sortBy, toPairs, uniq, values } from "lodash";

import { DB } from "./DB";
import { FlowValueImputationMethod, GraphEntityPartiteType, GraphType, TradeEdgeAttributes } from "./types";
import { GraphSerializationType, getTradeGraphsByYear } from "./utils";

interface FlowDataPoint {
  id: string;
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
  value?: number;
  partial?: string;
  reportedBy?: string;

  status: TradeEdgeAttributes["status"];
  notes?: string;

  valueToSplit?: number;
  newReporter?: string;
  newPartners?: string;
  originalReportedTradeFlowId?: string;
}

interface ComputedData {
  year: number;
  bilaterals: Record<FlowStatType, FlowStat>;
  nbReportingBilateral: number;
  nbReportingByAggregation: number;
  nbReportingBySplit: number;
  nbReportingFT: number;
  nbGPHAutonomousCited: number;
  GPHAutonomousCited: { id: string; label: string }[];
  worldFT: number;
  worldBilateral: number;
  inFTNotInBilateral: string[];
  inBilateralNotInFT: string[];
  flowData: FlowDataPoint[];
}

// TODO : recode form network data
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
  | Exclude<TradeEdgeAttributes["status"], "ignore_resolved" | undefined>
  | FlowValueImputationMethod
  | "splitFailedParts";

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
        partner = 'World Federico Tena'

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
  const bilaterals: Record<string, FlowStat> = {};
  const sumBilateralWorld = { nbFlows: 0, value: 0 };
  const flowData: FlowDataPoint[] = [];

  // count Bilateral Reporters
  const bilateralReporters = new Set<string>();
  const bilateralReportersByAggregation = new Set<string>();
  const bilateralReportersBySplit = new Set<string>();

  (graph as GraphEntityPartiteType).edges().forEach((e) => {
    const edgeAtts = (graph as GraphEntityPartiteType).getEdgeAttributes(e);
    const value = edgeAtts.value;
    if (
      edgeAtts.type === "trade" &&
      (edgeAtts.labels.has("REPORTED_TRADE") || edgeAtts.labels.has("GENERATED_TRADE"))
    ) {
      let ok = false;
      if (value !== undefined) {
        // && edgeAtts.status !== "ignore_resolved") {
        // if generated_trade track the method used for resolution
        ok = edgeAtts.status === "ok" && graph.source(e) !== "restOfTheWorld" && graph.target(e) !== "restOfTheWorld";
        const status: string | undefined =
          edgeAtts.labels.has("GENERATED_TRADE") && !edgeAtts.labels.has("REPORTED_TRADE")
            ? sortBy(uniq(edgeAtts.valueGeneratedBy)).join("|")
            : edgeAtts.status;
        // if restoftheworld => status = splitFailedParts
        // if (graph.source(e) === "restOfTheWorld" || graph.target(e) === "restOfTheWorld") status = "splitFailedParts";

        if (status !== undefined) {
          bilaterals[status] = {
            nbFlows: (bilaterals[status]?.nbFlows || 0) + 1,
            value:
              (bilaterals[status]?.value || 0) + status === "split_only_partial" ? edgeAtts.valueToSplit || 0 : value,
          };

          // bilateral sum
          if (ok) {
            sumBilateralWorld.nbFlows += 1;
            sumBilateralWorld.value += value;
          }
        }
      }
      const importer = (graph as GraphEntityPartiteType).getTargetAttributes(e);
      const exporter = (graph as GraphEntityPartiteType).getSourceAttributes(e);
      // count bilateral reporters
      if (ok) {
        if (importer.reporting) bilateralReporters.add(graph.target(e));
        if (importer.reportingByAggregateInto) bilateralReportersByAggregation.add(graph.target(e));
        if (importer.reportingBySplit) bilateralReportersBySplit.add(graph.target(e));
        if (exporter.reporting) bilateralReporters.add(graph.source(e));
        if (exporter.reportingByAggregateInto) bilateralReportersByAggregation.add(graph.source(e));
        if (exporter.reportingBySplit) bilateralReportersBySplit.add(graph.source(e));
      }

      flowData.push({
        id: e,
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

        value: edgeAtts.value,
        partial: edgeAtts.partial,
        reportedBy: edgeAtts.reportedBy,

        status: edgeAtts.status,
        notes: edgeAtts.notes,

        // to impute special fields
        valueToSplit: edgeAtts.valueToSplit,
        newPartners: edgeAtts.newPartners,
        newReporter: edgeAtts.newReporter,
        originalReportedTradeFlowId: edgeAtts.originalReportedTradeFlowId,
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
    nbReportingBilateral: bilateralReporters.size,
    nbReportingByAggregation: bilateralReportersByAggregation.size,
    nbReportingBySplit: bilateralReportersBySplit.size,
    worldFT,
    nbGPHAutonomousCited,
    worldBilateral: sumBilateralWorld.value,
    inFTNotInBilateral,
    inBilateralNotInFT,
    GPHAutonomousCited,
    flowData,
  };
}

async function graphsQuality(graphSerialization: GraphSerializationType = "ratios") {
  //TODO do not load all the graphs at once.
  const tradeGraphsByYear = await getTradeGraphsByYear(graphSerialization);
  // prepare out streams
  const GPHAutonomousCited: Record<string, { id: string; label: string; years: number[] }> = {};

  const tasks = values(tradeGraphsByYear).map((graph) => async () => {
    const qualityStats = await graphQuality(graph);
    const flowStream = fs.createWriteStream(`../data/tradeFlows_${qualityStats.year}.csv`, { flags: "w" });
    // BilateralStats
    const bilateralsStats = toPairs(qualityStats.bilaterals).reduce((acc, [key, stats]) => {
      return { ...acc, [`${key}_flows`]: stats.nbFlows, [`${key}_value`]: stats.value };
    }, {});

    const stats = {
      year: qualityStats.year,
      nbGPHAutonomousCited: qualityStats.nbGPHAutonomousCited,
      nbReportingFT: qualityStats.nbReportingFT,
      nbReportingBilateral: qualityStats.nbReportingBilateral,
      nbReportingByAggregation: qualityStats.nbReportingByAggregation,
      nbReportingBySplit: qualityStats.nbReportingBySplit,
      worldBilateral: qualityStats.worldBilateral,
      worldFT: qualityStats.worldFT,
      ...bilateralsStats,
      inFTNotInBilateral: qualityStats.inFTNotInBilateral.join("|"),
      inBilateralNotInFT: qualityStats.inBilateralNotInFT.join("|"),
    };

    const columns: (keyof FlowDataPoint)[] = [
      "id",
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

      "value",
      "reportedBy",
      "partial",

      "valueToSplit",
      "newReporter",
      "newPartners",
      "originalReportedTradeFlowId",

      "status",
      "notes",
    ];
    flowStream.write(
      stringify(qualityStats.flowData, {
        header: true,
        columns,
      }),
    );
    flowStream.end();

    // GPHAutonomousCited list
    qualityStats.GPHAutonomousCited.forEach((GPH) => {
      GPHAutonomousCited[GPH.id] = {
        ...GPH,
        years: sortBy([...(GPHAutonomousCited[GPH.id] ? GPHAutonomousCited[GPH.id].years : []), qualityStats.year]),
      };
    });

    return stats;
  });
  const stats = await parallelize(tasks, 5);

  const headers: string[] = [
    "id",
    "year",
    "nbGPHAutonomousCited",
    "nbReportingFT",
    "nbReportingBilateral",
    "nbReportingByAggregation",
    "nbReportingBySplit",
    "worldBilateral",
    "worldFT",
    "inFTNotInBilateral",
    "inBilateralNotInFT",
  ];
  const flowStatsHeaders = sortBy(uniq(flatten(stats.map((s) => keys(omit(s, headers))))));
  fs.writeFileSync(
    "../data/tradeGraphsStats.csv",
    stringify(stats, {
      header: true,
      columns: [...headers, ...flowStatsHeaders],
    }),
  );

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
