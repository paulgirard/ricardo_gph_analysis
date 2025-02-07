import { allSimpleEdgePaths } from "graphology-simple-path";
import { flatten, fromPairs, keys, mapValues, range, sum, toPairs, values, zip } from "lodash";

import conf from "./configuration.json";
import { GraphEntityPartiteType } from "./types";

export function findBilateralRatiosInOneYear(
  reportingGPHId: string,
  partnersGPHIds: string[],
  graph: GraphEntityPartiteType,
) {
  const year = graph.getAttribute("year");
  if (graph.addNode(reportingGPHId)) {
    // groupe trade edges by associated partners
    // there can be more than one partners by trade flow as some flows point to areas or groups
    const partnersByTradeEdges = partnersGPHIds.reduce<Record<string, string[]>>((acc, partner) => {
      const paths = allSimpleEdgePaths(graph, reportingGPHId, partner);
      if (paths.length > 0) {
        for (const path of paths) {
          const [firstEdge] = path;
          const labels = graph.getEdgeAttribute(firstEdge, "labels");
          if (labels.has("REPORTED_TRADE") || labels.has("GENERATED_TRADE"))
            return { ...acc, [firstEdge]: [...acc[firstEdge], partner] };
        }
        // none of the path was a trade flow
        throw new Error(
          `could not find any trade flow between ${reportingGPHId} and ${partner} in year ${year} but ${paths}`,
        );
      }
      // one missing edge with one partner: abort
      else throw new Error(`no trade data between ${reportingGPHId} and ${partner} in year ${year}`);
    }, {});

    const tradeValues = mapValues(partnersByTradeEdges, (_, edge) => {
      const { value, Exp, ExpReportedBy, Imp } = graph.getEdgeAttributes(edge);
      return (ExpReportedBy === reportingGPHId ? Exp || value : Imp || value) || 0; //  || 0 should never be used...
    });
    const total = sum(values(tradeValues));
    const ratios: Record<string, number> = {};
    const groupRatios: { partners: string[]; ratio: number }[] = [];
    toPairs(partnersByTradeEdges).forEach(([edge, partners]) => {
      const ratio = tradeValues[edge] / total;
      if (partners.length === 1) {
        ratios[partners[0]] = ratio;
      } else groupRatios.push({ partners, ratio });
    });
    return { ratios, groupRatios };

    // we need to inspect resolved networks and search for set of flows reported by reporting targeting the exact same set of partners
    // should we inspect mirror flows? their values are different but are the ratios impacted by mirror disalignement?
    // even if those partners are partially grouped

    // (FR) -> EN & DE & IT in year y
    // Mirror flows in same year: if in year y we have (EN)<-FR, (DE)<-FR and (IT)<-FR should ?
    // pro: conjoncture cons: mirror discrepencies

    // Same reporting other years
    // pro: stable reporting practices cons: trade change bias

    // from year y+/-1 where we have FR -> EN and FR -> DE & IT we take FR->EN/(FR->EN+FR->DE&IT) and  FR->DE&IT/(FR->EN+FR->DE&IT)
    // from year y+/-4 where we have FR -> DE and FR -> IT we take FR->DE/(FR->DE+FR->IT) and FR->IT/(FR->DE+FR->IT)
    // ratios are then :
    // EN : FR->EN/(FR->RN+FR->DE&IT) * original_value
    // DE : original_value * FR->DE&IT/(FR->EN+FR->DE&IT) * FR->DE/(FR->DE+FR->IT)
    // IT : original_value * FR->DE&IT/(FR->EN+FR->DE&IT) * FR->IT/(FR->DE+FR->IT)

    // problem: we should first compute networks for all years for simple cases before doing this resolution
    // should we accept to solve desagregation with computed values? I think yes.
    // 1-1 ne change pas les valeurs ça change les destinataires sauf pour les aggrégations
    // 1-n ne pas les prendre en compte en récursion..

    // for each partner
    // (partner) -[flow: GENERATED_TRADE|REPORTED_TRADE]- (reporting)
    // (partner) <-[SPLIT|AGGREGATE_INTO|SPLIT_OTHER]- (i*) -[flow: GENERATED_TRADE|REPORTED_TRADE]- (reporting)
    // group partners by flow

    // calculate ratio among flows
  }
  throw new Error(`can't find reporting ${reportingGPHId} in year ${year}`);
}

const YEAR_MAX_GAP = 10;

export function findBilateralRatios(
  year: number,
  reportingGPHId: string,
  partnersGPHIds: string[],
  tradeGraphsByYear: Record<string, GraphEntityPartiteType>,
) {
  const partnerRatios: Record<string, { ratio?: number; status?: "ok" | "in_a_group" }> = fromPairs(
    partnersGPHIds.map((p) => [p, {}]),
  );
  // generate list of years to test in proximity order: y-1, y+1, y-2, y+2 ... y+YEAR_MAX_GAP
  const yearsInScope = flatten(
    zip(range(year - 1, year - YEAR_MAX_GAP, -1), range(year + 1, year + YEAR_MAX_GAP, 1)),
  ).filter((y): y is number => y !== undefined && y >= conf.startDate && y <= conf.endDate);
  // we keep only valid years according to configuration

  for (const currentYear of yearsInScope) {
    const missingPartners = keys(partnerRatios).filter((p) => partnerRatios[p]?.status !== "ok");

    // early exit when all partners have a ratio
    if (missingPartners.length === 0) break;

    if (tradeGraphsByYear[currentYear] !== undefined) {
      try {
        const { ratios, groupRatios } = findBilateralRatiosInOneYear(
          reportingGPHId,
          missingPartners,
          tradeGraphsByYear[currentYear],
        );
        //update partners ratios
        toPairs(ratios).forEach(([partner, ratio]) => {
          partnerRatios[partner] = {
            ratio: (partnerRatios[partner].ratio || 1) * ratio,
            status: "ok",
          };
        });
        // groupRatios
        groupRatios.forEach((gr) => {
          gr.partners.forEach((p) => {
            // only keep group ratio if no other ratio has been seen to avoid applying group ratios on multiple years we keep only the first one we saw (i.e. the closest to original flow)
            if (!partnerRatios[p].status)
              partnerRatios[p] = {
                ratio: partnerRatios[p].ratio,
                status: "in_a_group",
              };
          });
        });
      } catch (error) {
        console.log(error);
        // try next year
      }
    } else console.log(`${currentYear} not available in tradeGraphs`);
  }
  // end of ratio lookups
  // we may have ratios for some partners
  // if we have a complete ratio (i.e. not in_a_group) we can generate a new flow
  // if not we will redirect the remaining ones in Rest Of The World
  return partnerRatios;
}
