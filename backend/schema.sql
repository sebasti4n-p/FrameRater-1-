-- ==========================
-- Extensions (required for CITEXT)
-- ==========================
CREATE EXTENSION IF NOT EXISTS citext;

-- ==========================
-- Users (Firebase-auth’d)
-- ==========================
CREATE TABLE app_user (
  uid TEXT PRIMARY KEY,                -- Firebase UID
  email CITEXT UNIQUE,                 -- case-insensitive unique email
  display_name TEXT,
  photo_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================
-- Movies / TV shows
-- ==========================
CREATE TABLE movie (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  release_date DATE,
  director_name VARCHAR(200),
  tmdb_id INT UNIQUE
);

CREATE TABLE tv_show (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  release_date DATE,
  director_name VARCHAR(200),
  tmdb_id INT UNIQUE
);

-- ==========================
-- Genres (shared)
-- ==========================
CREATE TABLE genre (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name CITEXT UNIQUE NOT NULL          -- case-insensitive unique genre name
);

-- Junction tables for many-to-many genres
CREATE TABLE movie_genre (
  movie_id INT NOT NULL REFERENCES movie(id) ON DELETE CASCADE,
  genre_id INT NOT NULL REFERENCES genre(id) ON DELETE CASCADE,
  PRIMARY KEY (movie_id, genre_id)
);

CREATE TABLE tv_genre (
  tv_id INT NOT NULL REFERENCES tv_show(id) ON DELETE CASCADE,
  genre_id INT NOT NULL REFERENCES genre(id) ON DELETE CASCADE,
  PRIMARY KEY (tv_id, genre_id)
);

-- Helpful reverse-lookup indexes
CREATE INDEX idx_movie_genre_genre_id ON movie_genre (genre_id, movie_id);
CREATE INDEX idx_tv_genre_genre_id    ON tv_genre    (genre_id, tv_id);

-- ==========================
-- User ratings (one row per user per item)
-- ==========================
CREATE TABLE movie_rating (
  uid TEXT NOT NULL REFERENCES app_user(uid) ON DELETE CASCADE,
  movie_id INT NOT NULL REFERENCES movie(id) ON DELETE CASCADE,
  rating_val NUMERIC(2,1) NOT NULL,   -- e.g., 0.0–10.0
  rated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (uid, movie_id),
  CHECK (rating_val >= 0 AND rating_val <= 10)
);

CREATE TABLE tv_rating (
  uid TEXT NOT NULL REFERENCES app_user(uid) ON DELETE CASCADE,
  tv_id INT NOT NULL REFERENCES tv_show(id) ON DELETE CASCADE,
  rating_val NUMERIC(3,1) NOT NULL,
  rated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (uid, tv_id),
  CHECK (rating_val >= 0 AND rating_val <= 10)
);

-- ==========================
-- Reviews (text + optional separate score)
-- ==========================
CREATE TABLE movie_review (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  movie_id INT NOT NULL REFERENCES movie(id) ON DELETE CASCADE,
  uid TEXT NOT NULL REFERENCES app_user(uid) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uniq_movie_review UNIQUE (movie_id, uid)
);

CREATE TABLE tv_review (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tv_id INT NOT NULL REFERENCES tv_show(id) ON DELETE CASCADE,
  uid TEXT NOT NULL REFERENCES app_user(uid) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uniq_tv_review UNIQUE (tv_id, uid)
);

-- ==========================
-- Favorites (many-to-many)
-- ==========================
CREATE TABLE favorite_movie (
  uid TEXT NOT NULL REFERENCES app_user(uid) ON DELETE CASCADE,
  movie_id INT NOT NULL REFERENCES movie(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (uid, movie_id)
);

CREATE TABLE favorite_tv (
  uid TEXT NOT NULL REFERENCES app_user(uid) ON DELETE CASCADE,
  tv_id INT NOT NULL REFERENCES tv_show(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (uid, tv_id)
);

-- ==========================
-- People / Cast / Crew
-- ==========================
CREATE TABLE person (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  birth_date DATE,
  bio TEXT,
  photo_url TEXT
);

CREATE TABLE role_type (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL  -- e.g. 'Actor', 'Director', 'Writer', 'Producer'
);

CREATE TABLE production_cast (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id INT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  movie_id INT REFERENCES movie(id) ON DELETE CASCADE,
  tv_id INT REFERENCES tv_show(id) ON DELETE CASCADE,
  role_type_id INT NOT NULL REFERENCES role_type(id),
  character_name VARCHAR(100),              -- if applicable
  billed_order INT CHECK (billed_order IS NULL OR billed_order > 0),  -- e.g., 1 = lead actor
  created_at TIMESTAMPTZ DEFAULT now(),
  CHECK (
    (movie_id IS NOT NULL AND tv_id IS NULL)
    OR (tv_id IS NOT NULL AND movie_id IS NULL)
  )
);

-- Prevent duplicate cast entries per production/role
CREATE UNIQUE INDEX uq_cast_movie
ON production_cast (person_id, role_type_id, movie_id, COALESCE(character_name, ''));

CREATE UNIQUE INDEX uq_cast_tv
ON production_cast (person_id, role_type_id, tv_id, COALESCE(character_name, ''));

-- ==========================
-- Aggregated Views
-- ==========================
CREATE VIEW movie_rating_agg AS
SELECT
  m.id AS movie_id,
  COUNT(r.rating_val) AS rating_count,
  AVG(r.rating_val)   AS rating_avg
FROM movie m
LEFT JOIN movie_rating r ON r.movie_id = m.id
GROUP BY m.id;

CREATE VIEW tv_rating_agg AS
SELECT
  t.id AS tv_id,
  COUNT(r.rating_val) AS rating_count,
  AVG(r.rating_val)   AS rating_avg
FROM tv_show t
LEFT JOIN tv_rating r ON r.tv_id = t.id
GROUP BY t.id;

-- ==========================
-- Helpful Indexes
-- ==========================
CREATE INDEX idx_movie_rating_movie_id ON movie_rating (movie_id);
CREATE INDEX idx_tv_rating_tv_id ON tv_rating (tv_id);
CREATE INDEX idx_movie_review_movie_id_created ON movie_review (movie_id, created_at DESC);
CREATE INDEX idx_tv_review_tv_id_created ON tv_review (tv_id, created_at DESC);
CREATE INDEX idx_movie_rating_uid ON movie_rating (uid);
CREATE INDEX idx_tv_rating_uid ON tv_rating (uid);
CREATE INDEX idx_fav_movie_uid ON favorite_movie (uid);
CREATE INDEX idx_fav_tv_uid ON favorite_tv (uid);

-- ==========================
-- Optional: better title search (enable if needed)
-- ==========================
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- CREATE INDEX movie_title_trgm  ON movie   USING gin (title gin_trgm_ops);
-- CREATE INDEX tv_title_trgm     ON tv_show USING gin (title gin_trgm_ops);
