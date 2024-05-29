import { Database } from "sqlite3";

import conf from "./configuration.json";

// RICardo database access as singleton
export class DB {
  static _db: Database | null = null;

  static get(): Database {
    if (this._db === null) {
      this._db = new Database(`${conf["pathToRICardoData"]}/sqlite_data/RICardo_viz.sqlite`);
    }
    return this._db;
  }
}
