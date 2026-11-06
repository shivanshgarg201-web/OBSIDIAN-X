import 'live_maps/live_routes_page.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const ObsidianXApp());

const ink = Color(0xFF080F1C);
const panel = Color(0xFF111E2E);
const panelLight = Color(0xFF192A3C);
const emerald = Color(0xFF40E0B0);
const softText = Color(0xFF96A9B9);
const danger = Color(0xFFFF6476);
const yellow = Color(0xFFFFC86C);

class Hazard {
  Hazard(this.id, this.name, this.type, this.x, this.y, this.radius, this.severity, {this.userReported = false});
  final String id, name, type;
  final double x, y, radius;
  final int severity;
  final bool userReported;
}

class SafeRoute {
  const SafeRoute(this.id, this.title, this.minutes, this.distance, this.points);
  final String id, title;
  final int minutes;
  final String distance;
  final List<Offset> points;
}

class RouteRating {
  RouteRating(this.route, this.score, this.intersections, this.closed);
  final SafeRoute route;
  final int score, intersections;
  final bool closed;
}

class EventLog {
  EventLog(this.name, this.description, this.time, this.icon);
  final String name, description, time;
  final IconData icon;
}

class DemoModel extends ChangeNotifier {
  final routes = <SafeRoute>[
    const SafeRoute('a', 'Central Express', 11, '4.2 km', [Offset(.13,.80), Offset(.28,.68), Offset(.44,.57), Offset(.63,.49), Offset(.83,.19)]),
    const SafeRoute('b', 'Riverside Bypass', 17, '5.6 km', [Offset(.13,.80), Offset(.11,.52), Offset(.19,.34), Offset(.46,.24), Offset(.70,.16), Offset(.83,.19)]),
    const SafeRoute('c', 'Southern Connector', 20, '6.7 km', [Offset(.13,.80), Offset(.35,.88), Offset(.65,.73), Offset(.88,.45), Offset(.83,.19)]),
  ];
  final hazards = <Hazard>[
    Hazard('f1', 'Riverbank flooding', 'Flood', .47, .57, .14, 5),
    Hazard('r1', 'Fallen tree / road obstruction', 'Roadblock', .75, .44, .10, 4),
    Hazard('f2', 'Low-lying waterlogged stretch', 'Flood', .23, .53, .09, 2),
  ];
  final events = <EventLog>[];
  final contacts = <String>['Demo contact: Family'];
  String origin = 'Central Plaza';
  String destination = 'City Relief Center';
  String selectedRoute = 'b';
  bool navigationStarted = false;
  bool sharing = false;
  bool sosActive = false;
  bool showHazards = true;
  double journeyProgress = 0;
  int page = 0;
  int sequence = 1;

  DemoModel() {
    addEvent('Demo ready', 'Simulated disaster scenario loaded', Icons.check_circle_outline);
  }

  void addEvent(String name, String description, IconData icon) {
    final now = TimeOfDay.now();
    events.insert(0, EventLog(name, description, '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}', icon));
    notifyListeners();
  }


