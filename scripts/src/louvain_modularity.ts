import { SerializedGraphDataset } from "@gephi/gephi-lite-sdk";
import { parse, stringify } from "csv/sync";
import { existsSync, readFileSync, writeFileSync } from "fs";
import { DirectedGraph, MultiDirectedGraph, UndirectedGraph } from "graphology";
import louvain from "graphology-communities-louvain";
import { circular } from "graphology-layout";
import forceAtlas2, { inferSettings } from "graphology-layout-forceatlas2";
import { modularity } from "graphology-metrics/graph";
import { density } from "graphology-metrics/graph/density";
import {
  camelCase,
  capitalize,
  fromPairs,
  groupBy,
  keys,
  mapKeys,
  mapValues,
  max,
  maxBy,
  omit,
  pick,
  pickBy,
  range,
  sortBy,
  toNumber,
  toPairs,
} from "lodash";

import { assignTIBI } from "./TIBI";
import { EntityNodeAttributes, FlowValueImputationMethod } from "./types";
import gephiLiteTemplate from "./undirectedLouvainTemplate.gephilite.json";

interface ModularityTestResult {
  year: number;
  resolution: number;
  modularity: number;
  nb_communities: number;
}

type OkEdgeAttributes = {
  observedTradeValues: number[];
  maxObservedTradeValues: number;
  TIBI?: number;
};
type OkNodeAttributes = EntityNodeAttributes & {
  blockLouvainTibi: number;
  blockLouvainProximity: number;
  blockLouvainMaxobservedtradevalues: number;
  blockIntraMax: string;
  blockAN: string;
};

type FlowData = {
  // id: string;
  // year: number;
  // importerId: string;
  // importerLabel: string;
  //importerType: string;
  // exporterId: string;
  // exporterLabel: string;
  //exporterType: string;
  value: number;
  //reportedBy: string;
  //partial: string;
  // valueToSplit: number;
  // newReporters: string;
  // newPartners: string;
  //originalReportedTradeFlowIds: string;
  status: string;
  notes: string;
  valueGeneratedBy: FlowValueImputationMethod[];
  CafFob: "caf" | "fob";
};
export type LouvainGraph = DirectedGraph<OkNodeAttributes, Partial<OkEdgeAttributes>>;

interface GravityResultsType {
  year: number;
  id: string;
  old_id: string;
  value: number;
  pred_trade: number;
  CafFob: "caf" | "fob";
  importerId: string;
  importerLabel: string;
  exporterId: string;
  exporterLabel: string;
  valueToSplit: number;
  status: string;
  valueGeneratedBy: FlowValueImputationMethod[];
  notes: string;
}

const blocksStats: {
  year: number;
  louvain_maxObservedTradeValues_modularity: number | null;
  network_density: number;
}[] = [];
const missingInANAll: Set<string> = new Set();

