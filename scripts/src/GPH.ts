import { parse } from "csv/sync";
import { readFileSync } from "fs";
import { groupBy, keyBy } from "lodash";

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
export interface GPHStatusInTime {
  GPH_code: string;
  GPH_name: string;
  start_year: string;
  end_year: string;
  GPH_status: "Member of";
  sovereign_GPH_code: string;
}
const _GPH_Data = readFileSync(`${conf.pathToGeoPolHist}/data/aggregated/GeoPolHist_entities_extended.json`, "utf8");
const GPHInTime: GeoPolHistEntitiesExtended = JSON.parse(_GPH_Data);

const gphEntitiesF = readFileSync(`${conf.pathToGeoPolHist}/data/GeoPolHist_entities.csv`);
export const GPHEntities = parse(gphEntitiesF, { columns: true }) as GPHEntity[];
export const GPHEntitiesByCode = keyBy(GPHEntities, (g) => g.GPH_code);

const gphInformalPartsF = readFileSync(`./GPH_informal.csv`);
export const gphInformalParts = parse(gphInformalPartsF, { columns: true }) as GPHStatusInTime[];
export const gphInformalPartsByCode = groupBy(gphInformalParts, (g) => g.sovereign_GPH_code);

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

export function autonomousGPHEntity(
  gphCode: string,
  year: number,
): { entity: GPHEntity; status?: GPHStatusType; autonomous: boolean } {
  const entity = GPHEntitiesByCode[gphCode];
  if (!entity) {
    throw new Error(`${gphCode} is not a known GPH code`);
  } else {
    const status = GPH_status(gphCode, year + "", true);
    switch (status?.status) {
      case undefined:
        //console.warn(`${entity.GPH_name} (${gphCode}) has no known status in ${year}`);
        return { entity, autonomous: false };
      case "Sovereign":
      case "Associated state of":
      case "Sovereign (limited)":
      case "Sovereign (unrecognized)":
      case "Colony of":
      case "Dependency of":
      case "Protectorate of":
      case "Vassal of":
        return { entity, status: status.status, autonomous: true };
      case "Informal":
        // to be treated as geographical area later
        return { entity, status: status.status, autonomous: false };
      default: {
        if (status && status.sovereign) {
          return autonomousGPHEntity(status?.sovereign, year);
        } else {
          // console.warn(
          //   `GPH_code ${gphCode} of status ${status?.status} does not have any sovereign ${status?.sovereign}`,
          // );
          return { entity, status: status?.status, autonomous: false };
        }
      }
    }
  }
}

/**
 * GPH_informal_parts retrieve entities which formed an informal entity at its creation
 * @param informal_GPH_code code of the informal entity
 * @param year year to filter out parts which are not autonomous
 */
export function GPH_informal_parts(informal_GPH_code: string, year: number) {
  const parts = gphInformalPartsByCode[informal_GPH_code];
  if (parts !== undefined) {
    return parts
      .filter((p) => {
        // keep parts which are listed for the requested year
        return p.start_year <= year + "" && "" + year <= p.end_year;
      })
      .map((p) => {
        return p.GPH_code;
      });
  }
  console.warn(`Unknown informal entity ${informal_GPH_code}`);
  return [];
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