  void go(int value) { page = value; notifyListeners(); }
  void selectRoute(String id) { selectedRoute = id; notifyListeners(); }
  void changeDestination(String value) {
    destination = value;
    notifyListeners();
  }
  void setHazards(bool value) { showHazards = value; notifyListeners(); }
  void beginTrip() {
    if (ratingFor(selectedRoute).closed) return;
    navigationStarted = true;
    journeyProgress = 0;
    addEvent('Journey started', 'Monitoring ${routeById(selectedRoute).title}', Icons.navigation_outlined);
  }
  void advanceTrip() {
    if (!navigationStarted) return;
    journeyProgress = (journeyProgress + .20).clamp(0.0, 1.0);
    if (journeyProgress >= 1) {
      navigationStarted = false;
      sharing = false;
      addEvent('Arrived', 'You have reached your destination (simulation)', Icons.flag_outlined);
    } else {
      addEvent('Position updated', '${(journeyProgress * 100).round()}% of demo route completed', Icons.my_location_outlined);
    }
    notifyListeners();
  }
  void stopTrip() {
    navigationStarted = false;
    sharing = false;
    addEvent('Journey ended', 'Trip tracking stopped', Icons.stop_circle_outlined);
  }
  void setSharing(bool enabled) {
    sharing = enabled;
    addEvent(enabled ? 'Sharing enabled' : 'Sharing disabled', enabled ? 'Demo journey visible in this app only' : 'Live-trip simulation stopped', Icons.share_location_outlined);
  }
  void triggerSos() {
    sosActive = true;
    addEvent('TEST SOS ACTIVATED', 'Demo alert #OX-${sequence++} recorded locally; no dispatch was sent', Icons.sos);
    notifyListeners();
  }
  void resolveSos() {
    sosActive = false;
    addEvent('Test SOS resolved', 'Demo event closed', Icons.verified_outlined);
  }
  void report(String type, String name) {
    final id = 'u${sequence++}';
    hazards.add(Hazard(id, name, type, .56, .31, .11, 3, userReported: true));
    addEvent('Unverified hazard report', '$type: $name — sample location (not public)', Icons.flag_outlined);
    notifyListeners();
  }
  SafeRoute routeById(String id) => routes.firstWhere((e) => e.id == id);

  RouteRating ratingFor(String id) {
    final r = routeById(id);
    double risk = 0;
    int intersections = 0;
    bool closed = false;
    for (final hazard in hazards) {
      final distance = distanceToPolyline(Offset(hazard.x, hazard.y), r.points);
      if (distance < hazard.radius) {
        intersections++;
        final closeness = (1 - distance / hazard.radius).clamp(0.0, 1.0);
        risk += (hazard.severity / 5) * (16 + closeness * 39);
        if (hazard.type == 'Roadblock' && hazard.severity == 5 && closeness > .65) closed = true;
      }
    }
    final score = (100 - risk).round().clamp(0, 100).toInt();
    return RouteRating(r, score, intersections, closed);
  }

  List<RouteRating> get ranked {
    final list = routes.map((r) => ratingFor(r.id)).toList();
    list.sort((a,b) {
      if (a.closed != b.closed) return a.closed ? 1 : -1;
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.route.minutes.compareTo(b.route.minutes);
    });
    return list;
  }
}

double distanceToPolyline(Offset point, List<Offset> path) {
  double best = double.infinity;
  for (int i = 0; i < path.length - 1; i++) {
    final a = path[i], b = path[i + 1];
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final denominator = dx * dx + dy * dy;
    final t = denominator == 0 ? 0.0 : (((point.dx - a.dx) * dx + (point.dy - a.dy) * dy) / denominator).clamp(0.0, 1.0);
    final q = Offset(a.dx + dx * t, a.dy + dy * t);
    best = math.min(best, (point - q).distance);
  }
  return best;
}

class ObsidianXApp extends StatefulWidget {
  const ObsidianXApp({super.key});
  @override State<ObsidianXApp> createState() => _ObsidianXAppState();
}

