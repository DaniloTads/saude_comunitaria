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
class MapaScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Onde estou")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(-23.5505, -46.6333), zoom: 15),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    ); // Ponto e vírgula correto aqui
  }
}

// --- TELA DE METAS ---
class MetasScreen extends StatefulWidget {
  @override
  _MetasScreenState createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  List<MetaCaminhada> listaMetas = [];
  final _tituloController = TextEditingController();
  final _objetivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarMetas();
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
}q