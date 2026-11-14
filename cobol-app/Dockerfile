# Stage 1: compile the COBOL programs.
# debian:bookworm-slim is published for linux/amd64 and linux/arm64,
# so the same Dockerfile builds on Intel, Apple Silicon, Windows and Linux.
FROM debian:bookworm-slim AS build

# gnucobol3 = GnuCOBOL 3.1.2 (compiler `cobc`), libpq-dev = PostgreSQL client library
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnucobol3 libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY copybooks/ copybooks/
COPY src/ src/

# -x: build an executable; -fstatic-call: resolve CALL "PQ..." (libpq) at link time
# -A: extra C compiler flags. GnuCOBOL 3.1.2 on arm64 generates C that uses a temporary
# named "temptr" (for a CALL that returns a POINTER) without declaring it, so the C
# compile fails. The one-line header supplies the missing declaration; on amd64 it is unused.
RUN mkdir -p out \
    && echo 'static void *temptr __attribute__((unused));' > temptr.h \
    && cobc -x -fstatic-call -A "-include /build/temptr.h" -I copybooks -o out/login.cgi src/LOGIN.cob -lpq \
    && cobc -x -fstatic-call -A "-include /build/temptr.h" -I copybooks -o out/acctsrch.cgi src/ACCTSRCH.cob -lpq


# Stage 2: small runtime image with a web server that runs the programs as CGI.
FROM debian:bookworm-slim

# curl is how the programs talk to the auth server
RUN apt-get update \
    && apt-get install -y --no-install-recommends lighttpd libcob4 libpq5 curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/www/html/cgi-bin /var/lib/tut-work \
    && chown www-data:www-data /var/lib/tut-work \
    && chmod 700 /var/lib/tut-work

COPY --from=build /build/out/ /var/www/html/cgi-bin/
COPY www/ /var/www/html/
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

ENV AUTH_URL=http://auth-server:5000 \
    DB_HOST=db \
    DB_PORT=5432 \
    DB_NAME=accounts_db

USER www-data
EXPOSE 8080
CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