class _ObsidianXAppState extends State<ObsidianXApp> {
  late final DemoModel model;
  @override void initState() { super.initState(); model = DemoModel(); }
  @override void dispose() { model.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBSIDIAN X', debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: ink,
        colorScheme: ColorScheme.fromSeed(seedColor: emerald, brightness: Brightness.dark, surface: panel),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: panelLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
        appBarTheme: const AppBarTheme(backgroundColor: ink, foregroundColor: Colors.white),
      ),
      home: AnimatedBuilder(animation: model, builder: (context, _) => Shell(model: model)),
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key, required this.model});
  final DemoModel model;
  @override Widget build(BuildContext context) {
    final screens = <Widget>[
      Dashboard(model: model),
      RoutesPage(model: model),
      AlertsPage(model: model),
      EmergencyPage(model: model),
      MorePage(model: model),
    ];
    return Scaffold(
      appBar: AppBar(titleSpacing: 18,
        title: Row(children: [const Icon(Icons.shield_outlined, color: emerald, size: 25), const SizedBox(width: 9),
          const Text('OBSIDIAN X', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 18)), const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: yellow.withOpacity(.12), borderRadius: BorderRadius.circular(30)),
            child: const Text('DEMO MODE', style: TextStyle(color: yellow, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
      ),
      body: screens[model.page],
      bottomNavigationBar: NavigationBar(height: 72, backgroundColor: panel, indicatorColor: emerald.withOpacity(.15),
        selectedIndex: model.page, onDestinationSelected: model.go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: emerald), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route, color: emerald), label: 'Routes'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), selectedIcon: Icon(Icons.warning_amber, color: emerald), label: 'Hazards'),
          NavigationDestination(icon: Icon(Icons.sos), selectedIcon: Icon(Icons.sos, color: danger), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz, color: emerald), label: 'More'),
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle!, style: const TextStyle(color: softText, fontSize: 12))],
  ]);
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = panel});
  final Widget child; final EdgeInsets padding; final Color color;
  @override Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.06))), child: child);
}

class DemoMap extends StatelessWidget {
  const DemoMap({super.key, required this.model, this.height = 275, this.showAllRoutes = true});
  final DemoModel model; final double height; final bool showAllRoutes;
  @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(17),
    child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: CityPainter(model: model, showAllRoutes: showAllRoutes))));
}

