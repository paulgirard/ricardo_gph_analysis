import { readFileSync } from "fs";

import conf from "./configuration.json";

// GeoPolHist
type GeoPolHistEntitiesExtended = Record<
  string,
  { name: string; years: Record<string, { status: string; sovereign: string }[]> }
>;
const _GPH_Data = readFileSync(`${conf.pathToGeoPolHist}/data/aggregated/GeoPolHist_entities_extended.json`, "utf8");
const GPH_Data: GeoPolHistEntitiesExtended = JSON.parse(_GPH_Data);

export function GPH_status(GPH_code: string, year: string, sovereignCode?: boolean) {
  if (GPH_Data && GPH_Data[GPH_code] && GPH_Data[GPH_code].years && year in GPH_Data[GPH_code].years) {
    return {
      status: GPH_Data[GPH_code].years[year][0].status,
      sovereign: sovereignCode
        ? GPH_Data[GPH_code].years[year][0].sovereign
        : GPH_Data[GPH_code].years[year][0].sovereign
          ? GPH_Data[GPH_Data[GPH_code].years[year][0].sovereign].name
          : GPH_Data[GPH_code].name,
    };
  }
  return null;
}
