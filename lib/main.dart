import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';

void main() => runApp(MaterialApp(
  home: SplashScreen(),
  debugShowCheckedModeBanner: false,
));

// --- MODELO DE DADOS PARA METAS ---
class MetaCaminhada {
  String titulo;
  int objetivo;
  int progresso;

  MetaCaminhada({required this.titulo, required this.objetivo, this.progresso = 0});

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'objetivo': objetivo,
    'progresso': progresso,
  };

  factory MetaCaminhada.fromMap(Map<String, dynamic> map) => MetaCaminhada(
    titulo: map['titulo'],
    objetivo: map['objetivo'],
    progresso: map['progresso'],
  );
}

// --- TELA INICIAL ---
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarCadastro();
  }

  _verificarCadastro() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? nome = prefs.getString('nome');
    if (!mounted) return;
    if (nome != null && nome.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CadastroScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: CircularProgressIndicator()));
}

// --- TELA DE CADASTRO ---
class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _idadeController = TextEditingController();
  final _cidadeController = TextEditingController();

  _salvarEEntrar() async {
    if (_nomeController.text.isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', _nomeController.text);
    await prefs.setInt('idade', int.tryParse(_idadeController.text) ?? 0);
    await prefs.setString('cidade', _cidadeController.text);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cadastro Inicial")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _nomeController, decoration: InputDecoration(labelText: "Nome")),
            TextField(controller: _idadeController, decoration: InputDecoration(labelText: "Idade"), keyboardType: TextInputType.number),
            TextField(controller: _cidadeController, decoration: InputDecoration(labelText: "Cidade")),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _salvarEEntrar, child: Text("Começar"))
          ],
        ),
      ),
    );
  }
}

// --- TELA PRINCIPAL ---
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Saúde Comunitária")),
      body: ListView(
        children: [
          _menuItem(context, "Ver Mapa e Meu Local", Icons.map, Colors.blue, MapaScreen()),
          _menuItem(context, "Minhas Metas", Icons.flag, Colors.orange, MetasScreen()),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String titulo, IconData icone, Color cor, Widget destino) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: cor, child: Icon(icone, color: Colors.white)),
      title: Text(titulo),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destino)),
    );
  }
}

// --- TELA DE MAPA (CORRIGIDA) ---
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class MapaScreen extends StatefulWidget {
  @override
  _MapaScreenState createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  late Stream<StepCount> _stepCountStream;
  int _passosHoje = 0;

  @override
  void initState() {
    super.initState();
    _iniciarContagem();
  }

  void _iniciarContagem() async {
    // Pede permissão para usar o sensor
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen((event) async {
        int calculo = await ContadorPassosService.calcularPassosDiarios(event.steps);
        setState(() => _passosHoje = calculo);
      }).onError((error) => print("Erro no sensor: $error"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Caminhada Ativa")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(-23.5505, -46.6333), zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          // Painel flutuante de passos
          Positioned(
            top: 15, left: 15, right: 15,
            child: Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Passos Hoje:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("$_passosHoje", style: TextStyle(fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
  _carregarMetas() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? metasSalvas = prefs.getString('metas_json');
    if (metasSalvas != null) {
      List<dynamic> list = jsonDecode(metasSalvas);
      setState(() {
        listaMetas = list.map((m) => MetaCaminhada.fromMap(m)).toList();
      });
    }
  }

  _salvarNoDisco() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String codificado = jsonEncode(listaMetas.map((m) => m.toMap()).toList());
    await prefs.setString('metas_json', codificado);
  }

  void _addMeta() {
    if (_tituloController.text.isEmpty) return;
    setState(() {
      listaMetas.add(MetaCaminhada(
        titulo: _tituloController.text,
        objetivo: int.tryParse(_objetivoController.text) ?? 5000,
      ));
    });
    _tituloController.clear();
    _objetivoController.clear();
    _salvarNoDisco();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Metas Ativas")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _tituloController, decoration: InputDecoration(hintText: "Nome da Meta"))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: _objetivoController, decoration: InputDecoration(hintText: "Passos"), keyboardType: TextInputType.number)),
                IconButton(icon: Icon(Icons.add_box, color: Colors.green), onPressed: _addMeta),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: listaMetas.length,
              itemBuilder: (context, index) {
                var meta = listaMetas[index];
                double progressoPercent = (meta.progresso / meta.objetivo).clamp(0.0, 1.0);
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(meta.titulo),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: progressoPercent, color: Colors.green),
                        Text("${meta.progresso} / ${meta.objetivo} passos"),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () {
                        setState(() {
                          meta.progresso += 500;
                          _salvarNoDisco();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
// --- NOVO: SERVIÇO DE ALERTAS DE SAÚDE ---
class AlertaSaudeService {
  static Timer? _timerAgua;

  // Inicia lembrete de água a cada 'x' minutos
  static void iniciarLembreteAgua(BuildContext context, int minutos) {
    _timerAgua?.cancel();
    _timerAgua = Timer.periodic(Duration(minutes: minutos), (timer) {
      _mostrarAlerta(context, "Hidratação!", "Está na hora de beber água para manter o ritmo!");
    });
  }

  static void avisarFruta(BuildContext context, String momento) {
    // momento pode ser "Durante o treino" ou "Pós-treino"
    _mostrarAlerta(context, "Nutrição $momento", "Não esqueça de comer uma fruta para repor as energias!");
  }

  static void _mostrarAlerta(BuildContext context, String titulo, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }
}
class ContadorPassosService {
  static const String KEY_PASSOS_INICIAIS = "passos_dispositivo_total";
  static const String KEY_DATA_HOJE = "data_atual";

  // Calcula quantos passos foram dados HOJE subtraindo o total do sensor pelo total do início do dia
  static Future<int> calcularPassosDiarios(int passosTotaisSensor) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String hoje = DateTime.now().toString().split(' ')[0];
    String? ultimaData = prefs.getString(KEY_DATA_HOJE);

    if (ultimaData != hoje) {
      // Novo dia detectado: salva o valor atual do sensor como "ponto zero"
      await prefs.setString(KEY_DATA_HOJE, hoje);
      await prefs.setInt(KEY_PASSOS_INICIAIS, passosTotaisSensor);
      return 0;
    }

    int pontoZero = prefs.getInt(KEY_PASSOS_INICIAIS) ?? passosTotaisSensor;
    return passosTotaisSensor - pontoZero;
  }
}