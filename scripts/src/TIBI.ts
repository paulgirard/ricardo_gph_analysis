import { DirectedGraph } from "graphology";
import { fromPairs, isNil, sum } from "lodash";

/**
 * For a given FOB or CAF trade graph (directed) add a new edge attribute TIBI
 * @param graph
 */

export function assignTIBI(graph: DirectedGraph, cafFob: "caf" | "fob") {
  // FOB ok
  // if CAF reverse edge direction

  // X(n)
  // FOB: sum of exports by n
  // CAF: sum of imports by n
  const X = fromPairs(
    graph.mapNodes((n) => {
      const xEdges = cafFob === "fob" ? graph.outboundEdges(n) : graph.inboundEdges(n);
      const totalExportN = sum(xEdges.map((e) => graph.getEdgeAttribute(e, "value") || 0));

      return [n, totalExportN];
    }),
  );

  graph.forEachEdge((e, atts, i, j) => {
    // Xij as export of i to j
    const Xij = atts.value || 0;
    const xrEdges = cafFob === "fob" ? graph.inboundEdges(j) : graph.outboundEdges(j);
    // Xrj as
    // FOB: all export from all the World but i to j
    // CAF: all import to all the World but i from j
    const Xrj = sum(
      xrEdges.map((rj) => {
        if (cafFob === "fob" ? graph.source(rj) !== i : graph.target(rj) !== i) {
          return graph.getEdgeAttribute(rj, "value") || 0;
        }
        return 0;
      }),
    );

    //Xr as
    // FOB: total exports from all the world but i
    // CAF: total imports from all the world but i
    const Xr =
      cafFob === "fob"
        ? sum(
            graph.mapOutEdges((_, rAtts, rSource) => {
              if (rSource !== i) return rAtts.value || 0;
              else return 0;
            }),
          )
        : sum(
            graph.mapInEdges((_, rAtts, __, rTarget) => {
              if (rTarget !== i) return rAtts.value || 0;
              else return 0;
            }),
          );

    let TIBI: number | undefined = undefined;
    // case of isolated trade partners with only one edge
    // TIBI can't be calculated
    if (Xrj == 0 || Xr == 0) TIBI = 1;
    else {
      // I1. If Xrj = 0 => infinity
      const I1 = Xij / X[i] / (Xrj / Xr); // Xij * Xr / (X[i] * Xrj)

      // I3
      const I3 = (1 - Xij / X[i]) / (1 - Xrj / Xr);

      // TIBI : I2 but on I1/I3
      TIBI = (I1 / I3 - 1) / (I1 / I3 + 1);
    }

    // assign result on edge
    // TIBI can be undefined when : i,j is the only flow to j (fob) from j (caf)
    graph.setEdgeAttribute(e, "TIBI", isNaN(TIBI) || isNil(TIBI) ? undefined : TIBI);
  });

  return graph;
}
