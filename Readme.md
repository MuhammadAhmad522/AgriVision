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

That is everything. Python, Node.js, and the database all run inside Docker — nothing else is
installed on your Mac.

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

## Part 2 — Run the iOS app

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
