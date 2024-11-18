export function registerSQLiteWasmInterface(worker, db, opts = {}) {
  const name = opts.name || "sqlite4rails";

  worker[name] = {
    exec: function (sql) {
      let cols = [];
      let rows = db.exec(sql, { columnNames: cols, returnValue: "resultRows" });

      return {
        cols,
        rows,
      };
    },

    changes: function () {
      return db.changes();
    },
  };
}

export const registerPGliteWasmInterface = (worker, db, opts = {}) => {
  const name = opts.name || "pglite4rails";

  worker[name] = {
    async query(sql, params) {
      return db.query(sql, params);
    }
  };
}
