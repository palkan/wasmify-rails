import sqlite3InitModule from "@sqlite.org/sqlite-wasm";

export const setupSQLiteDatabase = async () => {
  const sqlite3 = await sqlite3InitModule();

  console.log("Running SQLite3 version", sqlite3.version.libVersion);
  const db =
    "opfs" in sqlite3
      ? new sqlite3.oo1.OpfsDb("/railsdb.sqlite3")
      : new sqlite3.oo1.DB("/railsdb.sqlite3", "ct");
  console.log(
    "opfs" in sqlite3
      ? `OPFS is available, created persisted database at ${db.filename}`
      : `OPFS is not available, created transient database ${db.filename}`,
  );

  return db;
};