class CityPainter extends CustomPainter {
  CityPainter({required this.model, required this.showAllRoutes});
  final DemoModel model; final bool showAllRoutes;
  @override void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color=const Color(0xFF102338));
    final grid = Paint()..color=const Color(0xFF2B4656)..strokeWidth=1;
    for(var x=0.0;x<size.width;x+=26) {canvas.drawLine(Offset(x,0), Offset(x,size.height), grid);}
    for(var y=0.0;y<size.height;y+=26) {canvas.drawLine(Offset(0,y), Offset(size.width,y), grid);}
    final road = Paint()..color=const Color(0xFF365367)..strokeWidth=9..strokeCap=StrokeCap.round;
    for(final points in [
      [Offset(.04,.15),Offset(.95,.15)], [Offset(.02,.37),Offset(.98,.42)],
      [Offset(.04,.75),Offset(.92,.72)], [Offset(.24,.02),Offset(.19,.98)],
      [Offset(.58,.03),Offset(.56,.98)], [Offset(.88,.02),Offset(.85,.97)],
    ]) {
      canvas.drawLine(Offset(points[0].dx*size.width,points[0].dy*size.height),Offset(points[1].dx*size.width,points[1].dy*size.height),road);
    }
    if (model.showHazards) {
      for(final h in model.hazards) {
        final center = Offset(h.x*size.width,h.y*size.height);
        final radius = h.radius*math.min(size.width,size.height)*1.35;
        canvas.drawCircle(center,radius,Paint()..color=danger.withOpacity(.11));
        canvas.drawCircle(center,radius,Paint()..color=danger.withOpacity(.7)..style=PaintingStyle.stroke..strokeWidth=1.3);
        canvas.drawCircle(center,5,Paint()..color=danger);
      }
    }
    for(final route in model.routes) {
      if(!showAllRoutes && route.id!=model.selectedRoute) continue;
      final selected=route.id==model.selectedRoute;
      final color=selected?emerald:route.id=='a'?danger:yellow.withOpacity(.7);
      final routePath=Path();
      for(var i=0;i<route.points.length;i++) {
        final point=Offset(route.points[i].dx*size.width,route.points[i].dy*size.height);
        if(i==0) routePath.moveTo(point.dx,point.dy); else routePath.lineTo(point.dx,point.dy);
      }
      canvas.drawPath(routePath, Paint()..color=const Color(0xFF06131D)..strokeWidth=selected?10:7..style=PaintingStyle.stroke..strokeJoin=StrokeJoin.round..strokeCap=StrokeCap.round);
      canvas.drawPath(routePath,Paint()..color=color..strokeWidth=selected?5:3..style=PaintingStyle.stroke..strokeJoin=StrokeJoin.round..strokeCap=StrokeCap.round);
    }
    final start=Offset(size.width*.13,size.height*.80), end=Offset(size.width*.83,size.height*.19);
    canvas.drawCircle(start,9,Paint()..color=emerald);
    canvas.drawCircle(start,4,Paint()..color=ink);
    canvas.drawCircle(end,10,Paint()..color=Colors.white);
    canvas.drawCircle(end,5,Paint()..color=const Color(0xFF1F6DBA));
    if(model.navigationStarted) {
      final route=model.routeById(model.selectedRoute);
      final where=(route.points.length-1)*model.journeyProgress;
      final i=where.floor().clamp(0,route.points.length-2);
      final f=where-i;
      final p=Offset.lerp(route.points[i],route.points[i+1],f)!;
      final position=Offset(p.dx*size.width,p.dy*size.height);
      canvas.drawCircle(position,12,Paint()..color=emerald.withOpacity(.25));
      canvas.drawCircle(position,6,Paint()..color=emerald);
    }
    final textPainter=TextPainter(text:const TextSpan(text:'SIMULATED CITY MAP',style:TextStyle(color:Color(0xFF92B8C3),fontWeight:FontWeight.w600,fontSize:9,letterSpacing:1.4)),textDirection:TextDirection.ltr)..layout();
    textPainter.paint(canvas,Offset(12,size.height-20));
  }
  @override bool shouldRepaint(covariant CityPainter old) => true;
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.model});
  final DemoModel model;
  @override Widget build(BuildContext context) {
    final recommended=model.ranked.first;
    return ListView(padding: const EdgeInsets.fromLTRB(18,12,18,26), children: [
      const SectionTitle('Navigate with confidence',subtitle:'Safety-first route intelligence · Simulation'),
      const SizedBox(height:18),
      const Row(children:[Icon(Icons.circle,size:8,color:emerald),SizedBox(width:6),Text('SCENARIO ACTIVE',style:TextStyle(fontSize:11,color:emerald,fontWeight:FontWeight.w800)),Spacer(),Text('FLOOD + ROAD OBSTRUCTION',style:TextStyle(fontSize:10,color:softText))]),
      const SizedBox(height:12), _LiveMapsLauncher(),
      const SizedBox(height:12), DemoMap(model:model,height:250),
      const SizedBox(height:15), SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('PLAN YOUR TRIP',style:TextStyle(fontSize:11,color:softText,fontWeight:FontWeight.bold,letterSpacing:1.2)),
        const SizedBox(height:12),
        Row(children:[const Icon(Icons.radio_button_checked,color:emerald,size:19),const SizedBox(width:10),Expanded(child:Text(model.origin,style:const TextStyle(fontWeight:FontWeight.bold)))]),
        const Padding(padding:EdgeInsets.only(left:8),child:SizedBox(height:20,child:VerticalDivider(color:softText,thickness:1))),
        Row(children:[const Icon(Icons.location_on,color:danger,size:19),const SizedBox(width:10),Expanded(child:Text(model.destination,style:const TextStyle(fontWeight:FontWeight.bold)))]),
        const SizedBox(height:16), SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>model.go(1),icon:const Icon(Icons.route),label:const Text('Compare safer routes'),style:FilledButton.styleFrom(backgroundColor:emerald,foregroundColor:ink,padding:const EdgeInsets.all(15)))),
      ])),
      const SizedBox(height:16), Row(children:[Expanded(child:_Metric(label:'SAFER OPTION',value:recommended.route.title,icon:Icons.shield_outlined,color:emerald)),const SizedBox(width:9),Expanded(child:_Metric(label:'HAZARDS REPORTED',value:'${model.hazards.length}',icon:Icons.warning_amber_outlined,color:yellow))]),
      const SizedBox(height:16), if(model.sosActive) SurfaceCard(color:danger.withOpacity(.15),child:const Row(children:[Icon(Icons.sos,color:danger),SizedBox(width:12),Expanded(child:Text('TEST SOS ACTIVE. No real emergency dispatch has been sent.',style:TextStyle(color:danger,fontWeight:FontWeight.w700)))])),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label,required this.value,required this.icon,required this.color});
  final String label,value;final IconData icon;final Color color;
  @override Widget build(BuildContext context) => SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color),const SizedBox(height:12),Text(label,style:const TextStyle(color:softText,fontSize:10,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(value,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14),maxLines:2,overflow:TextOverflow.ellipsis)]));
}

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key,required this.model});
  final DemoModel model;
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.fromLTRB(18,12,18,26),children:[
    const SectionTitle('Route intelligence',subtitle:'Compare exposure to simulated hazards'),
    const SizedBox(height:14), _LiveMapsLauncher(),
    const SizedBox(height:14), DemoMap(model:model,height:250),
    const SizedBox(height:9), const Text('Safety scores are illustrative, not evidence of real-world road safety.',style:TextStyle(color:softText,fontSize:11)),
    const SizedBox(height:17), Row(children:[const Icon(Icons.auto_awesome,color:emerald,size:17),const SizedBox(width:8),const Text('RANKED ROUTES',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),const Spacer(),Text('${model.ranked.length} options',style:const TextStyle(color:softText,fontSize:12))]),
    const SizedBox(height:10),
    for(final rating in model.ranked) ...[
      InkWell(onTap:()=>model.selectRoute(rating.route.id),borderRadius:BorderRadius.circular(16),child:SurfaceCard(color:model.selectedRoute==rating.route.id?const Color(0xFF18382F):panel,child:Row(children:[
        Radio<String>(value:rating.route.id,groupValue:model.selectedRoute,onChanged:(v){if(v!=null)model.selectRoute(v);},activeColor:emerald),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(rating.route.title,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:3),Text('${rating.route.minutes} min  •  ${rating.route.distance}  •  ${rating.intersections} hazard overlaps',style:const TextStyle(color:softText,fontSize:11)),if(rating.closed)const Text('CONFIRMED CLOSED — NOT AVAILABLE',style:TextStyle(color:danger,fontSize:10))])),
        const SizedBox(width:8),Column(children:[Text('${rating.score}',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:rating.score>=70?emerald:rating.score>=40?yellow:danger)),const Text('/100',style:TextStyle(color:softText,fontSize:10))]),
      ]))),const SizedBox(height:9),
    ],
    const SizedBox(height:5),
    if(!model.navigationStarted) SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:model.ratingFor(model.selectedRoute).closed?null:model.beginTrip,icon:const Icon(Icons.navigation),label:const Text('Start simulated journey'),style:FilledButton.styleFrom(backgroundColor:emerald,foregroundColor:ink,padding:const EdgeInsets.all(16))))
    else SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.navigation,color:emerald),const SizedBox(width:8),const Expanded(child:Text('JOURNEY IN PROGRESS',style:TextStyle(color:emerald,fontWeight:FontWeight.w800))),Text('${(model.journeyProgress*100).round()}%')]),
      const SizedBox(height:12),LinearProgressIndicator(value:model.journeyProgress,color:emerald,backgroundColor:panelLight,minHeight:7,borderRadius:BorderRadius.circular(10)),
      const SizedBox(height:12),const Text('Advance the marker to simulate movement along the route.',style:TextStyle(fontSize:11,color:softText)),
      const SizedBox(height:12),Row(children:[Expanded(child:FilledButton(onPressed:model.advanceTrip,child:const Text('Advance trip'))),const SizedBox(width:8),OutlinedButton(onPressed:model.stopTrip,child:const Text('Stop'))]),
    ])),
  ]);
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key,required this.model});
  final DemoModel model;
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.fromLTRB(18,12,18,26),children:[
    const SectionTitle('Hazard intelligence',subtitle:'Illustrative data — not live disaster alerts'),
    const SizedBox(height:14),DemoMap(model:model,height:190,showAllRoutes:false),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Show hazards on map',style:TextStyle(fontSize:13)),value:model.showHazards,onChanged:model.setHazards,activeColor:emerald),
    const SizedBox(height:6),
    for(final hazard in model.hazards) ...[
      SurfaceCard(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:danger.withOpacity(.12),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.warning_amber_rounded,color:danger)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(hazard.name,style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:5),Text('${hazard.type}  •  Severity ${hazard.severity}/5',style:const TextStyle(color:softText,fontSize:12)),const SizedBox(height:5),Text(hazard.userReported?'UNVERIFIED USER REPORT · SIMULATION':'SIMULATED SCENARIO DATA',style:const TextStyle(color:yellow,fontSize:10,fontWeight:FontWeight.bold))]))])),
      const SizedBox(height:9),
    ],
    const SizedBox(height:7),FilledButton.icon(onPressed:()=>_reportDialog(context,model),icon:const Icon(Icons.add_location_alt_outlined),label:const Text('Report a hazard (demo)'),style:FilledButton.styleFrom(backgroundColor:emerald,foregroundColor:ink,padding:const EdgeInsets.all(14))),
  ]);
}

