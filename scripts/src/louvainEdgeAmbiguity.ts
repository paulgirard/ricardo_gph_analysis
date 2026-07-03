import Graph, { UndirectedGraph } from "graphology";
import louvain from "graphology-communities-louvain/experimental/robust-randomness";
import { mapValues, mean, zipObject } from "lodash";

function computeLouvainEdgeScores(
  graph: Graph,
  {
    runs,
    getEdgeWeight,
    resolution,
  }: {
    runs: number;
    getEdgeWeight?: string;
    resolution: number;
  },
) {
  const edgeScores: { [edge: string]: number } = {};

  // Init:
  graph.forEachEdge((e, _) => {
    edgeScores[e] = 0;
  });

  // Accumulate co-membership occurrences:
  for (let i = 0; i < runs; i++) {
    const communities = louvain(graph, {
      resolution,
      getEdgeWeight: getEdgeWeight || null,
    });
    graph.forEachEdge((e, _, source, target) => {
      if (communities[source] === communities[target]) edgeScores[e]++;
    });
  }

  const coMembershipEdgeScores = mapValues(edgeScores, (edgeScore) => edgeScore / runs);
  const bridgeNessEdgeScores = mapValues(coMembershipEdgeScores, (coMemberShip) => 1 - coMemberShip);
  const ambiguityEdgeScores = mapValues(coMembershipEdgeScores, (coMemberShip) => coMemberShip * (1 - coMemberShip) * 4);
  const nodes = graph.nodes();
  const meanAmbiguityNodeScores = zipObject(
    nodes,
    nodes.map((n) => mean(graph.mapEdges(n, (e) => ambiguityEdgeScores[e]))),
  );

  return {
    coMembershipEdgeScores,
    bridgeNessEdgeScores,
    ambiguityEdgeScores,
    meanAmbiguityNodeScores,
  };
}

export interface LouvainEdgeAmbiguityEdgeAttributes {
  coMembershipScore: number;
  bridgeNessEdgeScore: number;
  ambiguityScore: number;
  sourceCommunityId: string;
}

export interface LouvainEdgeAmbiguityNodeAttributes {
  meanAmbiguityScore: number;
  modularity: string;
}

export function assignLouvainEdgeAmbiguity(
  parameters: {
    runs: number;
    getEdgeWeight?: string;
    resolution: number;
  },
  graph: UndirectedGraph,
): UndirectedGraph {
  const { coMembershipEdgeScores, bridgeNessEdgeScores, ambiguityEdgeScores, meanAmbiguityNodeScores } =
    computeLouvainEdgeScores(graph, parameters);

  // Run Louvain once more, with the same setup, to get some community classes (for coloring, basically):
  louvain.assign(graph, {
    resolution: parameters.resolution,
    getEdgeWeight: parameters.getEdgeWeight || null,
    nodeCommunityAttribute: "community",
  });

  graph.forEachEdge((edge, _, source) => {
    graph.mergeEdgeAttributes(edge, {
      coMembershipScore: coMembershipEdgeScores[edge],
      bridgeNessEdgeScore: bridgeNessEdgeScores[edge],
      ambiguityScore: ambiguityEdgeScores[edge],
      sourceCommunityId: (coMembershipEdgeScores[edge] > 0.5
        ? graph.getNodeAttribute(source, "community")
        : "bridge") as string,
    });
  });
  graph.forEachNode((node) => {
    graph.setNodeAttribute(node, "meanAmbiguityScore", meanAmbiguityNodeScores[node]);
  });

  return graph;
}
