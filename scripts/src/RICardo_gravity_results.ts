import { parse } from "csv-parse/sync";
import { readFile, writeFile } from "fs/promises";
import { groupBy, toPairs, values } from "lodash";

import { aggregatedFlowNote } from "./graphTraversals";
import { tradeEdgeKey } from "./tradeGraphCreation";
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

          // add status to original flow :
          (graph as GraphEntityPartiteType).setEdgeAttribute(originalFlowId, "status", "ignore_resolved");

          grs.forEach((gr) => {
            // insert the new trade flows with
            const reporter = gr.CafFob === "FromImporter" ? gr.newimporterId : gr.newexporterId;
            const partner = gr.CafFob === "FromExporter" ? gr.newimporterId : gr.newexporterId;
            const expimp = gr.CafFob === "FromExporter" ? "Exp" : "Imp";
            const newFlowId = tradeEdgeKey(reporter, partner, expimp);
            //console.log({ reporter, partner, expimp, newFlowId, ...gr });
            if (graph.hasEdge(newFlowId)) {
              if ((graph as GraphEntityPartiteType).getEdgeAttribute(newFlowId, "status") === "to_impute")
                graph.dropEdge(newFlowId);
              else {
                console.log(
                  `${year} duplicated edge with gravity ${newFlowId} ${(graph as GraphEntityPartiteType).getEdgeAttribute(newFlowId, "status")}`,
                );
                return;
              }
            }
            graph.addEdgeWithKey(newFlowId, gr.newexporterId, gr.newimporterId, {
              type: "trade",
              labels: new Set(["GENERATED_TRADE"]),
              reportedBy: reporter,
              status: "ok",
              value: gr.pred_trade,
              valueGeneratedBy: ["split_by_gravity"],
              originalReportedTradeFlowId: originalFlowId,
              notes: aggregatedFlowNote(originalFlowId, gr.pred_trade, graph as GraphEntityPartiteType),
            });
          });
        });
        console.log(`${year}-${fileSuffix} done`);
      }),
    );
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
  await Promise.all(tasks);
}

readGravityResults()
  .catch((e) => console.log(e))
  .then(() => console.log("done"));
