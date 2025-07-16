import { parse } from "csv/sync";
import { readFileSync } from "fs";
import { groupBy, keyBy } from "lodash";

import { ContinentType } from "./GPH";

interface GeographicalAreaMember {
  gph_code: string;
  id_name: string;
  gph_continent: ContinentType;
  geo_name: string;
  geo_continent: string;
  included: string;
  partially_included: string;
}

const geographicalAreasF = readFileSync(`./GPH_geographical_area.csv`);
const geographicalAreas = (parse(geographicalAreasF, { columns: true }) as GeographicalAreaMember[])
  // only keep lines which were flaged as included
  .filter((row) => row.included === "1" || row.partially_included === "1")
  // transform as GPH entities
  .map((row) => ({
    GPH_code: row.gph_code,
    GPH_name: row.id_name,
    continent: row.gph_continent,
    geo_name: row.geo_name,
  }));

export const geographicalAreasMembers = groupBy(geographicalAreas, (ga) => ga.geo_name);

interface ColonialAreaToGeographicalArea {
  RICname: string;
  geographical_area: string;
  continental: string;
}

const colonialAreasF = readFileSync(`./RICardo_colonial_to_geographical_area.csv`);
const colonialAreas = parse(colonialAreasF, { columns: true }) as ColonialAreaToGeographicalArea[];

export const colonialAreasToGeographicalArea = keyBy(colonialAreas, (ca) => ca.RICname);
