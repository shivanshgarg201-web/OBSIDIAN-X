# OBSIDIAN X — OpenStreetMap Edition

A small hackathon Flutter mobile app with a built-in **offline simulator** and a separate **real OSM map / GPS / road-routing** page. This is not an emergency-navigation or rescue service.

## Quick start (Windows, Android emulator)

Requirements: Flutter 3.27+ / Dart 3.6+, Android Studio / Android SDK, Node.js 18+, an internet connection.

1. Extract the ZIP.
2. From the extracted folder, in PowerShell: `powershell -ExecutionPolicy Bypass -File .\setup_windows.ps1`.
3. In a **second terminal**: `cd backend`, `npm install`, `npm start`.
4. In a **third terminal**: `cd flutter_app`, `flutter run`.
5. Tap **Open LIVE OpenStreetMap** on the Home or Routes screen; use **Calculate real driving routes**. Use **Use my GPS location** only if you consent to the route service receiving coordinates.

No Google account, API key, billing account or cloud payment is needed for this development demo. The internet is required for live tiles and OSRM routes. For an Android physical device, set the backend LAN IP:

`flutter run --dart-define=OBSIDIAN_API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:3000`

Make sure phone and computer are on the same network, and your firewall allows port 3000. Use HTTPS for any deployed server. Android emulator uses `http://10.0.2.2:3000` by default.

## Folder guide

- `flutter_app/lib/main.dart`: original simulator, event history, safety/alerts/SOS demonstration. **Not connected to real emergency contacts.**
- `flutter_app/lib/live_maps/live_routes_page.dart`: live OpenStreetMap viewport, GPS permissions, real driving route selection, and simulated hazard overlays.
- `backend/src/server.js`: OSRM adapter, route processing, illustrative hazard intersections.
- `backend/src/geometry.js`: point-to-polyline proximity math.
- `backend/src/server.test.js`: tests using a mocked routing provider response.
- `web_demo/index.html`: earlier offline browser demonstration (does not use live maps).
- `README_OPENSTREETMAP.md`: provider usage, limitations and troubleshooting.

## Important limits

- The live map is real, **but all hazard circles, risk scores, emergency SOS and community reports remain simulated**.
- The free public routing endpoint is intended for **small-scale evaluation only**, may be throttled, and might return just one route. Alternative routes are **not guaranteed**.
- Public OSM tiles and public OSRM must not be used as high-traffic production infrastructure. Follow the policies linked in the setup guide.
- When requesting routes, the backend passes origin and destination coordinates to the public FOSSGIS service.
- The zip includes Flutter source, not a precompiled APK; Android SDK and Flutter are needed to build it.

## Tests

Backend: `cd backend && npm test` (after `npm install`).
Flutter static check: `cd flutter_app && flutter analyze` (after setup).
