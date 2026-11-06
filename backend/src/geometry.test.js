const test=require('node:test');
const assert=require('node:assert/strict');
const {decodePolyline,proximityMeters}=require('./geometry');
test('decodes Google canonical example',()=>{
  assert.deepEqual(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'),[
    [38.5,-120.2],[40.7,-120.95],[43.252,-126.453]
  ]);
});
test('distance is zero for point on segment',()=>{
  assert.ok(proximityMeters([28.6,77.2],[[28.6,77.19],[28.6,77.21]])<1);
});
test('distant hazards do not intersect',()=>{
  assert.ok(proximityMeters([28.7,77.2],[[28.6,77.19],[28.6,77.21]])>1000);
});
