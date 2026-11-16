import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MacroPantryApp());
}

class MacroPantryApp extends StatelessWidget {
  const MacroPantryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Macro & Pantry Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// DATA MODELS & DEFAULT CATALOG
// ==========================================

class Ingredient {
  String id;
  String name;
  double kcalPer100g;
  double proteinPer100g;
  double carbsPer100g;
  double fatPer100g;
  double pantryGrams;
  double defaultBuyGrams;
  bool isWeeklyStaple;

  Ingredient({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.pantryGrams = 0,
    this.defaultBuyGrams = 500,
    this.isWeeklyStaple = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kcalPer100g': kcalPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'pantryGrams': pantryGrams,
        'defaultBuyGrams': defaultBuyGrams,
        'isWeeklyStaple': isWeeklyStaple,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id'],
        name: json['name'],
        kcalPer100g: (json['kcalPer100g'] as num).toDouble(),
        proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
        carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
        fatPer100g: (json['fatPer100g'] as num).toDouble(),
        pantryGrams: (json['pantryGrams'] as num).toDouble(),
        defaultBuyGrams: (json['defaultBuyGrams'] as num).toDouble(),
        isWeeklyStaple: json['isWeeklyStaple'] ?? false,
      );
}

class RecipeItem {
  String ingredientId;
  double grams;
  RecipeItem({required this.ingredientId, required this.grams});

  Map<String, dynamic> toJson() => {'ingredientId': ingredientId, 'grams': grams};
  factory RecipeItem.fromJson(Map<String, dynamic> json) => RecipeItem(
        ingredientId: json['ingredientId'],
        grams: (json['grams'] as num).toDouble(),
      );
}

class Recipe {
  String id;
  String name;
  List<RecipeItem> items;
  Recipe({required this.id, required this.name, required this.items});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'],
        name: json['name'],
        items: (json['items'] as List).map((e) => RecipeItem.fromJson(e)).toList(),
      );
}

class FoodLogEntry {
  String id;
  String date; // yyyy-MM-dd
  String title;
  double grams;
  double kcal;
  double protein;
  double carbs;
  double fat;
  // Store deducted ingredients so deleting/editing can refund pantry
  Map<String, double> pantryDeductions;

  FoodLogEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.pantryDeductions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'pantryDeductions': pantryDeductions,
      };

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) => FoodLogEntry(
        id: json['id'],
        date: json['date'],
        title: json['title'],
        grams: (json['grams'] as num).toDouble(),
        kcal: (json['kcal'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        pantryDeductions: (json['pantryDeductions'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
      );
}

List<Ingredient> getDefaultCatalog() => [
      Ingredient(id: 'chicken_breast', name: 'Chicken Breast (Raw)', kcalPer100g: 120, proteinPer100g: 22.5, carbsPer100g: 0, fatPer100g: 2.6, defaultBuyGrams: 1000, isWeeklyStaple: true),
      Ingredient(id: 'canned_tuna', name: 'Canned Tuna (Drained)', kcalPer100g: 116, proteinPer100g: 26.0, carbsPer100g: 0, fatPer100g: 1.0, defaultBuyGrams: 400, isWeeklyStaple: true),
      Ingredient(id: 'egg_whites', name: 'Egg Whites', kcalPer100g: 52, proteinPer100g: 11.0, carbsPer100g: 0.7, fatPer100g: 0.2, defaultBuyGrams: 500, isWeeklyStaple: true),
      Ingredient(id: 'whole_eggs', name: 'Whole Eggs (~50g/egg)', kcalPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.5, defaultBuyGrams: 1500, isWeeklyStaple: true),
      Ingredient(id: 'sardines', name: 'Sardines (Drained fish)', kcalPer100g: 208, proteinPer100g: 24.6, carbsPer100g: 0, fatPer100g: 11.5, defaultBuyGrams: 300, isWeeklyStaple: true),
      Ingredient(id: 'ww_tortilla', name: 'Whole Wheat Tortilla', kcalPer100g: 295, proteinPer100g: 9.0, carbsPer100g: 49.0, fatPer100g: 6.5, defaultBuyGrams: 360, isWeeklyStaple: true),
      Ingredient(id: 'ricotta', name: 'Ricotta Cheese', kcalPer100g: 150, proteinPer100g: 11.0, carbsPer100g: 3.5, fatPer100g: 10.5, defaultBuyGrams: 400, isWeeklyStaple: true),
      Ingredient(id: 'whey_protein', name: 'Whey Protein Powder', kcalPer100g: 380, proteinPer100g: 78.0, carbsPer100g: 6.0, fatPer100g: 5.0, defaultBuyGrams: 1000, isWeeklyStaple: false),
      Ingredient(id: 'oats', name: 'Rolled Oats', kcalPer100g: 379, proteinPer100g: 13.2, carbsPer100g: 67.7, fatPer100g: 6.5, defaultBuyGrams: 1000, isWeeklyStaple: true),
      Ingredient(id: 'chickpeas', name: 'Chickpeas (Boiled)', kcalPer100g: 164, proteinPer100g: 8.9, carbsPer100g: 27.4, fatPer100g: 2.6, defaultBuyGrams: 500, isWeeklyStaple: true),
      Ingredient(id: 'lentils', name: 'Lentils (Boiled)', kcalPer100g: 116, proteinPer100g: 9.0, carbsPer100g: 20.1, fatPer100g: 0.4, defaultBuyGrams: 500, isWeeklyStaple: true),
      Ingredient(id: 'harissa', name: 'Harissa Paste', kcalPer100g: 75, proteinPer100g: 2.5, carbsPer100g: 11.0, fatPer100g: 2.0, defaultBuyGrams: 200, isWeeklyStaple: false),
      Ingredient(id: 'olives', name: 'Olives', kcalPer100g: 145, proteinPer100g: 1.0, carbsPer100g: 3.8, fatPer100g: 15.3, defaultBuyGrams: 250, isWeeklyStaple: false),
      Ingredient(id: 'dark_choc', name: 'Dark Chocolate Coating', kcalPer100g: 545, proteinPer100g: 6.5, carbsPer100g: 46.0, fatPer100g: 35.0, defaultBuyGrams: 500, isWeeklyStaple: false),
      Ingredient(id: 'olive_oil', name: 'Olive Oil', kcalPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100.0, defaultBuyGrams: 1000, isWeeklyStaple: false),
    ];

// ==========================================
// MAIN SCREEN & STATE CONTROLLER
// ==========================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // User Goals
  double goalKcal = 2150;
  double goalProtein = 175;
  double goalCarbs = 180;
  double goalFat = 65;
  double goalWaterMl = 3500;

  // App Data
  List<Ingredient> catalog = [];
  List<Recipe> recipes = [];
  List<FoodLogEntry> foodLogs = [];
  Map<String, double> waterLogs = {}; // date -> ml
  Map<String, double> weightLogs = {}; // date -> kg

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('app_full_state_v1');
    if (rawJson != null) {
      _applyStateFromMap(jsonDecode(rawJson));
    } else {
      catalog = getDefaultCatalog();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_full_state_v1', jsonEncode(_exportStateToMap()));
    setState(() {});
  }

  Map<String, dynamic> _exportStateToMap() => {
        'goalKcal': goalKcal,
        'goalProtein': goalProtein,
        'goalCarbs': goalCarbs,
        'goalFat': goalFat,
        'goalWaterMl': goalWaterMl,
        'catalog': catalog.map((e) => e.toJson()).toList(),
        'recipes': recipes.map((e) => e.toJson()).toList(),
        'foodLogs': foodLogs.map((e) => e.toJson()).toList(),
        'waterLogs': waterLogs,
        'weightLogs': weightLogs,
      };

  void _applyStateFromMap(Map<String, dynamic> data) {
    goalKcal = (data['goalKcal'] ?? 2150).toDouble();
    goalProtein = (data['goalProtein'] ?? 175).toDouble();
    goalCarbs = (data['goalCarbs'] ?? 180).toDouble();
    goalFat = (data['goalFat'] ?? 65).toDouble();
    goalWaterMl = (data['goalWaterMl'] ?? 3500).toDouble();
    catalog = (data['catalog'] as List?)
            ?.map((e) => Ingredient.fromJson(e))
            .toList() ??
        getDefaultCatalog();
    recipes = (data['recipes'] as List?)
            ?.map((e) => Recipe.fromJson(e))
            .toList() ??
        [];
    foodLogs = (data['foodLogs'] as List?)
            ?.map((e) => FoodLogEntry.fromJson(e))
            .toList() ??
        [];
    waterLogs = (data['waterLogs'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
        {};
    weightLogs = (data['weightLogs'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
        {};
  }

  // Backup & Restore Functions
Future<void> _importBackupFile() async {
    final ctrl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().startsWith('{')) {
      ctrl.text = clip.text!;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup JSON'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Paste exported JSON backup here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final decoded = jsonDecode(ctrl.text.trim()) as Map<String, dynamic>;
                _applyStateFromMap(decoded);
                await _saveData();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored successfully!')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid JSON format.')),
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      _buildDashboardTab(),
      _buildPantryAndWeeklyTab(),
      _buildRecipesTab(),
      _buildAnalyticsTab(),
      _buildSettingsBackupTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Macro & Pantry Tracker'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_selectedDate),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(_selectedDate),
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Daily'),
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Graphs'),
          NavigationDestination(icon: Icon(Icons.settings_backup_restore), label: 'Control'),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DAILY DASHBOARD & FOOD LOGGING
  // ==========================================

  Widget _buildDashboardTab() {
    final dayLogs = foodLogs.where((e) => e.date == _selectedDate).toList();
    final totalKcal = dayLogs.fold(0.0, (s, e) => s + e.kcal);
    final totalP = dayLogs.fold(0.0, (s, e) => s + e.protein);
    final totalC = dayLogs.fold(0.0, (s, e) => s + e.carbs);
    final totalF = dayLogs.fold(0.0, (s, e) => s + e.fat);
    final currentWater = waterLogs[_selectedDate] ?? 0.0;
    final currentWeight = weightLogs[_selectedDate];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Macro Progress Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Targets ($_selectedDate)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildMacroBar('Calories', totalKcal, goalKcal, 'kcal', Colors.orangeAccent),
                _buildMacroBar('Protein', totalP, goalProtein, 'g', Colors.tealAccent),
                _buildMacroBar('Carbs', totalC, goalCarbs, 'g', Colors.blueAccent),
                _buildMacroBar('Fats', totalF, goalFat, 'g', Colors.purpleAccent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Water & Morning Weight Row
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Water Intake', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${currentWater.toInt()} / ${goalWaterMl.toInt()} ml',
                          style: const TextStyle(fontSize: 16, color: Colors.lightBlueAccent)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (currentWater / goalWaterMl).clamp(0.0, 1.0),
                        color: Colors.lightBlueAccent,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              waterLogs[_selectedDate] = (currentWater - 250).clamp(0, 15000);
                              _saveData();
                            },
                          ),
                          TextButton(
                            onPressed: () {
                              waterLogs[_selectedDate] = currentWater + 250;
                              _saveData();
                            },
                            child: const Text('+250ml'),
                          ),
                          TextButton(
                            onPressed: () {
                              waterLogs[_selectedDate] = currentWater + 500;
                              _saveData();
                            },
                            child: const Text('+500ml'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Morning Weight', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        currentWeight != null ? '${currentWeight.toStringAsFixed(1)} kg' : 'Not logged',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                        label: const Text('Log kg'),
                        onPressed: _showWeightDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Buttons to Eat from Pantry or Recipes
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Eat Ingredient'),
                onPressed: _showEatIngredientDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.restaurant),
                label: const Text('Eat Recipe'),
                onPressed: () => setState(() => _selectedIndex = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('Eaten Today (Tap to Edit / Delete)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (dayLogs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No food logged for this date yet.')),
          ),
        ...dayLogs.map((entry) => Card(
              child: ListTile(
                title: Text('${entry.title} (${entry.grams.toInt()}g)'),
                subtitle: Text(
                    '${entry.kcal.toInt()} kcal • P: ${entry.protein.toStringAsFixed(1)}g • C: ${entry.carbs.toStringAsFixed(1)}g • F: ${entry.fat.toStringAsFixed(1)}g'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditLogDialog(entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteFoodLog(entry),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildMacroBar(String label, double val, double goal, String unit, Color color) {
    final pct = (val / (goal <= 0 ? 1 : goal)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${val.toInt()} / ${goal.toInt()} $unit'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: color,
          ),
        ],
      ),
    );
  }

  void _showWeightDialog() {
    final ctrl = TextEditingController(text: weightLogs[_selectedDate]?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Weight ($_selectedDate)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight in kg (e.g. 83.0)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                weightLogs[_selectedDate] = val;
                _saveData();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEatIngredientDialog() {
    Ingredient selected = catalog.first;
    final gramsCtrl = TextEditingController(text: '100');
    bool deductPantry = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Ingredient Eaten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Ingredient>(
                value: selected,
                isExpanded: true,
                items: catalog
                    .map((ing) => DropdownMenuItem(
                          value: ing,
                          child: Text('${ing.name} (Stock: ${ing.pantryGrams.toInt()}g)'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selected = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gramsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Grams Eaten'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deduct from Pantry stock'),
                value: deductPantry,
                onChanged: (v) => setDialogState(() => deductPantry = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final g = double.tryParse(gramsCtrl.text) ?? 0;
                if (g > 0) {
                  final factor = g / 100.0;
                  final deductions = <String, double>{};
                  if (deductPantry) {
                    selected.pantryGrams = (selected.pantryGrams - g).clamp(0, 999999);
                    deductions[selected.id] = g;
                  }
                  foodLogs.add(FoodLogEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    date: _selectedDate,
                    title: selected.name,
                    grams: g,
                    kcal: selected.kcalPer100g * factor,
                    protein: selected.proteinPer100g * factor,
                    carbs: selected.carbsPer100g * factor,
                    fat: selected.fatPer100g * factor,
                    pantryDeductions: deductions,
                  ));
                  _saveData();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Log Eaten'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLogDialog(FoodLogEntry entry) {
    final gramsCtrl = TextEditingController(text: entry.grams.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${entry.title}'),
        content: TextField(
          controller: gramsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'New Weight in Grams'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final newGrams = double.tryParse(gramsCtrl.text) ?? entry.grams;
              if (newGrams > 0 && entry.grams > 0) {
                final ratio = newGrams / entry.grams;
                // Adjust pantry stock proportionally
                entry.pantryDeductions.forEach((ingId, oldDeducted) {
                  final ing = catalog.where((e) => e.id == ingId).firstOrNull;
                  if (ing != null) {
                    final newDeducted = oldDeducted * ratio;
                    final diff = newDeducted - oldDeducted;
                    ing.pantryGrams = (ing.pantryGrams - diff).clamp(0, 999999);
                    entry.pantryDeductions[ingId] = newDeducted;
                  }
                });
                entry.grams = newGrams;
                entry.kcal *= ratio;
                entry.protein *= ratio;
                entry.carbs *= ratio;
                entry.fat *= ratio;
                _saveData();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Update & Sync Pantry'),
          ),
        ],
      ),
    );
  }

  void _deleteFoodLog(FoodLogEntry entry) {
    // Refund pantry stock when deleting a log
    entry.pantryDeductions.forEach((ingId, deductedGrams) {
      final ing = catalog.where((e) => e.id == ingId).firstOrNull;
      if (ing != null) {
        ing.pantryGrams += deductedGrams;
      }
    });
    foodLogs.removeWhere((e) => e.id == entry.id);
    _saveData();
  }

  // ==========================================
  // TAB 2: PANTRY & ONE-CLICK WEEKLY BUY LIST
  // ==========================================

  Widget _buildPantryAndWeeklyTab() {
    final weeklyStaples = catalog.where((e) => e.isWeeklyStaple).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.teal.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weekly Bought Items (1-Click Restock)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    FilledButton.tonal(
                      onPressed: () {
                        for (final item in weeklyStaples) {
                          item.pantryGrams += item.defaultBuyGrams;
                        }
                        _saveData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All weekly staples added to Pantry!')),
                        );
                      },
                      child: const Text('Add All Weekly'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: weeklyStaples
                      .map((ing) => ActionChip(
                            avatar: const Icon(Icons.add_shopping_cart, size: 16),
                            label: Text('${ing.name} (+${ing.defaultBuyGrams.toInt()}g)'),
                            onPressed: () {
                              ing.pantryGrams += ing.defaultBuyGrams;
                              _saveData();
                            },
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Master Catalog & Pantry Stock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New Item'),
              onPressed: () => _showAddOrEditIngredientDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...catalog.map((ing) => Card(
              child: ListTile(
                title: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Per 100g: ${ing.kcalPer100g.toInt()} kcal | P:${ing.proteinPer100g}g C:${ing.carbsPer100g}g F:${ing.fatPer100g}g\nIn Pantry: ${ing.pantryGrams.toInt()}g'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Quick Buy (+${ing.defaultBuyGrams.toInt()}g)',
                      icon: const Icon(Icons.add_box_outlined, color: Colors.tealAccent),
                      onPressed: () {
                        ing.pantryGrams += ing.defaultBuyGrams;
                        _saveData();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showAddOrEditIngredientDialog(existing: ing),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        catalog.removeWhere((e) => e.id == ing.id);
                        _saveData();
                      },
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  void _showAddOrEditIngredientDialog({Ingredient? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final kcalCtrl = TextEditingController(text: existing?.kcalPer100g.toString() ?? '100');
    final pCtrl = TextEditingController(text: existing?.proteinPer100g.toString() ?? '20');
    final cCtrl = TextEditingController(text: existing?.carbsPer100g.toString() ?? '5');
    final fCtrl = TextEditingController(text: existing?.fatPer100g.toString() ?? '2');
    final stockCtrl = TextEditingController(text: existing?.pantryGrams.toString() ?? '0');
    final buyCtrl = TextEditingController(text: existing?.defaultBuyGrams.toString() ?? '500');
    bool weekly = existing?.isWeeklyStaple ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Ingredient' : 'Edit Ingredient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ingredient Name')),
                TextField(controller: kcalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kcal per 100g')),
                TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein per 100g')),
                TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs per 100g')),
                TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat per 100g')),
                TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Pantry Stock (g)')),
                TextField(controller: buyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Weekly Buy Pack (g)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include in Weekly Bought List'),
                  value: weekly,
                  onChanged: (v) => setDialogState(() => weekly = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final item = Ingredient(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim().isEmpty ? 'Custom Item' : nameCtrl.text.trim(),
                  kcalPer100g: double.tryParse(kcalCtrl.text) ?? 0,
                  proteinPer100g: double.tryParse(pCtrl.text) ?? 0,
                  carbsPer100g: double.tryParse(cCtrl.text) ?? 0,
                  fatPer100g: double.tryParse(fCtrl.text) ?? 0,
                  pantryGrams: double.tryParse(stockCtrl.text) ?? 0,
                  defaultBuyGrams: double.tryParse(buyCtrl.text) ?? 500,
                  isWeeklyStaple: weekly,
                );
                if (existing == null) {
                  catalog.add(item);
                } else {
                  final idx = catalog.indexWhere((e) => e.id == existing.id);
                  if (idx != -1) catalog[idx] = item;
                }
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: RECIPE BUILDER & MARK AS EATEN
  // ==========================================

  Widget _buildRecipesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Custom Recipes & Meals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Recipe'),
              onPressed: () => _showRecipeBuilderDialog(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recipes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Create recipes from your Pantry items to log full meals in one click.'),
            ),
          ),
        ...recipes.map((recipe) {
          double kcal = 0, p = 0, c = 0, f = 0, totalGrams = 0;
          for (final item in recipe.items) {
            final ing = catalog.where((e) => e.id == item.ingredientId).firstOrNull;
            if (ing != null) {
              final factor = item.grams / 100.0;
              totalGrams += item.grams;
              kcal += ing.kcalPer100g * factor;
              p += ing.proteinPer100g * factor;
              c += ing.carbsPer100g * factor;
              f += ing.fatPer100g * factor;
            }
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(recipe.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              recipes.removeWhere((r) => r.id == recipe.id);
                              _saveData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                      'Total (${totalGrams.toInt()}g): ${kcal.toInt()} kcal • P: ${p.toStringAsFixed(1)}g • C: ${c.toStringAsFixed(1)}g • F: ${f.toStringAsFixed(1)}g',
                      style: const TextStyle(color: Colors.tealAccent)),
                  const SizedBox(height: 6),
                  ...recipe.items.map((ri) {
                    final ing = catalog.where((e) => e.id == ri.ingredientId).firstOrNull;
                    return Text('• ${ing?.name ?? 'Unknown'}: ${ri.grams.toInt()}g');
                  }),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _eatRecipe(recipe, 0.5, kcal, p, c, f, totalGrams),
                        child: const Text('Eat 1/2'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Mark Eaten (Full)'),
                        onPressed: () => _eatRecipe(recipe, 1.0, kcal, p, c, f, totalGrams),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _eatRecipe(
      Recipe r, double portion, double kcal, double p, double c, double f, double totalGrams) {
    final deductions = <String, double>{};
    for (final item in r.items) {
      final ing = catalog.where((e) => e.id == item.ingredientId).firstOrNull;
      if (ing != null) {
        final used = item.grams * portion;
        ing.pantryGrams = (ing.pantryGrams - used).clamp(0, 999999);
        deductions[ing.id] = (deductions[ing.id] ?? 0) + used;
      }
    }
    foodLogs.add(FoodLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      title: '${r.name} (${(portion * 100).toInt()}%)',
      grams: totalGrams * portion,
      kcal: kcal * portion,
      protein: p * portion,
      carbs: c * portion,
      fat: f * portion,
      pantryDeductions: deductions,
    ));
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged ${r.name} & updated Pantry stock!')),
    );
  }

  void _showRecipeBuilderDialog() {
    final nameCtrl = TextEditingController();
    final List<RecipeItem> draftItems = [];
    Ingredient selectedIng = catalog.first;
    final gramsCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Build Recipe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Recipe Name (e.g. Tuna Wrap)'),
                ),
                const Divider(height: 24),
                DropdownButtonFormField<Ingredient>(
                  value: selectedIng,
                  isExpanded: true,
                  items: catalog
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedIng = v);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: gramsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Grams'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final g = double.tryParse(gramsCtrl.text) ?? 0;
                        if (g > 0) {
                          setDialogState(() {
                            draftItems.add(RecipeItem(ingredientId: selectedIng.id, grams: g));
                          });
                        }
                      },
                      child: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...draftItems.map((di) {
                  final ing = catalog.where((e) => e.id == di.ingredientId).firstOrNull;
                  return ListTile(
                    dense: true,
                    title: Text('${ing?.name}: ${di.grams.toInt()}g'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setDialogState(() => draftItems.remove(di)),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (draftItems.isNotEmpty) {
                  recipes.add(Recipe(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim().isEmpty ? 'Custom Meal' : nameCtrl.text.trim(),
                    items: draftItems,
                  ));
                  _saveData();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save Recipe'),
            ),
          ],
        ),
      ),
    );
  }

 // ==========================================
  // TAB 4: GRAPHS (WEIGHT & CALORIE HISTORY)
  // ==========================================

  Widget _buildAnalyticsTab() {
    final sortedWeightDates = weightLogs.keys.toList()..sort();
    final dailyWeightSpots = <FlSpot>[];
    final rollingAvgSpots = <FlSpot>[];

    for (int i = 0; i < sortedWeightDates.length; i++) {
      final currentDateStr = sortedWeightDates[i];
      final currentWeight = weightLogs[currentDateStr]!;
      dailyWeightSpots.add(FlSpot(i.toDouble(), currentWeight));

      // Calculate true 7-day calendar window average (current day + previous 6 days)
      final currentDate = DateTime.parse(currentDateStr);
      double sum = 0;
      int count = 0;

      for (int j = i; j >= 0; j--) {
        final pastDate = DateTime.parse(sortedWeightDates[j]);
        if (currentDate.difference(pastDate).inDays <= 6) {
          sum += weightLogs[sortedWeightDates[j]]!;
          count++;
        } else {
          break;
        }
      }
      final rollingAvg = count > 0 ? (sum / count) : currentWeight;
      rollingAvgSpots.add(FlSpot(i.toDouble(), double.parse(rollingAvg.toStringAsFixed(2))));
    }

    // Latest summary stats for the header
    final latestDaily = dailyWeightSpots.isNotEmpty ? dailyWeightSpots.last.y : null;
    final latestRolling = rollingAvgSpots.isNotEmpty ? rollingAvgSpots.last.y : null;

    // Last 7 days calories bar chart
    final last7Days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateFormat('yyyy-MM-dd').format(d);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Morning Weight Trend (kg)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (latestDaily != null && latestRolling != null)
              Text(
                '7d Avg: ${latestRolling.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Legend for Daily vs 7-Day Rolling Average
        Row(
          children: [
            Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('Daily Morning Weight', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(width: 16),
            Container(width: 16, height: 4, color: Colors.orangeAccent),
            const SizedBox(width: 6),
            const Text('7-Day Rolling Average', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 250,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
              child: dailyWeightSpots.isEmpty
                  ? const Center(child: Text('Log morning weights on the Daily tab to see trend.'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: (sortedWeightDates.length / 4).clamp(1, 30).toDouble(),
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= sortedWeightDates.length) {
                                  return const SizedBox.shrink();
                                }
                                final shortDate = sortedWeightDates[idx].substring(5); // MM-dd
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(shortDate, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                final dateLabel = (idx >= 0 && idx < sortedWeightDates.length)
                                    ? sortedWeightDates[idx].substring(5)
                                    : '';
                                final isRolling = spot.barIndex == 1;
                                return LineTooltipItem(
                                  isRolling
                                      ? '7d Avg: ${spot.y.toStringAsFixed(2)} kg'
                                      : '$dateLabel\nDaily: ${spot.y.toStringAsFixed(1)} kg',
                                  TextStyle(
                                    color: isRolling ? Colors.orangeAccent : Colors.tealAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          // Bar 0: Daily Raw Weight (Teal, slightly subtle with visible dots)
                          LineChartBarData(
                            spots: dailyWeightSpots,
                            isCurved: false,
                            color: Colors.tealAccent.withOpacity(0.55),
                            barWidth: 2,
                            dotData: const FlDotData(show: true),
                          ),
                          // Bar 1: 7-Day Rolling Average (Orange, smooth bold trend line)
                          LineChartBarData(
                            spots: rollingAvgSpots,
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: Colors.orangeAccent,
                            barWidth: 3.5,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Last 7 Days Calorie Intake',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= last7Days.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              last7Days[idx].substring(5),
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final dateKey = last7Days[i];
                    final kcal = foodLogs
                        .where((e) => e.date == dateKey)
                        .fold(0.0, (s, e) => s + e.kcal);
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: kcal,
                          color: kcal > goalKcal ? Colors.orangeAccent : Colors.tealAccent,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 5: GOALS & FULL BACKUP / RESTORE
  // ==========================================

  Widget _buildSettingsBackupTab() {
    final kcalCtrl = TextEditingController(text: goalKcal.toInt().toString());
    final pCtrl = TextEditingController(text: goalProtein.toInt().toString());
    final cCtrl = TextEditingController(text: goalCarbs.toInt().toString());
    final fCtrl = TextEditingController(text: goalFat.toInt().toString());
    final wCtrl = TextEditingController(text: goalWaterMl.toInt().toString());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Backup & Restore Saves (JSON)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Export your entire database (logs, pantry stock, recipes, and goals) to a file or restore from a previous backup.'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Export Backup'),
                        onPressed: _exportBackupFile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_done),
                        label: const Text('Restore Save'),
                        onPressed: _importBackupFile,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set Daily Macro & Water Goals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: kcalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Calories (kcal)')),
                TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Protein (g)')),
                TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Carbs (g)')),
                TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Fat (g)')),
                TextField(controller: wCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Water (ml)')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    goalKcal = double.tryParse(kcalCtrl.text) ?? goalKcal;
                    goalProtein = double.tryParse(pCtrl.text) ?? goalProtein;
                    goalCarbs = double.tryParse(cCtrl.text) ?? goalCarbs;
                    goalFat = double.tryParse(fCtrl.text) ?? goalFat;
                    goalWaterMl = double.tryParse(wCtrl.text) ?? goalWaterMl;
                    _saveData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily goals updated!')),
                    );
                  },
                  child: const Text('Save Daily Goals'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
