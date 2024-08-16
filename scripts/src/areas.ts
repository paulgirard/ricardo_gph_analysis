import { parse } from "csv/sync";
import { readFileSync } from "fs";
import { groupBy, keyBy } from "lodash";

import { ContinentType } from "./GPH";

interface GeographicalAreaMember {
  GPH_code: string;
  GPH_name: string;
  continent: ContinentType;
  RICname: string;
  "RicnamePeriod (begin/end year": string;
  partially_included: string;
}

const geographicalAreasF = readFileSync(`./GPH_geographical_area.csv`);
const geographicalAreas = parse(geographicalAreasF, { columns: true }) as GeographicalAreaMember[];

export const geographicalAreasMembers = groupBy(geographicalAreas, (ga) => ga.RICname);

interface ColonialAreaToGeographicalArea {
  RICname: string;
  geographical_area: string;
  continental: string;
}

const colonialAreasF = readFileSync(`./RICardo_colonial_to_geographical_area.csv`);
const colonialAreas = parse(colonialAreasF, { columns: true }) as ColonialAreaToGeographicalArea[];

export const colonialAreasToGeographicalArea = keyBy(colonialAreas, (ca) => ca.RICname);
