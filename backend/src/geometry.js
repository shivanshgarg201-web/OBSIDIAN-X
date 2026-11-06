// Google Encoded Polyline Algorithm (lat/lng degree values).
function decodePolyline(encoded) {
  const pts = [];
  let index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    const deltas = [];
    for (let k = 0; k < 2; k++) {
      let result = 0, shift = 0, byte;
      do {
        if (index >= encoded.length) throw new Error('Invalid encoded polyline');
        byte = encoded.charCodeAt(index++) - 63;
        if (byte < 0) throw new Error('Invalid encoded polyline byte');
        result |= (byte & 31) << shift;
        shift += 5;
        if (shift > 35) throw new Error('Invalid encoded polyline shift');
      } while (byte >= 32);
      deltas.push((result & 1) ? ~(result >> 1) : (result >> 1));
    }
    lat += deltas[0]; lng += deltas[1];
    pts.push([lat / 1e5, lng / 1e5]);
  }
  return pts;
}

// Short-distance approximation for point-to-route checks; demo only.
function pointToSegmentMeters(p, a, b) {
  const latFactor = 111320;
  const lngFactor = 111320 * Math.cos(p[0] * Math.PI / 180);
  const x1 = (a[1]-p[1]) * lngFactor, y1=(a[0]-p[0])*latFactor;
  const x2 = (b[1]-p[1]) * lngFactor, y2=(b[0]-p[0])*latFactor;
  const dx=x2-x1, dy=y2-y1;
  const t = dx*dx+dy*dy === 0 ? 0 : Math.max(0, Math.min(1, -(x1*dx+y1*dy)/(dx*dx+dy*dy)));
  return Math.hypot(x1+t*dx,y1+t*dy);
}
function proximityMeters(point, polyline) {
  if (polyline.length === 0) return Infinity;
  if (polyline.length === 1) return pointToSegmentMeters(point,polyline[0],polyline[0]);
  let best = Infinity;
  for (let i=0;i<polyline.length-1;i++) best=Math.min(best, pointToSegmentMeters(point,polyline[i],polyline[i+1]));
  return best;
}
module.exports = {decodePolyline, proximityMeters};
