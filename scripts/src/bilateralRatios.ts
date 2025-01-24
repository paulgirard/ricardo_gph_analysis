export async function findBilateralRatios(year: number, reportingGPHId: string, partnersGPHIds: string[]) {
  // for each years nearby the target one

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

  return partnersGPHIds.reduce((ratios, partner) => ({ ...ratios, [partner]: 1 / partnersGPHIds.length }), {});
}
