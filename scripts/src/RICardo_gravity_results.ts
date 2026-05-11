import { parse } from "csv-parse/sync";
import { readFile, writeFile } from "fs/promises";
import { groupBy, identity, sortBy, toPairs, uniq, values } from "lodash";

import { aggregatedFlowNote } from "./graphTraversals";
import { flagPartialAggregations, flagReporters, tradeEdgeKey } from "./tradeGraphCreation";
import { GraphEntityPartiteType } from "./types";
import { exportGephLiteFile, getTradeGraphsByYear, setReplacer } from "./utils";

interface GravityResultsType {
  year: number;
  id: string;
  importerLabel: string;
  exporterLabel: string;
  importerReporting: string;
  exporterReporting: string;
  CafFob: "FromExporter" | "FromImporter";
  newimporterId: string;
  newimporterLabel: string;
  newexporterId: string;
  newexporterLabel: string;
  valueToSplit: number;
  pred_trade: number;
}

async function readGravityResults() {
  // read existing network file
  const tradeGraphsByYear = await getTradeGraphsByYear("ratios");
  const tasks = values(tradeGraphsByYear).map(async (graph) => {
    const year = graph.getAttribute("year");
    console.log(`Start ${year}...`);
    // read gravity results
    await Promise.all(
      ["FromExporter", "FromImporter"].map(async (fileSuffix) => {
        console.log(`${year}-${fileSuffix}...`);
        const csvString = await readFile(`../results/gravity_${year}_${fileSuffix}.csv`);
        const gravityRows = parse<GravityResultsType>(csvString, {
          columns: true,
          cast: (v, ctx) => {
            switch (ctx.column) {
              case "year":
              case "valueToSplit":
              case "pred_trade":
                return v ? parseInt(v) : undefined;
              default:
                return v;
            }
          },
        });

        toPairs(
          groupBy(
            gravityRows.filter((gr) => gr.newexporterId !== gr.newimporterId),
            (gr) => gr.id,
          ),
        ).forEach(([originalFlowId, grs]) => {
          // for each group of rows having the same id

          const originalFlowAtts = (graph as GraphEntityPartiteType).getEdgeAttributes(originalFlowId);
          const mergedIn: string[] = [];

          grs.forEach((gr) => {
            // insert the new trade flows with
            const reporter = gr.CafFob === "FromImporter" ? gr.newimporterId : gr.newexporterId;
            const partner = gr.CafFob === "FromExporter" ? gr.newimporterId : gr.newexporterId;
            const expimp = gr.CafFob === "FromExporter" ? "Exp" : "Imp";
            const newFlowId = tradeEdgeKey(reporter, partner, expimp);

            if (graph.hasEdge(newFlowId)) {
              const existingEdgeAtts = (graph as GraphEntityPartiteType).getEdgeAttributes(newFlowId);
              // a gravity imputed flow can collide with an existing flow when a part reporter trade with an area or a group
              // which contains one partner which has reported trade with another part-of reporter of the same aggregated reporter
              if (
                existingEdgeAtts.labels.has("GENERATED_TRADE") &&
                existingEdgeAtts.valueGeneratedBy?.includes("aggregation")
              ) {
                // merge as an aggregation
                (graph as GraphEntityPartiteType).mergeDirectedEdgeWithKey(
                  newFlowId,
                  gr.newexporterId,
                  gr.newimporterId,
                  {
                    value: (existingEdgeAtts.value || 0) + gr.pred_trade,
                    status: "ok",
                    originalReporters: new Set([
                      ...(existingEdgeAtts.originalReporters || []),
                      ...(originalFlowAtts.originalReporters || []),
                    ]),
                    originalPartners: new Set([
                      ...(existingEdgeAtts.originalPartners || []),
                      ...(originalFlowAtts.originalPartners || []),
                    ]),
                    valueGeneratedBy: uniq(sortBy([...existingEdgeAtts.valueGeneratedBy, "split_by_gravity"])),
                    originalReportedTradeFlowIds: [existingEdgeAtts.originalReportedTradeFlowIds, originalFlowId]
                      .filter(identity)
                      .join("|"),
                    notes: [
                      existingEdgeAtts.notes,
                      aggregatedFlowNote(originalFlowId, gr.pred_trade, graph as GraphEntityPartiteType),
                    ].join("\n"),
                  },
                );
              } else {
                console.log(`${year} duplicated edge with gravity ${newFlowId} ${JSON.stringify(existingEdgeAtts)}`);
                return;
              }
            } else {
              graph.addEdgeWithKey(newFlowId, gr.newexporterId, gr.newimporterId, {
                type: "trade",
                labels: new Set(["GENERATED_TRADE"]),
                reportedBy: reporter,
                originalReporters: originalFlowAtts.originalReporters,
                originalPartners: originalFlowAtts.originalPartners,
                status: "ok",
                value: gr.pred_trade,
                valueGeneratedBy: ["split_by_gravity"],
                originalReportedTradeFlowIds: originalFlowId,
                notes: aggregatedFlowNote(originalFlowId, gr.pred_trade, graph as GraphEntityPartiteType),
              });
            }
            mergedIn.push(newFlowId);
          });

          // add status to original flow :
          (graph as GraphEntityPartiteType).setEdgeAttribute(originalFlowId, "status", "ignore_resolved");
          (graph as GraphEntityPartiteType).setEdgeAttribute(originalFlowId, "mergedIn", mergedIn);
        });
        console.log(`${year}-${fileSuffix} done`);
      }),
    );
    // flag partial aggregations
    flagPartialAggregations(graph);
    // flag reporters created by aggregations/split
    flagReporters(graph);

    console.log(`${year} writing JSON`);
    // export graph in graphology
    await writeFile(
      `../data/entity_networks/${year}_gravity.json`,
      JSON.stringify(graph.export(), setReplacer, 2),
      "utf8",
    );
    console.log(`${year} writing Gephi Lite`);
    exportGephLiteFile(graph, "gravity");

    console.log(`${year} done`);
  });
  const r = await Promise.allSettled(tasks);
  const errors = r.filter((r) => r.status === "rejected");
  if (errors.length > 0) console.log(errors);
}

readGravityResults()
  .catch((e) => console.log(e))
  .then(() => console.log("done"));
