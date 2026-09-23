import { DirectedGraph } from "graphology";
import { fromPairs, sum } from "lodash";

/**
 * For a given FOB or CAF trade graph (directed) add a new edge attribute TIBI
 * @param graph
 */

export function assignTIBI(graph: DirectedGraph) {
  // sum of exports by nodes
  const X = fromPairs(
    graph.mapNodes((n) => {
      let totalExportN = 0;
      graph.forEachOutboundEdge(n, (_, eAtts) => {
        totalExportN += eAtts.value || 0;
      });
      return [n, totalExportN];
    }),
  );

  graph.forEachEdge((e, atts, i, j) => {
    // Xij as export of i to j
    const Xij = atts.value || 0;

    // Xrj as all export from all the World but i to j
    const Xrj = sum(
      graph.mapInboundEdges(j, (_, rjAtts, rjSource) => {
        if (rjSource !== i) {
          return rjAtts.value || 0;
        }
        return 0;
      }),
    );

    //Xr as total exports from all the world but i and j
    const Xr = sum(
      graph.mapOutEdges((_, rAtts, rSource) => {
        if (rSource !== i && rSource !== j) return rAtts.value || 0;
        else return 0;
      }),
    );
    // I1
    const I1 = Xij / X[i] / (Xrj / Xr);
    // I3
    const I3 = (1 - Xij / X[i]) / (1 - Xrj / Xr);
    // TIBI : I2 but on I1/I3
    const TIBI = (I1 / I3 - 1) / (I1 / I3 + 1);
    // assign result on edge
    graph.setEdgeAttribute(e, "TIBI", TIBI);
  });

  return graph;
}
