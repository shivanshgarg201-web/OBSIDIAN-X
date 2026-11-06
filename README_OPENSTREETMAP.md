# OpenStreetMap integration and provider guidance

## Included live capabilities

1. OpenStreetMap road tiles in Flutter using `flutter_map`.
2. Interactive pan, zoom, route polylines, start/end markers and hazard circles.
3. Foreground GPS on user request using `geolocator`.
4. OSRM route geometry, distance, and estimated driving time via local Node.js backend; alternatives requested where available.
5. Demo-only hazard proximity scoring and route ranking.

## What is *not* included

- Geocoding or free-text destination lookup: four sample Delhi destinations are available; add a consent-aware geocoder later.
- Verified live disaster feeds, road closures, emergency dispatch, real contact notifications, production location tracking.
- Offline OSM map downloading or navigation voice guidance.

## No billing or API keys

This app uses OpenStreetMap tiles and a community-hosted FOSSGIS OSRM service as a **limited, noncommercial demo**. It does not ask for a Google Cloud account or Google Maps key. These community services have usage limits, can be unavailable, and are not guaranteed free hosting for public deployment.

- Tiles: https://operations.osmfoundation.org/policies/tiles/
- Routing: https://routing.openstreetmap.de/about.html
- flutter_map: https://pub.dev/packages/flutter_map

The tile URL is `https://tile.openstreetmap.org/{z}/{x}/{y}.png`; visible attribution is required. The app identifies itself using an app-specific User-Agent and does not offer bulk tile downloading. Avoid generating excessive requests; follow cache requirements. The OSRM adapter serializes requests to approximately one per second, but this **does not make a public service suitable for heavy usage**. For public releases, use an approved hosted tile provider and private or contracted OSRM endpoint.

## Build & launch

1. Install Flutter/Dart, Android Studio, Git, Node.js.
2. Extract the ZIP.
3. Execute `powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1` from the root.
4. Run backend: `cd backend; npm install; npm start`.
5. From another terminal run Flutter: `cd flutter_app; flutter run`.
6. Open the LIVE OpenStreetMap screen.

### Emulator versus phone

- Android emulator backend: `http://10.0.2.2:3000`.
- Real phone: use `flutter run --dart-define=OBSIDIAN_API_BASE_URL=http://192.168.x.x:3000` with your computer's actual LAN IP.
- `setup_windows.ps1` enables cleartext requests only for debug builds; production must use HTTPS.

### Troubleshooting

- Gray map: check internet, OSM tile server policy, and access restrictions.
- Routes fail: start the Node server, check `/api/health`, and try again; public OSRM may be down or throttle requests.
- GPS unavailable: enable location and allow foreground permission. The map starts on Delhi as demo coordinates.
- One route only: the public router may not provide alternative driving routes for that trip.
- Android SDK issue: run `flutter doctor` and follow its diagnostics.

### Privacy and safety

The route request forwards the chosen origin and destination to a third-party routing server, where logs may be kept. The example map sends tile requests to OSM servers. The built-in SOS does not contact emergency services. Never rely on prototype safety scores for real journeys or disasters.
