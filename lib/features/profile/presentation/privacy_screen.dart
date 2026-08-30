import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkFlowColors.background,
      appBar: AppBar(
        backgroundColor: InkFlowColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Privacidade e Segurança',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _PrivacySection(
            title: 'Seus dados',
            body:
                'Informações como nome, e-mail, CPF e telefone são usadas apenas para '
                'identificação, agendamentos e comunicação dentro do InkFlow.',
          ),
          SizedBox(height: 20),
          _PrivacySection(
            title: 'Compartilhamento',
            body:
                'Dados de perfil público (nome, estilos, portfólio) ficam visíveis '
                'para clientes na busca. Mensagens e anamneses são compartilhadas '
                'somente entre você e o cliente da sessão.',
          ),
          SizedBox(height: 20),
          _PrivacySection(
            title: 'Segurança',
            body:
                'Senhas são gerenciadas pelo Supabase Auth. Recomendamos usar senha '
                'forte e não compartilhar credenciais de acesso.',
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}
