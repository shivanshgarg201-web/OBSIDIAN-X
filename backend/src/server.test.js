const test = require('node:test');
const assert = require('node:assert/strict');
const app = require('./server');

test('rejects invalid coordinates without contacting OSRM', async () => {
  const server = app.listen(0, '127.0.0.1');
  try {
    const port = server.address().port;
    const res = await fetch(`http://127.0.0.1:${port}/api/routes`, {
      method:'POST', headers:{'Content-Type':'application/json'},
      body:JSON.stringify({origin:{lat:100,lng:77},destination:{lat:28,lng:77}}),
    });
    assert.equal(res.status,400);
  } finally { await new Promise(resolve=>server.close(resolve)); }
});

test('maps mocked OSRM GeoJSON response into sorted routes', async () => {
  const original = global.fetch;
  global.fetch = async (_url, opts) => {
    assert.match(_url,/route\/v1\/driving/);
    assert.match(_url,/geometries=geojson/);
    assert.equal(opts.headers.Accept,'application/json');
    return {ok:true,json:async()=>({code:'Ok',routes:[
      {distance:2000,duration:300,geometry:{coordinates:[[77.20,28.60],[77.21,28.61]]}},
      {distance:2500,duration:380,geometry:{coordinates:[[77.22,28.62],[77.23,28.63]]}},
    ]})};
  };
  const server = app.listen(0, '127.0.0.1');
  try {
    const response = await original(`http://127.0.0.1:${server.address().port}/api/routes`,{
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({origin:{lat:28.6,lng:77.2},destination:{lat:28.63,lng:77.23}}),
    });
    assert.equal(response.status,200);
    const result = await response.json();
    assert.equal(result.routes.length,2);
    assert.deepEqual(result.routes[0].points[0],[28.62,77.22]);
    assert.equal(result.routes[0].durationMinutes,6);
    assert.equal(result.hazardData,'SIMULATED / NOT VERIFIED');
  } finally {
    global.fetch=original;
    await new Promise(resolve=>server.close(resolve));
  }
});
