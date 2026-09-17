import { parse, stringify } from "csv/sync";
import { existsSync, readFileSync, writeFileSync } from "fs";
import { MultiDirectedGraph, UndirectedGraph } from "graphology";
import louvain from "graphology-communities-louvain";
import gexf from "graphology-gexf";
import { modularity } from "graphology-metrics/graph";
import { density } from "graphology-metrics/graph/density";
import {
  camelCase,
  groupBy,
  keys,
  mapKeys,
  max,
  maxBy,
  pick,
  pickBy,
  range,
  sortBy,
  sum,
  toNumber,
  toPairs,
} from "lodash";

import { assignLouvainEdgeAmbiguity } from "./louvainEdgeAmbiguity";
import { EntityNodeAttributes } from "./types";

interface ModularityTestResult {
  year: number;
  resolution: number;
  modularity: number;
  nb_communities: number;
}

type OkEdgeAttributes = {
  proximity: number;
  observedTradeValues: number[];
};
type OkNodeAttributes = EntityNodeAttributes & { blockLouvain: number; blockIntraMax: string; blockAN: string };

const blocksStats: {
  year: number;
  cafFob: string; //"caf" | "fob";
  louvain_modularity: number | null;
  intramax_modularity: number | null;
  an_modularity: number | null;
  network_density: number;
}[] = [];
const missingInANAll: Set<string> = new Set();

