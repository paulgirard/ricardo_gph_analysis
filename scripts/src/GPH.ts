import { parse } from "csv/sync";
import { readFileSync } from "fs";
import { groupBy, keyBy, sortBy } from "lodash";

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
  lat?: number;
  lng?: number;
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

const gphStatusF = readFileSync(`${conf.pathToGeoPolHist}/data/GeoPolHist_status.csv`);
const _gphStatusFullMetadata = sortBy(
  parse(gphStatusF, { columns: true }) as GPHStatusMetadataType[],
  (s) => s.priority_order * -1,
);
const priorityByStatus = _gphStatusFullMetadata.map((s) => s.GPH_status);
const gphStatusFullMetadata = keyBy(_gphStatusFullMetadata, (s) => s.GPH_status);

export function GPH_status(GPH_code: string, year: string, sovereignCode?: boolean) {
  if (GPHInTime && GPHInTime[GPH_code] && GPHInTime[GPH_code].years && year in GPHInTime[GPH_code].years) {
    const status = sortBy(GPHInTime[GPH_code].years[year], (s) => priorityByStatus.indexOf(s.status))[0];
    if (status && gphStatusFullMetadata[status.status] !== undefined)
      return {
        ...gphStatusFullMetadata[status.status],
        sovereign: sovereignCode
          ? status.sovereign
          : status.sovereign
            ? GPHInTime[status.sovereign].name
            : GPHInTime[GPH_code].name,
      };
  }
  return null;
}

function checkDissolved(gphCode: string, year: number) {
  let firstKnownPastStatus: ReturnType<typeof GPH_status> | null = null;
  let pastYear = year - 1;
  while (firstKnownPastStatus === null && pastYear >= 1816) {
    const pastStatus = GPH_status(gphCode, pastYear + "", true);
    if (pastStatus !== null) {
      console.log(`found pastStatus ${JSON.stringify(pastStatus)} ${pastYear}`);
      firstKnownPastStatus = pastStatus;
    }
    pastYear -= 1;
  }
  if (firstKnownPastStatus !== null && firstKnownPastStatus.GPH_status === "Dissolved into") {
    console.log("replace dissolved", gphCode, year, firstKnownPastStatus.sovereign);
    return autonomousGPHEntity(firstKnownPastStatus.sovereign, year);
  } else {
    // we don't log missing status here. Missing status can be searched when looking at the network
    return { entity: GPHEntitiesByCode[gphCode], autonomous: false };
  }
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

    try {
      switch (status?.group) {
        case undefined:
          // check if dissolved into
          return checkDissolved(gphCode, year);
        case "Sovereign (all)":
        case "Non sovereign":
          return { entity, status: status.GPH_status, autonomous: true };
        default: {
          // Informal
          if (status?.GPH_status === "Informal") {
            // to be treated as geographical area later
            return { entity, status: status.GPH_status, autonomous: false };
          }
          // Part of
          if (status && status.sovereign) {
            return autonomousGPHEntity(status.sovereign, year);
          } else {
            return { entity, status: status?.GPH_status, autonomous: false };
          }
        }
      }
    } catch (error) {
      if (error instanceof RangeError) {
        return { entity, status: status?.GPH_status, autonomous: false };
        // GPH overlapping year model can generate self llop in part of links
      } else throw Error;
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

interface GPHStatusMetadataType {
  GPH_status: GPHStatusType;
  slug: string;
  group: "Sovereign (all)" | "Non sovereign" | "Miscellaneous" | "Part of" | "";
  priority_order: number;
}
