require('dotenv').config();
const express = require('express');
const {proximityMeters} = require('./geometry');
const app = express();
app.disable('x-powered-by');
app.use(express.json({limit:'12kb'}));

// DEMO ONLY: illustrative scenarios; no verified disaster or closure information.
const demoHazards = [
  {id:'demo-flood-1', name:'SIMULATED flood zone', lat:28.6086, lng:77.2260,
    radiusMeters:450, severity:4},
  {id:'demo-block-1', name:'SIMULATED obstruction', lat:28.5700, lng:77.2470,
    radiusMeters:350, severity:3},
];

function validCoordinate(c) {
  return c && typeof c.lat === 'number' && typeof c.lng === 'number' &&
    Number.isFinite(c.lat) && Number.isFinite(c.lng) &&
    Math.abs(c.lat) <= 90 && Math.abs(c.lng) <= 180;
}

// Route requests are deliberately serialized to respect public demo server policy.
let lastRequestAt = 0;
let queued = Promise.resolve();
async function waitForTurn() {
  const previous = queued;
  let release;
  queued = new Promise(resolve => { release = resolve; });
  await previous;
  const delay = Math.max(0, 1100 - (Date.now() - lastRequestAt));
  if (delay) await new Promise(resolve => setTimeout(resolve, delay));
  lastRequestAt = Date.now();
  release();
}

const baseUrl = process.env.OSRM_BASE_URL || 'https://routing.openstreetmap.de/routed-car';
app.get('/api/health', (_req, res) => res.json({ok:true, routing:'OSRM', configured:true}));
app.post('/api/routes', async (req, res) => {
  const {origin, destination} = req.body || {};
  if (!validCoordinate(origin) || !validCoordinate(destination)) {
    return res.status(400).json({error:'Provide valid origin and destination lat/lng.'});
  }
  try {
    await waitForTurn();
    const coordinates = `${origin.lng},${origin.lat};${destination.lng},${destination.lat}`;
    const requestUrl = `${baseUrl.replace(/\/$/, '')}/route/v1/driving/${coordinates}` +
      '?overview=full&geometries=geojson&alternatives=true&steps=false';
    const upstream = await fetch(requestUrl, {
      headers: {'User-Agent': 'OBSIDIAN-X-Hackathon-Prototype/1.1 (noncommercial demo)',
        'Accept': 'application/json'},
      signal: AbortSignal.timeout(20000),
    });
    if (!upstream.ok) throw new Error(`Routing provider returned HTTP ${upstream.status}`);
    const result = await upstream.json();
    if (result.code !== 'Ok') {
      return res.status(502).json({error:'Routing service could not calculate this trip.'});
    }
    const routes = (result.routes || []).slice(0, 4).map((route, i) => {
      const points = (route.geometry?.coordinates || []).map(([lng,lat])=>[lat,lng]);
      const overlapping = demoHazards.filter(h =>
        proximityMeters([h.lat,h.lng], points) < h.radiusMeters);
      const demoRisk = Math.min(90, overlapping.reduce((sum,h)=>sum+h.severity*13, 0));
      return {
        label:`Driving alternative ${i+1}`,
        distanceMeters:Math.round(route.distance),
        durationMinutes:Math.max(1,Math.round(route.duration/60)),
        points,
        hazardHits:overlapping.length,
        hazardNames:overlapping.map(h=>h.name),
        demoScore:100-demoRisk,
      };
    }).filter(r=>r.points.length>1 && r.points.length<60000);
    routes.sort((a,b)=>b.demoScore-a.demoScore || a.durationMinutes-b.durationMinutes);
    res.json({routes, demoHazards, routeProvider:'FOSSGIS OSRM',
      hazardData:'SIMULATED / NOT VERIFIED',
      disclaimer:'Route geometry uses OSM road data; hazard scores are fabricated for demonstration and are not safety assessments.'});
  } catch (error) {
    console.error('Routing request failed:', error.message);
    res.status(502).json({error:'OSRM routing unavailable. Check internet or retry later. Public services are best-effort.'});
  }
});
if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  app.listen(port, '0.0.0.0', () => console.log(`OBSIDIAN X API listening on ${port}`));
}
module.exports = app;
