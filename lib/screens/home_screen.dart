import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_api_service.dart';
import '../services/recipe_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = RecipeApiService();
  final _repository = RecipeRepository();
  final _searchController = TextEditingController();
  int _selectedTab = 0;
  Future<List<Recipe>>? _searchResults;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showMessage('Digite o nome de um prato para pesquisar.');
      return;
    }
    setState(() => _searchResults = _api.search(query));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(Recipe recipe) async {
    try {
      final completeRecipe = recipe.hasDetails
          ? recipe
          : await _api.getRecipe(recipe.sourceId);
      await _repository.saveRecipe(widget.user.uid, completeRecipe);
      if (mounted) _showMessage('Receita salva no seu caderno.');
    } catch (error) {
      if (mounted) _showMessage('Não foi possível salvar a receita: $error');
    }
  }

  Future<void> _delete(Recipe recipe) async {
    final id = recipe.id;
    if (id == null) return;
    try {
      await _repository.deleteRecipe(widget.user.uid, id);
      if (mounted) _showMessage('Receita removida do caderno.');
    } catch (error) {
      if (mounted) _showMessage('Não foi possível excluir a receita: $error');
    }
  }

  Future<void> _edit([Recipe? recipe]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(
          recipe: recipe,
          onSave: (value) => _repository.saveRecipe(widget.user.uid, value),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (mounted) _showMessage('Não foi possível sair da conta: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBook = _selectedTab == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu),
            SizedBox(width: 10),
            Text('Receitas, é Tudo Gostoso!'),
          ],
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width > 600)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  widget.user.email ?? 'Minha conta',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: isBook ? _buildBook() : _buildDiscover()),
      floatingActionButton: isBook
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nova receita'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Descobrir'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Meu caderno',
          ),
        ],
      ),
    );
  }

  Widget _buildDiscover() => _PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroPanel(),
        const SizedBox(height: 28),
        Text(
          'O que vamos cozinhar?',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  hintText: 'Ex.: lasanha, frango, bolo...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _search,
              style: FilledButton.styleFrom(
                minimumSize: const Size(58, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_searchResults == null)
          const _EmptyState(
            icon: Icons.soup_kitchen_outlined,
            title: 'Encontre sua próxima receita',
            message: 'Pesquise por um prato e explore receitas da comunidade.',
          )
        else
          FutureBuilder<List<Recipe>>(
            future: _searchResults,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.wifi_off,
                  title: 'Não foi possível buscar receitas',
                  message: '${snapshot.error}',
                );
              }
              final recipes = snapshot.data ?? const [];
              if (recipes.isEmpty) {
                return const _EmptyState(
                  icon: Icons.search_off,
                  title: 'Nenhuma receita encontrada',
                  message: 'Tente pesquisar usando outro nome de prato.',
                );
              }
              return _RecipeGrid(
                recipes: recipes,
                actionLabel: 'Salvar no caderno',
                actionIcon: Icons.bookmark_add_outlined,
                onAction: _save,
                onOpen: (recipe) => _openDetails(recipe),
              );
            },
          ),
      ],
    ),
  );

  Widget _buildBook() => StreamBuilder<List<Recipe>>(
    stream: _repository.watchRecipes(widget.user.uid),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar seu caderno',
          message: '${snapshot.error}',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final recipes = snapshot.data!;
      if (recipes.isEmpty) {
        return const _PageFrame(
          child: _EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Seu caderno está esperando',
            message: 'Salve receitas que encontrar ou crie uma receita sua.',
          ),
        );
      }
      return _PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meu caderno',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('${recipes.length} receita(s) guardada(s)'),
            const SizedBox(height: 20),
            _RecipeGrid(
              recipes: recipes,
              actionLabel: 'Editar receita',
              actionIcon: Icons.edit_outlined,
              onAction: _edit,
              onOpen: (recipe) => _openDetails(recipe, saved: true),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _openDetails(Recipe recipe, {bool saved = false}) async {
    var detailedRecipe = recipe;
    if (!saved) {
      try {
        detailedRecipe = await _api.getRecipe(recipe.sourceId);
      } catch (error) {
        if (mounted) {
          _showMessage('Não foi possível carregar a receita: $error');
        }
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: detailedRecipe,
          saved: saved,
          onSave: () => _save(detailedRecipe),
          onEdit: () => _edit(recipe),
          onDelete: () => _delete(recipe),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: child,
      ),
    ),
  );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SABOR PARA TODOS OS DIAS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Receitas gostosas,\nmemórias deliciosas.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Descubra novos pratos e guarde os seus favoritos em um só lugar.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.ramen_dining, size: 84, color: colors.primary),
        ],
      ),
    );
  }
}

class _RecipeGrid extends StatelessWidget {
  const _RecipeGrid({
    required this.recipes,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.onOpen,
  });

