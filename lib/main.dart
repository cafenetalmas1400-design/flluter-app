// MoodFlow - Smart Mood & Habit Tracker
// All code integrated into single file

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ============================================================================
// MODELS
// ============================================================================

class MoodEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int moodLevel; // 1-5 (Very Bad to Excellent)

  @HiveField(2)
  String note;

  @HiveField(3)
  List<String> tags;

  @HiveField(4)
  DateTime dateTime;

  @HiveField(5)
  String? emoji;

  @HiveField(6)
  int energyLevel; // 1-5

  MoodEntry({
    required this.id,
    required this.moodLevel,
    this.note = '',
    this.tags = const [],
    required this.dateTime,
    this.emoji,
    this.energyLevel = 3,
  });

  String get moodEmoji {
    switch (moodLevel) {
      case 1:
        return '😢';
      case 2:
        return '😔';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '🤩';
      default:
        return '😐';
    }
  }

  String get moodLabel {
    switch (moodLevel) {
      case 1:
        return 'خیلی بد';
      case 2:
        return 'بد';
      case 3:
        return 'معمولی';
      case 4:
        return 'خوب';
      case 5:
        return 'عالی';
      default:
        return 'معمولی';
    }
  }

  String get energyLabel {
    switch (energyLevel) {
      case 1:
        return 'خیلی کم';
      case 2:
        return 'کم';
      case 3:
        return 'متوسط';
      case 4:
        return 'زیاد';
      case 5:
        return 'عالی';
      default:
        return 'متوسط';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'moodLevel': moodLevel,
      'note': note,
      'tags': tags,
      'dateTime': dateTime.toIso8601String(),
      'emoji': emoji,
      'energyLevel': energyLevel,
    };
  }
}

class MoodEntryAdapter extends TypeAdapter<MoodEntry> {
  @override
  final int typeId = 0;

