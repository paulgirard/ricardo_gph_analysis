import { flatten, fromPairs, keys, mapValues, range, sum, toPairs, values, zip } from "lodash";

import conf from "./configuration.json";
import { findRelevantTradeFlowToEntity } from "./graphTraversals";
import { GraphEntityPartiteType } from "./types";

export function findBilateralRatiosInOneYear(
  reportingGPHId: string,
  partnersGPHIds: string[],
  direction: "Export" | "Import",
  graph: GraphEntityPartiteType,
) {
  const year = graph.getAttribute("year");

  if (graph.hasNode(reportingGPHId) && partnersGPHIds.every((id) => graph.hasNode(id))) {
    // groupe trade edges by associated partners
    // there can be more than one partners by trade flow as some flows point to areas or groups
    const partnersByTradeEdges = findRelevantTradeFlowToEntity(graph, reportingGPHId, partnersGPHIds, direction);

    if (keys(partnersByTradeEdges).length > 1) {
      // check that we found all partners
      const foundAllPartners = values(partnersByTradeEdges)
        .reduce((ac, s) => {
          return ac.union(s);
        }, new Set<string>())
        .isSupersetOf(new Set(partnersGPHIds));
      if (!foundAllPartners) throw new Error(`can't find ratios in year ${year} can't find all entities`);

      console.log(year, reportingGPHId, partnersByTradeEdges);
      const tradeValues = mapValues(partnersByTradeEdges, (_, edge) => {
        const { Exp, Imp } = graph.getEdgeAttributes(edge);
        const value = direction === "Export" ? Exp : Imp;
        if (value === undefined) throw new Error(`Edge ${edge} is not reported by ${reportingGPHId}`);
        return value;
      });

      const ratios: Record<string, number> = {};
      let groupRatios: { partners: string[]; value: number }[] = [];
      toPairs(partnersByTradeEdges).forEach(([edge, partnersSet]) => {
        const value = tradeValues[edge];
        const partners = Array.from(partnersSet);

        if (partners.length === 1) {
          ratios[partners[0]] = value;
        } else groupRatios.push({ partners, value });
      });

      // if we have one direct edge to one partner we must remove it from group list
      // in case of split other we can have this situation
      // USA -> Cartagena (Colombia)
      // USA -> south_america -> Cartagena (Colombia)
      // we want to ignore the second flow as it's already reported by USA there fore we don't consider it's included in central america value
      groupRatios = groupRatios
        .map((gr) => {
          const filteredPartners = gr.partners.filter((p) => ratios[p] === undefined);
          //test if group is still a group
          if (filteredPartners.length > 1)
            return {
              value: gr.value,
              partners: filteredPartners,
            };
          else if (filteredPartners.length === 1) {
            ratios[filteredPartners[0]] = gr.value;
          }
          return undefined;
        })
        .filter((gr) => gr !== undefined);

      // compute ratios
      const total = sum(values(ratios)) + sum(groupRatios.map((gr) => gr.value));
      return {
        ratios: mapValues(ratios, (v) => v / total),
        groupRatios: groupRatios.map((gr) => ({ partners: gr.partners, ratio: gr.value / total })),
      };
    } else throw new Error(`can't find ratios in year ${year} found ${keys(partnersByTradeEdges).length} trade flow`);

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
  throw new Error(`can't find ratios in year ${year} can't find all entities`);
}

const YEAR_MAX_GAP = 10;

export function findBilateralRatios(
  year: number,
  reportingGPHId: string,
  partnersGPHIds: string[],
  direction: "Export" | "Import",
  tradeGraphsByYear: Record<string, GraphEntityPartiteType>,
) {
  // TODO: filter out members for which we already have a reported trade flow (reportingGPHId) - (partnersGPHIds)
  // TODO: remove reportingGPHId from partnersGPHIds

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
    console.log(currentYear, reportingGPHId, missingPartners);
    // early exit when all partners have a ratio
    if (missingPartners.length === 0) break;

    if (tradeGraphsByYear[currentYear + ""] !== undefined) {
      try {
        const { ratios, groupRatios } = findBilateralRatiosInOneYear(
          reportingGPHId,
          missingPartners,
          direction,
          tradeGraphsByYear[currentYear + ""],
        );
        console.log(currentYear, reportingGPHId, { ratios, groupRatios });
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
                ratio: gr.ratio,
                status: "in_a_group",
              };
          });
        });
      } catch (error) {
        console.log((error as Error).message);
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
