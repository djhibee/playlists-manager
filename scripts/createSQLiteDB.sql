-- SQLITE script to create DB tables
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE FILES(
ID       INTEGER     PRIMARY KEY   AUTOINCREMENT,
LOSSY    TEXT                          ,
LOSSLESS TEXT,
MATCH_TYPE INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX i  ON FILES(LOSSY);
CREATE INDEX i2 ON FILES(LOSSLESS);
CREATE TABLE PLAYLISTS(
PLAYLISTNAME  TEXT    NOT NULL,
PLAYORDER     INTEGER NOT NULL,
TRACKID       INTEGER NOT NULL,
PRIMARY KEY(PLAYLISTNAME,PLAYORDER),
FOREIGN KEY(TRACKID) REFERENCES FILES(ID)
);
CREATE INDEX i3 ON PLAYLISTS(PLAYLISTNAME);
COMMIT;
