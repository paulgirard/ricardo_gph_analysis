import { DirectedGraph } from "graphology";
import { isNil, sum } from "lodash";

/**
 * For a given FOB or CAF trade graph (directed) add a new edge attribute TIBI
 * @param graph
 */

export function assignTIBI(graph: DirectedGraph) {
  // Xi
  // FOB: sum of exports by i
  const _X: Record<string, number> = {};
  const X = (i: string): number => {
    if (_X[i] !== undefined) return _X[i];
    const xEdges = graph.outboundEdges(i).filter((e) => graph.getEdgeAttribute(e, "CafFob") === "fob");
    _X[i] = sum(xEdges.map((e) => graph.getEdgeAttribute(e, "value") || 0));
    return _X[i];
  };
  // Mj
  // CAF: sum of imports by i
  const _M: Record<string, number> = {};
  const M = (j: string): number => {
    if (_M[j] !== undefined) return _M[j];
    const xEdges = graph.inboundEdges(j).filter((e) => graph.getEdgeAttribute(e, "CafFob") === "caf");
    _M[j] = sum(xEdges.map((e) => graph.getEdgeAttribute(e, "value") || 0));
    return _M[j];
  };
  // FOB: Xr_ = total exports from all the world but i
  const _Xr_: Record<string, number> = {};
  const Xr_ = (i: string) => {
    if (_Xr_[i] !== undefined) return _Xr_[i];
    _Xr_[i] = sum(
      graph.outEdges().map((e) => {
        if (graph.getEdgeAttribute(e, "CafFob") === "fob" && graph.source(e) !== i)
          return graph.getEdgeAttribute(e, "value") || 0;
        else return 0;
      }),
    );
    return _Xr_[i];
  };
  // CAF: M_r = total imports from all the world but to j
  const _M_r: Record<string, number> = {};
  const M_r = (j: string) => {
    if (_M_r[j] !== undefined) return _M_r[j];
    _M_r[j] = sum(
      graph.inEdges().map((e) => {
        if (graph.getEdgeAttribute(e, "CafFob") === "caf" && graph.target(e) !== j)
          return graph.getEdgeAttribute(e, "value") || 0;
        else return 0;
      }),
    );
    return _M_r[j];
  };

  graph.updateEachEdgeAttributes((e, atts) => {
    const CafFob = atts.CafFob;

    const i = graph.source(e);
    const j = graph.target(e);
    // Xij as export of i to j
    const XMij = atts.value || 0;

    if (CafFob === "fob") {
      const Xi = X(i);
      if (Xi == 0) throw new Error("PAS CONTENT");
      // Xrj as
      // FOB/CAF: all export from all the World but i to j
      const Xrj = sum(
        graph.inboundEdges(j).map((rj) => {
          if (graph.getEdgeAttribute(rj, "CafFob") === CafFob && graph.source(rj) !== i) {
            return graph.getEdgeAttribute(rj, "value") || 0;
          }
          return 0;
        }),
      );
      const Xr_i = Xr_(i);
      let TIBI: number | undefined = undefined;
      // case of isolated trade partners with only one edge
      // TIBI can't be calculated
      if (Xrj === 0 || Xr_i === 0 || XMij === Xi) TIBI = 1;
      else if (XMij === 0) TIBI = -1;
      else {
        // I1
        const I1 = XMij / Xi / (Xrj / Xr_i);
        // I3
        const I3 = (1 - XMij / Xi) / (1 - Xrj / Xr_i);

        // TIBI : I2 but on I1/I3
        TIBI = (I1 / I3 - 1) / (I1 / I3 + 1);
      }
      if (isNaN(TIBI) || isNil(TIBI)) {
        console.log(TIBI, CafFob, { XMij, Xrj, Xr_i, Xi });
        throw new Error("TIBI is undefined");
      }
      return {
        ...atts,
        TIBI,
      };
    } //end FOB
    else if (CafFob === "caf") {
      const Mj = M(j);
      if (Mj == 0) throw new Error("PAS CONTENT");

      const Mir = sum(
        graph.outboundEdges(i).map((ir) => {
          if (graph.getEdgeAttribute(ir, "CafFob") === CafFob && graph.target(ir) !== j) {
            return graph.getEdgeAttribute(ir, "value") || 0;
          }
          return 0;
        }),
      );
      const M_rj = M_r(j);
      let TIBI: number | undefined = undefined;
      // case of isolated trade partners with only one edge
      // TIBI can't be calculated
      if (Mir === 0 || M_rj === 0 || XMij === Mj) TIBI = 1;
      else if (XMij === 0) TIBI = -1;
      else {
        // I1. If Xrj = 0 => infinity
        const I1 = XMij / Mj / (Mir / M_rj);

        // I3
        const I3 = (1 - XMij / Mj) / (1 - Mir / M_rj);

        // TIBI : I2 but on I1/I3
        TIBI = (I1 / I3 - 1) / (I1 / I3 + 1);
      }
      if (isNaN(TIBI) || isNil(TIBI)) {
        console.log(TIBI, CafFob, { XMij, Mir, M_rj, Mj });
        throw new Error("TIBI is undefined");
      }
      return {
        ...atts,
        TIBI,
      };
    } // end CAF
    return atts;
  });
  return graph;
}
