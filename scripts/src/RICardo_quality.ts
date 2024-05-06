import async from "async";
import fs from "fs";
import { MultiDirectedGraph } from "graphology";
import { flatten, get, identity, isNaN, keyBy, keys, last, range, sortBy, sum, uniq } from "lodash";
import sqlite3, { Database } from "sqlite3";

import conf from "./configuration.json";

// GeoPolHist
type GeoPolHistEntitiesExtended = Record<
  string,
  { name: string; years: Record<string, { status: string; sovereign: string }[]> }
>;
const _GPH_Data = fs.readFileSync(`${conf.pathToGeoPolHist}/data/aggregated/GeoPolHist_entities_extended.json`, "utf8");
const GPH_Data: GeoPolHistEntitiesExtended = JSON.parse(_GPH_Data);

function GPH_status(GPH_code: string, year: string) {
  if (GPH_Data && GPH_Data[GPH_code] && GPH_Data[GPH_code].years && year in GPH_Data[GPH_code].years) {
    return {
      status: GPH_Data[GPH_code].years[year][0].status,
      sovereign: GPH_Data[GPH_code].years[year][0].sovereign
        ? GPH_Data[GPH_Data[GPH_code].years[year][0].sovereign].name
        : GPH_Data[GPH_code].name,
    };
  }
  return null;
}

// RICardo database access as singleton
class DB {
  static _db: Database | null = null;

  static get(): Database {
    if (this._db === null) {
      this._db = new sqlite3.Database(`${conf["pathToRICardoData"]}/sqlite_data/RICardo_viz.sqlite`);
    }
    return this._db;
  }
}

interface ComputedData {
  year: number;
  nbFlowsIntraReportings: number;
  nbFlowsDeadHands: number;
  ratioFlowsDeadsHands: number;
  valueFlowsIntraReporting: number;
  valueFlowsDeadHands: number;
  ratioValueDeadHands: number;
  ratioValueIntraOnBestGuestReportingBilateral: number;
  ratioValueBestGuessReportingBilateralOnBestGuess: number;
  ratioValueBestGuessReportingBilateralOnFedericoTena: number;
  partnersOnlyRatio: Record<string, number>;
  reportingRatio: Record<string, number>;
}
type NodeAttributes = Record<string, string | number>;

const computeGraph = (year: number, done: (error: Error | null, data?: ComputedData) => void) => {
  DB.get().all(
    `SELECT * FROM flow_aggregated
    WHERE
      flow is not null and rate is not null AND
      year = ${year} AND
      (partner is not null AND (partner not LIKE 'world%' OR partner IN ('World_best_guess', 'World Federico Tena')))
      `,
    function (err, rows) {
      console.log(year);
      if (err) done(err);

      const graph = new MultiDirectedGraph();

      //build bilateral trade network
      rows.forEach((r) => {
        const w = (r.flow * (r.unit || 1)) / r.rate;
        if (w && w != 0) {
          if (["WorldFedericoTena", "Worldbestguess"].includes(r.partner_slug)) {
            // store total flows as nodes params
            const p: NodeAttributes = {
              type: r.reporting_type,
              label: r.reporting,
              continent: r.reporting_continent,
            };
            p[`${r.partner_slug}_${r.expimp}`] = w;

            graph.mergeNode(r.reporting_slug, p);
          } else {
            const reporting_GPH_status = GPH_status(r.reporting_GPH_code, "" + year);
            graph.mergeNode(r.reporting_slug, {
              type: r.reporting_type,
              label: r.reporting,
              GPH_status: reporting_GPH_status?.status || r.reporting_type,
              part_of: r.reporting_part_of_GPH_entity || reporting_GPH_status?.sovereign,
              continent: r.reporting_continent,
              reporting: 1,
            });
            const partner_GPH_status = GPH_status(r.partner_GPH_code, "" + year);
            graph.mergeNode(r.partner_slug, {
              type: r.partner_type,
              label: r.partner,
              GPH_status: partner_GPH_status?.status || r.partner_type,
              part_of: r.partner_part_of_GPH_entity || partner_GPH_status?.sovereign,
              continent: r.partner_continent,
            });
            let source = r.reporting_slug;
            let target = r.partner_slug;
            // swap
            if (r.expimp === "Imp") {
              [source, target] = [target, source];
            }
            const edgeData = {
              weight: w,
              direction: r.expimp,
              source_type: r.type,
            };
            graph.addEdge(source, target, edgeData);
          }
        }
      });

      // analysis

      // count flows to "dead hands"
      // dead hands are trade partners who are not reporters the same year
      // imperfections which breaks the ideal squared trade matrix

      let nbFlowsIntraReportings = 0;
      let valueFlowsIntraReporting = 0;
      let nbFlowsDeadHands = 0;
      let valueFlowsDeadHands = 0;
      const deadHandsTypes = { groups: 0, informal: 0, others: 0 };
      graph.forEachEdge((_e, eAtts, _src, _srcAtts, _trg, trgAtts) => {
        if (eAtts.direction === "Exp") {
          if (trgAtts.reporting === 1) {
            // bilateral flow between two reportings
            nbFlowsIntraReportings += 1;
            valueFlowsIntraReporting += eAtts.weight;
          } else {
            nbFlowsDeadHands += 1;
            if (trgAtts.type === "group") deadHandsTypes.groups += 1;
            else if (trgAtts.GPH_status === "informal") deadHandsTypes.informal += 1;
            else deadHandsTypes.others += 1;

            valueFlowsDeadHands += eAtts.weight;
          }
        }
      });
      let worldTradeReportingBilateral = 0;
      let worldTradeReporting = 0;
      let worldTradeTena = 0;
      let nbReportings = 0;
      const partnersOnlyRatio: Record<string, number> = {};
      const reportingRatio: Record<string, number> = {};
      graph.forEachNode((n, atts) => {
        worldTradeTena += atts.WorldFedericoTena_Exp || 0;
        if (atts.reporting === 1) {
          nbReportings += 1;
          if (graph.degree(n) > 0 && atts.Worldbestguess_Exp) {
            if (atts.WorldFedericoTena_Exp) reportingRatio[n] = atts.Worldbestguess_Exp / atts.WorldFedericoTena_Exp;
            worldTradeReportingBilateral += atts.Worldbestguess_Exp || 0;
          }
        }
        worldTradeReporting += atts.Worldbestguess_Exp || 0;
      });
      graph.forEachNode((n, atts) => {
        if (atts.reporting !== 1 && graph.inDegree(n) > 0) {
          // partner only trade partner aka dead hand
          // how important if that dead hand
          const totalTradePartner = sum(
            graph.inboundEdges(n).map((e) => {
              const { weight, direction } = graph.getEdgeAttributes(e);
              if (direction) return weight;
              else return 0;
            }),
          );
          partnersOnlyRatio[atts.label] = (totalTradePartner / worldTradeReporting) * 100;
        } else if (atts.reporting !== 1) {
          console.log(`dead hand partner with no incoming flows ${n}`);
        }
      });
      const data = {
        year,
        nbFlowsIntraReportings,
        nbFlowsDeadHands,
        ratioFlowsDeadsHands: nbFlowsDeadHands / (nbFlowsIntraReportings + nbFlowsDeadHands),
        valueFlowsIntraReporting,
        valueFlowsDeadHands,
        ratioValueDeadHands: valueFlowsDeadHands / (valueFlowsDeadHands + valueFlowsIntraReporting),
        ratioValueIntraOnBestGuestReportingBilateral: valueFlowsIntraReporting / worldTradeReportingBilateral,
        ratioValueBestGuessReportingBilateralOnBestGuess: worldTradeReportingBilateral / worldTradeReporting,
        ratioValueBestGuessReportingBilateralOnFedericoTena: worldTradeReportingBilateral / worldTradeTena,
        reportingRatio,
        partnersOnlyRatio,
      };
      done(null, data);
    },
  );
};

