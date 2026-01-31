import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MaterialApp(
  home: SplashScreen(),
  debugShowCheckedModeBanner: false,
));

class MetaCaminhada {
  String titulo;
  int objetivo;
  int progresso;
  MetaCaminhada({required this.titulo, required this.objetivo, this.progresso = 0});

  Map<String, dynamic> toMap() => {'titulo': titulo, 'objetivo': objetivo, 'progresso': progresso};
  factory MetaCaminhada.fromMap(Map<String, dynamic> map) => MetaCaminhada(
    titulo: map['titulo'], objetivo: map['objetivo'], progresso: map['progresso'],
  );
}

class AlertaSaudeService {
  static Timer? _timerAgua;
  static void iniciarLembreteAgua(BuildContext context) {
    _timerAgua?.cancel();
    _timerAgua = Timer.periodic(Duration(minutes: 20), (timer) {
      _mostrarAlerta(context, "Hidratação!", "Hora de beber água!");
    });
  }
  static void avisarFruta(BuildContext context, String momento) {
    _mostrarAlerta(context, "Nutrição", "Coma uma fruta $momento!");
  }
  static void _mostrarAlerta(BuildContext context, String titulo, String msg) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(titulo), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("OK"))]));
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); _verificar(); }
  _verificar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? nome = prefs.getString('nome');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => (nome != null) ? HomeScreen() : CadastroScreen()));
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: CircularProgressIndicator()));
}

class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}
class _CadastroScreenState extends State<CadastroScreen> {
  final _n = TextEditingController();
  _salvar() async {
    if (_n.text.isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', _n.text);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => HomeScreen()));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Cadastro")),
    body: Padding(
      padding: EdgeInsets.all(20),
      child: Column(children: [TextField(controller: _n, decoration: InputDecoration(labelText: "Seu Nome")), SizedBox(height: 20), ElevatedButton(onPressed: _salvar, child: Text("Entrar"))]),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Saúde Comunitária")),
    body: ListView(children: [
      ListTile(leading: Icon(Icons.map, color: Colors.blue), title: Text("Mapa e Treino"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MapaScreen()))),
      ListTile(leading: Icon(Icons.flag, color: Colors.orange), title: Text("Minhas Metas"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MetasScreen()))),
    ]),
  );
}

class MapaScreen extends StatefulWidget {
  @override
  _MapaScreenState createState() => _MapaScreenState();
}
class _MapaScreenState extends State<MapaScreen> {
  int _passos = 0;
  StreamSubscription<StepCount>? _subscription;

  @override
  void initState() { super.initState(); _iniciar(); }

  _iniciar() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _subscription = Pedometer.stepCountStream.listen((event) {
        if (mounted) setState(() => _passos = event.steps);
      });
      AlertaSaudeService.iniciarLembreteAgua(context);
    }
  }
  @override
  void dispose() {
    _subscription?.cancel();
    AlertaSaudeService._timerAgua?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Treino")),
    body: Stack(children: [
      GoogleMap(initialCameraPosition: CameraPosition(target: LatLng(-23.55, -46.63), zoom: 15), myLocationEnabled: true),
      Positioned(top: 10, left: 10, right: 10, child: Card(child: Padding(padding: EdgeInsets.all(15), child: Text("Passos Acumulados: $_passos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))))
    ]),
  );
}

class MetasScreen extends StatefulWidget {
  @override
  _MetasScreenState createState() => _MetasScreenState();
}
class _MetasScreenState extends State<MetasScreen> {
  List<MetaCaminhada> lista = [];
  @override
  void initState() { super.initState(); _carregar(); }
  _carregar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? s = prefs.getString('metas_json');
    if (s != null) {
      setState(() {
        lista = (jsonDecode(s) as List).map((m) => MetaCaminhada.fromMap(m)).toList();
      });
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Metas")),
    body: lista.isEmpty
        ? Center(child: Text("Nenhuma meta cadastrada"))
        : ListView.builder(itemCount: lista.length, itemBuilder: (c, i) => ListTile(title: Text(lista[i].titulo), subtitle: LinearProgressIndicator(value: 0.5))),
  );
}