  @override
  MoodEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MoodEntry(
      id: fields[0] as String,
      moodLevel: fields[1] as int,
      note: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      dateTime: fields[4] as DateTime,
      emoji: fields[5] as String?,
      energyLevel: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MoodEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.moodLevel)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.dateTime)
      ..writeByte(5)
      ..write(obj.emoji)
      ..writeByte(6)
      ..write(obj.energyLevel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class Habit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String icon;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  List<DateTime> completedDates;

  @HiveField(5)
  int streak;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  String category;

  Habit({
    required this.id,
    required this.title,
    required this.icon,
    required this.colorValue,
    this.completedDates = const [],
    this.streak = 0,
    required this.createdAt,
    this.category = 'عمومی',
  });

  bool isCompletedToday() {
    final now = DateTime.now();
    return completedDates.any((date) =>
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day);
  }

  bool isCompletedOn(DateTime date) {
    return completedDates.any((d) =>
        d.year == date.year &&
        d.month == date.month &&
        d.day == date.day);
  }

  int calculateStreak() {
    if (completedDates.isEmpty) return 0;

    final sortedDates = List<DateTime>.from(completedDates)
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime checkDate = DateTime.now();

    if (!isCompletedToday()) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    for (int i = 0; i < 365; i++) {
      if (sortedDates.any((d) =>
          d.year == checkDate.year &&
          d.month == checkDate.month &&
          d.day == checkDate.day)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  int getThisWeekCompletions() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return completedDates.where((d) => d.isAfter(startOfWeek)).length;
  }
}

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 1;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      title: fields[1] as String,
      icon: fields[2] as String,
      colorValue: fields[3] as int,
      completedDates: (fields[4] as List).cast<DateTime>(),
      streak: fields[5] as int,
      createdAt: fields[6] as DateTime,
      category: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.completedDates)
      ..writeByte(5)
      ..write(obj.streak)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// ============================================================================
// SERVICES
// ============================================================================

class DatabaseService {
  static const String _moodBoxName = 'mood_entries';
  static const String _habitBoxName = 'habits';
  static const String _settingsBoxName = 'settings';

  late Box<MoodEntry> _moodBox;
  late Box<Habit> _habitBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MoodEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HabitAdapter());
    }

    _moodBox = await Hive.openBox<MoodEntry>(_moodBoxName);
    _habitBox = await Hive.openBox<Habit>(_habitBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  Future<void> addMoodEntry(MoodEntry entry) async {
    await _moodBox.put(entry.id, entry);
  }

  Future<void> updateMoodEntry(MoodEntry entry) async {
    await entry.save();
  }

  Future<void> deleteMoodEntry(String id) async {
    await _moodBox.delete(id);
  }

  List<MoodEntry> getAllMoodEntries() {
    final entries = _moodBox.values.toList();
    entries.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return entries;
  }

  List<MoodEntry> getMoodEntriesByDateRange(DateTime start, DateTime end) {
    return _moodBox.values
        .where((entry) =>
            entry.dateTime.isAfter(start) && entry.dateTime.isBefore(end))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  List<MoodEntry> getTodayMoodEntries() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getMoodEntriesByDateRange(startOfDay, endOfDay);
  }

  double getAverageMoodForDays(int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final entries = getMoodEntriesByDateRange(startDate, now);
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.moodLevel).reduce((a, b) => a + b) / entries.length;
  }

  Map<int, int> getMoodDistribution(int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final entries = getMoodEntriesByDateRange(startDate, now);
    
    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var entry in entries) {
      distribution[entry.moodLevel] = (distribution[entry.moodLevel] ?? 0) + 1;
    }
    return distribution;
  }

  Future<void> addHabit(Habit habit) async {
    await _habitBox.put(habit.id, habit);
  }

  Future<void> updateHabit(Habit habit) async {
    await habit.save();
  }

  Future<void> deleteHabit(String id) async {
    await _habitBox.delete(id);
  }

  List<Habit> getAllHabits() {
    return _habitBox.values.toList();
  }

  Future<void> toggleHabitCompletion(String habitId, DateTime date) async {
    final habit = _habitBox.get(habitId);
    if (habit == null) return;

    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    if (habit.isCompletedOn(normalizedDate)) {
      habit.completedDates.removeWhere((d) =>
          d.year == normalizedDate.year &&
          d.month == normalizedDate.month &&
          d.day == normalizedDate.day);
    } else {
      habit.completedDates.add(normalizedDate);
    }
    
    habit.streak = habit.calculateStreak();
    await habit.save();
  }

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Map<String, dynamic> getOverallStats() {
    final allMoods = getAllMoodEntries();
    final allHabits = getAllHabits();
    
    final totalMoodEntries = allMoods.length;
    final avgMood = allMoods.isEmpty
        ? 0.0
        : allMoods.map((e) => e.moodLevel).reduce((a, b) => a + b) / totalMoodEntries;
    final avgEnergy = allMoods.isEmpty
        ? 0.0
        : allMoods.map((e) => e.energyLevel).reduce((a, b) => a + b) / totalMoodEntries;
    
    final totalHabits = allHabits.length;
    final completedToday = allHabits.where((h) => h.isCompletedToday()).length;
    
    final longestStreak = allHabits.isEmpty
        ? 0
        : allHabits.map((h) => h.calculateStreak()).reduce((a, b) => a > b ? a : b);

    return {
      'totalMoodEntries': totalMoodEntries,
      'averageMood': avgMood,
      'averageEnergy': avgEnergy,
      'totalHabits': totalHabits,
      'completedToday': completedToday,
      'longestStreak': longestStreak,
    };
  }

  List<Map<String, dynamic>> getDailyMoodData(int days) {
    final now = DateTime.now();
    List<Map<String, dynamic>> data = [];
    
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final nextDay = normalizedDate.add(const Duration(days: 1));
      
      final dayEntries = getMoodEntriesByDateRange(normalizedDate, nextDay);
      
      if (dayEntries.isNotEmpty) {
        final avgMood = dayEntries.map((e) => e.moodLevel).reduce((a, b) => a + b) / dayEntries.length;
        final avgEnergy = dayEntries.map((e) => e.energyLevel).reduce((a, b) => a + b) / dayEntries.length;
        data.add({
          'date': normalizedDate,
          'mood': avgMood,
          'energy': avgEnergy,
          'count': dayEntries.length,
        });
      } else {
        data.add({
          'date': normalizedDate,
          'mood': 0.0,
          'energy': 0.0,
          'count': 0,
        });
      }
    }
    
    return data;
  }

  Future<void> close() async {
    await _moodBox.close();
    await _habitBox.close();
    await _settingsBox.close();
  }
}