void _reportDialog(BuildContext context,DemoModel model) {
  String type='Flood';
  final controller=TextEditingController();
  showDialog<void>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
    title:const Text('Report hazard'),
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Demo report: will be added at a sample map location. No report is transmitted.'),
      const SizedBox(height:12),DropdownButtonFormField<String>(value:type,items:['Flood','Fire','Roadblock','Landslide','Other'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>type=v??type)),
      const SizedBox(height:12),TextField(controller:controller,decoration:const InputDecoration(labelText:'Description')),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){model.report(type,controller.text.trim().isEmpty?'Community-reported hazard':controller.text.trim());Navigator.pop(context);},child:const Text('Add report'))],
  ))).then((_)=>controller.dispose());
}

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key,required this.model});
  final DemoModel model;
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.fromLTRB(18,12,18,26),children:[
    const SectionTitle('Emergency center',subtitle:'Your safety tools — simulated and local only'),
    const SizedBox(height:17),
    SurfaceCard(color:danger.withOpacity(.08),child:Column(children:[
      const Icon(Icons.shield_outlined,color:danger,size:42),const SizedBox(height:12),
      const Text('NEED HELP?',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
      const SizedBox(height:6),const Text('This prototype does not contact emergency services or anyone outside this device.',style:TextStyle(fontSize:12,color:softText),textAlign:TextAlign.center),
      const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>_confirmSos(context,model),icon:const Icon(Icons.sos),label:Text(model.sosActive?'Create another TEST SOS':'ACTIVATE TEST SOS'),style:FilledButton.styleFrom(backgroundColor:danger,foregroundColor:ink,padding:const EdgeInsets.symmetric(vertical:17)))),
      if(model.sosActive) ...[const SizedBox(height:10),const Text('TEST EVENT ACTIVE · NO MESSAGE SENT',style:TextStyle(color:danger,fontSize:11,fontWeight:FontWeight.bold)),TextButton(onPressed:model.resolveSos,child:const Text('Resolve test SOS'))],
    ])),
    const SizedBox(height:14),SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.share_location,color:emerald),SizedBox(width:10),Text('Journey sharing (demo)',style:TextStyle(fontWeight:FontWeight.bold))]),
      const SizedBox(height:7),const Text('Simulate giving trusted contacts access to the journey. No real location is transmitted.',style:TextStyle(fontSize:12,color:softText)),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(model.sharing?'Simulation ON':'Simulation OFF'),value:model.sharing,onChanged:model.setSharing,activeColor:emerald),
      Text('Trusted contacts: ${model.contacts.join(', ')}',style:const TextStyle(color:softText,fontSize:11)),
    ])),
    const SizedBox(height:14),SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.health_and_safety_outlined,color:yellow),SizedBox(width:10),Text('Quick emergency guidance',style:TextStyle(fontWeight:FontWeight.bold))]),
      const SizedBox(height:12),for(final guide in const [
        ['Flood', 'Move to higher ground. Avoid walking or driving through floodwater.'],
        ['Fire', 'Move away from smoke and fire. Use safe exits; do not use lifts.'],
        ['Earthquake', 'Drop, cover, and hold on. Move outside only once shaking stops and it is safe.'],
        ['Medical emergency', 'Contact local emergency services immediately; follow dispatcher instructions.'],
      ]) ExpansionTile(tilePadding:EdgeInsets.zero,title:Text(guide[0],style:const TextStyle(fontSize:13)),children:[Padding(padding:const EdgeInsets.only(bottom:10),child:Text(guide[1],style:const TextStyle(color:softText,fontSize:12)))]),
    ])),
    const SizedBox(height:12),const Text('For a real emergency in India, use 112 where available. This app is not a substitute for official emergency services.',style:TextStyle(fontSize:11,color:softText)),
  ]);
}