  final List<Recipe> recipes;
  final String actionLabel;
  final IconData actionIcon;
  final ValueChanged<Recipe> onAction;
  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 900
          ? 3
          : constraints.maxWidth > 580
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recipes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 330,
        ),
        itemBuilder: (context, index) => _RecipeCard(
          recipe: recipes[index],
          actionLabel: actionLabel,
          actionIcon: actionIcon,
          onAction: () => onAction(recipes[index]),
          onOpen: () => onOpen(recipes[index]),
        ),
      );
    },
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.onOpen,
  });

  final Recipe recipe;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFFE9E1D8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(onTap: onOpen, child: const _ImagePlaceholder()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                recipe.stats.prepareTimeMinutes == null
                    ? recipe.hasDetails
                          ? '${recipe.ingredients.length} ingredientes'
                          : 'Toque para ver os detalhes'
                    : '${recipe.stats.prepareTimeMinutes} min de preparo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 18),
            label: Text(actionLabel),
          ),
        ),
      ],
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF5E6D6),
    child: Center(
      child: Icon(
        Icons.restaurant,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 16),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.saved,
    required this.onSave,
    required this.onEdit,
    required this.onDelete,
  });

  final Recipe recipe;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes da receita')),
    body: _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (recipe.stats.prepareTimeMinutes != null ||
              recipe.stats.portionOutput != null ||
              recipe.stats.favorites != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (recipe.stats.prepareTimeMinutes != null)
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text('${recipe.stats.prepareTimeMinutes} min'),
                  ),
                if (recipe.stats.portionOutput != null)
                  Chip(
                    avatar: const Icon(Icons.restaurant, size: 18),
                    label: Text('${recipe.stats.portionOutput} porções'),
                  ),
                if (recipe.stats.favorites != null)
                  Chip(
                    avatar: const Icon(Icons.favorite_border, size: 18),
                    label: Text('${recipe.stats.favorites} favoritos'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              if (saved)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                )
              else
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Salvar no caderno'),
                ),
              if (saved)
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Ingredientes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (recipe.ingredientSections.isEmpty)
            const Text('Nenhum ingrediente cadastrado.')
          else
            ...recipe.ingredientSections.map(
              (section) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.title != 'default')
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ...section.items.map(
                    (ingredient) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.circle, size: 9),
                      title: Text(ingredient),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Modo de preparo',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (recipe.instructionSections.isEmpty)
            const Text('Nenhuma instrução cadastrada.')
          else
            ...recipe.instructionSections.map(
              (section) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.title != 'default')
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ...section.items.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            child: Text(
                              '${entry.$1 + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(entry.$2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir receita?'),
        content: const Text('Esta ação remove a receita do seu caderno.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete();
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({super.key, this.recipe, required this.onSave});

  final Recipe? recipe;
  final Future<void> Function(Recipe) onSave;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _instructionsController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _titleController = TextEditingController(text: recipe?.title ?? '');
    _ingredientsController = TextEditingController(
      text: recipe?.ingredients.join('\n') ?? '',
    );
    _instructionsController = TextEditingController(
      text: recipe?.instructions.join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ingredients = _parseLines(_ingredientsController.text);
    final instructions = _parseLines(_instructionsController.text);
    final original = widget.recipe;
    final keepIngredientSections =
        original != null &&
        original.ingredients.join('\n') == ingredients.join('\n');
    final keepInstructionSections =
        original != null &&
        original.instructions.join('\n') == instructions.join('\n');
    final recipe = Recipe(
      id: widget.recipe?.id,
      sourceId: widget.recipe?.sourceId ?? '',
      title: _titleController.text.trim(),
      ingredients: ingredients,
      instructions: instructions,
      ingredientSections: keepIngredientSections
          ? original.ingredientSections
          : const [],
      instructionSections: keepInstructionSections
          ? original.instructionSections
          : const [],
      stats: original?.stats ?? const RecipeStats(),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(recipe);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = 'Não foi possível salvar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseLines(String input) => input
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recipe == null ? 'Nova receita' : 'Editar receita'),
    ),
    body: _PageFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _formField(
              _titleController,
              'Nome da receita',
              requiredField: true,
            ),
            _formField(
              _ingredientsController,
              'Ingredientes (um por linha)',
              requiredField: true,
              maxLines: 6,
            ),
            const SizedBox(height: 14),
            _formField(
              _instructionsController,
              'Modo de preparo (uma etapa por linha)',
              requiredField: true,
              maxLines: 8,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_saving ? 'Salvando...' : 'Salvar receita'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _formField(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    minLines: maxLines == 1 ? 1 : maxLines,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
    validator: requiredField
        ? (value) => value == null || value.trim().isEmpty
              ? 'Este campo é obrigatório.'
              : null
        : null,
  );
}