const years = range(1833, 2026);
years.forEach((year) => {
  let intramaxOk = true;
  // read intramax block from results/communities/Intramax
  const intraMaxBlocks: { [year: number]: { [node: string]: string } } = {};
  const intramaxFile = `../results/communities/Intramax/paires_blocs_${year}.csv`;
  if (existsSync(intramaxFile)) {
    const csvString = readFileSync(intramaxFile);
    const intramaxData = parse<{
      value: string;
      importerId: string;
      exporterId: string;
      bloc_exp: string;
      bloc_imp: string;
    }>(csvString, { columns: true });
    intraMaxBlocks[year] = {};
    intramaxData.forEach((row) => {
      if (row.value !== "NA" && row.bloc_exp !== "NA" && row.bloc_imp !== "NA") {
        intraMaxBlocks[year][row.exporterId] = row.bloc_exp;
        intraMaxBlocks[year][row.importerId] = row.bloc_imp;
      }
    });
    intramaxOk = true;
  } else {
    console.log(`no intramax for ${year}`);
    intraMaxBlocks[year] = {};
    intramaxOk = false;
  }
  // read Adnerson blocks from a csv to create from XLSX file
  const anBlocsFile = "../external data/BlocselonAN.csv";
  const anBlocks: { [node: string]: string } = {};
  if (existsSync(anBlocsFile)) {
    const csvString = readFileSync(anBlocsFile);
    const anblocsData = parse<{ GPH_code: string; region_AndersonNorheim: string }>(csvString, {
      columns: true,
    });

    anblocsData.forEach((row) => {
      anBlocks[row.GPH_code] = row.region_AndersonNorheim;
    });
  } else {
    throw new Error("file AN does not exist");
  }
  // read csv flows from gravity results
  const tradeFlowsFile = `../results/gravity/gravity_${year}.csv`;

  if (existsSync(tradeFlowsFile)) {
    const tradeFlowsCsvString = readFileSync(tradeFlowsFile);
    const tradeFlowsData = parse<GravityResultsType>(tradeFlowsCsvString, {
      columns: true,
      cast: (v, ctx) => {
        switch (ctx.column) {
          case "year":
            return v ? parseInt(v) : undefined;
          case "value":
          case "valueToSplit":
          case "pred_trade":
            return v ? parseFloat(v) : undefined;
          case "valueGeneratedBy":
            return v.split("|");
          default:
            return v;
        }
      },
    });

    const bilateralGraph = new MultiDirectedGraph<
      { id: string; label: string; type: string; blockLouvain: number; blockIntraMax: string; blockAN: string },
      FlowData & { TIBI?: number; CafFob?: "caf" | "fob" }
    >({ multi: true });
    tradeFlowsData.forEach((flow) => {
      bilateralGraph.mergeNode(flow.exporterId, {
        ...mapKeys(
          pickBy(flow, (_, k) => k.startsWith("exporter")),
          (_, k) => k.replace(/^exporter/, "").toLowerCase(),
        ),
        blockIntraMax: intraMaxBlocks[year][flow.exporterId],
        blockAN: anBlocks[flow.exporterId],
      });
      bilateralGraph.mergeNode(flow.importerId, {
        ...mapKeys(
          pickBy(flow, (_, k) => k.startsWith("importer")),
          (_, k) => k.replace(/^importer/, "").toLowerCase(),
        ),
        blockIntraMax: intraMaxBlocks[year][flow.exporterId],
        blockAN: anBlocks[flow.exporterId],
      });
      bilateralGraph.addDirectedEdgeWithKey(flow.id, flow.exporterId, flow.importerId, {
        ...pick(flow, ["CafFob", "status", "valueGeneratedBy", "notes", "value"]),
      });
    });

    // flag CAF and FOB flows
    // FOB = reporter is exporter
    // CAF = reporter is importer

    // total trade = sum of values
    // const totalBilateralTrade = sum(edges.map((e) => bilateralGraph.getEdgeAttribute(e, "value") || 0));
    // const weightedDegrees: Record<"in" | "out", Record<string, number>> = { in: {}, out: {} };
    // edges.forEach((e) => {
    //   const value = bilateralGraph.getEdgeAttribute(e, "value");
    //   if (value === undefined || isNaN(value)) {
    //     throw new Error(`ok flow no value ${e} ${JSON.stringify(bilateralGraph.getEdgeAttributes(e))}`);
    //   }
    //   cafFobGraph.addDirectedEdgeWithKey(
    //     e,
    //     bilateralGraph.source(e),
    //     bilateralGraph.target(e),
    //     bilateralGraph.getEdgeAttributes(e),
    //   );

    //   weightedDegrees.out[bilateralGraph.source(e)] = (weightedDegrees.out[bilateralGraph.source(e)] || 0) + value;
    //   weightedDegrees.in[bilateralGraph.target(e)] = (weightedDegrees.in[bilateralGraph.target(e)] || 0) + value;
    // });

    // remove deprecated edges/nodes
    bilateralGraph
      .filterEdges((_, atts) => atts.status !== "ok" || atts.CafFob === undefined)
      .forEach((e) => bilateralGraph.dropEdge(e));
    bilateralGraph.filterNodes((n) => bilateralGraph.degree(n) === 0).forEach((n) => bilateralGraph.dropNode(n));
    console.log(
      `${year} directed after filter out non-ok edges and no-degree ${bilateralGraph.size} flows ${bilateralGraph.order} nodes`,
    );

    // // compute and assign proximity
    // cafFobGraph.forEachEdge((e, atts) => {
    //   const Iij = atts.value || 0;

    //   const Ipij =
    //     (weightedDegrees.out[bilateralGraph.source(e)] * weightedDegrees.in[bilateralGraph.target(e)]) /
    //     totalBilateralTrade;

    //   if (Ipij === 0)
    //     throw new Error(
    //       `${Iij} ${Ipij} ${weightedDegrees.out[bilateralGraph.source(e)]} ${weightedDegrees.in[bilateralGraph.target(e)]} ${totalBilateralTrade}`,
    //     );
    //   const proximity =
    //     cafFob === "fob"
    //       ? // FOB
    //         (Iij - Ipij) / weightedDegrees.out[bilateralGraph.source(e)]
    //       : // CAF
    //         (Iij - Ipij) / weightedDegrees.in[bilateralGraph.target(e)];

    //   cafFobGraph.setEdgeAttribute(e, "proximity", proximity);
    // });
    //compute and assign TIBI
    assignTIBI(bilateralGraph);
    console.log("TIBI assigned merging flows into undirected");
    // reduce to undirected
    const undirectedGraph = UndirectedGraph.from(bilateralGraph.emptyCopy({ multi: false }) as DirectedGraph, {
      multi: false,
    }) as unknown as LouvainGraph;
    // we use undirected as we have many missing trade edges, directed version would bias reporters over partners

    // group edges by pair of trade partners
    const groupedEdges = groupBy(bilateralGraph.edges(), (e) =>
      sortBy([bilateralGraph.source(e), bilateralGraph.target(e)]).join("-"),
    );

    toPairs(groupedEdges).forEach(([groupKey, impExpCouple]) => {
      const tibis = impExpCouple
        .map((e) => bilateralGraph.getEdgeAttribute(e, "TIBI"))
        .filter((tibi) => tibi !== undefined);

      // we use max over mean as we want to boost local max proximity when calculating blocks
      const maxTIBI = max(tibis);

      const sourceTarget = sortBy(
        [bilateralGraph.source(impExpCouple[0]), bilateralGraph.target(impExpCouple[0])],
        (id) => toNumber(id),
      );
      // reduce to maximum values
      undirectedGraph.addUndirectedEdgeWithKey(groupKey, sourceTarget[0], sourceTarget[1], {
        observedTradeValues: impExpCouple.map((e) => bilateralGraph.getEdgeAttribute(e, "value")),
        maxObservedTradeValues: max(impExpCouple.map((e) => bilateralGraph.getEdgeAttribute(e, "value"))),
        TIBI: maxTIBI,
      });
    });

    console.log(
      `${year} Louvain after merged reciprocal+cafFob flows ${undirectedGraph.size} flows ${undirectedGraph.order} nodes`,
    );

    // find optimal resolution
    const weightAtts: (keyof OkEdgeAttributes)[] = ["maxObservedTradeValues"];
    weightAtts.forEach((weightAtt) => {
      const result: ModularityTestResult[] = [];
      // - calculate louvain blocks
      range(0.2, 4, 0.2).forEach((resolution) => {
        const details = louvain.detailed(undirectedGraph, {
          resolution,
          getEdgeWeight: weightAtt,
        });
        if (details.count > 1)
          result.push({
            year,
            resolution,
            modularity: modularity(undirectedGraph, {
              getEdgeWeight: weightAtt,
              getNodeCommunity: (n) => details.communities[n],
              resolution: 1,
            }),
            nb_communities: details.count,
          });
      });
      const optimalResolution = maxBy(result, (r) => r.modularity)?.resolution;
      // compute Louvain + ambiguity metric
      // assignLouvainEdgeAmbiguity(
      //   {
      //     runs: 10,
      //     getEdgeWeight: weightAtt,
      //     resolution: optimalResolution || 1,
      //     communityAttribute: `blockLouvain${capitalize(weightAtt)}`,
      //   },
      //   undirectedGraph,
      // );
      louvain.assign(undirectedGraph, {
        getEdgeWeight: weightAtt,
        resolution: optimalResolution || 1,
        nodeCommunityAttribute: `blockLouvain${capitalize(weightAtt)}`,
      });
    });

    // export as CSV
    const csvData: Record<string, string | number | undefined>[] = [];
    const nodeAttsToKeep = [
      "cited",
      "reporting",
      "label",
      "gphStatus",
      "blockLouvainMaxobservedtradevalues",
      "blockAN",
      "blockIntraMax",
      "meanAmbiguityScore",
      "weighted",
    ];
    undirectedGraph.forEachEdge((e, atts, source, target, srcAtts, trgAtts) => {
      csvData.push({
        key: e,
        source,
        target,
        ...atts,
        observedTradeValues: (atts.observedTradeValues || []).join("|"),
        ...mapKeys(pick(srcAtts, nodeAttsToKeep), (_, k) => camelCase(`source ${k}`)),
        ...mapKeys(pick(trgAtts, nodeAttsToKeep), (_, k) => camelCase(`target ${k}`)),
      });
    });

    const csvString = stringify(
      sortBy(csvData, (row) => row.key),
      {
        columns: [
          "key",
          "source",
          "target",
          "TIBI",
          "maxObservedTradeValues",
          "observedTradeValues",
          // "coMembershipScore",
          // "bridgeNessEdgeScore",
          // "ambiguityScore",
          "maxObservedTradeValue",
          // "sourceCited",
          // "sourceReporting",
          "sourceLabel",
          // "sourceGphStatus",

          "sourceBlockLouvainMaxobservedtradevalues",
          "sourceBlockIntraMax",
          "sourceBlockAn",
          // "sourceMeanAmbiguityScore",
          // "targetCited",
          // "targetReporting",
          "targetLabel",
          // "targetGphStatus",

          "targetBlockLouvainMaxobservedtradevalues",
          "targetBlockIntraMax",
          "targetBlockAn",
          // "targetMeanAmbiguityScore",
        ],
        header: true,
      },
    );
    writeFileSync(`../results/communities/louvain/${year}.csv`, csvString);
    // Gephi Lite format
    const graphDataset: SerializedGraphDataset = { ...(gephiLiteTemplate.graphDataset as SerializedGraphDataset) };
    graphDataset.metadata.title = `${year} blocs`;
    graphDataset.nodeData = fromPairs(undirectedGraph.mapNodes((n, atts) => [n, omit(atts, "type")]));
    graphDataset.edgeData = fromPairs(
      undirectedGraph.mapEdges((n, atts) => [n, mapValues(atts, (v) => (Array.isArray(v) ? v.join("|") : v))]),
    );
    graphDataset.fullGraph.nodes = undirectedGraph.nodes().map((n) => ({ key: n }));
    graphDataset.fullGraph.edges = undirectedGraph.mapEdges((key, _, source, target) => ({ source, target, key }));
    circular.assign(undirectedGraph, { scale: 100 });
    const positions = forceAtlas2(undirectedGraph, {
      iterations: 200,
      settings: { ...inferSettings(undirectedGraph), scalingRatio: 15 },
      //getEdgeWeight: "TIBI",
    });
    graphDataset.layout = positions;
    writeFileSync(
      `../results/communities/louvain/${year}_gephi_lite.json`,
      JSON.stringify({ ...gephiLiteTemplate, graphDataset }),
    );

    const entitiesBlocksCsvString = stringify(
      sortBy(
        undirectedGraph.mapNodes((n, atts) => ({
          id: n,
          label: atts.label,
          year,
          blockLouvainMaxobservedtradevalues: atts.blockLouvainMaxobservedtradevalues,
          blockIntraMax: atts.blockIntraMax,
        })),
        (row) => toNumber(row.id),
      ),
      {
        columns: ["id", "label", "blockLouvainMaxobservedtradevalues", "blockIntraMax", "year"],
        header: true,
      },
    );
    writeFileSync(`../results/communities/gph_blocks_by_year/${year}.csv`, entitiesBlocksCsvString);

    // - compute modularity louvain blocks
    const modularityScores: { [type: string]: number | null } = {};

    modularityScores.louvainMaxobservedtradevalues = modularity(undirectedGraph, {
      getEdgeWeight: "maxObservedTradeValues",
      getNodeCommunity: (n) => undirectedGraph.getNodeAttribute(n, "blockLouvainMaxobservedtradevalues"),
      resolution: 1,
    });
    if (intramaxOk) {
      // - compute modularity intramax blocks
      const missingInIntraMax = undirectedGraph.filterNodes((n) => intraMaxBlocks[year][n] === undefined);
      const missingInGravity = keys(intraMaxBlocks[year]).filter((k) => !undirectedGraph.hasNode(k));
      if (missingInIntraMax.length > 0 || missingInGravity.length > 0)
        console.log(
          `${missingInIntraMax.length} missing in IntraMax ${missingInIntraMax} ; ${missingInGravity.length} missing in Gravity ${missingInGravity} ;`,
        );
    }
    // - compute modularity Adnerson blocks
    const missingInAN = undirectedGraph.filterNodes((n) => anBlocks[n] === undefined);

    const networkDensity = density(undirectedGraph);
    if (missingInAN.length > 0) {
      missingInAN.forEach((m) => missingInANAll.add(m));
      console.log(`${missingInAN.length} missing in AN ${missingInAN}`);
      missingInAN.forEach((missing) => undirectedGraph.dropNode(missing));
    }

    blocksStats.push({
      year,
      louvain_maxObservedTradeValues_modularity: modularityScores.louvainMaxobservedtradevalues,
      network_density: networkDensity,
    });
  }

  writeFileSync(
    "../results/communities/modularities_by_year.csv",
    stringify(blocksStats, {
      columns: ["year", "louvain_maxObservedTradeValues_modularity", "network_density"],
      header: true,
    }),
  );
});
console.log(`missing entities in AN`);
console.log([...missingInANAll].join("\n"));
