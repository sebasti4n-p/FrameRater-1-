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

if __name__ == '__main__':
    # Get port safely with a default, and bind to all interfaces in Docker
    port = int(os.getenv("FLASK_PORT", "3000"))
    app.run(debug=True, host='0.0.0.0', port=port)