void _confirmSos(BuildContext context,DemoModel model) {
  showDialog<void>(context:context,builder:(context)=>AlertDialog(
    title:const Text('Activate TEST SOS?'),
    content:const Text('This creates a local test event for your hackathon demo. It will NOT contact emergency services or a trusted contact.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
      FilledButton(onPressed:(){Navigator.pop(context);model.triggerSos();},style:FilledButton.styleFrom(backgroundColor:danger,foregroundColor:ink),child:const Text('Activate test'))],
  ));
}

class MorePage extends StatelessWidget {
  const MorePage({super.key,required this.model});
  final DemoModel model;
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.fromLTRB(18,12,18,26),children:[
    const SectionTitle('Control center',subtitle:'Demo configuration, event history and project information'),
    const SizedBox(height:16),SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('DEMO ENVIRONMENT',style:TextStyle(color:emerald,fontWeight:FontWeight.w800,fontSize:11)),const SizedBox(height:9),
      const Text('The built-in demonstration remains offline and simulated. Open LIVE OpenStreetMap from Home or Routes; real routes need separate Maps and Routes API keys.',style:TextStyle(color:softText,fontSize:12)),
      const SizedBox(height:14),const Text('Destination',style:TextStyle(fontWeight:FontWeight.w700,fontSize:12)),const SizedBox(height:7),
      for(final dest in ['City Relief Center','North Hospital','Community Shelter']) RadioListTile<String>(dense:true,contentPadding:EdgeInsets.zero,title:Text(dest,style:const TextStyle(fontSize:13)),value:dest,groupValue:model.destination,onChanged:(v){if(v!=null)model.changeDestination(v);}),
      const Text('Destinations share the same simulated demo endpoint; this is not geocoding.',style:TextStyle(color:softText,fontSize:11)),
    ])),
    const SizedBox(height:17),const Text('EVENT HISTORY',style:TextStyle(fontWeight:FontWeight.w800,fontSize:12,letterSpacing:1)),const SizedBox(height:8),
    for(final log in model.events.take(15)) ...[SurfaceCard(child:Row(children:[Icon(log.icon,color:emerald,size:20),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(log.name,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),const SizedBox(height:4),Text(log.description,style:const TextStyle(color:softText,fontSize:11))])),const SizedBox(width:6),Text(log.time,style:const TextStyle(color:softText,fontSize:10))])),const SizedBox(height:7)],
    const SizedBox(height:12),const Text('OBSIDIAN X • Hackathon functional simulation • Not intended for real emergency navigation.',style:TextStyle(color:softText,fontSize:11),textAlign:TextAlign.center),
  ]);
}


/// Opens the OpenStreetMap and OSRM routing integration without changing demo scoring.
class _LiveMapsLauncher extends StatelessWidget {
  const _LiveMapsLauncher();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LiveRoutesPage()),
      ),
      icon: const Icon(Icons.public),
      label: const Text('Open LIVE OpenStreetMap'),
      style: FilledButton.styleFrom(
        backgroundColor: emerald, foregroundColor: ink,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}
