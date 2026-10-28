import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  String? _token;

  Future<void> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode != 200) {
      throw Exception('Email o contraseña incorrectos');
    }
    _token = jsonDecode(r.body)['access'];
  }

  Future<List<Map<String, dynamic>>> materias() async {
    final r = await http.get(
      Uri.parse('$baseUrl/materias/'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (r.statusCode != 200) {
      throw Exception('No se pudo cargar la lista (${r.statusCode})');
    }
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return List<Map<String, dynamic>>.from(data['results']);
  }
}