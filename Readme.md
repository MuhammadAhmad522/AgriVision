# AgriVision — Precision Agriculture Platform

AgriVision is a precision-agriculture system with three parts:

- **Backend API** — FastAPI + PostgreSQL (PostGIS/TimescaleDB) + MQTT broker
- **Web dashboard** — React + TypeScript
- **iOS app** — SwiftUI

All configuration and credential files are already included in this package. You do not need to
create any environment files, API keys, or Firebase settings.

---

## What you need to install

| Software | Where to get it | Needed for |
|---|---|---|
| **Docker Desktop** | https://www.docker.com/products/docker-desktop/ | Backend + web dashboard |
| **Xcode 26.1 or later** | Mac App Store | iOS app only |
| **Node.js 20 or later** | https://nodejs.org/ (or `brew install node`) | Only for the `npm run dev` workflow in Part 2 |
| **Python 3.11 or later** | https://www.python.org/ (or `brew install python`) | Only for the Super Admin seed script in Part 3 |

For the normal Docker workflow in Part 1 that is everything — Python, Node.js, and the database all
run inside Docker, and nothing else is installed on your Mac. Node.js and Python are only needed if
you want the hot-reloading dev server (Part 2) or want to seed the Super Admin from your Mac
(Part 3).

---

## Part 1 — Run the backend and web dashboard

**Step 1.** Install Docker Desktop, open it, and wait until the whale icon in the menu bar stops
animating. Docker must be running before you continue.

**Step 2.** Open the Terminal app and go into the backend folder inside this project. The easiest
way is to type `cd ` (with a space), then drag the `AgriVision-Backend` folder from Finder into the
Terminal window and press Return:

```bash
cd /path/to/AgriVision/AgriVision-Backend
```

**Step 3.** Start everything with one command:

```bash
docker compose up --build
```

The first run downloads the required images and takes **5–10 minutes**. Later runs take a few
seconds. Leave this Terminal window open — it shows the live logs.

**Step 4.** When the logs stop scrolling and show `Application startup complete`, open your browser:

| What | Address |
|---|---|
| **Web dashboard** | http://localhost:3000 |
| Backend API documentation | http://127.0.0.1:8000/docs |
| Health check | http://127.0.0.1:8000/health |

The health check should return `"status":"healthy"`. That confirms the API, database, and
authentication are all working.

**Step 5.** Log in to the dashboard at http://localhost:3000 with the account credentials supplied
separately with this submission.

### Stopping the app

Press `Control + C` in the Terminal window, then run:

```bash
docker compose down
```

Your data is preserved. To start again later, just run `docker compose up` (the `--build` flag is
only needed the first time).

---

## Part 2 — Run the web dashboard in development mode (`npm run dev`)

Part 1 already serves a production build of the dashboard on http://localhost:3000 through Nginx.
Use this part only if you want the Vite dev server instead — hot reload, source maps, and instant
refresh when you edit a file in `AgriVision-Web/src`.

**Step 1.** Start the backend first. The dev server does not include an API of its own — it calls
the backend at `http://127.0.0.1:8000`. In one Terminal window:

```bash
cd /path/to/AgriVision/AgriVision-Backend
docker compose up
```



**Step 2.** Open a **second** Terminal window and go into the web folder:

```bash
cd /path/to/AgriVision/AgriVision-Web
```

**Step 3.** Install the Node dependencies. This is only needed the first time, or after
`package.json` changes:

```bash
npm install
```

**Step 4.** Start the dev server:

```bash
npm run dev
```

Vite prints a local address, normally:

```
  ➜  Local:   http://localhost:5173/
```

**Step 5.** Open **http://localhost:5173** in your browser and log in with the same credentials you
use for the dashboard on port 3000. Both point at the same backend and the same database.

Edit any file under `AgriVision-Web/src` and the browser updates within a second — no rebuild and no
`docker compose` restart needed.

### Other useful commands

| Command | What it does |
|---|---|
| `npm run dev` | Start the dev server with hot reload on port 5173 |
| `npm run build` | Type-check with TypeScript and produce a production build in `dist/` |
| `npm run preview` | Serve the built `dist/` folder locally, to check a production build |
| `npm run lint` | Run Oxlint over the source |

### Pointing the dev server at a different backend

By default the app falls back to `http://127.0.0.1:8000`. To override it, create a file named
`.env.local` inside `AgriVision-Web/` before starting the dev server:

```bash
VITE_API_URL=http://127.0.0.1:8000
```

Setting `VITE_API_URL=` (empty) makes the app use relative paths, which is what the Docker/Nginx
build in Part 1 relies on. Restart `npm run dev` after changing this file.

### Stopping the dev server

Press `Control + C` in the Terminal window running `npm run dev`.

---

## Part 3 — Seed the Super Admin account

The dashboard has no sign-up screen for administrators, so the first Super Admin has to be created
by a script: `AgriVision-Backend/scripts/seed_admin.py`. It does two things:

1. Creates the user in **Firebase Authentication**, or resets the password if the user already
   exists.
2. Creates the matching row in the **PostgreSQL** `users` table with the role `admin`, or upgrades
   an existing row to `admin`.

The email and password it seeds are the two constants at the top of the script:

```python
ADMIN_EMAIL = "muhammadahmad522@gmail.com"
ADMIN_PASSWORD = "Password@123"
```

Edit those first if you want a different Super Admin. Running the script more than once is safe — it
updates instead of failing since it is idempotent.

The backend and database Docker containers from Part 1 must be up and running — the script connects to PostgreSQL on `localhost:5432` and writes the Super Admin record.

### Steps to Seed Super Admin

**Step 1 — Ensure Docker containers are running.**
Make sure your Docker services are running (from Part 1):
```bash
cd AgriVision-Backend
docker compose up -d
```
Verify that the containers (`agrivision_db` and `agrivision_backend`) are healthy.

