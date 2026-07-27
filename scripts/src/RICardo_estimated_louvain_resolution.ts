import { stringify } from "csv/sync";
import { existsSync } from "fs";
import { readFile, writeFile } from "fs/promises";
import { UndirectedGraph } from "graphology";
import louvain from "graphology-communities-louvain";
import gexf from "graphology-gexf";
import { flatten, range } from "lodash";

import conf from "./configuration.json";
import { EntityNodeAttributes } from "./types";

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

interface ModularityTestResult {
  year: number;
  resolution: number;
  modularity: number;
  cafFob: "caf" | "fob";
  nb_communities: number;
}

async function computeLouvainResolution() {
  // read existing network file
  const graphFile = (year: number, cafFob: "caf" | "fob") => `../data/blocks/louvain/${year}_${cafFob}.gexf`;
  const yearsCafFob = flatten(
    range(conf.startDate, conf.endDate + 1).map((year) =>
      (["caf", "fob"] as const).map((cafFob) => ({ year, cafFob })),
    ),
  );

  const tasksResults = await Promise.allSettled<Promise<ModularityTestResult[]>[]>(
    yearsCafFob
      .filter(({ year, cafFob }) => existsSync(graphFile(year, cafFob)))
      .map(async ({ year, cafFob }) => {
        const graphXML = await readFile(graphFile(year, "fob"));
        const graph = gexf.parse(UndirectedGraph, graphXML.toString());

        const result: ModularityTestResult[] = [];
        // run louvain with many reoslution and keep modularity
        range(0.2, 4, 0.2).forEach((resolution) => {
          const details = louvain.detailed(graph, { resolution, getEdgeWeight: "proximity" });
          if (details.count > 1)
            result.push({
              year,
              resolution,
              modularity: details.modularity,
              cafFob,
              nb_communities: details.count,
            });
        });

        return result;
      }),
  );

  const errors = tasksResults.filter((r) => r.status === "rejected");
  if (errors.length > 0) console.log(errors);
  const data = flatten(tasksResults.filter((r) => r.status === "fulfilled").map((r) => r.value));

  const dataCSV = stringify(data, { header: true });
  await writeFile("../data/blocks/louvain_resolution_ratio.csv", dataCSV);
}

computeLouvainResolution()
  .catch((e) => console.log(e))
  .then(() => console.log("done"));
