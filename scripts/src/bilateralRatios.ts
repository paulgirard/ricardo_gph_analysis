export async function findBilateralRatios(year: number, reportingGPHId: string, partnersGPHIds: string[]) {
  // for each years nearby the target one
  // we need to inspect resolved networks and search for set of flows reported by reporting targeting the exact same set of partners
  // should we inspect mirror flows? their values are different but are the ratios impacted by mirror disalignement?
  // even if those partners are partially grouped
  // FR -> EN & DE & IT
  // we can use
  // from year y+1 where we have FR -> EN and FR -> DE & IT we take FR->EN/(FR->RN+FR->DE&IT) and  FR->DE&IT/(FR->RN+FR->DE&IT)
  // from year y+4 where we have FR -> DE and FR -> IT we take FR->DE/(FR->DE+FR->IT) and FR->IT/(FR->DE+FR->IT)
  // ratios are then :
  // EN : FR->EN/(FR->RN+FR->DE&IT) * original_value
  // DE : FR->DE&IT/(FR->RN+FR->DE&IT) * FR->DE/(FR->DE+FR->IT) * original_value
  // IT : FR->DE&IT/(FR->RN+FR->DE&IT) * FR->IT/(FR->DE+FR->IT) * original_value

  // problem: we should first compute networks for all years for simple cases before doing this resolution
  // should we accept to solve desagregation with computed values? I think yes.

  return partnersGPHIds.reduce((ratios, partner) => ({ ...ratios, [partner]: 1 / partnersGPHIds.length }), {});
}