**Step 2 — Activate the Python virtual environment.**
From the `AgriVision-Backend` folder, activate your virtual environment before running the script:
```bash
source venv/bin/activate
# or if your virtual environment is at the repository root:
# source ../.venv/bin/activate
```
Your terminal prompt will now show `(venv)` or `(.venv)`.

> If the virtual environment does not exist yet, set it up once:
> ```bash
> python3 -m venv venv
> source venv/bin/activate
> pip install sqlalchemy psycopg2-binary geoalchemy2 firebase-admin pydantic pydantic-settings
> ```

**Step 3 — Run the seed script:**
```bash
python3 scripts/seed_admin.py
```

**Step 4 — Verify completion & Log in:**
The terminal will display:
```
Seeding Super Admin: muhammadahmad522@gmail.com
...
Seeding complete.
```
Now open **http://localhost:3000** in your browser and log in with the administrator credentials:
- **Email:** `muhammadahmad522@gmail.com`
- **Password:** `Password@123`

When finished, you can optionally deactivate the virtual environment:
```bash
deactivate
```

### Seeding problems

| Problem | Solution |
|---|---|
| `ModuleNotFoundError: No module named 'app'` | You ran the script from the wrong folder. `cd` into `AgriVision-Backend` and run it as `python3 scripts/seed_admin.py` |
| `ERROR: FIREBASE_SERVICE_ACCOUNT_PATH not set.` | `firebase-credentials.json` is missing from `AgriVision-Backend/`, or your `.env` points at the in-container path `/app/firebase-credentials.json`. Remove that line from `.env`, or run `FIREBASE_SERVICE_ACCOUNT_PATH=firebase-credentials.json python3 scripts/seed_admin.py` |
| `could not connect to server` / `Connection refused` on port 5432 | The database container is not running. Run `docker compose up -d db`, wait a few seconds, and retry |
| `relation "users" does not exist` | The backend has not created the tables yet. Run `docker compose up -d backend`, wait for it to finish starting, then seed again |
| `command not found: python3` or missing packages | The virtual environment is not active. Run `source venv/bin/activate` (or `source ../.venv/bin/activate`), or install required packages |
| Login says the account is not an administrator | You are on a stale session. Sign out, re-run Step 3, and sign in again |

---

## Part 4 — Run the iOS app

The backend from Part 1 must be running first — the iOS app connects to it.

**Step 1.** In Finder, open the project folder and double-click **`AgriVision.xcodeproj`**. Xcode
will launch.

**Step 2.** Wait for Xcode to download the Swift package dependencies (Firebase and others). A
progress bar appears at the top of the window. This takes 2–5 minutes on the first open. Do not
build until it finishes.

> If it seems stuck, choose **File → Packages → Resolve Package Versions**.

**Step 3.** At the top of the Xcode window, click the device selector next to the app name and
choose any iPhone simulator, for example **iPhone 17 Pro**.

**Step 4.** Press **⌘R** (or click the ▶ Play button) to build and run. The first build takes a few
minutes. The Simulator opens automatically and the app launches.

**Step 5.** Sign in with the same account credentials used for the web dashboard.

### If Xcode shows a signing error

If you see *"Signing for AgriVision requires a development team"*:

1. Click the blue **AgriVision** project icon at the top of the left sidebar.
2. Select the **AgriVision** target, then the **Signing & Capabilities** tab.
3. Tick **Automatically manage signing** and pick your own name from the **Team** dropdown
   (any free personal Apple ID works for the Simulator).
4. Press **⌘R** again.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `docker: command not found` | Docker Desktop is not installed, or not yet started. Open it from Applications and wait for it to finish starting |
| `Cannot connect to the Docker daemon` | Docker Desktop is not running. Open it and try again |
| `port is already allocated` | Another program is using port 3000, 8000, 5432, or 1883. Quit that program, or restart your Mac, then retry |
| Web dashboard shows a blank page or network errors | The backend is still starting. Wait for `Application startup complete` in the Terminal, then refresh the browser |
| `npm: command not found` | Node.js is not installed. Install it from nodejs.org or with `brew install node`, then reopen the Terminal |
| `npm run dev` fails with missing packages | You skipped `npm install`. Run it inside `AgriVision-Web`, then try again |
| Port 5173 is already in use | Vite picks the next free port and prints it — use the address it shows. Or quit whatever is on 5173 |
| Dev server loads but every request fails or is blocked by CORS | The backend is not running. Check http://127.0.0.1:8000/health, and confirm `VITE_API_URL` in `AgriVision-Web/.env.local` if you created one |
| The first `docker compose up` seems frozen | It is downloading several gigabytes of images. Give it up to 10 minutes on a normal connection |
| iOS app is stuck on "Connecting to AgriVision" | The backend is not running. Check that http://127.0.0.1:8000/health opens in your browser |
| Xcode build fails with missing packages | The package download did not finish. Use **File → Packages → Reset Package Caches**, then build again |

To completely reset the backend and database and start fresh:

```bash
docker compose down -v
docker compose up --build
```

---

## Project structure

```
AgriVision/
├── AgriVision-Backend/     FastAPI backend, database, Docker setup  ← run docker compose here
├── AgriVision-Web/         React web dashboard
├── AgriVision/             iOS app source code (SwiftUI)
├── AgriVision.xcodeproj    Xcode project  ← double-click to open the iOS app
├── esp/                    ESP32 sensor firmware (not required to run the app)
└── Docs/                   Architecture documents and SRS
```

## Additional documentation

- `Docs/end-to-end-architecture.md` — system architecture
- `Docs/api-services-summary.md` — API endpoint reference
- `Docs/srs/` — software requirements specification
