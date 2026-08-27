import { stringify } from "csv/sync";
import { existsSync } from "fs";
import { readFile, writeFile } from "fs/promises";
import { DirectedGraph } from "graphology";
import louvain from "graphology-communities-louvain";
import gexf from "graphology-gexf";
import { modularity } from "graphology-metrics/graph";
import { flatten, groupBy, mapValues, maxBy, range, sum } from "lodash";

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
        const graph = gexf.parse(DirectedGraph, graphXML.toString());

        const result: ModularityTestResult[] = [];
        // run louvain with many reoslution and keep modularity
        range(0.2, 4, 0.2).forEach((resolution) => {
          const details = louvain.detailed(graph, {
            resolution,
            getEdgeWeight: "proximity",
          });
          if (details.count > 1)
            result.push({
              year,
              resolution,
              modularity: modularity(graph, {
                getEdgeWeight: "proximity",
                getNodeCommunity: (n) => details.communities[n],
                resolution: 1,
              }),
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

  const allResolutions: number[] = [];
  const allNbCommunities: number[] = [];
  console.log(
    mapValues(
      groupBy(data, (d) => d.year),
      (vs) => {
        const maxReso = maxBy(vs, (v) => v.modularity);
        if (maxReso) {
          allResolutions.push(maxReso?.resolution);
          allNbCommunities.push(maxReso.nb_communities);
        }
        return maxReso;
      },
    ),
  );

  console.log(`average resolution ${sum(allResolutions) / allResolutions.length}`);
  const resolution1Data = data.filter((d) => d.resolution === 1);
  const averageNbCommunities = sum(resolution1Data.map((d) => d.nb_communities)) / resolution1Data.length;
  const sd1 = Math.sqrt(
    sum(resolution1Data.map((d) => Math.pow(d.nb_communities - averageNbCommunities, 2))) / resolution1Data.length,
  );

  const averageNbCommunitiesManyReso = sum(allNbCommunities) / allNbCommunities.length;
  const sdManyReso = Math.sqrt(
    sum(allNbCommunities.map((nb) => Math.pow(nb - averageNbCommunitiesManyReso, 2))) / allNbCommunities.length,
  );

  console.log(`SD resol=1 ${sd1}, SD varying reso= ${sdManyReso}`);

  const dataCSV = stringify(data, { header: true });
  await writeFile("../data/blocks/louvain_resolution_ratio.csv", dataCSV);
}

computeLouvainResolution()
  .catch((e) => console.log(e))
  .then(() => console.log("done"));