// ============================================================================
// THEME
// ============================================================================

class AppTheme {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondary = Color(0xFFA29BFE);
  static const Color accent = Color(0xFFFD79A8);
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF74B9FF);

  static const List<Color> moodColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFA07A),
    Color(0xFFFDCB6E),
    Color(0xFF74B9FF),
    Color(0xFF00B894),
  ];

  static const List<Color> energyColors = [
    Color(0xFF636E72),
    Color(0xFFB2BEC3),
    Color(0xFFDFE6E9),
    Color(0xFF81ECEC),
    Color(0xFF00CEC9),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        tertiary: accent,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FE),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF2D3436),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Color(0xFF2D3436)),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFFB2BEC3),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: secondary,
        tertiary: accent,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: const Color(0xFF25253E),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A2E),
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF636E72),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF25253E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3D3D5C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3D3D5C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient moodGradient(int level) {
    if (level <= 0) level = 1;
    if (level > 5) level = 5;
    return LinearGradient(
      colors: [
        moodColors[level - 1],
        moodColors[level - 1].withOpacity(0.7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

// ============================================================================
// MAIN
// ============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final db = DatabaseService();
  await db.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MoodFlowApp(databaseService: db));
}

// ============================================================================
// SPLASH SCREEN
// ============================================================================

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showSplash = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Show splash for 1.5 seconds then fade out
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _controller.forward().then((_) {
          if (mounted) setState(() => _showSplash = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showSplash)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🌊',
                      style: TextStyle(fontSize: 80),
                    ).animate().scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1.0, 1.0),
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),
                    const SizedBox(height: 20),
                    const Text(
                      'MoodFlow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                    const SizedBox(height: 8),
                    Text(
                      'ردیاب حال و عادت روزانه',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white.withOpacity(0.7)),
                      ),
                    ).animate().fadeIn(delay: 700.ms),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MoodFlowApp extends StatefulWidget {
  final DatabaseService databaseService;

  const MoodFlowApp({super.key, required this.databaseService});

  @override
  State<MoodFlowApp> createState() => _MoodFlowAppState();
}

