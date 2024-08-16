import { parse } from "csv/sync";
import { readFileSync } from "fs";
import { keyBy, toPairs, values } from "lodash";

import conf from "./configuration.json";

// GeoPolHist
type GeoPolHistEntitiesExtended = Record<
  string,
  { name: string; years: Record<string, { status: GPHStatusType; sovereign: string }[]> }
>;

export type ContinentType =
  | "Adriatic"
  | "Africa"
  | "America"
  | "Antarctic"
  | "Arctic"
  | "Asia"
  | "Atlantic"
  | "Baltic"
  | "Europe"
  | "Mediterranean"
  | "Oceania"
  | "Pacific"
  | "Red Sea"
  | "World";
export interface GPHEntity {
  GPH_code: string;
  GPH_name: string;
  continent: ContinentType;
  wikidata?: string;
  wikidata_alt1?: string;
  wikidata_alt2?: string;
  wikidata_alt3?: string;
  notes?: string;
}
const _GPH_Data = readFileSync(`${conf.pathToGeoPolHist}/data/aggregated/GeoPolHist_entities_extended.json`, "utf8");
const GPHInTime: GeoPolHistEntitiesExtended = JSON.parse(_GPH_Data);

const gphEntitiesF = readFileSync(`${conf.pathToGeoPolHist}/data/GeoPolHist_entities.csv`);
export const GPHEntities = parse(gphEntitiesF, { columns: true }) as GPHEntity[];
export const GPHEntitiesByCode = keyBy(GPHEntities, (g) => g.GPH_code);

export function GPH_status(GPH_code: string, year: string, sovereignCode?: boolean) {
  if (GPHInTime && GPHInTime[GPH_code] && GPHInTime[GPH_code].years && year in GPHInTime[GPH_code].years) {
    return {
      status: GPHInTime[GPH_code].years[year][0].status,
      sovereign: sovereignCode
        ? GPHInTime[GPH_code].years[year][0].sovereign
        : GPHInTime[GPH_code].years[year][0].sovereign
          ? GPHInTime[GPHInTime[GPH_code].years[year][0].sovereign].name
          : GPHInTime[GPH_code].name,
    };
  }
  return null;
}
/**
 * GPH_informal_parts retrieve entities which formed an informal entity at its creation
 * @param informal_GPH_code code of the informal entity
 * @param year year to filter out parts which are not autonomous
 */
export function GPH_informal_parts(informal_GPH_code: string, year: number) {
  const parts = toPairs(GPHInTime)
    .map(([entity_code, gph_data]) => {
      // get all entities which are 'part of' or 'dissolved into' the informal
      if (
        gph_data.years[year] &&
        values(gph_data.years).some((statuses) =>
          statuses.some((s) => s.sovereign === informal_GPH_code && ["Part of", "Dissolved into"].includes(s.status)),
        )
      ) {
        return entity_code;
      } else return null;
    })
    .filter((code): code is string => code !== null);

  return parts;
}

export type GPHStatusType =
  | "Dissolved into"
  | "Sovereign"
  | "Associated state of"
  | "Sovereign (limited)"
  | "Sovereign (unrecognized)"
  | "Colony of"
  | "Dependency of"
  | "Possession of"
  | "Protectorate of"
  | "Leased to"
  | "Mandated to"
  | "Occupied by"
  | "Vassal of"
  | "Claimed by"
  | "Neutral or demilitarized zone of"
  | "Discovered"
  | "Part of"
  | "Unknown"
  | "Informal"
  | "International";
