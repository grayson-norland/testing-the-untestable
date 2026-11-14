# python:3.12-slim is published for linux/amd64 and linux/arm64.
# psycopg[binary] ships pre-built wheels for both, so no compiler or libpq is needed.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

RUN useradd --system --no-create-home authsvc
USER authsvc

EXPOSE 5000
# One worker on purpose: tokens are kept in memory and must be shared by every request.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "8", \
     "--access-logfile", "-", "--chdir", "src", "app:app"]
