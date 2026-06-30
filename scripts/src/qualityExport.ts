import { parallelize } from "@ouestware/async";
import { stringify } from "csv/sync";
import fs from "fs";
import { difference, flatten, keys, omit, sortBy, toPairs, uniq, values } from "lodash";

import { DB } from "./DB";
import {
  FlowValueImputationMethod,
  GraphEntityPartiteType,
  GraphType,
  TradeEdgeAttributes,
  TradeEdgeStatus,
} from "./types";
import { GraphSerializationType, getTradeGraphsByYear, unMirroredTradeNetworkDensity } from "./utils";

interface FlowDataPoint {
  id: string;
  year: number;
  importerId: string;
  importerLabel: string;
  importerType: string;

  exporterId: string;
  exporterLabel: string;
  exporterType: string;

  value?: number;
  partial?: string;
  reportedBy?: string;

  status: TradeEdgeAttributes["status"];
  notes?: string;

  valueToSplit?: number;
  newReporters?: string;
  newPartners?: string;
  originalReportedTradeFlowIds?: string;
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
  reportedNetworkDensity: number;
  generatedNetworkDensity: number;
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

const failedStatuses: TradeEdgeStatus[] = ["split_failed_error", "split_only_partial", "split_failed_no_ratio"];

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
          edgeAtts.labels.has("GENERATED_TRADE") && !edgeAtts.labels.has("REPORTED_TRADE") && edgeAtts.status === "ok"
            ? // use valueGeneratedBy for GENERATED_TRADE
              sortBy(uniq(edgeAtts.valueGeneratedBy)).join("|")
            : // use status for REPORTED_TRADE
              edgeAtts.labels.has("REPORTED_TRADE")
              ? edgeAtts.status
              : // IGNORE intermediate GENERATED_TRADE i.e. not ok but resolved or stayed failed
                undefined;

        if (status !== undefined) {
          const aggregatedStatus =
            status === "toTreat" || failedStatuses.includes(status as TradeEdgeStatus)
              ? "failed"
              : // priority to gravity over ratios and aggregation
                status.includes("split_by_gravity")
                ? "generated_by_gravity"
                : // priority to ratios over aggregation
                  status.includes("split_by_years_ratio")
                  ? "generated_by_years_ratio"
                  : status.includes("aggregation")
                    ? "generated_by_aggregation"
                    : status.includes("ignore")
                      ? //TODO: solve the ignore_internal issue and distinguish here recolve cases
                        "discarded"
                      : status === "ok"
                        ? "good_as_reported"
                        : undefined;

          if (aggregatedStatus !== undefined)
            bilaterals[aggregatedStatus] = {
              nbFlows: (bilaterals[aggregatedStatus]?.nbFlows || 0) + 1,
              value:
                (bilaterals[aggregatedStatus]?.value || 0) +
                (status === "split_only_partial" ? edgeAtts.valueToSplit || 0 : value),
            };
          else console.log("undefine status", JSON.stringify(edgeAtts));

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

        exporterId: graph.source(e),
        exporterLabel: exporter.label,
        exporterType: exporter.entityType,

        value: edgeAtts.value,
        partial: edgeAtts.partial,
        reportedBy: edgeAtts.reportedBy,

        status: edgeAtts.status,
        notes: edgeAtts.notes,

        // to impute special fields
        valueToSplit: edgeAtts.valueToSplit,
        newPartners: edgeAtts.newPartners,
        newReporters: edgeAtts.newReporters,
        originalReportedTradeFlowIds: edgeAtts.originalReportedTradeFlowIds,
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

  // density metrics

  const reportedNetworkDensity = unMirroredTradeNetworkDensity(
    graph as GraphEntityPartiteType,
    (_, atts) => atts.type === "trade" && atts.labels.has("REPORTED_TRADE"),
  );

  const generatedNetworkDensity = unMirroredTradeNetworkDensity(
    graph as GraphEntityPartiteType,
    (_, atts) =>
      atts.type === "trade" && (atts.status === "ok" || (atts.status && failedStatuses.includes(atts.status))),
  );

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
    reportedNetworkDensity,
    generatedNetworkDensity,
  };
}

export async function graphsQuality(
  graphSerialization: GraphSerializationType = "ratios",
  exportFlows: boolean = true,
) {
  //TODO do not load all the graphs at once.
  const tradeGraphsByYear = await getTradeGraphsByYear(graphSerialization);
  // prepare out streams
  const GPHAutonomousCited: Record<string, { id: string; label: string; years: number[] }> = {};

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
      nbReportingBilateral: qualityStats.nbReportingBilateral,
      nbReportingByAggregation: qualityStats.nbReportingByAggregation,
      nbReportingBySplit: qualityStats.nbReportingBySplit,
      worldBilateral: qualityStats.worldBilateral,
      worldFT: qualityStats.worldFT,
      ...bilateralsStats,
      inFTNotInBilateral: qualityStats.inFTNotInBilateral.join("|"),
      inBilateralNotInFT: qualityStats.inBilateralNotInFT.join("|"),
      reportedNetworkDensity: qualityStats.reportedNetworkDensity,
      generatedNetworkDensity: qualityStats.generatedNetworkDensity,
    };
    if (exportFlows) {
      const flowStream = fs.createWriteStream(`../data/tradeFlows_${qualityStats.year}_${graphSerialization}.csv`, {
        flags: "w",
      });

      const columns: (keyof FlowDataPoint)[] = [
        "id",
        "year",
        "importerId",
        "importerLabel",
        "importerType",

        "exporterId",
        "exporterLabel",
        "exporterType",

        "value",
        "reportedBy",
        "partial",

        "valueToSplit",
        "newReporters",
        "newPartners",
        "originalReportedTradeFlowIds",

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
    }
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
    "reportedNetworkDensity",
    "generatedNetworkDensity",
  ];
  const flowStatsHeaders = sortBy(uniq(flatten(stats.map((s) => keys(omit(s, headers))))));
  fs.writeFileSync(
    `../data/tradeGraphsStats_${graphSerialization}.csv`,
    stringify(stats, {
      header: true,
      columns: [...headers, ...flowStatsHeaders],
    }),
  );

  fs.writeFileSync(
    `../data/GPHAutonomousCited_${graphSerialization}.csv`,
    stringify(
      toPairs(GPHAutonomousCited).reduce<{ GPH_code: string; label: string; years: string }[]>(
        (acc, [GPH, { label, years }]) => [...acc, { GPH_code: GPH, label, years: years.join("|") }],
        [],
      ),
      { header: true, columns: ["GPH_code", "label", "years"] },
    ),
  );
  DB.get().close();
}
