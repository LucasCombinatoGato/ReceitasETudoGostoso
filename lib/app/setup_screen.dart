import 'package:flutter/material.dart';

class SetupApp extends StatelessWidget {
  const SetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuração do Firebase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB84A2B)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.restaurant_menu, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    'Configure o Firebase para começar',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Crie um projeto Firebase e informe FIREBASE_API_KEY, '
                    'FIREBASE_APP_ID e FIREBASE_MESSAGING_SENDER_ID com '
                    '--dart-define. O projeto usa o ID receitasetudogostoso '
                    'por padrão. Configure também RECIPES_API_BASE_URL para '
                    'apontar para a Receitas Web Scrapper. As instruções '
                    'completas estão no README.md.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
