import 'dart:convert';

import 'package:http/http.dart' as http;

class BrazilianState {
  final String code;
  final String name;

  const BrazilianState(this.code, this.name);
}

class BrazilLocationsRepository {
  static const states = <BrazilianState>[
    BrazilianState('AC', 'Acre'),
    BrazilianState('AL', 'Alagoas'),
    BrazilianState('AP', 'Amapá'),
    BrazilianState('AM', 'Amazonas'),
    BrazilianState('BA', 'Bahia'),
    BrazilianState('CE', 'Ceará'),
    BrazilianState('DF', 'Distrito Federal'),
    BrazilianState('ES', 'Espírito Santo'),
    BrazilianState('GO', 'Goiás'),
    BrazilianState('MA', 'Maranhão'),
    BrazilianState('MT', 'Mato Grosso'),
    BrazilianState('MS', 'Mato Grosso do Sul'),
    BrazilianState('MG', 'Minas Gerais'),
    BrazilianState('PA', 'Pará'),
    BrazilianState('PB', 'Paraíba'),
    BrazilianState('PR', 'Paraná'),
    BrazilianState('PE', 'Pernambuco'),
    BrazilianState('PI', 'Piauí'),
    BrazilianState('RJ', 'Rio de Janeiro'),
    BrazilianState('RN', 'Rio Grande do Norte'),
    BrazilianState('RS', 'Rio Grande do Sul'),
    BrazilianState('RO', 'Rondônia'),
    BrazilianState('RR', 'Roraima'),
    BrazilianState('SC', 'Santa Catarina'),
    BrazilianState('SP', 'São Paulo'),
    BrazilianState('SE', 'Sergipe'),
    BrazilianState('TO', 'Tocantins'),
  ];

  Future<List<String>> fetchCities(String stateCode) async {
    final uri = Uri.https(
      'servicodados.ibge.gov.br',
      '/api/v1/localidades/estados/$stateCode/municipios',
      {'orderBy': 'nome'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Não foi possível consultar as cidades.');
    }

    final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return rows
        .map((row) => (row as Map<String, dynamic>)['nome']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }
}
