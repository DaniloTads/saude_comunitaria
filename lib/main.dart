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
  theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
));

// --- MODELO PARA HISTÓRICO DE METAS ---
class RegistroTreino {
  final String data;
  final int passos;
  final int meta;

  RegistroTreino({required this.data, required this.passos, required this.meta});

  Map<String, dynamic> toMap() => {'data': data, 'passos': passos, 'meta': meta};
  factory RegistroTreino.fromMap(Map<String, dynamic> map) => RegistroTreino(
    data: map['data'],
    passos: map['passos'],
    meta: map['meta'],
  );
}

// --- SERVIÇO DE ALERTAS PERSONALIZADO POR IDADE ---
class AlertaSaudeService {
  static Timer? _timerAgua;

  static void iniciarAlertas(BuildContext context, int idade) {
    _timerAgua?.cancel();

    // Normas de saúde: Intervalos menores para idades avançadas
    int intervaloMinutos = 30; // Até 35 anos
    if (idade > 35 && idade <= 45) intervaloMinutos = 25;
    if (idade > 45) intervaloMinutos = 20;

    _timerAgua = Timer.periodic(Duration(minutes: intervaloMinutos), (timer) {
      _mostrarAlerta(context, "Hidratação!", "Lembrete para seus $idade anos: beba água agora!");
    });

    Future.delayed(Duration(seconds: 15), () => avisarFruta(context, "durante o treino"));
  }

  static void avisarFruta(BuildContext context, String momento) {
    _mostrarAlerta(context, "Nutrição", "Consuma uma fruta $momento para manter a energia!");
  }

  static void _mostrarAlerta(BuildContext context, String titulo, String msg) {
    if (!context.mounted) return;
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            content: Text(msg),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]));
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
    final int? idadeVerificada = int.tryParse(_idade.text);
    if (_nome.text.isEmpty || idadeVerificada == null || !_maiorDeIdade) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha os dados e confirme a idade (+18)")));
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', _nome.text);
    await prefs.setInt('idade', idadeVerificada);
    await prefs.setString('cidade', _cidade.text);
    await prefs.setString('bairro', _bairro.text);

    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Cadastro Inicial")),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(controller: _nome, decoration: const InputDecoration(labelText: "Nome Completo")),
        TextField(controller: _cidade, decoration: const InputDecoration(labelText: "Cidade")),
        TextField(controller: _bairro, decoration: const InputDecoration(labelText: "Bairro")),
        TextField(controller: _idade, decoration: const InputDecoration(labelText: "Idade"), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        CheckboxListTile(
          title: const Text("Declaro ser maior de 18 anos"),
          value: _maiorDeIdade,
          onChanged: (v) => setState(() => _maiorDeIdade = v!),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _salvar, child: const Text("Cadastrar e Iniciar")),
      ]),
    ),
  );
}

// --- TELA DE MAPA COM MONITORAMENTO ---
class MapaScreen extends StatefulWidget {
  @override
  _MapaScreenState createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  int _passosNoInicio = -1;
  int _passosAtuais = 0;
  int _metaPassos = 5000;
  int _idadeUsuario = 30;
  StreamSubscription<StepCount>? _subscription;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

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
          title: const Text("Meta de Hoje"),
          content: TextField(
            decoration: const InputDecoration(hintText: "Ex: 3000 passos"),
            keyboardType: TextInputType.number,
            onSubmitted: (val) {
              setState(() => _metaPassos = int.tryParse(val) ?? 5000);
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
        if (mounted) {
          if (_passosNoInicio == -1) _passosNoInicio = event.steps;
          setState(() => _passosAtuais = event.steps - _passosNoInicio);
        }
      });
    }
  }

  _finalizarTreino() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> historico = prefs.getStringList('historico') ?? [];
    RegistroTreino novo = RegistroTreino(
      data: DateTime.now().toString().substring(0, 16),
      passos: _passosAtuais,
      meta: _metaPassos,
    );
    historico.add(jsonEncode(novo.toMap()));
    await prefs.setStringList('historico', historico);
    if (mounted) Navigator.pop(context);
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
      appBar: AppBar(title: const Text("Monitor de Treino"), actions: [
        IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: _finalizarTreino)
      ]),
      body: Stack(children: [
        const GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(-23.55, -46.63), zoom: 15),
            myLocationEnabled: true),
        Positioned(
          top: 20, left: 15, right: 15,
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text("Passos: $_passosAtuais / $_metaPassos", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progresso, minHeight: 12, color: Colors.green),
                Text("Progresso: ${(progresso * 100).toStringAsFixed(1)}%"),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// --- TELAS DE SUPORTE ---
class SplashScreen extends StatefulWidget { @override _SplashScreenState createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); _verificar(); }
  _verificar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? nome = prefs.getString('nome');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => (nome != null) ? HomeScreen() : CadastroScreen()));
  }
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class HomeScreen extends StatelessWidget {
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Saúde Comunitária")),
    body: Column(children: [
      Container(padding: const EdgeInsets.all(20), color: Colors.blue[50], child: const Text("Mantenha o corpo em movimento e siga as orientações de saúde.", textAlign: TextAlign.center)),
      Expanded(child: ListView(children: [
        ListTile(leading: const Icon(Icons.directions_run, color: Colors.green), title: const Text("Iniciar Caminhada"), subtitle: const Text("GPS e Contador de passos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MapaScreen()))),
        ListTile(leading: const Icon(Icons.history, color: Colors.blue), title: const Text("Ver Histórico"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MetasScreen()))),
      ])),
    ]),
  );
}

class MetasScreen extends StatefulWidget { @override _MetasScreenState createState() => _MetasScreenState(); }
class _MetasScreenState extends State<MetasScreen> {
  List<RegistroTreino> lista = [];
  @override void initState() { super.initState(); _carregar(); }
  _carregar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> historico = prefs.getStringList('historico') ?? [];
    setState(() {
      lista = historico.map((e) => RegistroTreino.fromMap(jsonDecode(e))).toList().reversed.toList();
    });
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Meu Histórico")),
    body: lista.isEmpty ? const Center(child: Text("Nenhum treino registrado.")) : ListView.builder(
      itemCount: lista.length,
      itemBuilder: (c, i) => ListTile(
        title: Text("Data: ${lista[i].data}"),
        subtitle: Text("Passos: ${lista[i].passos} | Meta: ${lista[i].meta}"),
        trailing: Icon(lista[i].passos >= lista[i].meta ? Icons.star : Icons.run_circle, color: Colors.orange),
      ),
    ),
  );
}