const years = [...range(1833, 1939), ...range(1948, 2026)];
years.forEach((year) => {
  let intramaxOk = true;
  // read intramax block from data/blocks/Intramax
  const intraMaxBlocks: { [year: number]: { [node: string]: string } } = {};
  const intramaxFile = `../data/blocks/Intramax/paires_blocs_${year}.csv`;
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
  const anBlocsFile = "../data/BlocselonAN.csv";
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
  // read csv flows data/tradeFlows_{yyyy}_gravity.csv
  const tradeFlowsFile = `../data/tradeFlows_${year}_gravity.csv`;

  if (existsSync(tradeFlowsFile)) {
    const csvString = readFileSync(tradeFlowsFile);
    type FlowData = {
      id: string;
      year: number;
      importerId: string;
      importerLabel: string;
      importerType: string;
      exporterId: string;
      exporterLabel: string;
      exporterType: string;
      value: number;
      reportedBy: string;
      partial: string;
      valueToSplit: string;
      newReporters: string;
      newPartners: string;
      originalReportedTradeFlowIds: string;
      status: string;
      notes: string;
    };
    const tradeFlowsData = parse<FlowData>(csvString, {
      columns: true,
      cast: (value, ctx) => {
        if (ctx.column === "value") return toNumber(value);
        return value;
      },
    });
    const bilateralGraph = new MultiDirectedGraph<
      { id: string; label: string; type: string; blockLouvain: number; blockIntraMax: string; blockAN: string },
      FlowData
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
      bilateralGraph.addDirectedEdgeWithKey(flow.id, flow.exporterId, flow.importerId, flow);
    });

    // isolate CAF and FOB subgraphs
    // FOB = reporter is exporter
    // CAF = reporter is importer
    const okEdges = {
      fob: bilateralGraph.filterEdges(
        (_, atts, source) => atts.status === "ok" && atts.reportedBy === source && !!atts.value && isFinite(atts.value),
      ),
      caf: bilateralGraph.filterEdges(
        (_, atts, __, target) =>
          atts.status === "ok" && atts.reportedBy === target && !!atts.value && isFinite(atts.value),
      ),
    };

    // iterate on Caf and Fob
    toPairs(okEdges).map(([cafFob, edges]) => {
      if (edges.length === 0) {
        console.log(`No ${cafFob} flows for ${year}`);
        return;
      }

      const okGraph = UndirectedGraph.from(bilateralGraph.emptyCopy({ multi: false }) as UndirectedGraph, {
        multi: false,
      }) as unknown as UndirectedGraph<OkNodeAttributes, OkEdgeAttributes>;
      // total trade = sum of values
      const totalBilateralTrade = sum(edges.map((e) => bilateralGraph.getEdgeAttribute(e, "value") || 0));
      const weightedDegrees: Record<"in" | "out", Record<string, number>> = { in: {}, out: {} };
      edges.forEach((e) => {
        const value = bilateralGraph.getEdgeAttribute(e, "value");
        if (value === undefined || isNaN(value) || value === 0) {
          throw new Error(`ok flow no value ${e} ${JSON.stringify(bilateralGraph.getEdgeAttributes(e))}`);
        }
        weightedDegrees.out[bilateralGraph.source(e)] = (weightedDegrees.out[bilateralGraph.source(e)] || 0) + value;
        weightedDegrees.in[bilateralGraph.target(e)] = (weightedDegrees.in[bilateralGraph.target(e)] || 0) + value;
      });

      // group edges by pair of trade partners

      // we use undirected as we have many missing trade edges, directed version would bias reporters over partners
      const groupedEdges = groupBy(edges, (e) =>
        sortBy([bilateralGraph.source(e), bilateralGraph.target(e)]).join("-"),
      );
      toPairs(groupedEdges).forEach(([groupKey, impExpCouple]) => {
        const observations: number[] = [];

        const proximities = impExpCouple.map((e) => {
          const observed = (bilateralGraph.getEdgeAttribute(e, "value") || 0) / totalBilateralTrade;
          if (observed) observations.push(observed);
          const expected =
            (weightedDegrees.out[bilateralGraph.source(e)] * weightedDegrees.in[bilateralGraph.target(e)]) /
            (totalBilateralTrade * totalBilateralTrade);
          if (expected === 0)
            throw new Error(
              `${observed} ${expected} ${weightedDegrees.out[bilateralGraph.source(e)]} ${weightedDegrees.in[bilateralGraph.target(e)]} ${totalBilateralTrade}`,
            );
          const proximity = expected !== 0 ? observed / expected - 1 : 0;
          return proximity;
        });
        // we use max over mean as we want to boost local max proximity when calculating blocks
        const maxProximity = max(proximities) || -1;
        if (maxProximity > 0) {
          const sourceTarget = sortBy(
            [bilateralGraph.source(impExpCouple[0]), bilateralGraph.target(impExpCouple[0])],
            (id) => toNumber(id),
          );
          okGraph.addUndirectedEdgeWithKey(groupKey, sourceTarget[0], sourceTarget[1], {
            proximity: Math.log(maxProximity + 1),
            observedTradeValues: observations,
          });
        }
        //else console.log(`Discard edge cause proximity=${maxProximity} ${JSON.stringify(proximities)}`);
      });

      // remove deprecated nodes
      okGraph.filterNodes((n) => okGraph.degree(n) === 0).forEach((n) => okGraph.dropNode(n));
      console.log(`${year} ${cafFob} after filter out no-degree ${okGraph.size} flows ${okGraph.order} nodes`);
      // find optimal resolution
      const result: ModularityTestResult[] = [];
      // - calculate louvain blocks
      range(0.2, 4, 0.2).forEach((resolution) => {
        const details = louvain.detailed(okGraph, {
          resolution,
          getEdgeWeight: "proximity",
        });
        if (details.count > 1)
          result.push({
            year,
            resolution,
            modularity: modularity(okGraph, {
              getEdgeWeight: "proximity",
              getNodeCommunity: (n) => details.communities[n],
              resolution: 1,
            }),
            nb_communities: details.count,
          });
      });
      const optimalResolution = maxBy(result, (r) => r.modularity)?.resolution;
      // compute Louvain + ambiguity metric
      assignLouvainEdgeAmbiguity(
        {
          runs: 20,
          getEdgeWeight: "proximity",
          resolution: optimalResolution || 1,
          communityAttribute: "blockLouvain",
        },
        okGraph,
      );

      // export as CSV
      const csvData: Record<string, string | number | undefined>[] = [];
      const nodeAttsToKeep = [
        "cited",
        "reporting",
        "label",
        "gphStatus",
        "blockLouvain",
        "blockAN",
        "blockIntraMax",
        "meanAmbiguityScore",
        "weighted",
      ];
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

      const csvString = stringify(
        sortBy(csvData, (row) => row.key),
        {
          columns: [
            "key",
            "source",
            "target",
            "proximity",
            "observedTradeValues",
            "coMembershipScore",
            "bridgeNessEdgeScore",
            "ambiguityScore",
            "maxObservedTradeValue",
            "sourceCited",
            "sourceReporting",
            "sourceLabel",
            "sourceGphStatus",
            "sourceBlockLouvain",
            "sourceBlockIntraMax",
            "sourceBlockAn",
            "sourceMeanAmbiguityScore",
            "targetCited",
            "targetReporting",
            "targetLabel",
            "targetGphStatus",
            "targetBlockLouvain",
            "targetBlockIntraMax",
            "targetBlockAn",
            "targetMeanAmbiguityScore",
          ],
          header: true,
        },
      );
      writeFileSync(`../data/blocks/louvain/${year}_${cafFob}.csv`, csvString);
      // TODO: export in Gephi Lite format
      const gexfString = gexf.write(okGraph);
      writeFileSync(`../data/blocks/louvain/${year}_${cafFob}.gexf`, gexfString);

      const entitiesBlocksCsvString = stringify(
        sortBy(
          okGraph.mapNodes((n, atts) => ({
            id: n,
            label: atts.label,
            year,
            cafFob,
            blockLouvain: atts.blockLouvain,
            blockIntraMax: atts.blockIntraMax,
          })),
          (row) => toNumber(row.id),
        ),
        {
          columns: ["id", "label", "blockLouvain", "blockIntraMax", "year", "cafFob"],
          header: true,
        },
      );
      writeFileSync(`../data/blocks/gph_blocks_by_year/${year}_${cafFob}.csv`, entitiesBlocksCsvString);

      // - compute modularity louvain blocks
      const modularityScores: { [type: string]: number | null } = { louvain: null, intramax: null, AN: null };
      modularityScores.louvain = modularity(okGraph, {
        getEdgeWeight: "proximity",
        getNodeCommunity: (n) => okGraph.getNodeAttribute(n, "blockLouvain"),
        resolution: 1,
      });
      if (cafFob === "fob" && intramaxOk) {
        // - compute modularity intramax blocks
        const missingInIntraMax = okGraph.filterNodes((n) => intraMaxBlocks[year][n] === undefined);
        const missingInGravity = keys(intraMaxBlocks[year]).filter((k) => !okGraph.hasNode(k));
        if (missingInIntraMax.length > 0 || missingInGravity.length > 0)
          console.log(
            `${missingInIntraMax.length} missing in IntraMax ${missingInIntraMax} ; ${missingInGravity.length} missing in Gravity ${cafFob} ${missingInGravity} ;`,
          );
        modularityScores.intramax = modularity(okGraph, {
          getEdgeWeight: "proximity",
          getNodeCommunity: (n) => intraMaxBlocks[year][n] || "indéterminé",
          resolution: 1,
        });
      }
      // - compute modularity Adnerson blocks
      const missingInAN = okGraph.filterNodes((n) => anBlocks[n] === undefined);

      const networkDensity = density(okGraph);
      if (missingInAN.length > 0) {
        missingInAN.forEach((m) => missingInANAll.add(m));
        console.log(`${missingInAN.length} missing in AN ${missingInAN}`);
        missingInAN.forEach((missing) => okGraph.dropNode(missing));
      }

      modularityScores.AN = modularity(okGraph, {
        getEdgeWeight: "proximity",
        getNodeCommunity: (n) => anBlocks[n],
        resolution: 1,
      });
      blocksStats.push({
        year,
        cafFob,
        louvain_modularity: modularityScores.louvain,
        intramax_modularity: modularityScores.intramax,
        an_modularity: modularityScores.AN,
        network_density: networkDensity,
      });
    });

    writeFileSync(
      "../data/blocks/modularities_by_year.csv",
      stringify(blocksStats, {
        columns: ["year", "cafFob", "louvain_modularity", "intramax_modularity", "an_modularity", "network_density"],
        header: true,
      }),
    );
  } else {
    throw new Error("file AN does not exist");
  }
});
console.log(`missing entities in AN`);
console.log(missingInANAll);
