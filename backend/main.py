import os
from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

app = Flask(__name__)

CORS(app)

def get_db_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "frameratr"),
        user=os.getenv("DB_USER", "fr_user"),
        password=os.getenv("DB_PASS", "fr_password")
    )

@app.route("/health")
def health():
    return {"ok": True}

@app.route("/api/movies", methods=["GET"])
def list_movies():
    q = request.args.get("q")  # optional search term
    sql = "SELECT id, title, release_date, tmdb_id FROM movie"
    params = []
    if q:
        sql += " WHERE title ILIKE %s"
        params.append(f"%{q}%")
    sql += " ORDER BY id DESC LIMIT 50"
    with get_db_conn() as con, con.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify(rows)

@app.route('/api/data', methods=['GET'])
def get_data():
    data = {
        'message': 'Hello, World!',
        'status': 'success'
    }
    return jsonify(data)

@app.route('/')
def index():
    return "Welcome to the Flask API!"

@app.route("/api/movies/<int:movie_id>", methods=["GET"])
def movie_detail(movie_id: int):
    # one query for movie + rating aggregate via the view, and one for genres
    with get_db_conn() as con, con.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("""
            SELECT m.id, m.title, m.release_date, m.tmdb_id,
                   COALESCE(a.rating_count, 0) AS rating_count,
                   ROUND(COALESCE(a.rating_avg, 0)::numeric, 1) AS rating_avg
            FROM movie m
            LEFT JOIN movie_rating_agg a ON a.movie_id = m.id
            WHERE m.id = %s
        """, (movie_id,))
        movie = cur.fetchone()
        if not movie:
            return jsonify({"error": "not found"}), 404

        cur.execute("""
            SELECT g.name
            FROM movie_genre mg
            JOIN genre g ON g.id = mg.genre_id
            WHERE mg.movie_id = %s
            ORDER BY g.name
        """, (movie_id,))
        genres = [row["name"] for row in cur.fetchall()]
    movie["genres"] = genres
    return jsonify(movie)

@app.route("/api/movies/<int:movie_id>/reviews", methods=["GET"])
def movie_reviews(movie_id: int):
    with get_db_conn() as con, con.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("""
            SELECT r.id, r.body, r.created_at, u.display_name, u.uid
            FROM movie_review r
            JOIN app_user u ON u.uid = r.uid
            WHERE r.movie_id = %s
            ORDER BY r.created_at DESC
            LIMIT 50
        """, (movie_id,))
        rows = cur.fetchall()
    return jsonify(rows)

if __name__ == '__main__':
    # Get port safely with a default, and bind to all interfaces in Docker
    port = int(os.getenv("FLASK_PORT", "3000"))
    app.run(debug=True, host='0.0.0.0', port=port)
