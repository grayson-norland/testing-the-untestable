"""Auth server.

Endpoints
  GET  /health          liveness check
  POST /login           JSON {"username", "password"} -> {"token", "token_type"}
  GET  /db-credentials  Authorization: Bearer <token> -> {"user", "password"}
                        (the account the COBOL app uses to read the database)

Tokens are kept in memory, so they are forgotten when the container restarts.
Each token is good for a fixed number of lookups (MAX_LOOKUPS), then it is spent.

Small, boring, and load-bearing. It is the one service that holds the keys;
the COBOL side merely asks it nicely and hopes for the best.
"""
import os
import secrets
import threading

import psycopg
from flask import Flask, jsonify, request

app = Flask(__name__)

# Token -> [username, lookups so far], in memory. No database, no clock, no
# ceremony. A restart of this container logs everybody out, which the night
# shift calls "a feature".
TOKENS = {}
TOKENS_LOCK = threading.Lock()   # gunicorn runs threads; be polite about it

# Max lookups: 30. The figure was agreed in a meeting.
# The minutes of the meeting are in the same place as everything else.
MAX_LOOKUPS = 30

# Same limits as the COBOL side (its fields have fixed widths and firm opinions).
MAX_USERNAME = 50
MAX_PASSWORD = 100


def env(name, default=""):
    return os.environ.get(name, default)


def db_connection():
    """Connect as the auth service's own (read-only) database account.

    Not the account the COBOL app uses; that one is handed out below and can
    read accounts but not users. Nobody has ever asked why. Good."""
    return psycopg.connect(
        host=env("DB_HOST", "db"),
        port=env("DB_PORT", "5432"),
        dbname=env("DB_NAME", "accounts_db"),
        user=env("AUTH_DB_USER"),
        password=env("AUTH_DB_PASS"),
        connect_timeout=5,
    )


def password_is_valid(username, password):
    # The hash is checked inside the database (pgcrypto's crypt), so the stored
    # hash never leaves it. Both values are bound parameters, not pasted in.
    with db_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM app_users "
            "WHERE lower(btrim(username)) = lower(btrim(%s)) "
            "AND password_hash = crypt(%s, password_hash)",
            (username, password),
        )
        # One row or none. Two rows would be a different conversation.
        return cur.fetchone() is not None


def bearer_token():
    # "Authorization: Bearer <token>" -> "<token>", or "" if it isn't one.
    header = request.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        return header[len("Bearer "):].strip()
    return ""


# Compose asks this every few seconds. It is the only endpoint that
# is never in a bad mood.
@app.get("/health")
def health():
    return jsonify(status="ok")


@app.post("/login")
def login():
    # JSON in, token out. Anything that isn't a JSON object with two strings of
    # sensible length is a 400 before we so much as look at the database.
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify(error="invalid_request"), 400
    username = body.get("username")
    password = body.get("password")
    if (not isinstance(username, str) or not isinstance(password, str)
            or not 1 <= len(username) <= MAX_USERNAME
            or not 1 <= len(password) <= MAX_PASSWORD):
        return jsonify(error="invalid_request"), 400

    try:
        valid = password_is_valid(username, password)
    except psycopg.Error:
        app.logger.exception("database error during login")
        return jsonify(error="internal_error"), 500

    if not valid:
        app.logger.info("login failed for %r", username[:MAX_USERNAME])
        return jsonify(error="invalid_credentials"), 401

    # 16 random bytes from the OS = 32 lowercase hex characters (the COBOL side
    # checks for exactly that shape, so please do not get creative here).
    token = secrets.token_hex(16)
    with TOKENS_LOCK:
        TOKENS[token] = [username, 0]
    app.logger.info("login ok for %r", username)
    return jsonify(token=token, token_type="Bearer")


# Any valid token gets the (read-only) database account for the COBOL app.
@app.get("/db-credentials")
def db_credentials():
    token = bearer_token()
    with TOKENS_LOCK:
        entry = TOKENS.get(token)
        if entry is not None:
            entry[1] += 1
            if entry[1] > MAX_LOOKUPS:
                del TOKENS[token]
                entry = None
    if entry is None:
        return jsonify(error="unauthorized"), 401
    return jsonify(user=env("COBOL_DB_USER"), password=env("COBOL_DB_PASS"))
