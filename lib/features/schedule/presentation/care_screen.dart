import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/theme/app_theme.dart';

class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Guia de Cuidados',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: InkFlowColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: InkFlowColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.healing, color: InkFlowColors.accent, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Uma boa cicatrização garante 50% da qualidade final da sua tatuagem.',
                      style: TextStyle(
                          color: InkFlowColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Fases da Cicatrização',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: InkFlowColors.primary)),
            const SizedBox(height: 16),
            _buildCareStep(
                'Dias 1 a 3',
                'Limpeza e Proteção',
                'Lave suavemente com sabonete neutro e água fria. Seque com papel toalha (sem esfregar). Aplique uma camada muito fina de pomada cicatrizante.',
                Icons.water_drop_outlined),
            _buildCareStep(
                'Dias 4 a 14',
                'Hidratação e Descamação',
                'A tatuagem vai começar a descascar e coçar. NUNCA puxe as casquinhas. Mantenha a área hidratada com creme sem perfume 2x ao dia.',
                Icons.spa_outlined),
            _buildCareStep(
                'Após 15 dias',
                'Manutenção a longo prazo',
                'A pele já está fechada, mas a regeneração interna continua. Use sempre protetor solar fator 50+ para evitar que a tinta desbote.',
                Icons.wb_sunny_outlined,
                isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCareStep(
      String time, String title, String description, IconData icon,
      {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300)),
                child: Icon(icon, color: InkFlowColors.primary, size: 20),
              ),
              if (!isLast)
                Expanded(
                    child: Container(width: 2, color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time,
                      style: const TextStyle(
                          color: InkFlowColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: const TextStyle(
                          color: InkFlowColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
