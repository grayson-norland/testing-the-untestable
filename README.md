# LegacyWorks AccountView

A person logs in, searches for an account, and is told what was
found. That is the entire system.

## Getting it running

```
docker compose up --build
```

The first build takes about a minute on a cooperative network. Once
it's up, there's a screen of sorts at `http://localhost:8085/`. Its
use is optional.

To be sure it's alive:

```
curl http://localhost:8085/health
```

If `{"status":"ok"}` comes back, it is running. If something else
comes back, it is running differently.

Stopping it:

```
docker compose down
```

## Logging in

Speak to the dev team. It isn't kept here.

## What's in the repo

**`cobol-app/`** - the application itself.

- `src/` : the programs
- `copybooks/` : parts held in common (record layouts, shared plumbing)
- `www/` : the screen mentioned above
- `lighttpd.conf` : settings for the web server
- `Dockerfile` : instructions for building the above

Comments are in English and in capitals, as was the custom at the
time.

**`auth-server/`** - decides whether a login is permitted, and hands
over the connection details the application needs in order to read
the database.

- `POST /login` : log in; receive a token
- `GET /db-credentials` : present the token; receive the database
  connection details
- `GET /health` : is it alive

Reachable from inside the Compose network only. No port is published
to the host, and this is intended.

**`db/`** - PostgreSQL 16. Rebuilt from `init/` at every start.
Nothing is saved, and nothing needs to be.

- `01-schema.sql` : tables, roles, permissions
- `02-seed-accounts.sql` : the accounts
- `03-seed-users.sql` : those permitted to log in

No port is published to the host.

**`scripts/`** - the regression automation. See below.

**`docs/`** - see "Further documentation" below.

## Accounts

Account numbers look like ACC001, and they run from ACC001 to ACC050.

- Most of them are ordinary, active accounts.
- A few are locked.
- A few are on "the old system" (you'll spot them, they're the higher
  numbers).

There's a data dump in `docs/handoff/accounts_extract.txt` if you want
to see what's supposed to be in there.

One more thing: the accounts on the old system run noticeably slower
than everything else. We never got to the bottom of why. It's been
like that as long as anyone remembers. Probably fine to ignore unless
it's actually causing you problems.

## Regression testing

`scripts/test-automation/run_all_accounts.py` is what we've been
running before each release: it drives the real screen, account by
account, and signs on and off each time.

```
pip install -r scripts/test-automation/requirements.txt
python3 scripts/test-automation/run_all_accounts.py
```

You need Chrome installed. A window opens and drives itself; leave it
alone while it runs. It prints one line per account (`PASS` or `FAIL`,
with whatever it read), and a screenshot of each result lands in
`screenshots/`. `chromedriver` isn't needed separately - recent
Selenium finds Chrome and its driver on its own.

It takes a while - budget the best part of ten minutes for all fifty
accounts, more on a slower machine or a busier network.

Before this, the release checklist said "log in, check a few accounts
by hand, log out" and left it at that. This is that checklist with a
browser doing the clicking instead of a person, so the same steps get
run the same way every time, which is at least an improvement.

## Further documentation

Further documentation exists under `docs/ja/`, in Japanese, and has
not been translated. A handover note from the previous team, covering
what isn't in this file, is in `docs/handoff/`. The email that started
this piece of work is `docs/client-request.txt`.

---

Anything this file doesn't cover, we didn't think needed covering.
