import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// Emulator: http://10.0.2.2:3000. Real Android phone: use LAN IP or HTTPS.
const backendUrl = String.fromEnvironment(
  'OBSIDIAN_API_BASE_URL', defaultValue: 'http://10.0.2.2:3000',
);

class RealRoute {
  RealRoute({required this.label, required this.distanceMeters,
    required this.durationMinutes, required this.points,
    required this.hazardHits, required this.demoScore,
    required this.hazardNames});
  final String label;
  final int distanceMeters, durationMinutes, hazardHits, demoScore;
  final List<LatLng> points;
  final List<String> hazardNames;

  factory RealRoute.fromJson(Map<String, dynamic> json) {
    final path = (json['points'] as List<dynamic>).map((point) {
      final coordinate = point as List<dynamic>;
      return LatLng((coordinate[0] as num).toDouble(), (coordinate[1] as num).toDouble());
    }).toList();
    return RealRoute(
      label: json['label'] as String,
      distanceMeters: (json['distanceMeters'] as num).round(),
      durationMinutes: (json['durationMinutes'] as num).round(),
      points: path,
      hazardHits: (json['hazardHits'] as num).round(),
      demoScore: (json['demoScore'] as num).round(),
      hazardNames: (json['hazardNames'] as List<dynamic>).cast<String>(),
    );
  }
}

class LiveRoutesPage extends StatefulWidget {
  const LiveRoutesPage({super.key});
  @override
  State<LiveRoutesPage> createState() => _LiveRoutesPageState();
}

class _LiveRoutesPageState extends State<LiveRoutesPage> {
  static const initial = LatLng(28.6139, 77.2090);
  static const destinations = <String, LatLng>{
    'India Gate, Delhi': LatLng(28.6129, 77.2295),
    'Lotus Temple, Delhi': LatLng(28.5535, 77.2588),
    'DTU, Delhi': LatLng(28.7499, 77.1170),
    'Red Fort, Delhi': LatLng(28.6562, 77.2410),
  };

  final MapController _map = MapController();
  LatLng _origin = initial;
  String _destination = 'Lotus Temple, Delhi';
  bool _loadingLocation = false, _loadingRoutes = false;
  String? _error;
  List<RealRoute> _routes = [];
  List<Map<String, dynamic>> _hazards = [];
  int _selected = 0;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() { _loadingLocation = true; _error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on device location services.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission unavailable; enable it in Android settings.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _routes = [];
        _hazards = [];
      });
      _map.move(_origin, 13);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _findRoutes() async {
    setState(() { _loadingRoutes = true; _error = null; _routes = []; });
    try {
      final dest = destinations[_destination]!;
      final response = await http.post(
        Uri.parse('$backendUrl/api/routes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin': {'lat': _origin.latitude, 'lng': _origin.longitude},
          'destination': {'lat': dest.latitude, 'lng': dest.longitude},
        }),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Routing error ${response.statusCode}');
      }
      final routes = (data['routes'] as List<dynamic>)
          .map((r) => RealRoute.fromJson(r as Map<String, dynamic>)).toList();
      if (routes.isEmpty) throw Exception('No driving routes found for this trip.');
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _hazards = (data['demoHazards'] as List<dynamic>)
            .map((h) => Map<String, dynamic>.from(h as Map)).toList();
        _selected = 0;
      });
      _fitRoute(routes.first.points);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not calculate a route: $error');
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  void _fitRoute(List<LatLng> path) {
    if (path.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(path);
    _map.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(38),
      maxZoom: 16,
    ));
  }

  List<Polyline> get _routeLines => [
    for (int i = 0; i < _routes.length; i++)
      Polyline(
        points: _routes[i].points,
        strokeWidth: i == _selected ? 7 : 4,
        color: i == _selected ? const Color(0xFF40E0B0) : Colors.orangeAccent,
      ),
  ];

  List<CircleMarker> get _hazardCircles => [
    for (final hazard in _hazards)
      CircleMarker(
        point: LatLng((hazard['lat'] as num).toDouble(),
            (hazard['lng'] as num).toDouble()),
        radius: (hazard['radiusMeters'] as num).toDouble(),
        useRadiusInMeter: true,
        color: Colors.red.withValues(alpha: .14),
        borderColor: Colors.redAccent,
        borderStrokeWidth: 2,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final destination = destinations[_destination]!;
    return Scaffold(
      appBar: AppBar(title: const Text('LIVE OPENSTREETMAP')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('Real road map + optional live driving route',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Route geometry comes from an OSM-based public routing service. '
          'Red hazard circles and safety scores are SIMULATED. '
          'Never rely on this demo for an emergency.',
          style: TextStyle(color: Colors.amberAccent, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 335,
            child: FlutterMap(
              mapController: _map,
              options: const MapOptions(initialCenter: initial, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.obsidianx.obsidian_x',
                ),
                if (_hazards.isNotEmpty) CircleLayer(circles: _hazardCircles),
                if (_routes.isNotEmpty) PolylineLayer(polylines: _routeLines),
                MarkerLayer(markers: [
                  Marker(
                    point: _origin, width: 44, height: 44,
                    child: const Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 34),
                  ),
                  Marker(
                    point: destination, width: 44, height: 44,
                    child: const Icon(Icons.location_on, color: Colors.greenAccent, size: 38),
                  ),
                ]),
                const SimpleAttributionWidget(
                  source: Text('© OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loadingLocation ? null : _locate,
          icon: const Icon(Icons.my_location),
          label: Text(_loadingLocation ? 'Finding GPS…' : 'Use my GPS location'),
        ),
        Text('Origin: ${_origin.latitude.toStringAsFixed(5)}, '
            '${_origin.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _destination,
          decoration: const InputDecoration(labelText: 'Destination'),
          items: destinations.keys.map((name) => DropdownMenuItem(
            value: name, child: Text(name),
          )).toList(),
          onChanged: (name) {
            if (name == null) return;
            setState(() { _destination = name; _routes = []; _hazards = []; });
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loadingRoutes ? null : _findRoutes,
          icon: const Icon(Icons.alt_route),
          label: Text(_loadingRoutes ? 'Contacting routing service…'
              : 'Calculate real driving routes'),
        ),
        if (_error != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _routes.length; i++)
          Card(
            color: i == _selected ? const Color(0xFF18382F) : null,
            child: ListTile(
              title: Text(_routes[i].label),
              subtitle: Text('${_routes[i].durationMinutes} min • '
                  '${(_routes[i].distanceMeters / 1000).toStringAsFixed(1)} km • '
                  '${_routes[i].hazardHits} DEMO hazard overlaps'),
              trailing: Text('${_routes[i].demoScore}/100',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () { setState(() => _selected = i); _fitRoute(_routes[i].points); },
            ),
          ),
        if (_routes.isNotEmpty) const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Routes and travel estimates are produced from OpenStreetMap road data. '
            'OBSIDIAN X hazard data, scores, and SOS functions remain demos.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        const SizedBox(height: 18),
        const Text('Map tiles © OpenStreetMap contributors. Routing via FOSSGIS OSRM public demo. '
            'The backend sends your origin and destination coordinates to that routing provider.',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
    );
  }
}