class _MoodFlowAppState extends State<MoodFlowApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode =
        widget.databaseService.getSetting('darkMode', defaultValue: false)
            as bool;
  }

  void _toggleTheme(bool value) {
    setState(() => _isDarkMode = value);
    widget.databaseService.saveSetting('darkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return Provider<DatabaseService>.value(
      value: widget.databaseService,
      child: MaterialApp(
        title: 'MoodFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: SplashScreen(
          child: MainScreen(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleTheme;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;

  final List<Widget> _screens = const [
    HomeScreen(),
    HabitsScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'خانه'),
                _buildNavItem(1, Icons.fitness_center_rounded, 'عادت‌ها'),
                _buildNavItem(2, Icons.bar_chart_rounded, 'آمار'),
                _buildNavItem(3, Icons.settings_rounded, 'تنظیمات'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _animController.forward(from: 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primary
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ).animate(controller: _animController)
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: -0.5, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class MoodCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MoodCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF25253E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.moodColors[entry.moodLevel - 1].withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.moodGradient(entry.moodLevel),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    entry.moodEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.moodLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.moodColors[entry.moodLevel - 1],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.energyColors[entry.energyLevel - 1]
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⚡ ${entry.energyLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.energyColors[entry.energyLevel - 1],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm - d MMMM y', 'fa').format(entry.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (entry.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }
}

class HabitTile extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const HabitTile({
    super.key,
    required this.habit,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = habit.isCompletedToday();
    final color = Color(habit.colorValue);
    final streak = habit.calculateStreak();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF25253E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isCompleted
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? color.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(isCompleted ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  habit.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (streak > 0) ...[
                        Icon(Icons.local_fire_department,
                            size: 14, color: AppTheme.warning),
                        const SizedBox(width: 2),
                        Text(
                          '$streak روز',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${habit.getThisWeekCompletions()} این هفته',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted ? color : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isCompleted
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Icon(Icons.add, color: Colors.grey.shade500, size: 20),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scaleXY(
          begin: 0.95,
          end: 1,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }
}

class MoodLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MoodLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final mood = data[i]['mood'] as double;
      if (mood > 0) {
        spots.add(FlSpot(i.toDouble(), mood));
      }
    }

    if (spots.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('هنوز داده‌ای ثبت نشده',
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  final emojis = ['😢', '😔', '😐', '😊', '🤩'];
                  if (value >= 1 && value <= 5) {
                    return Text(emojis[value.toInt() - 1],
                        style: const TextStyle(fontSize: 14));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.length / 7).ceilToDouble().clamp(1, 100),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    final date = data[index]['date'] as DateTime;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 5.5,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppTheme.primary,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.3),
                    AppTheme.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoodBarChart extends StatelessWidget {
  final Map<int, int> distribution;

  const MoodBarChart({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    final maxVal = distribution.values.isEmpty
        ? 1
        : distribution.values.reduce((a, b) => a > b ? a : b);
    final emojis = ['😢', '😔', '😐', '😊', '🤩'];

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal.toDouble() + 1,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < 5) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(emojis[index],
                          style: const TextStyle(fontSize: 18)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(5, (index) {
            final count = distribution[index + 1] ?? 0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.moodColors[index],
                      AppTheme.moodColors[index].withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ============================================================================
// SCREENS
// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseService _db;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صبح بخیر';
    if (hour < 17) return 'ظهر بخیر';
    if (hour < 21) return 'عصر بخیر';
    return 'شب بخیر';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habits = _db.getAllHabits();
    final completedHabits = habits.where((h) => h.isCompletedToday()).length;
    final moodEntries = _db.getAllMoodEntries();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FE),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF25253E), const Color(0xFF1A1A2E)]
                        : [AppTheme.primary.withOpacity(0.1), AppTheme.secondary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ).animate().fadeIn(delay: 100.ms),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE، d MMMM', 'fa').format(DateTime.now()),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                                  ),
                                ).animate().fadeIn(delay: 200.ms),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: const Text('MoodFlow'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.format_quote, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'هر روز یک فرصت جدید است 🌅',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'حالت چطوره؟',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _navigateToAddMood(),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('ثبت'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  final moodLevel = index + 1;
                  final emojis = ['😢', '😔', '😐', '😊', '🤩'];
                  final labels = ['خیلی بد', 'بد', 'معمولی', 'خوب', 'عالی'];

                  return GestureDetector(
                    onTap: () => _quickAddMood(moodLevel),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.moodColors[index].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.moodColors[index].withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(emojis[index],
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.moodColors[index],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (500 + index * 100).ms).scaleXY(
                        begin: 0.8,
                        end: 1,
                        duration: 300.ms,
                      );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'عادت‌های امروز',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: habits.isEmpty ? 0 : completedHabits / habits.length,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey.shade200,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$completedHabits/${habits.length}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (habits.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'هنوز عادتی اضافه نکردی!',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return HabitTile(
                  habit: habits[index],
                  onToggle: () async {
                    await _db.toggleHabitCompletion(
                        habits[index].id, DateTime.now());
                    setState(() {});
                  },
                );
              },
              childCount: habits.isEmpty ? 1 : habits.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'یادداشت‌های اخیر',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (moodEntries.isNotEmpty)
                    Text(
                      '${moodEntries.length} یادداشت',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (moodEntries.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.mood, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'اولین حالت رو ثبت کن!',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (index >= moodEntries.length) return null;
                return MoodCard(
                  entry: moodEntries[index],
                  onDelete: () => _confirmDelete(moodEntries[index]),
                );
              },
              childCount: moodEntries.isEmpty ? 1 : moodEntries.length.clamp(0, 5),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddMood,
        icon: const Icon(Icons.edit_note),
        label: const Text('ثبت حال و هوا'),
      ).animate().fadeIn(delay: 800.ms).scaleXY(begin: 0, end: 1, duration: 400.ms),
    );
  }

  Future<void> _quickAddMood(int moodLevel) async {
    final entry = MoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      moodLevel: moodLevel,
      dateTime: DateTime.now(),
      energyLevel: 3,
    );
    await _db.addMoodEntry(entry);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text('${entry.moodEmoji} حالت ثبت شد: ${entry.moodLabel}'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppTheme.moodColors[moodLevel - 1],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToAddMood() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMoodScreen()),
    );
    if (result == true) setState(() {});
  }

  void _confirmDelete(MoodEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف یادداشت'),
        content: const Text('آیا مطمئنی می‌خوای این یادداشت رو حذف کنی؟'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              await _db.deleteMoodEntry(entry.id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('حذف', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class AddMoodScreen extends StatefulWidget {
  final MoodEntry? editEntry;

  const AddMoodScreen({super.key, this.editEntry});

  @override
  State<AddMoodScreen> createState() => _AddMoodScreenState();
}

class _AddMoodScreenState extends State<AddMoodScreen> {
  int _selectedMood = 3;
  int _selectedEnergy = 3;
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editEntry != null) {
      _selectedMood = widget.editEntry!.moodLevel;
      _selectedEnergy = widget.editEntry!.energyLevel;
      _noteController.text = widget.editEntry!.note;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editEntry != null ? 'ویرایش یادداشت' : 'ثبت حال و هوا'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'ذخیره',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'حال و هوای الان',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  final moodLevel = index + 1;
                  final isSelected = _selectedMood == moodLevel;
                  final emojis = ['😢', '😔', '😐', '😊', '🤩'];
                  final labels = ['خیلی بد', 'بد', 'معمولی', 'خوب', 'عالی'];

                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = moodLevel),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.moodColors[index].withOpacity(0.2)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.moodColors[index]
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(emojis[index],
                                style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? AppTheme.moodColors[index]
                                  : Colors.grey,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سطح انرژی ⚡',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      final energyLevel = index + 1;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedEnergy = energyLevel),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: energyLevel <= _selectedEnergy
                                  ? AppTheme.energyColors[_selectedEnergy - 1]
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'یادداشت 📝',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'چه اتفاقی افتاد؟ چه حسی داری؟',
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final db = context.read<DatabaseService>();

      if (widget.editEntry != null) {
        widget.editEntry!.moodLevel = _selectedMood;
        widget.editEntry!.energyLevel = _selectedEnergy;
        widget.editEntry!.note = _noteController.text;
        await db.updateMoodEntry(widget.editEntry!);
      } else {
        final entry = MoodEntry(
          id: const Uuid().v4(),
          moodLevel: _selectedMood,
          energyLevel: _selectedEnergy,
          note: _noteController.text,
          tags: [],
          dateTime: DateTime.now(),
        );
        await db.addMoodEntry(entry);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late DatabaseService _db;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
  }

  @override
  Widget build(BuildContext context) {
    final habits = _db.getAllHabits();
    final completedToday = habits.where((h) => h.isCompletedToday()).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عادت‌های من'),
      ),
      body: Column(
        children: [
          if (habits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.check_circle_outline,
                      value: '$completedToday',
                      label: 'انجام شده',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white30,
                    ),
                    _buildStatItem(
                      icon: Icons.pending_outlined,
                      value: '${habits.length - completedToday}',
                      label: 'باقیمانده',
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
          Expanded(
            child: habits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.self_improvement,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'هنوز عادتی اضافه نکردی!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showAddHabitDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('اولین عادت رو بساز'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: habits.length,
                    itemBuilder: (context, index) {
                      return Dismissible(
                        key: Key(habits[index].id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('حذف عادت'),
                              content: Text(
                                  'آیا مطمئنی می‌خوای "${habits[index].title}" رو حذف کنی؟'),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('لغو'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('حذف',
                                      style: TextStyle(color: AppTheme.danger)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await _db.deleteHabit(habits[index].id);
                          setState(() {});
                        },
                        child: HabitTile(
                          habit: habits[index],
                          onToggle: () async {
                            await _db.toggleHabitCompletion(
                                habits[index].id, DateTime.now());
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHabitDialog,
        icon: const Icon(Icons.add),
        label: const Text('عادت جدید'),
      ).animate().fadeIn(delay: 500.ms).scaleXY(begin: 0, end: 1),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _showAddHabitDialog({Habit? habit}) {
    final titleController = TextEditingController(text: habit?.title ?? '');
    String selectedIcon = habit?.icon ?? '💪';
    Color selectedColor = habit != null
        ? Color(habit.colorValue)
        : AppTheme.primary;

    final icons = ['💪', '📚', '🏃', '🧘', '💧', '🥗', '😴', '✍️', '🎵', '🧹'];
    final colors = [
      AppTheme.primary, AppTheme.accent, AppTheme.success,
      AppTheme.warning, AppTheme.info, AppTheme.danger,
      const Color(0xFF00CEC9), const Color(0xFF6C5CE7),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(habit != null ? 'ویرایش عادت' : 'عادت جدید'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'نام عادت...',
                      prefixIcon: Icon(Icons.edit),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('آیکون', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((icon) {
                      final isSelected = selectedIcon == icon;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedColor.withOpacity(0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: selectedColor, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(icon, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('رنگ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                if (habit != null) {
                  habit.title = titleController.text.trim();
                  habit.icon = selectedIcon;
                  habit.colorValue = selectedColor.value;
                  await _db.updateHabit(habit);
                } else {
                  final newHabit = Habit(
                    id: const Uuid().v4(),
                    title: titleController.text.trim(),
                    icon: selectedIcon,
                    colorValue: selectedColor.value,
                    createdAt: DateTime.now(),
                  );
                  await _db.addHabit(newHabit);
                }
                
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(habit != null ? 'ویرایش' : 'اضافه کن'),
            ),
          ],
        ),
      ),
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late DatabaseService _db;
  int _selectedPeriod = 7;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _db.getOverallStats();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('آمار و تحلیل'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildPeriodChip(7, '۷ روز'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(14, '۱۴ روز'),
                  const SizedBox(width: 8),
                  _buildPeriodChip(30, '۳۰ روز'),
                ],
              ),
            ).animate().fadeIn(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _buildOverviewCard(
                    icon: Icons.mood,
                    value: (stats['averageMood'] as double).toStringAsFixed(1),
                    label: 'میانگین حال',
                    color: AppTheme.primary,
                    subtitle: 'از ۵',
                  ),
                  _buildOverviewCard(
                    icon: Icons.flash_on,
                    value: (stats['averageEnergy'] as double).toStringAsFixed(1),
                    label: 'میانگین انرژی',
                    color: AppTheme.info,
                    subtitle: 'از ۵',
                  ),
                  _buildOverviewCard(
                    icon: Icons.note_alt,
                    value: '${stats['totalMoodEntries']}',
                    label: 'کل یادداشت‌ها',
                    color: AppTheme.accent,
                    subtitle: '',
                  ),
                  _buildOverviewCard(
                    icon: Icons.local_fire_department,
                    value: '${stats['longestStreak']}',
                    label: 'بهترین استریک',
                    color: AppTheme.warning,
                    subtitle: 'روز',
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25253E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'روند حال و هوا',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MoodLineChart(
                    data: _db.getDailyMoodData(_selectedPeriod),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25253E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'توزیع حالت‌ها',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MoodBarChart(
                    distribution: _db.getMoodDistribution(_selectedPeriod),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(int days, String label) {
    final isSelected = _selectedPeriod == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedPeriod = days),
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    String subtitle = '',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF25253E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late DatabaseService _db;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _isDarkMode = _db.getSetting('darkMode', defaultValue: false) as bool;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Text('🧘', style: TextStyle(fontSize: 30)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MoodFlow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ردیاب حال و عادت روزانه',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Text(
              'ظاهر برنامه',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF25253E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dark_mode_outlined,
                          color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حالت تاریک',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تغییر بین حالت روشن و تاریک',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isDarkMode,
                      onChanged: (value) async {
                        setState(() => _isDarkMode = value);
                        await _db.saveSetting('darkMode', value);
                      },
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),
        ],
      ),
    );
  }
}
