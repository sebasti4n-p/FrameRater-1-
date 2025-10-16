import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

def get_db_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "frameratr"),
        user=os.getenv("DB_USER", "fr_user"),
        password=os.getenv("DB_PASS", "fr_password"),
    )

def upsert_movie_with_genres(title, release_date, tmdb_id, genres):
    with get_db_conn() as con, con.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("""
            INSERT INTO movie (title, release_date, tmdb_id)
            VALUES (%s, %s, %s)
            ON CONFLICT (tmdb_id) DO UPDATE
            SET title = EXCLUDED.title,
                release_date = EXCLUDED.release_date
            RETURNING id;
        """, (title, release_date, tmdb_id))
        movie_id = cur.fetchone()["id"]

        for g in genres:
            cur.execute("""
                INSERT INTO genre (name) VALUES (%s)
                ON CONFLICT (name) DO NOTHING
                RETURNING id;
            """, (g,))
            if cur.rowcount == 0:
                cur.execute("SELECT id FROM genre WHERE name = %s", (g,))
            genre_id = cur.fetchone()["id"]

            cur.execute("""
                INSERT INTO movie_genre (movie_id, genre_id)
                VALUES (%s, %s) ON CONFLICT DO NOTHING;
            """, (movie_id, genre_id))

if __name__ == "__main__":
    upsert_movie_with_genres(
        title="The Dark Knight",
        release_date="2008-07-18",
        tmdb_id=155,
        genres=["Action", "Crime", "Drama"]
    )
    print("Seeded The Dark Knight.")