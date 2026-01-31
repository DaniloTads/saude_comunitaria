import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';

void main() => runApp(MaterialApp(
  home: SplashScreen(),
  debugShowCheckedModeBanner: false, // Remove a faixa de debug
));

// --- TELA INICIAL (LOGICA DE REDIRECIONAMENTO) ---
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
    // Aguarda os dados do SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? nome = prefs.getString('nome');

    // Verifica se o widget ainda existe na árvore antes de navegar (Boa prática!)
    if (!mounted) return;

    if (nome != null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => HomeScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => CadastroScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

// --- TELA DE CADASTRO COMPLETA ---
class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  // Controladores para capturar o texto
  final _nomeController = TextEditingController();
  final _idadeController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _bairroController = TextEditingController();

  // IMPORTANTE: Limpa a memória ao fechar a tela
  @override
  void dispose() {
    _nomeController.dispose();
    _idadeController.dispose();
    _cidadeController.dispose();
    _bairroController.dispose();
    super.dispose();
  }

  _salvarEEntrar() async {
    int idade = int.tryParse(_idadeController.text) ?? 0;
    if (idade < 18) {
      _aviso("Apenas maiores de 18 anos podem se cadastrar.");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('nome', _nomeController.text);
    await prefs.setInt('idade', idade);
    await prefs.setString('cidade', _cidadeController.text);
    await prefs.setString('bairro', _bairroController.text);

    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => HomeScreen()));
  }

  _aviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cadastro Inicial")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: "Nome Completo")),
            TextField(
                controller: _idadeController,
                decoration: InputDecoration(labelText: "Idade"),
                keyboardType: TextInputType.number),
            TextField(
                controller: _cidadeController,
                decoration: InputDecoration(labelText: "Cidade")),
            TextField(
                controller: _bairroController,
                decoration: InputDecoration(labelText: "Bairro")),
            SizedBox(height: 30),
            ElevatedButton(
                onPressed: _salvarEEntrar, child: Text("Salvar e Começar"))
          ],
        ),
      ),
    );
  }
}

// --- TELA PRINCIPAL (DASHBOARD) ---
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Saúde Comunitária"),
        // Removido o botão exit(0) para seguir as boas práticas de UX
      ),
      body: ListView(
        children: [
          _cardClima(),
          _menuItem(context, "Ver Mapa e Parques", Icons.map, Colors.blue,
              MapaScreen()),
          _menuItem(context, "Metas de Caminhada", Icons.flag, Colors.orange,
              MetasScreen()),
          _menuItem(context, "Estatísticas (Km)", Icons.bar_chart, Colors.green,
              EstatisticasScreen()),
          _menuItem(context, "Ranking de Amigos", Icons.emoji_events,
              Colors.purple, RankingScreen()),
        ],
      ),
    );
  }

  Widget _cardClima() {
    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.blue[50], borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.wb_sunny, color: Colors.orange, size: 40),
          SizedBox(width: 15),
          Text("Clima em sua região: Ensolarado",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String titulo, IconData icone,
      Color cor, Widget destino) {
    return ListTile(
      leading:
      CircleAvatar(backgroundColor: cor, child: Icon(icone, color: Colors.white)),
      title: Text(titulo),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => destino)),
    );
  }
}

// --- TELA DE MAPA ---
class MapaScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapa e Rotas")),
      body: Stack(
        children: [
          Center(
              child: Text(
                "O Mapa aparecerá aqui\n(Requer Configuração de API Key)",
                textAlign: TextAlign.center,
              )),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton.extended(
              onPressed: () {},
              label: Text("Traçar Rota para Casa"),
              icon: Icon(Icons.home),
            ),
          )
        ],
      ),
    );
  }
}

// --- TELAS PLACEHOLDERS ---
class MetasScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text("Minhas Metas")));
}

class EstatisticasScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text("KM Percorridos")));
}

class RankingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text("Ranking Comunitário")));
}