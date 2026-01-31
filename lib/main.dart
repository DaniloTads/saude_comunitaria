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
  theme: ThemeData(primarySwatch: Colors.blue),
));

// --- SERVIÇO DE ALERTAS PERSONALIZADO POR IDADE ---
class AlertaSaudeService {
  static Timer? _timerAgua;

  static void iniciarAlertas(BuildContext context, int idade) {
    _timerAgua?.cancel();

    // Define intervalo de água baseado na idade (Normas de Saúde)
    int intervaloMinutos = 30; // Padrão até 35 anos
    if (idade > 35 && idade <= 45) intervaloMinutos = 25;
    if (idade > 45) intervaloMinutos = 20;

    _timerAgua = Timer.periodic(Duration(minutes: intervaloMinutos), (timer) {
      _mostrarAlerta(context, "Hidratação!", "Para sua faixa etária ($idade anos), beba água agora!");
    });

    // Lembrete de fruta imediato (Início do treino)
    Future.delayed(Duration(seconds: 10), () => avisarFruta(context, "durante o treino"));
  }

  static void avisarFruta(BuildContext context, String momento) {
    _mostrarAlerta(context, "Nutrição", "Momento ideal para uma fruta $momento!");
  }

  static void _mostrarAlerta(BuildContext context, String titulo, String msg) {
    if (!context.mounted) return;
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            content: Text(msg),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text("Entendido"))]
        )
    );
  }
}

// --- TELA DE CADASTRO COMPLETA ---
class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}
class _CadastroScreenState extends State<CadastroScreen> {
  final _nome = TextEditingController();
  final _cidade = TextEditingController();
  final _bairro = TextEditingController();
  final _idade = TextEditingController();
  bool _maiorDeIdade = false;

  _salvar() async {
    if (_nome.text.isEmpty || _idade.text.isEmpty || !_maiorDeIdade) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Preencha tudo e confirme ser maior de 18 anos")));
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', _nome.text);
    await prefs.setInt('idade', int.parse(_idade.text));
    await prefs.setString('cidade', _cidade.text);
    await prefs.setString('bairro', _bairro.text);

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Cadastro de Saúde")),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(children: [
        TextField(controller: _nome, decoration: InputDecoration(labelText: "Nome Completo")),
        TextField(controller: _cidade, decoration: InputDecoration(labelText: "Cidade")),
        TextField(controller: _bairro, decoration: InputDecoration(labelText: "Bairro")),
        TextField(controller: _idade, decoration: InputDecoration(labelText: "Idade"), keyboardType: TextInputType.number),
        CheckboxListTile(
          title: Text("Confirmo que tenho mais de 18 anos"),
          value: _maiorDeIdade,
          onChanged: (v) => setState(() => _maiorDeIdade = v!),
        ),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _salvar, child: Text("Finalizar Cadastro", style: TextStyle(fontSize: 18))),
      ]),
    ),
  );
}

// --- TELA DE MAPA COM META DE PASSOS ---
class MapaScreen extends StatefulWidget {
  @override
  _MapaScreenState createState() => _MapaScreenState();
}
class _MapaScreenState extends State<MapaScreen> {
  int _passosAtuais = 0;
  int _metaPassos = 5000; // Meta padrão
  int _idadeUsuario = 30;
  StreamSubscription<StepCount>? _subscription;

  @override
  void initState() { super.initState(); _carregarDados(); }

  _carregarDados() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _idadeUsuario = prefs.getInt('idade') ?? 30;
    _solicitarMeta();
    _iniciarPedometer();
  }

  _solicitarMeta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text("Defina sua Meta de hoje"),
          content: TextField(
            decoration: InputDecoration(hintText: "Ex: 5000 passos"),
            keyboardType: TextInputType.number,
            onSubmitted: (val) {
              setState(() => _metaPassos = int.parse(val));
              Navigator.pop(c);
              AlertaSaudeService.iniciarAlertas(context, _idadeUsuario);
            },
          ),
        ),
      );
    });
  }

  _iniciarPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _subscription = Pedometer.stepCountStream.listen((event) {
        if (mounted) setState(() => _passosAtuais = event.steps);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    AlertaSaudeService._timerAgua?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progresso = (_passosAtuais / _metaPassos).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: Text("Treino em Tempo Real")),
      body: Stack(children: [
        GoogleMap(initialCameraPosition: CameraPosition(target: LatLng(-23.55, -46.63), zoom: 15), myLocationEnabled: true),
        Positioned(
          top: 20, left: 15, right: 15,
          child: Card(
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Progresso da Meta: ${(_passosAtuais)} / $_metaPassos", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  LinearProgressIndicator(value: progresso, minHeight: 10, color: Colors.green, backgroundColor: Colors.grey[300]),
                  Text("${(progresso * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// --- SPLASH E HOME (ESTRUTURA BASE) ---
class SplashScreen extends StatefulWidget { @override _SplashScreenState createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); _verificar(); }
  _verificar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => (prefs.getString('nome') != null) ? HomeScreen() : CadastroScreen()));
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: CircularProgressIndicator()));
}

class HomeScreen extends StatelessWidget {
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Saúde Comunitária")),
    body: Column(
      children: [
        Container(padding: EdgeInsets.all(20), color: Colors.blue[50], child: Text("Bem-vindo ao seu monitor de saúde! Clique em Mapa para iniciar seu treino.", textAlign: TextAlign.center)),
        Expanded(
          child: ListView(children: [
            ListTile(leading: Icon(Icons.directions_run, color: Colors.green, size: 30), title: Text("Iniciar Caminhada"), subtitle: Text("Monitorar passos e GPS"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MapaScreen()))),
            ListTile(leading: Icon(Icons.history, color: Colors.blue), title: Text("Minhas Metas Antigas"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MetasScreen()))),
          ]),
        ),
      ],
    ),
  );
}

class MetasScreen extends StatelessWidget {
  @override Widget