import { parse } from "csv-parse/sync";
import { stringify } from "csv/sync";
import { mkdirSync, writeFileSync } from "fs";
import { readFile, writeFile } from "fs/promises";
import { UndirectedGraph } from "graphology";
import gexf from "graphology-gexf";
import { camelCase, groupBy, identity, keys, mapKeys, max, pick, sortBy, sum, toPairs, uniq, values } from "lodash";

import { aggregatedFlowNote } from "./graphTraversals";
import { assignLouvainEdgeAmbiguity } from "./louvainEdgeAmbiguity";
import { flagPartialAggregations, flagReporters, tradeEdgeKey } from "./tradeGraphCreation";
import { EntityNodeAttributes, GraphEntityPartiteType } from "./types";
import { exportGephLiteFile, getTradeGraphsByYear, setReplacer } from "./utils";

interface GravityResultsType {
  year: number;
  id: string;
  full_id: string;
  importerLabel: string;
  exporterLabel: string;
  CafFob: "FromExporter" | "FromImporter";
  newimporterId: string;
  newimporterLabel: string;
  newexporterId: string;
  newexporterLabel: string;
  valueToSplit: number;
  pred_trade: number;
}

type OkEdgeAttributes = {
  proximity: number;
  observedTradeValues: number[];
};
type OkNodeAttributes = EntityNodeAttributes;

async function readGravityResults() {
  // read existing network file
  const tradeGraphsByYear = await getTradeGraphsByYear("ratios");
  const tasks = values(tradeGraphsByYear).map(async (graph) => {
    const year = graph.getAttribute("year");
    console.log(`Start ${year}...`);
    // read gravity results

    console.log(`${year}...`);
    const csvString = await readFile(`../results/gravity_${year}.csv`);
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
            (graph as GraphEntityPartiteType).mergeDirectedEdgeWithKey(newFlowId, gr.newexporterId, gr.newimporterId, {
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
            });
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
    console.log(`${year} done`);

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

    mkdirSync("../data/blocks/louvain/", { recursive: true });
    // isolate CAF and FOB subgraphs
    // FOB = reporter is exporter
    // CAF = reporter is importer
    const okEdges = {
      fob: graph.filterEdges(
        (_, atts, source) => atts.type === "trade" && atts.status === "ok" && atts.reportedBy === source,
      ),
      caf: graph.filterEdges(
        (_, atts, __, target) => atts.type === "trade" && atts.status === "ok" && atts.reportedBy === target,
      ),
    };

    const okGraphs = {
      fob: UndirectedGraph.from(graph.emptyCopy()) as unknown as UndirectedGraph<OkNodeAttributes, OkEdgeAttributes>,
      caf: UndirectedGraph.from(graph.emptyCopy()) as unknown as UndirectedGraph<OkNodeAttributes, OkEdgeAttributes>,
    };

    // iterate on Caf and Fob
    toPairs(okEdges).map(([cafFob, edges]) => {
      const okGraph = okGraphs[cafFob as "caf" | "fob"];
      // total trade = sum of values
      const totalBilateralTrade = sum(edges.map((e) => (graph as GraphEntityPartiteType).getEdgeAttribute(e, "value")));
      const weightedDegrees: Record<"in" | "out", Record<string, number>> = { in: {}, out: {} };
      edges.forEach((e) => {
        const value = (graph as GraphEntityPartiteType).getEdgeAttribute(e, "value");
        if (value === undefined) {
          throw new Error("ok flow can't have no value");
        }
        weightedDegrees.out[graph.source(e)] = (weightedDegrees.out[graph.source(e)] || 0) + value;
        weightedDegrees.in[graph.target(e)] = (weightedDegrees.in[graph.target(e)] || 0) + value;
      });
      // group edges by pair of trade partners
      const groupedEdges = groupBy(edges, (e) => sortBy([graph.source(e), graph.target(e)]).join("-"));
      toPairs(groupedEdges).forEach(([groupKey, impExpCouple]) => {
        const observations: number[] = [];

        const proximities = impExpCouple.map((e) => {
          const observed = (graph as GraphEntityPartiteType).getEdgeAttribute(e, "value") || 0;
          if (observed) observations.push(observed);
          const expected =
            (weightedDegrees.out[graph.source(e)] * weightedDegrees.in[graph.target(e)]) /
            (totalBilateralTrade * totalBilateralTrade);
          const proximity = observed / expected - 1;
          return proximity;
        });
        const maxProximity = max(proximities) || 0;
        if (maxProximity > 0)
          okGraph.addUndirectedEdgeWithKey(groupKey, graph.source(impExpCouple[0]), graph.target(impExpCouple[0]), {
            proximity: Math.log(maxProximity),
            observedTradeValues: observations,
          });
      });

      // remove deprecated nodes
      okGraph.filterNodes((n) => okGraph.degree(n) === 0).forEach((n) => okGraph.dropNode(n));

      // compute Louvain + ambiguity metric
      assignLouvainEdgeAmbiguity({ runs: 20, getEdgeWeight: "proximity", resolution: 1 }, okGraph);

      // export as CSV
      const csvData: Record<string, string | number | undefined>[] = [];
      const nodeAttsToKeep = ["cited", "reporting", "label", "gphStatus", "community", "meanAmbiguityScore"];
      okGraph.forEachEdge((e, atts, source, target, srcAtts, trgAtts) => {
        csvData.push({
          key: e,
          source,
          target,
          ...atts,
          observedTradeValues: atts.observedTradeValues.join("|"),
          maxObservedTradeValue: max(atts.observedTradeValues),
          ...mapKeys(pick(srcAtts, nodeAttsToKeep), (_, k) => camelCase(`source ${k}`)),
          ...mapKeys(pick(trgAtts, nodeAttsToKeep), (_, k) => camelCase(`target ${k}`)),
        });
      });

      const csvString = stringify(csvData, { columns: keys(csvData[0]), header: true });
      writeFileSync(`../data/blocks/louvain/${year}_${cafFob}.csv`, csvString);
      // TODO: export for Gephi Lite
      const gexfString = gexf.write(okGraph);
      writeFileSync(`../data/blocks/louvain/${year}_${cafFob}.gexf`, gexfString);
    });

    console.log(`${year} done`);
  });
  const r = await Promise.allSettled(tasks);
  const errors = r.filter((r) => r.status === "rejected");
  if (errors.length > 0) console.log(errors);
}

readGravityResults()
  .catch((e) => console.log(e))
  .then(() => console.log("done"));