// prepare list of years to compute from cnnfig
const years = range(conf.startDate, conf.endDate);

// throw computation in async mode
async.map(years, computeGraph, (err, data) => {
  if (err || data === undefined) throw new Error(err ? err.message : "No Data");
  if (data !== undefined) {
    const header = (variable: string) => `${variable},${years.join(",")}\n`;

    let csv = header("Global ratios");
    const variables = uniq(
      flatten(
        data.map((d) => {
          return keys(d).filter((k) => !["year", "reportingRatio", "partnersOnlyRatio"].includes(k));
        }),
      ),
    ) as (keyof ComputedData)[];

    const dataByYear = keyBy(
      data.filter((d): d is ComputedData => d !== undefined),
      (d) => d.year,
    );

    const csvLine = (path: string[]) =>
      `${last(path)},${years
        .map((y) => {
          const value = get(dataByYear[y], path) || "";
          // reduce float precision
          return value % 1 !== 0 ? value.toPrecision(3) : value;
        })
        .join(",")}\n`;

    variables.forEach((variable) => {
      csv += csvLine([variable]);
    });
    csv += header("Reportings (BestGuess/FT)");
    // Reportings data: list and sort by average of logs
    const reportings = sortBy(
      uniq(
        flatten(
          data.map((d) => {
            return keys(d?.reportingRatio);
          }),
        ),
      ),
      (r) => {
        const logs = data
          .map((d) =>
            d?.reportingRatio[r] && !isNaN(d.reportingRatio[r]) ? Math.abs(Math.log(d?.reportingRatio[r])) : null,
          )

          .filter((log): log is number => log !== null);
        if (logs.length > 0) return (-1 * sum(logs)) / logs.length;
        else return null;
      },
    ).filter(identity);
    reportings.forEach((reporting) => {
      csv += csvLine(["reportingRatio", reporting]);
    });
    // Partner data: list and sort by average value
    csv += header("Partners (percentage on total bilateral trade)");
    const partners = sortBy(
      uniq(
        flatten(
          data.map((d) => {
            return keys(d?.partnersOnlyRatio);
          }),
        ),
      ),
      (p) => {
        const values = data
          .map((d) => d?.partnersOnlyRatio[p])
          .filter((v): v is number => v !== undefined && !isNaN(v));
        if (values.length > 0) return (-1 * sum(values)) / values.length;
        else {
          console.log(`no data for partner ${p}`);
          return null;
        }
      },
    ).filter(identity);
    partners.forEach((partner) => {
      csv += csvLine(["partnersOnlyRatio", partner]);
    });

    fs.writeFile(`../data/quality.csv`, csv, "utf8", (err) => {
      if (err) console.log(`error : couldn't write quality CSV ${err}`);
      else console.log(`writing to quality CSV`);
    });
  }
});
DB.get().close();
