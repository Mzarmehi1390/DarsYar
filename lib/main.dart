import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'answer_scoring.dart';
import 'backup_codec.dart';
import 'exam_sheet.dart';
import 'exam_result.dart';
import 'study_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DarsYarApp());
}

const accent = Color(0xFF16A36A);
const ink = Color(0xFF14231D);
const muted = Color(0xFF8A9B92);
const canvas = Color(0xFFF0F5F2);

class StudyTask {
  StudyTask(this.id, this.title, this.subject, {this.done = false});
  final String id;
  final String title;
  final String subject;
  bool done;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'subject': subject, 'done': done};
  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
    json['id'] as String, json['title'] as String, json['subject'] as String? ?? 'عمومی',
    done: json['done'] as bool? ?? false,
  );
}

class DarsYarApp extends StatefulWidget {
  const DarsYarApp({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<DarsYarApp> createState() => _DarsYarAppState();
}

class _DarsYarAppState extends State<DarsYarApp> {
  ThemeMode mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('darsyar.themeMode');
      final restored = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (restored != null && mounted) {
        setState(() => mode = restored);
      }
    } catch (_) {
      // Theme preferences are optional; keep the system default if unavailable.
    }
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() => mode = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = switch (value) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString('darsyar.themeMode', stored);
    } catch (_) {
      // The selected theme remains active for this run even if persistence fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(seedColor: accent);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'درس‌یار',
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: const Color(0xFFEAF2EE),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: ink),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xBFFFFFFF), width: 1.1),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08130F),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: const Color(0xE61A2B23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: const Color(0xFFB5F5D2).withValues(alpha: 0.16), width: 1.1),
          ),
        ),
      ),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? SizedBox()),
      home: DarsYarHome(initialTab: widget.initialTab, mode: mode, onModeChanged: _setThemeMode),
    );
  }
}

class DarsYarHome extends StatefulWidget {
  const DarsYarHome({required this.mode, required this.onModeChanged, this.initialTab = 0, super.key});
  final int initialTab;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  @override
  State<DarsYarHome> createState() => _DarsYarHomeState();
}

class _DarsYarHomeState extends State<DarsYarHome> {
  late int tab;
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 3);
    load();
  }
  bool loading = true;
  // Serialize writes so a slower older save cannot overwrite newer state.
  Future<bool> _saveQueue = Future<bool>.value(true);
  final tasks = <StudyTask>[];
  final results = <ExamResult>[];
  final studySessions = <StudySession>[];
  int selectedStudyDay = DateTime.now().weekday % 7;
  String? _lastSnackMessage;
  DateTime? _lastSnackAt;
  final Map<int, GlobalKey> _plannerDayKeys = {for (final day in weekDayOrder) day: GlobalKey()};
  final Map<int, GlobalKey> _plannerWeekKeys = {for (final day in weekDayOrder) day: GlobalKey()};
  static const weekDays = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
  static const weekDayOrder = [6, 0, 1, 2, 3, 4, 5];
  final exams = <ExamSheet>[
    ExamSheet(id: 'default', name: 'آزمون اول'),
  ];
  String activeExamId = 'default';

  Timer? _examTimer;
  int _remainingExamSeconds = 0;
  int examSection = 0;
  bool isTakingExam = false;
  int currentQuestionNumber = 1;
  bool _examTimerRunning = false;
  bool _savingExamResult = false;
  String? _timerExamId;
  DateTime? _examDeadline;

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  ExamSheet get activeExam => exams.firstWhere((exam) => exam.id == activeExamId, orElse: () => exams.first);
  int get count => activeExam.questionCount;
  set count(int value) => activeExam.questionCount = value;
  Map<int, int> get answers => activeExam.answers;
  Map<int, int> get answerKey => activeExam.answerKey;
  Set<int> get marked => activeExam.marked;

  Future<void> load() async {
    late final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      if (mounted) setState(() => loading = false);
      return;
    }

    // Read each storage key independently: one damaged section must not hide
    // otherwise valid tasks, study sessions, exam sheets, or results.
    final rawTasks = _readStoredList(prefs.getString('darsyar.tasks'));
    if (rawTasks != null) {
      for (final item in rawTasks) {
        try {
          if (item is Map) {
            tasks.add(StudyTask.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip only the invalid task entry.
        }
      }
    }

    final rawSessions = _readStoredList(prefs.getString('darsyar.studySessions'));
    if (rawSessions != null) {
      for (final item in rawSessions) {
        try {
          if (item is Map) {
            studySessions.add(StudySession.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip only the invalid study session.
        }
      }
    }

    final rawResults = _readStoredList(prefs.getString('darsyar.results'));
    if (rawResults != null) {
      for (final item in rawResults) {
        try {
          if (item is Map) {
            results.add(ExamResult.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip only the invalid exam result.
        }
      }
    }

    final storedExamsJson = prefs.getString('darsyar.exams');
    final rawExams = _readStoredList(storedExamsJson);
    exams.clear();
    if (rawExams != null) {
      for (final item in rawExams) {
        try {
          if (item is Map) {
            exams.add(ExamSheet.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {
          // Skip only the invalid exam sheet.
        }
      }
    } else if (storedExamsJson == null) {
      // Migrate legacy single-sheet data only when the current-format key
      // does not exist. Corrupt current data must never resurrect stale
      // legacy answers over the user's newer exam state.
      final legacyAnswers = _readIntMap(prefs.getString('darsyar.answers'));
      final legacyKey = _readIntMap(prefs.getString('darsyar.answerKey'));
      final legacyMarked = <int>{};
      final legacyMarkedRaw = prefs.getString('darsyar.marked');
      final decodedMarked = _readStoredList(legacyMarkedRaw);
      if (decodedMarked != null) {
        for (final item in decodedMarked) {
          if (item is num) legacyMarked.add(item.toInt());
        }
      }
      final legacyCount = (prefs.getInt('darsyar.count') ?? 20).clamp(1, 200).toInt();
      exams.add(ExamSheet(
        id: 'default',
        name: 'آزمون اول',
        questionCount: legacyCount,
        answers: legacyAnswers,
        answerKey: legacyKey,
        marked: legacyMarked,
      ));
    }

    if (exams.isEmpty) {
      exams.add(ExamSheet(id: 'default', name: 'آزمون اول'));
    }
    activeExamId = prefs.getString('darsyar.activeExamId') ?? exams.first.id;
    if (!exams.any((exam) => exam.id == activeExamId)) {
      activeExamId = exams.first.id;
    }
    if (mounted) {
      setState(() => loading = false);
      if (tab == 1) _revealSelectedDay();
    }
  }

  List<dynamic>? _readStoredList(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> save() {
    final pending = _saveQueue.then((_) => _saveCurrentState());
    _saveQueue = pending;
    return pending;
  }

  Future<bool> _saveCurrentState() async {
    SharedPreferences? prefs;
    Map<String, String?>? previousValues;
    const storageKeys = <String>[
      'darsyar.tasks',
      'darsyar.exams',
      'darsyar.activeExamId',
      'darsyar.results',
      'darsyar.studySessions',
    ];

    Future<void> rollbackStoredValues(
      SharedPreferences store,
      Map<String, String?> previous,
    ) async {
      for (final entry in previous.entries) {
        try {
          if (entry.value == null) {
            await store.remove(entry.key);
          } else {
            await store.setString(entry.key, entry.value!);
          }
        } catch (_) {
          // Best-effort rollback: never hide the original save failure.
        }
      }
    }

    try {
      // Serialize everything before touching storage, so a bad model cannot
      // leave only some sections updated.
      final values = <String, String>{
        'darsyar.tasks': jsonEncode(tasks.map((e) => e.toJson()).toList()),
        'darsyar.exams': jsonEncode(exams.map((exam) => exam.toJson()).toList()),
        'darsyar.activeExamId': activeExamId,
        'darsyar.results': jsonEncode(results.map((result) => result.toJson()).toList()),
        'darsyar.studySessions': jsonEncode(studySessions.map((session) => session.toJson()).toList()),
      };

      final store = await SharedPreferences.getInstance();
      prefs = store;
      previousValues = {
        for (final key in storageKeys) key: store.getString(key),
      };

      var writesSucceeded = true;
      for (final entry in values.entries) {
        final saved = await store.setString(entry.key, entry.value);
        if (!saved) {
          writesSucceeded = false;
          break;
        }
      }
      if (writesSucceeded) return true;

      await rollbackStoredValues(prefs, previousValues);
      if (mounted) {
        _showSnackBar(
          SnackBar(content: Text('ذخیره‌سازی کامل نشد؛ تلاش شد اطلاعات قبلی حفظ شوند.')),
        );
      }
      return false;
    } catch (_) {
      if (prefs != null && previousValues != null) {
        await rollbackStoredValues(prefs, previousValues);
      }
      if (mounted) {
        _showSnackBar(
          SnackBar(content: Text('ذخیره‌سازی با خطا مواجه شد؛ تلاش شد اطلاعات قبلی حفظ شوند.')),
        );
      }
      return false;
    }
  }

  int get completed => tasks.where((e) => e.done).length;

  @override
  Widget build(BuildContext context) {
    final pages = [dashboard(), planner(), answerSheet(), settings()];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? const [Color(0xFF0B1D15), Color(0xFF07100D), Color(0xFF101A24)]
                    : const [Color(0xFFF4FAF7), Color(0xFFE8F1EC), Color(0xFFE8EDF5)],
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -125,
            child: IgnorePointer(
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.22 : 0.16),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -175,
            left: -135,
            child: IgnorePointer(
              child: Container(
                width: 370,
                height: 370,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark ? const Color(0xFF4B83A5) : const Color(0xFF8BB9D5))
                          .withValues(alpha: isDark ? 0.16 : 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    reverseDuration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.018),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(tab),
                      child: pages[tab],
                    ),
                  ),
          ),
        ],
      ),
      // Edge-light floating glass dock: no opaque rectangular tray or bottom stroke.
      bottomNavigationBar: loading
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 9),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
                      blurRadius: 34,
                      spreadRadius: -7,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: (isDark ? const Color(0xFF75D9A5) : Colors.white)
                          .withValues(alpha: isDark ? 0.12 : 0.86),
                      blurRadius: 20,
                      spreadRadius: -9,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        const Color(0xFF315B47).withValues(alpha: 0.54),
                                        const Color(0xFF12251B).withValues(alpha: 0.46),
                                        const Color(0xFF0C1712).withValues(alpha: 0.40),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.58),
                                        const Color(0xFFE8F8EF).withValues(alpha: 0.38),
                                        const Color(0xFFD9E9E1).withValues(alpha: 0.30),
                                      ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 30,
                          right: 30,
                          child: Container(
                            height: 1.3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: isDark ? 0.58 : 0.96),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        NavigationBar(
                          height: 70,
                          backgroundColor: Colors.transparent,
                          indicatorColor: Colors.transparent,
                          selectedIndex: tab,
                          onDestinationSelected: (value) {
                            if (value == 1) {
                              _openPlanner();
                            } else {
                              setState(() => tab = value);
                            }
                          },
                          destinations: [
                            NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: _selectedNavIcon(Icons.grid_view_rounded), label: 'خانه'),
                            NavigationDestination(key: ValueKey('nav-planner'), icon: Icon(Icons.calendar_month_rounded), selectedIcon: _selectedNavIcon(Icons.calendar_month_rounded), label: 'برنامه‌ریزی'),
                            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: _selectedNavIcon(Icons.fact_check_rounded), label: 'پاسخ‌برگ'),
                            NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: _selectedNavIcon(Icons.tune_rounded), label: 'تنظیمات'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: null,
    );
  }

  Widget _selectedNavIcon(IconData icon) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.86, end: 1),
    duration: const Duration(milliseconds: 240),
    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.8),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 10)],
      ),
      child: Icon(icon, color: accent, size: 21),
    ),
  );
  void _openPlanner() {
    setState(() => tab = 1);
    _revealSelectedDay();
  }

  void _revealSelectedDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tab != 1) return;
      for (final target in [
        _plannerDayKeys[selectedStudyDay]?.currentContext,
        _plannerWeekKeys[selectedStudyDay]?.currentContext,
      ]) {
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 350),
            alignment: 0.5,
          );
        }
      }
    });
  }
  void _showSnackBar(SnackBar snackBar) {
    final content = snackBar.content;
    final message = content is Text ? (content.data ?? content.toString()) : content.toString();
    final now = DateTime.now();
    if (_lastSnackMessage == message && _lastSnackAt != null &&
        now.difference(_lastSnackAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSnackMessage = message;
    _lastSnackAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: snackBar.content,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget dashboard() => ListView(padding: const EdgeInsets.all(20), children: [
    Row(children: [
      CircleAvatar(backgroundColor: Color(0xFFDDF3E6), child: Icon(Icons.auto_stories_rounded, color: accent)),
      SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('درس‌یار', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        Text('برنامه‌ریزی هوشمند برای یادگیری بهتر', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ]),
    SizedBox(height: 24),
    ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A9B6B), Color(0xFF126448), Color(0xFF0B3D30)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1.2),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.24), blurRadius: 28, offset: const Offset(0, 14)),
            BoxShadow(color: Colors.white.withValues(alpha: 0.18), blurRadius: 1, offset: const Offset(0, 1)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -58,
              left: -28,
              child: IgnorePointer(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -74,
              right: -36,
              child: IgnorePointer(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF72E8BB).withValues(alpha: 0.24), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('هر روز، یک قدم به هدفت نزدیک‌تر',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: Icon(Icons.auto_awesome_rounded, color: Colors.white.withValues(alpha: 0.95)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('برنامه‌ات را ساده نگه دار و با استمرار پیش برو.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82))),
                  SizedBox(height: 22),
                  Text(tasks.isEmpty ? 'هنوز وظیفه‌ای ثبت نشده است' : 'وظایف انجام‌شده: $completed از ${tasks.length}',
                    style: TextStyle(color: Colors.white)),
                  SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: tasks.isEmpty ? 0 : completed / tasks.length),
                      duration: const Duration(milliseconds: 850),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) => LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.24),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    SizedBox(height: 24),
    Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
    SizedBox(height: 12),
    Row(children: [
      Expanded(child: quickAction(Icons.calendar_month_rounded, 'برنامه‌ریزی درسی', 'مدیریت وظایف', _openPlanner, const Color(0xFFDDF5E9))),
      SizedBox(width: 12),
      Expanded(child: quickAction(Icons.fact_check_rounded, 'پاسخ‌برگ آزمون', 'ثبت پاسخ‌ها', () => setState(() => tab = 2), const Color(0xFFDDF5E9))),
    ]),
    SizedBox(height: 14),
    Row(children: [Expanded(child: Text('وظایف پیش رو', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
      TextButton(onPressed: _openPlanner, child: Text('مشاهده همه'))]),
    if (tasks.where((e) => !e.done).isEmpty)
      emptyState(Icons.event_available_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'از بخش برنامه‌ریزی، اولین وظیفه‌ات را اضافه کن.')
    else ...tasks.where((e) => !e.done).take(3).map(taskTile),
  ]);

  Widget quickAction(IconData icon, String title, String subtitle, VoidCallback action, Color tint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: isDark ? 0.10 : 0.09), blurRadius: 20, offset: const Offset(0, 9)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Theme.of(context).cardColor.withValues(alpha: isDark ? 0.64 : 0.70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(23),
              side: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.82), width: 1.1),
            ),
            child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(23),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF285744), const Color(0xFF142F25)]
                            : [const Color(0xFFE8FFF4), const Color(0xFFBCEBD6)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.70), width: 1),
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 15, offset: const Offset(0, 6)),
                        BoxShadow(color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.75), blurRadius: 1, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Icon(icon, color: isDark ? const Color(0xFF9BF2CC) : const Color(0xFF087B55)),
                  ),
                  SizedBox(height: 14),
                  Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget planner() {
    final daySessions = studySessions.where((session) => session.weekday == selectedStudyDay).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final completedSessions = studySessions.where((session) => session.completed).length;
    final totalMinutes = daySessions.fold<int>(0, (sum, session) => sum + session.durationMinutes);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 90), children: [
      Text('برنامه‌ریزی درسی', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
      SizedBox(height: 6),
      Text('برای هر روز، جلسه مطالعه با زمان و مدت مشخص بچین.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      SizedBox(height: 18),
      Row(children: [
        Expanded(child: summary('جلسه‌ها', studySessions.length, Icons.calendar_month_rounded)),
        SizedBox(width: 8),
        Expanded(child: summary('انجام‌شده', completedSessions, Icons.check_circle_outline)),
        SizedBox(width: 8),
        Expanded(child: summary('دقیقه امروز', totalMinutes, Icons.timer_outlined)),
      ]),
      SizedBox(height: 20),
      Text('انتخاب روز', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 10),
      SizedBox(height: 44, child: ListView(
        scrollDirection: Axis.horizontal,
        children: weekDayOrder.map((day) => Padding(
          key: _plannerDayKeys[day],
          padding: const EdgeInsets.only(left: 8),
          child: ChoiceChip(
            showCheckmark: false,
            label: Text(weekDays[day]),
            selected: selectedStudyDay == day,
            onSelected: (_) { setState(() => selectedStudyDay = day); _revealSelectedDay(); },
          ),
        )).toList(),
      )),
      SizedBox(height: 20),
      Text('نمای کلی هفته', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 10),
      SizedBox(height: 124, child: ListView(
        scrollDirection: Axis.horizontal,
        children: weekDayOrder.map((day) => Padding(
          padding: const EdgeInsets.only(left: 10),
          child: SizedBox(key: _plannerWeekKeys[day], width: 190, child: weekOverviewCard(day)),
        )).toList(),
      )),
      SizedBox(height: 16),
      weeklyReportCard(),
      SizedBox(height: 20),
      Row(children: [
        Expanded(child: Text(weekDays[selectedStudyDay], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        OutlinedButton.icon(onPressed: addStudySession, icon: Icon(Icons.add_rounded), label: Text('جلسه جدید')),
        SizedBox(width: 6),
        PopupMenuButton<int>(
          tooltip: 'کپی برنامه این روز',
          icon: Icon(Icons.copy_all_rounded),
          onSelected: copySelectedDayTo,
          itemBuilder: (context) => List.generate(7, (day) => PopupMenuItem<int>(
            value: day,
            enabled: day != selectedStudyDay,
            child: Text('کپی برنامه به ${weekDays[day]}'),
          )),
        ),
      ]),
      if (daySessions.isEmpty)
        emptyState(Icons.event_available_rounded, 'برای این روز جلسه‌ای نداری', 'با دکمه «جلسه جدید» یک زمان مطالعه اضافه کن.')
      else ...daySessions.map(studySessionTile),
      SizedBox(height: 22),
      Row(children: [Expanded(child: Text('فهرست وظایف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))), FilledButton.tonalIcon(onPressed: addTask, icon: Icon(Icons.add_rounded), label: Text('ثبت وظیفه'))]),
      SizedBox(height: 10),
      if (tasks.isEmpty)
        emptyState(Icons.edit_calendar_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'برای یادآوری تکالیف، دکمه «افزودن وظیفه» را بزن.')
      else ...tasks.map(taskTile),
    ]);
  }

  Widget weeklyReportCard() {
    final plannedMinutes = studySessions.fold<int>(
      0, (sum, session) => sum + session.durationMinutes,
    );
    final completedMinutes = studySessions
        .where((session) => session.completed)
        .fold<int>(0, (sum, session) => sum + session.durationMinutes);
    final completion = plannedMinutes == 0 ? 0.0 : completedMinutes / plannedMinutes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [const Color(0xFF294238).withValues(alpha: 0.70), const Color(0xFF14251E).withValues(alpha: 0.82)]
                  : [Colors.white.withValues(alpha: 0.82), const Color(0xFFE9F5EE).withValues(alpha: 0.72)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.76), width: 1.1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, color: accent),
          SizedBox(width: 8),
          Text('گزارش هفتگی مطالعه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        SizedBox(height: 14),
        Row(children: [
          Expanded(child: _weeklyMetric('برنامه‌ریزی‌شده', plannedMinutes, 'دقیقه')),
          Expanded(child: _weeklyMetric('مطالعه تکمیل‌شده', completedMinutes, 'دقیقه')),
          Expanded(child: _weeklyMetric('پیشرفت', (completion * 100).round(), '٪')),
        ]),
        SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: completion,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(height: 6),
        Text(
          studySessions.isEmpty
              ? 'با افزودن جلسه‌ها، گزارش اینجا نمایش داده می‌شود.'
              : '${studySessions.where((session) => session.completed).length} از ${studySessions.length} جلسه تکمیل شده است.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
          ]),
        ),
      ),
    );
  }

  Widget _glassSurface({
    required Widget child,
    double radius = 20,
    Color? tint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? (isDark ? const Color(0xFF18372B) : const Color(0xFFF8FFFB));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 13),
          ),
          BoxShadow(
            color: (isDark ? const Color(0xFF75D9A5) : Colors.white)
                .withValues(alpha: isDark ? 0.09 : 0.78),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.72),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            base.withValues(alpha: isDark ? 0.48 : 0.42),
                            (isDark ? const Color(0xFF0B1B14) : const Color(0xFFE5F4EC))
                                .withValues(alpha: isDark ? 0.62 : 0.34),
                            (isDark ? const Color(0xFF6ABF91) : const Color(0xFFFFFFFF))
                                .withValues(alpha: isDark ? 0.08 : 0.20),
                          ],
                          stops: const [0, 0.58, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: radius * 0.8,
                  right: radius * 0.8,
                  child: IgnorePointer(
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: isDark ? 0.62 : 0.96),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weeklyMetric(String label, int value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$value', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: accent)),
      Text(unit, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );

  Future<void> copySelectedDayTo(int targetDay) async {
    if (targetDay == selectedStudyDay) return;
    final sourceSessions = studySessions
        .where((session) => session.weekday == selectedStudyDay)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    if (sourceSessions.isEmpty) {
      _showSnackBar(
        SnackBar(content: Text('برای کپی‌کردن، ابتدا در این روز جلسه‌ای بساز.')),
      );
      return;
    }
    final copies = sourceSessions.map((session) => StudySession(
      id: '${DateTime.now().microsecondsSinceEpoch}-${session.id}-$targetDay',
      title: session.title,
      subject: session.subject,
      weekday: targetDay,
      startMinutes: session.startMinutes,
      durationMinutes: session.durationMinutes,
    )).toList();
    final conflicts = copies.any((candidate) => _hasOverlappingSession(candidate));
    if (conflicts) {
      _showSnackBar(
        SnackBar(content: Text('برنامه ${weekDays[targetDay]} با ساعت یکی از جلسه‌های فعلی تداخل دارد؛ چیزی کپی نشد.')),
      );
      return;
    }
    setState(() {
      studySessions.addAll(copies);
      selectedStudyDay = targetDay;
    });
    await save();
    if (!mounted) return;
    _revealSelectedDay();
    _showSnackBar(
      SnackBar(content: Text('${copies.length} جلسه به ${weekDays[targetDay]} کپی شد.')),
    );
  }

  Widget weekOverviewCard(int day) {
    final sessions = studySessions.where((session) => session.weekday == day).toList();
    final minutes = sessions.fold<int>(0, (sum, session) => sum + session.durationMinutes);
    final done = sessions.where((session) => session.completed).length;
    final selected = day == selectedStudyDay;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 54) / 2,
      child: _glassSurface(
        radius: 18,
        tint: selected ? accent.withValues(alpha: 0.12) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () { setState(() => selectedStudyDay = day); _revealSelectedDay(); },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(weekDays[day], style: TextStyle(
                  fontWeight: FontWeight.w800, color: selected ? accent : null))),
                if (selected) Icon(Icons.check_circle_rounded, size: 16, color: accent),
              ]),
              SizedBox(height: 8),
              Text('${sessions.length} جلسه • $minutes دقیقه', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: sessions.isEmpty ? 0 : done / sessions.length),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => LinearProgressIndicator(
                    minHeight: 5,
                    value: progress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(sessions.isEmpty ? 'بدون برنامه' : '$done از ${sessions.length} انجام‌شده',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget studySessionTile(StudySession session) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _glassSurface(
      radius: 19,
      tint: session.completed ? accent.withValues(alpha: 0.07) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
      Checkbox(value: session.completed, activeColor: accent, onChanged: (value) async {
        final index = studySessions.indexWhere((item) => item.id == session.id);
        if (index < 0) return;
        setState(() => studySessions[index] = session.copyWith(completed: value ?? false));
        await save();
      }),
      Container(width: 4, height: 42, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(session.title, style: TextStyle(fontWeight: FontWeight.w800,
          decoration: session.completed ? TextDecoration.lineThrough : null)),
        SizedBox(height: 4),
        Text('${session.subject} • ${_formatStudyTime(session.startMinutes)} • ${session.durationMinutes} دقیقه',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      IconButton(tooltip: 'ویرایش جلسه', onPressed: () => editStudySession(session),
        icon: Icon(Icons.edit_outlined, color: accent)),
      IconButton(tooltip: 'حذف جلسه', onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
            title: Text('حذف جلسه مطالعه'),
            content: Text('جلسه «${session.title}» حذف شود؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('حذف'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        setState(() => studySessions.removeWhere((item) => item.id == session.id));
        await save();
      }, icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    ),
  );

  String _formatStudyTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  Widget summary(String label, int? value, IconData icon) => _glassSurface(
    radius: 19,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: accent),
        SizedBox(height: 8),
        Text(value?.toString() ?? '—', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Widget taskTile(StudyTask task) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _glassSurface(
      radius: 19,
      tint: task.done ? accent.withValues(alpha: 0.07) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
      Checkbox(value: task.done, activeColor: accent, onChanged: (value) async { setState(() => task.done = value ?? false); await save(); }),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: task.done ? TextDecoration.lineThrough : null)),
        SizedBox(height: 4), Text(task.subject, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      IconButton(tooltip: 'ویرایش وظیفه', onPressed: () => addTask(task),
        icon: Icon(Icons.edit_outlined, color: accent)),
      IconButton(tooltip: 'حذف', onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
            title: Text('حذف وظیفه'),
            content: Text('وظیفه «${task.title}» حذف شود؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('حذف'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        setState(() => tasks.removeWhere((e) => e.id == task.id));
        await save();
      },
        icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    ),
  );

  Widget answerSheet() {
    if (isTakingExam) return _takingExamView();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('پاسخ‌برگ آزمون', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('ساخت آزمون جدید')),
              ButtonSegment(value: 1, label: Text('آزمون‌های من')),
            ],
            selected: {examSection},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => examSection = value.first),
          ),
        ]),
      ),
      Expanded(child: examSection == 0
        ? _ExamSetupPanel(onCreate: _createExamFromSetup)
        : _myExamsView()),
    ]);
  }

  Widget _myExamsView() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: [
      Text('پاسخ‌برگ‌های ذخیره‌شده', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      SizedBox(height: 10),
      if (exams.isEmpty)
        emptyState(Icons.assignment_outlined, 'هنوز آزمونی نساخته‌ای', 'از بخش ساخت آزمون جدید، اولین پاسخ‌برگت را ایجاد کن.')
      else
        for (final exam in exams.reversed)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            child: _glassSurface(
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text(exam.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  PopupMenuButton<String>(
                    tooltip: 'مدیریت آزمون',
                    onSelected: (action) {
                      setState(() => activeExamId = exam.id);
                      if (action == 'rename') renameExam();
                      if (action == 'delete') deleteExam();
                      if (action == 'key') editAnswerKey();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                      PopupMenuItem(value: 'key', child: Text('ویرایش کلید پاسخ')),
                      PopupMenuItem(value: 'delete', child: Text('حذف آزمون')),
                    ],
                  ),
                ]),
                SizedBox(height: 4),
                Text('${exam.questionCount} سؤال  •  ${_formatDuration(exam.durationSeconds)}  •  ${exam.answers.length} پاسخ',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: exam.isCompleted
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, size: 17, color: accent),
                      SizedBox(width: 6),
                      Text('آزمون پایان یافته', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ])
                  : FilledButton.tonalIcon(
                      onPressed: () => _beginExam(exam),
                      icon: Icon(Icons.play_arrow_rounded),
                      label: Text(exam.answers.isEmpty ? 'شروع آزمون' : 'ادامه آزمون'),
                    )),
                ]),
              ),
            ),
          ),
      SizedBox(height: 14),
      Text('نتایج آزمون‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      SizedBox(height: 8),
      resultsHistory(),
    ],
  );

  bool _showQuestionNavigator = false;
  Widget _takingExamView() {
    final ExamSheet exam = activeExam;
    final int q = currentQuestionNumber.clamp(1, exam.questionCount).toInt();
    final remaining = _timerExamId == activeExamId ? _remainingExamSeconds : exam.durationSeconds;
    final answered = exam.answers.length;
    return Column(children: [
      Material(color: Theme.of(context).colorScheme.surfaceContainerHigh, elevation: 3, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Row(children: [IconButton(onPressed: () => setState(() => isTakingExam = false), icon: Icon(Icons.arrow_forward)), Expanded(child: Text(exam.name, style: TextStyle(fontWeight: FontWeight.w800))), Text(_formatDuration(remaining), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accent)), IconButton(tooltip: 'فهرست سؤال‌ها', onPressed: () => setState(() => _showQuestionNavigator = !_showQuestionNavigator), icon: Icon(Icons.format_list_numbered_rounded)), IconButton(onPressed: _toggleExamTimer, icon: Icon(_examTimerRunning ? Icons.pause : Icons.play_arrow))]),
        LinearProgressIndicator(value: exam.questionCount == 0 ? 0 : answered / exam.questionCount, minHeight: 7),
        SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('پیشرفت پاسخ‌ها: $answered از ${exam.questionCount}'), Text('سؤال $q از ${exam.questionCount}')]),
      ]))),
      Expanded(child: Row(children: [
        if (_showQuestionNavigator) Container(width: (MediaQuery.of(context).size.width * 0.34).clamp(112.0, 190.0).toDouble(), color: Theme.of(context).colorScheme.surfaceContainer, child: ListView.builder(padding: const EdgeInsets.all(8), itemCount: exam.questionCount, itemBuilder: (context, index) {
          final number = index + 1; final current = number == q; final markedQuestion = exam.marked.contains(number); final hasAnswer = exam.answers.containsKey(number);
          return Padding(padding: const EdgeInsets.only(bottom: 6), child: Material(color: markedQuestion ? const Color(0xFFB8EBD2) : current ? accent.withValues(alpha: 0.18) : hasAnswer ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => setState(() => currentQuestionNumber = number), child: Padding(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8), child: Row(children: [Expanded(child: Text('سؤال $number', style: TextStyle(fontSize: 12, fontWeight: current || markedQuestion ? FontWeight.w800 : FontWeight.w500, color: markedQuestion ? const Color(0xFF155C3D) : null))), if (markedQuestion) Icon(Icons.flag_rounded, size: 15, color: const Color(0xFF155C3D)) else if (hasAnswer) Icon(Icons.check_circle, size: 14, color: const Color(0xFF159A68))])))));
        })),
        Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
          _glassSurface(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Text('سؤال $q', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), SizedBox(height: 16),
            for (var option = 0; option < 4; option++) Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity, child: FilledButton.tonal(style: FilledButton.styleFrom(backgroundColor: exam.answers[q] == option ? const Color(0xFFB8EBD2) : Theme.of(context).colorScheme.secondaryContainer, foregroundColor: exam.answers[q] == option ? const Color(0xFF155C3D) : null), onPressed: () => _answerQuestion(option), child: Text('گزینه ${option + 1}${exam.answers[q] == option ? ' ✓' : ''}')))),
            TextButton.icon(onPressed: () => _toggleQuestionMarked(q), icon: Icon(Icons.flag_outlined), label: Text(exam.marked.contains(q) ? 'حذف علامت مرور' : 'علامت برای مرور')),
          ]))),
          Row(children: [Expanded(child: OutlinedButton(onPressed: q > 1 ? () => setState(() => currentQuestionNumber--) : null, child: Text('قبلی'))), SizedBox(width: 8), Expanded(child: FilledButton(onPressed: q < exam.questionCount ? () => setState(() => currentQuestionNumber++) : _finishExam, child: Text(q == exam.questionCount ? 'پایان آزمون' : 'بعدی')))]),
          TextButton(onPressed: _finishExam, child: Text('ثبت پایان آزمون')),
        ])),
      ])),
    ]);
  }

  Future<void> _answerQuestion(int option) async {
    setState(() {
      activeExam.answers[currentQuestionNumber] = option;
      activeExam.marked.remove(currentQuestionNumber);
      if (currentQuestionNumber < activeExam.questionCount) currentQuestionNumber++;
    });
    await save();
  }

  Future<void> _toggleQuestionMarked(int question) async {
    setState(() {
      if (!activeExam.marked.add(question)) activeExam.marked.remove(question);
    });
    await save();
  }

  void _beginExam(ExamSheet exam) {
    if (_timerExamId != exam.id) {
      _examTimer?.cancel();
      _examTimerRunning = false;
      _examDeadline = null;
      _remainingExamSeconds = exam.durationSeconds;
      _timerExamId = exam.id;
    } else if (_remainingExamSeconds == 0) {
      _remainingExamSeconds = exam.durationSeconds;
    }
    setState(() {
      activeExamId = exam.id;
      isTakingExam = true;
      currentQuestionNumber = List.generate(exam.questionCount, (i) => i + 1)
        .firstWhere((q) => !exam.answers.containsKey(q), orElse: () => 1);
    });
    if (!_examTimerRunning) _toggleExamTimer();
    save();
  }

  Future<void> _finishExam({bool automatic = false}) async {
    if (!isTakingExam) return;
    if (!automatic) {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('پایان آزمون؟'),
        content: Text('پاسخ‌ها ذخیره و نتیجه ثبت می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ادامه')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('پایان')),
        ],
      ));
      if (ok != true || !mounted || !isTakingExam) return;
    }
    _examTimer?.cancel();
    setState(() {
      activeExam.isCompleted = true;
      isTakingExam = false;
      _examTimerRunning = false;
      _examDeadline = null;
      examSection = 1;
    });
    await saveExamResult();
  }

  Future<void> saveExamResult() async {
    if (_savingExamResult) return;
    final exam = activeExam;
    final score = calculateAnswerScore(
      answers: exam.answers,
      answerKey: exam.answerKey,
      questionCount: exam.questionCount,
      negativeMarking: exam.negativeMarking,
    );
    final result = ExamResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      examId: exam.id,
      examName: exam.name,
      completedAt: DateTime.now().toUtc().toIso8601String(),
      questionCount: exam.questionCount,
      correct: score.correct,
      wrong: score.wrong,
      unanswered: score.unanswered,
      keyedQuestions: score.keyedQuestions,
      percentage: score.percentage,
      negativeMarking: exam.negativeMarking,
      answers: Map<int, int>.from(exam.answers),
      answerKey: Map<int, int>.from(exam.answerKey),
    );
    setState(() {
      _savingExamResult = true;
      results.add(result);
    });
    final saved = await save();
    if (!mounted) return;
    setState(() => _savingExamResult = false);
    if (saved) {
      _showSnackBar(SnackBar(
        content: Text(score.percentage == null
          ? 'پاسخ‌ها ذخیره شدند؛ برای محاسبه درصد بعداً کلید را وارد کن.'
          : 'نتیجه آزمون در تاریخچه ذخیره شد.'),
      ));
    }
  }

  Widget resultsHistory() {
    final sorted = results.toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final chartResults = sorted.where((result) => result.percentage != null).take(7).toList().reversed.toList();
    final scoredResults = results.where((result) => result.percentage != null).toList();
    final average = scoredResults.isEmpty ? 0.0 :
        scoredResults.map((result) => result.percentage!).reduce((a, b) => a + b) / scoredResults.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تاریخچه و پیشرفت', style: TextStyle(
          fontSize: 25, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,
        )),
        SizedBox(height: 6),
        Text('نتایج ذخیره‌شده آزمون‌ها و روند درصدها را دنبال کن.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: 18),
        Row(children: [
          Expanded(child: summary('آزمون‌ها', results.length, Icons.assignment_turned_in_outlined)),
          SizedBox(width: 8),
          Expanded(child: summary('میانگین درصد', scoredResults.isEmpty ? null : average.round(), Icons.insights_rounded)),
        ]),
        SizedBox(height: 20),
        if (results.isEmpty)
          _resultsEmptyIllustration()
        else ...[
          if (chartResults.isNotEmpty) ...[
          Text('روند ۷ نتیجه اخیر', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,
          )),
          SizedBox(height: 12),
          _glassSurface(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (var i = 0; i < chartResults.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        SizedBox(width: 26, child: Text('${i + 1}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            value: ((chartResults[i].percentage ?? 0) / 100).clamp(0.0, 1.0),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        )),
                        SizedBox(width: 10),
                        SizedBox(width: 46, child: Text(
                          '${chartResults[i].percentage?.round() ?? '—'}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        )),
                      ]),
                    ),
                ],
              ),
            )),
          ],
          SizedBox(height: 20),
          Text('همه نتایج', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,
          )),
          SizedBox(height: 10),
          for (final result in sorted)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _glassSurface(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.assignment_turned_in_outlined, color: accent),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.examName, style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                        '${result.dateTime.day.toString().padLeft(2, '0')}/${result.dateTime.month.toString().padLeft(2, '0')}/${result.dateTime.year}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      SizedBox(height: 6),
                      Text('درست: ${result.correct}  •  غلط: ${result.wrong}  •  بی‌پاسخ: ${result.unanswered}',
                        style: TextStyle(fontSize: 12)),
                      if (result.percentage == null)
                        TextButton.icon(onPressed: () => editResultAnswerKey(result), icon: Icon(Icons.key_rounded), label: Text('ثبت کلید و محاسبه درصد')),
                    ],
                  )),
                  Text(result.percentage == null ? 'بدون کلید' : '${result.percentage!.round()}%',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
                ]),
              ))),
        ],
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startExamTimer() {
    _examTimer?.cancel();
    setState(() {
      _remainingExamSeconds = activeExam.durationSeconds;
      _timerExamId = activeExamId;
      _examDeadline = DateTime.now().add(
        Duration(seconds: activeExam.durationSeconds),
      );
      _examTimerRunning = true;
    });
    _scheduleExamTimerTick();
  }

  void _scheduleExamTimerTick() {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateExamTimer();
    });
  }

  void _updateExamTimer() {
    if (!mounted) {
      _examTimer?.cancel();
      return;
    }
    final deadline = _examDeadline;
    if (!_examTimerRunning || deadline == null) return;

    final millisecondsRemaining = deadline.difference(DateTime.now()).inMilliseconds;
    final remaining = millisecondsRemaining <= 0
        ? 0
        : (millisecondsRemaining + 999) ~/ 1000;
    if (remaining <= 0) {
      _examTimer?.cancel();
      setState(() {
        _remainingExamSeconds = 0;
        _examTimerRunning = false;
        _examDeadline = null;
      });
      if (isTakingExam) {
        _finishExam(automatic: true);
      } else {
        _showSnackBar(SnackBar(content: Text('زمان‌سنج به پایان رسید.')));
      }
      return;
    }

    if (remaining != _remainingExamSeconds) {
      setState(() => _remainingExamSeconds = remaining);
    }
  }

  void _toggleExamTimer() {
    if (_examTimerRunning) {
      final deadline = _examDeadline;
      final millisecondsRemaining = deadline?.difference(DateTime.now()).inMilliseconds;
      final remaining = millisecondsRemaining == null
          ? _remainingExamSeconds
          : millisecondsRemaining <= 0
              ? 0
              : (millisecondsRemaining + 999) ~/ 1000;
      _examTimer?.cancel();
      setState(() {
        _remainingExamSeconds = remaining.clamp(0, 24 * 60 * 60).toInt();
        _examTimerRunning = false;
        _examDeadline = null;
      });
      if (remaining <= 0) {
        _showSnackBar(
          SnackBar(content: Text('زمان آزمون به پایان رسید.')),
        );
      }
      return;
    }

    if (_remainingExamSeconds > 0 && _timerExamId == activeExamId) {
      setState(() {
        _examTimerRunning = true;
        _examDeadline = DateTime.now().add(
          Duration(seconds: _remainingExamSeconds),
        );
      });
      _scheduleExamTimerTick();
    } else {
      _startExamTimer();
    }
  }

  Widget legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);

  Map<int, int> _readIntMap(String? raw) {
    if (raw == null) return <int, int>{};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return map.map((key, value) => MapEntry(int.parse(key), (value as num).toInt()));
    } catch (_) {
      return <int, int>{};
    }
  }

  void _createExamFromSetup(String name, int questionCount, int durationSeconds, bool negativeMarking, Map<int, int> answerKey) {
    final exam = ExamSheet(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      questionCount: questionCount,
      durationSeconds: durationSeconds,
      negativeMarking: negativeMarking,
      answerKey: answerKey,
    );
    setState(() {
      exams.add(exam);
      activeExamId = exam.id;
      examSection = 1;
    });
    save();
    _beginExam(exam);
  }

  ExamResult _recalculateResult(ExamResult result, Map<int, int> key) {
    final score = calculateAnswerScore(
      answers: result.answers,
      answerKey: key,
      questionCount: result.questionCount,
      negativeMarking: result.negativeMarking,
    );
    return result.copyWith(
      correct: score.correct,
      wrong: score.wrong,
      unanswered: score.unanswered,
      keyedQuestions: score.keyedQuestions,
      percentage: score.percentage,
      clearPercentage: score.percentage == null,
      answerKey: Map<int, int>.from(key),
    );
  }

  void _syncExamResults(ExamSheet exam) {
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.examId == exam.id ||
          (result.examId == null && result.examName == exam.name)) {
        results[i] = _recalculateResult(result, exam.answerKey);
      }
    }
  }

  Future<void> editResultAnswerKey(ExamResult result) async {
    final draft = Map<int, int>.from(result.answerKey);
    final updatedKey = await showDialog<Map<int, int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, dialogSet) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('کلید پاسخ: ${result.examName}'),
        content: SizedBox(
          width: 440, height: 420,
          child: ListView.builder(
            itemCount: result.questionCount,
            itemBuilder: (context, index) {
              final q = index + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(width: 62, child: Text('سؤال $q')),
                  for (var option = 0; option < 4; option++)
                    Expanded(child: ChoiceChip(
                      label: Text((option + 1).toString()),
                      selected: draft[q] == option,
                      onSelected: (_) => dialogSet(() {
                        if (draft[q] == option) { draft.remove(q); } else { draft[q] = option; }
                      }),
                    )),
                ]),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => dialogSet(() => draft.clear()), child: Text('پاک‌کردن')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, draft), child: Text('محاسبه نتیجه')),
        ],
      )),
    );
    if (updatedKey == null || !mounted) return;
    final index = results.indexWhere((item) => item.id == result.id);
    if (index < 0) return;

    ExamSheet? linkedExam;
    for (final exam in exams) {
      if (exam.id == result.examId ||
          (result.examId == null && exam.name == result.examName)) {
        linkedExam = exam;
        break;
      }
    }

    setState(() {
      if (linkedExam != null) {
        linkedExam.answerKey
          ..clear()
          ..addAll(updatedKey);
        _syncExamResults(linkedExam);
      } else {
        results[index] = _recalculateResult(result, updatedKey);
      }
    });
    await save();
  }

  Widget _resultsEmptyIllustration() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(children: [
      SizedBox(
        height: 112, width: 150,
        child: Stack(alignment: Alignment.center, children: [
          Positioned(top: 5, right: 20, child: CircleAvatar(radius: 34, backgroundColor: accent.withValues(alpha: 0.12))),
          Positioned(bottom: 5, left: 20, child: CircleAvatar(radius: 24, backgroundColor: Colors.teal.withValues(alpha: 0.13))),
          Icon(Icons.assignment_turned_in_rounded, size: 66, color: accent),
          Positioned(bottom: 8, right: 25, child: Icon(Icons.auto_graph_rounded, size: 30, color: Colors.teal)),
        ]),
      ),
      SizedBox(height: 8),
      Text('هنوز نتیجه‌ای ذخیره نشده', style: TextStyle(fontWeight: FontWeight.w800)),
      SizedBox(height: 5),
      Text('بعد از پایان آزمون، نتیجه‌ها و روند پیشرفتت اینجا نمایش داده می‌شوند.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
    ]),
  );

  Future<void> addExam() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ExamNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final exam = ExamSheet(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    setState(() {
      exams.add(exam);
      activeExamId = exam.id;
      tab = 2;
    });
    await save();
  }

  Future<void> renameExam() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ExamNameDialog(initialName: activeExam.name, isRename: true),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final oldName = activeExam.name;
    setState(() {
      activeExam.name = name.trim();
      for (var i = 0; i < results.length; i++) {
        if (results[i].examId == activeExam.id ||
            (results[i].examId == null && results[i].examName == oldName)) {
          results[i] = results[i].copyWith(examName: name.trim());
        }
      }
    });
    await save();
  }

  Future<void> deleteExam() async {
    if (exams.length == 1) {
      _showSnackBar(
        SnackBar(content: Text('حداقل یک پاسخ‌برگ باید باقی بماند.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
      title: Text('حذف پاسخ‌برگ'),
      content: Text('«${activeExam.name}» و تمام پاسخ‌ها و کلید آن حذف شوند؟ این کار قابل بازگشت نیست.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف')),
      ],
    ));
    if (confirmed != true) return;
    final deletedExam = activeExam;
    setState(() {
      final index = exams.indexWhere((exam) => exam.id == activeExamId);
      exams.removeWhere((exam) => exam.id == activeExamId);
      results.removeWhere((result) => result.examId == deletedExam.id || (result.examId == null && result.examName == deletedExam.name));
      activeExamId = exams[(index - 1).clamp(0, exams.length - 1).toInt()].id;
    });
    await save();
  }

  Future<void> resize(int value) async {
    setState(() { count = value; answers.removeWhere((key, _) => key > count); answerKey.removeWhere((key, _) => key > count); marked.removeWhere((key) => key > count); });
    await save();
  }

  Future<void> editAnswer(int number) async {
    int? answer = answers[number];
    bool flag = marked.contains(number);
    final result = await showDialog<({int? answer, bool marked})>(context: context, builder: (context) =>
      StatefulBuilder(builder: (context, dialogSet) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('سؤال $number'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: Alignment.centerRight, child: Text('گزینهٔ پاسخ')),
          SizedBox(height: 8),
          Wrap(spacing: 6, children: List.generate(4, (i) => ChoiceChip(
            label: Text(['الف', 'ب', 'ج', 'د'][i]), selected: answer == i,
            onSelected: (_) => dialogSet(() => answer = answer == i ? null : i)))),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: flag, title: Text('نیاز به مرور دارد'),
            onChanged: (value) => dialogSet(() => flag = value ?? false)),
          TextButton(onPressed: () => dialogSet(() => answer = null), child: Text('پاک کردن پاسخ')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, (answer: answer, marked: flag)), child: Text('ذخیره')),
        ],
      )));
    if (result == null) return;
    setState(() {
      if (result.answer != null) {
        answers[number] = result.answer!;
        // Answering a marked question clears its review marker.
        marked.remove(number);
      } else {
        answers.remove(number);
        // Clearing an answer never creates a review marker automatically.
        if (result.marked) { marked.add(number); } else { marked.remove(number); }
      }
    });
    await save();
  }

  Future<void> editAnswerKey() async {
    if (answerKey.length < count) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('تنظیم کلید پاسخ'),
        content: Text('برای محاسبه نتیجه، گزینه صحیح هر سؤال را وارد کن. فعلاً برای $count سؤال، کلید ${answerKey.length} سؤال ثبت شده است.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('بعداً')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('شروع')),
        ],
      ));
      if (!mounted || confirmed != true) return;
    }
    final result = await showDialog<Map<int, int>>(context: context, builder: (context) {
      final draft = Map<int, int>.from(answerKey);
      return StatefulBuilder(builder: (context, dialogSet) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('کلید پاسخ‌ها'),
        content: SizedBox(width: 420, height: 420, child: ListView.builder(
          itemCount: count,
          itemBuilder: (context, index) {
            final n = index + 1;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
              SizedBox(width: 52, child: Text('سؤال $n', style: TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: Wrap(spacing: 4, children: List.generate(4, (i) => ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text(['الف', 'ب', 'ج', 'د'][i]),
                selected: draft[n] == i,
                onSelected: (_) => dialogSet(() {
                  if (draft[n] == i) { draft.remove(n); } else { draft[n] = i; }
                }),
              )))),
            ]));
          },
        )),
        actions: [
          TextButton(onPressed: () => dialogSet(() => draft.clear()), child: Text('پاک‌کردن کلید')),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, draft), child: Text('ذخیره کلید')),
        ],
      ));
    });
    if (result == null) return;
    setState(() {
      answerKey
        ..clear()
        ..addAll(result);
      _syncExamResults(activeExam);
    });
    await save();
  }


  Map<String, dynamic> _createBackupPayload() =>
      DarsYarBackupCodec.createPayload(
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        activeExamId: activeExamId,
        tasks: tasks.map((item) => item.toJson()).toList(),
        studySessions: studySessions.map((item) => item.toJson()).toList(),
        exams: exams.map((item) => item.toJson()).toList(),
        results: results.map((item) => item.toJson()).toList(),
      );

  Future<void> exportBackup() async {
    try {
      final backup = DarsYarBackupCodec.encode(_createBackupPayload());
      await Clipboard.setData(ClipboardData(text: backup));
      if (!mounted) return;
      _showSnackBar(
        SnackBar(content: Text('نسخه پشتیبان در کلیپ‌بورد کپی شد؛ آن را در یک فایل امن ذخیره کن.')),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        SnackBar(content: Text('ساخت نسخه پشتیبان انجام نشد. دوباره تلاش کن.')),
      );
    }
  }

  Future<void> importBackup() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('بازیابی نسخه پشتیبان'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('محتوای فایل پشتیبان را اینجا جای‌گذاری کن. اطلاعات فعلی پس از تأیید جایگزین می‌شوند.'),
              SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 5,
                maxLines: 12,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'محتوای نسخه پشتیبان…',
                  border: OutlineInputBorder(),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text('بررسی نسخه'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    List<StudyTask> importedTasks;
    List<StudySession> importedSessions;
    List<ExamSheet> importedExams;
    List<ExamResult> importedResults;
    String importedActiveExamId;
    try {
      final decoded = DarsYarBackupCodec.decode(raw);

      List<dynamic> readList(String key) =>
          decoded[key] as List<dynamic>;

      importedTasks = readList('tasks').map((item) {
        if (item is! Map) throw const FormatException('Invalid task');
        return StudyTask.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      importedSessions = readList('studySessions').map((item) {
        if (item is! Map) throw const FormatException('Invalid study session');
        return StudySession.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      importedExams = readList('exams').map((item) {
        if (item is! Map) throw const FormatException('Invalid exam sheet');
        return ExamSheet.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      importedResults = readList('results').map((item) {
        if (item is! Map) throw const FormatException('Invalid exam result');
        return ExamResult.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      if (importedExams.isEmpty) {
        throw const FormatException('Backup has no exam sheets');
      }
      importedActiveExamId = decoded['activeExamId'] as String;
    } catch (_) {
      _showSnackBar(
        SnackBar(content: Text('نسخه پشتیبان معتبر نیست یا با این نسخه از درس‌یار سازگار نیست؛ اطلاعات فعلی تغییر نکرد.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
        title: Text('جایگزینی اطلاعات؟'),
        content: Text(
          'در نسخه پشتیبان ${importedTasks.length} وظیفه، ${importedSessions.length} جلسه مطالعه، '
          '${importedExams.length} پاسخ‌برگ و ${importedResults.length} نتیجه آزمون وجود دارد. '
          'اطلاعات فعلی با این داده‌ها جایگزین می‌شوند.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('بازیابی')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final oldTasks = List<StudyTask>.from(tasks);
    final oldSessions = List<StudySession>.from(studySessions);
    final oldExams = List<ExamSheet>.from(exams);
    final oldResults = List<ExamResult>.from(results);
    final oldActiveExamId = activeExamId;

    // A countdown belongs to the exam data that was active before restore.
    // Stop it before replacing that data so a stale timer cannot carry over
    // to an imported exam that happens to reuse the same identifier.
    _examTimer?.cancel();
    setState(() {
      _examTimerRunning = false;
      _remainingExamSeconds = 0;
      _timerExamId = null;
      _examDeadline = null;
      tasks..clear()..addAll(importedTasks);
      studySessions..clear()..addAll(importedSessions);
      exams..clear()..addAll(importedExams);
      results..clear()..addAll(importedResults);
      activeExamId = importedActiveExamId;
    });

    if (await save()) {
      if (!mounted) return;
      _showSnackBar(
        SnackBar(content: Text('نسخه پشتیبان با موفقیت بازیابی شد.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      tasks..clear()..addAll(oldTasks);
      studySessions..clear()..addAll(oldSessions);
      exams..clear()..addAll(oldExams);
      results..clear()..addAll(oldResults);
      activeExamId = oldActiveExamId;
    });
    await save();
    if (!mounted) return;
    _showSnackBar(
      SnackBar(content: Text('ذخیره نسخه بازیابی‌شده ناموفق بود؛ اطلاعات قبلی در برنامه بازگردانده شد.')),
    );
  }

  Widget settings() => ListView(padding: const EdgeInsets.all(20), children: [
    Text('تنظیمات', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
    SizedBox(height: 6), Text('ظاهر برنامه را مطابق سلیقه‌ات تنظیم کن.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    SizedBox(height: 18),
    _glassSurface(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.all(8), child: Text('پوسته برنامه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      RadioGroup<ThemeMode>(
        groupValue: widget.mode,
        onChanged: (value) {
          if (value != null) widget.onModeChanged(value);
        },
        child: Column(children: [
          RadioListTile<ThemeMode>(contentPadding: EdgeInsets.zero, value: ThemeMode.system, title: Text('مطابق دستگاه')),
          RadioListTile<ThemeMode>(contentPadding: EdgeInsets.zero, value: ThemeMode.light, title: Text('روشن')),
          RadioListTile<ThemeMode>(contentPadding: EdgeInsets.zero, value: ThemeMode.dark, title: Text('تیره')),
        ]),
      ),
    ]))),
    SizedBox(height: 12),
    _glassSurface(child: ListTile(leading: Icon(Icons.phone_android_rounded, color: accent), title: Text('ذخیره‌سازی محلی'),
      subtitle: Text('وظایف و پاسخ‌ها روی همین دستگاه ذخیره می‌شوند.'))),
    SizedBox(height: 12),
    _glassSurface(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.backup_outlined, color: accent),
          SizedBox(width: 8),
          Expanded(child: Text('پشتیبان‌گیری و بازیابی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        SizedBox(height: 6),
        Text('از وظایف، برنامه مطالعه، پاسخ‌برگ‌ها و نتایج آزمون نسخه پشتیبان بساز یا آن‌ها را بازیابی کن.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: exportBackup,
          icon: Icon(Icons.copy_all_rounded),
          label: Text('ساخت فایل پشتیبان'),
        )),
        SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7))),
          onPressed: importBackup,
          icon: Icon(Icons.warning_amber_rounded),
          label: Text('بازیابی فایل پشتیبان'),
        )),
      ]),
    )),
  ]);

  Widget emptyState(IconData icon, String title, String subtitle) => Container(padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(22)),
    child: Column(children: [
      Icon(icon, color: accent, size: 38), SizedBox(height: 10),
      Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
      SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
    ]));

  bool _hasOverlappingSession(StudySession candidate, {String? excludingId}) {
    return studySessions.any((session) {
      if (session.id == excludingId || session.weekday != candidate.weekday) return false;
      return studySessionsOverlap(candidate, session);
    });
  }

  Future<void> addStudySession() => editStudySession();

  Future<void> editStudySession([StudySession? existing]) async {
    final result = await showDialog<StudySession>(
      context: context,
      builder: (_) => _StudySessionEditorDialog(
        existing: existing,
        initialWeekday: selectedStudyDay,
        weekDays: weekDays,
        hasOverlap: (candidate) => _hasOverlappingSession(
          candidate,
          excludingId: existing?.id,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = studySessions.indexWhere((session) => session.id == result.id);
      if (index < 0) {
        studySessions.add(result);
      } else {
        studySessions[index] = result;
      }
      selectedStudyDay = result.weekday;
    });
    _revealSelectedDay();
    await save();
  }

  Future<void> addTask([StudyTask? existing]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _TaskEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      final subject = result.$2.isEmpty ? 'عمومی' : result.$2;
      if (existing == null) {
        tasks.add(StudyTask(DateTime.now().microsecondsSinceEpoch.toString(), result.$1, subject));
      } else {
        final index = tasks.indexWhere((task) => task.id == existing.id);
        if (index >= 0) {
          tasks[index] = StudyTask(existing.id, result.$1, subject, done: existing.done);
        }
      }
    });
    await save();
  }
}


class _LiquidGlassPanel extends StatelessWidget {
  const _LiquidGlassPanel({
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.62),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.58),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface.withValues(alpha: isDark ? 0.78 : 0.72),
                  colors.surfaceContainerHighest.withValues(alpha: isDark ? 0.52 : 0.48),
                  colors.surface.withValues(alpha: isDark ? 0.66 : 0.62),
                ],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _ExamSetupPanel extends StatefulWidget {
  const _ExamSetupPanel({required this.onCreate});
  final void Function(String, int, int, bool, Map<int, int>) onCreate;

  @override
  State<_ExamSetupPanel> createState() => _ExamSetupPanelState();
}

class _ExamSetupPanelState extends State<_ExamSetupPanel> {
  final _name = TextEditingController();
  final _count = TextEditingController(text: '20');
  Duration _duration = const Duration(minutes: 30);
  final Map<int, int> _answerKey = {};
  bool _negativeMarking = false;
  String? _lastError;
  DateTime? _lastErrorAt;

  void _showValidationMessage(String message) {
    final now = DateTime.now();
    if (_lastError == message && _lastErrorAt != null && now.difference(_lastErrorAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastError = message; _lastErrorAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final count = int.tryParse(_count.text);
    if (name.isEmpty || count == null || count < 1 || count > 200) {
      _showValidationMessage('نام و تعداد سؤال را درست وارد کن.');
      return;
    }
    final duration = _duration.inSeconds;
    if (duration < 1 || duration > 24 * 60 * 60) {
      _showValidationMessage('زمان آزمون باید بین یک ثانیه تا ۲۴ ساعت باشد.');
      return;
    }
    widget.onCreate(name, count, duration, _negativeMarking, Map<int, int>.fromEntries(_answerKey.entries.where((entry) => entry.key >= 1 && entry.key <= count)));
  }

  String _formatExamDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _editDuration() async {
    final updated = await showDialog<Duration>(
      context: context,
      builder: (_) => _ExamDurationDialog(initialDuration: _duration),
    );
    if (updated != null && mounted) setState(() => _duration = updated);
  }

  Future<void> _editSetupAnswerKey() async {
    final count = int.tryParse(_count.text)?.clamp(1, 200).toInt() ?? 20;
    final draft = Map<int, int>.from(_answerKey);
    final updated = await showDialog<Map<int, int>>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, dialogSet) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
      title: Text('کلید پاسخ آزمون'),
      content: SizedBox(width: 420, height: 420, child: ListView.builder(itemCount: count, itemBuilder: (context, index) { final q = index + 1; return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 65, child: Text('سؤال $q')), for (var option = 0; option < 4; option++) Expanded(child: ChoiceChip(label: Text(['الف', 'ب', 'ج', 'د'][option]), selected: draft[q] == option, onSelected: (_) => dialogSet(() { if (draft[q] == option) { draft.remove(q); } else { draft[q] = option; } }))) ])); })),
      actions: [TextButton(onPressed: () => dialogSet(() => draft.clear()), child: Text('پاک‌کردن')), TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(dialogContext, draft), child: Text('ذخیره کلید'))],
    )));
    if (updated != null && mounted) setState(() { _answerKey..clear()..addAll(updated); });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      _LiquidGlassPanel(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مشخصات آزمون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 14),
          TextField(controller: _name, maxLength: 60,
            decoration: InputDecoration(labelText: 'نام آزمون', hintText: 'مثلاً آزمون فصل اول ریاضی')),
          TextField(controller: _count, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'تعداد سؤال (۱ تا ۲۰۰)')),
          SizedBox(height: 14),
          Text('زمان دلخواه آزمون', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.timer_outlined, color: accent),
              ),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مدت آزمون', style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  )),
                  SizedBox(height: 3),
                  Text(_formatExamDuration(_duration),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ],
              )),
              OutlinedButton(
                onPressed: _editDuration,
                child: Text('تغییر زمان'),
              ),
            ]),
          ),
          SizedBox(height: 12),
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('کلید پاسخ اختیاری', style: TextStyle(fontWeight: FontWeight.w700)), Text(_answerKey.isEmpty ? 'هنوز کلیدی ثبت نشده' : 'کلید ${_answerKey.length} سؤال وارد شده', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])), OutlinedButton.icon(onPressed: _editSetupAnswerKey, icon: Icon(Icons.key_rounded), label: Text('ورود کلید'))]),
          SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _negativeMarking,
            onChanged: (value) => setState(() => _negativeMarking = value),
            title: Text('محاسبه با نمره منفی'),
            subtitle: Text('هر سه پاسخ غلط، معادل یک پاسخ درست کسر می‌شود.'),
          ),
          SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _submit,
            icon: Icon(Icons.play_arrow_rounded),
            label: Text('ساخت پاسخ‌برگ و شروع آزمون'),
          )),
          SizedBox(height: 4),
          Text('ثبت کلید پاسخ اختیاری است و می‌توانی بعد از آزمون آن را وارد کنی.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      )),
    ],
  );
}

class _ExamDurationDialog extends StatefulWidget {
  const _ExamDurationDialog({required this.initialDuration});

  final Duration initialDuration;

  @override
  State<_ExamDurationDialog> createState() => _ExamDurationDialogState();
}

class _ExamDurationDialogState extends State<_ExamDurationDialog> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;

  @override
  void initState() {
    super.initState();
    _hours = TextEditingController(text: widget.initialDuration.inHours.toString());
    _minutes = TextEditingController(
      text: widget.initialDuration.inMinutes.remainder(60).toString(),
    );
    _seconds = TextEditingController(
      text: widget.initialDuration.inSeconds.remainder(60).toString(),
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _setPreset(int minutes) {
    setState(() {
      _hours.text = (minutes ~/ 60).toString();
      _minutes.text = (minutes % 60).toString();
      _seconds.text = '0';
    });
  }

  void _submit() {
    final hours = int.tryParse(_hours.text) ?? -1;
    final minutes = int.tryParse(_minutes.text) ?? -1;
    final seconds = int.tryParse(_seconds.text) ?? -1;
    if (hours < 0 || hours > 24 ||
        minutes < 0 || minutes > 59 ||
        seconds < 0 || seconds > 59 ||
        (hours == 24 && (minutes != 0 || seconds != 0))) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('ساعت باید حداکثر ۲۴ و دقیقه و ثانیه کمتر از ۶۰ باشند.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    if (duration.inSeconds < 1) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('زمان آزمون باید حداقل یک ثانیه باشد.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    Navigator.pop(context, duration);
  }

  Widget _timeField(String label, TextEditingController controller) => Expanded(
    child: TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
    title: Text('تنظیم زمان آزمون'),
    content: SizedBox(
      width: 360,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('زمان را به ساعت، دقیقه و ثانیه وارد کن.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: 18),
        Row(children: [
          _timeField('ساعت', _hours),
          SizedBox(width: 8),
          _timeField('دقیقه', _minutes),
          SizedBox(width: 8),
          _timeField('ثانیه', _seconds),
        ]),
        SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: Text('زمان‌های پیشنهادی',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final preset in [15, 30, 45, 60, 90, 120])
            ActionChip(
              label: Text('$preset دقیقه'),
              onPressed: () => _setPreset(preset),
            ),
        ]),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('انصراف')),
      FilledButton(onPressed: _submit, child: Text('ذخیره زمان')),
    ],
  );
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.existing});

  final StudyTask? existing;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _subjectController = TextEditingController(text: widget.existing?.subject ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
    title: Text(widget.existing == null ? 'وظیفه جدید' : 'ویرایش وظیفه'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: _titleController,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(labelText: 'عنوان وظیفه'),
      ),
      SizedBox(height: 10),
      TextField(
        controller: _subjectController,
        maxLength: 50,
        decoration: InputDecoration(labelText: 'درس'),
      ),
    ]),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('انصراف'),
      ),
      FilledButton(
        onPressed: () {
          final title = _titleController.text.trim();
          if (title.isNotEmpty) {
            Navigator.pop(context, (title, _subjectController.text.trim()));
          }
        },
        child: Text(widget.existing == null ? 'افزودن' : 'ذخیره'),
      ),
    ],
  );
}


class _ExamNameDialog extends StatefulWidget {
  const _ExamNameDialog({this.initialName = '', this.isRename = false});

  final String initialName;
  final bool isRename;

  @override
  State<_ExamNameDialog> createState() => _ExamNameDialogState();
}

class _ExamNameDialogState extends State<_ExamNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
    title: Text(widget.isRename ? 'تغییر نام آزمون' : 'پاسخ‌برگ جدید'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 60,
      decoration: InputDecoration(
        labelText: 'نام آزمون',
        hintText: widget.isRename ? null : 'مثلاً آزمون ریاضی فصل اول',
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('انصراف'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.isRename ? 'ذخیره' : 'ساختن'),
      ),
    ],
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }
}

class _StudySessionEditorDialog extends StatefulWidget {
  const _StudySessionEditorDialog({
    required this.initialWeekday,
    required this.weekDays,
    required this.hasOverlap,
    this.existing,
  });

  final StudySession? existing;
  final int initialWeekday;
  final List<String> weekDays;
  final bool Function(StudySession candidate) hasOverlap;

  @override
  State<_StudySessionEditorDialog> createState() => _StudySessionEditorDialogState();
}

class _StudySessionEditorDialogState extends State<_StudySessionEditorDialog> {
  static const weekDayOrder = [6, 0, 1, 2, 3, 4, 5];
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late int _weekday;
  late int _startMinutes;
  late int _durationMinutes;
  late final TextEditingController _durationController;
  String? _lastError;
  DateTime? _lastErrorAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _subjectController = TextEditingController(text: widget.existing?.subject ?? '');
    _weekday = widget.existing?.weekday ?? widget.initialWeekday;
    _startMinutes = widget.existing?.startMinutes ?? 16 * 60;
    _durationMinutes = widget.existing?.durationMinutes ?? 55;
    _durationController = TextEditingController(text: _durationMinutes.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
    surfaceTintColor: Colors.transparent,
    elevation: 18,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    ),
    title: Text(widget.existing == null ? 'جلسه مطالعه جدید' : 'ویرایش جلسه مطالعه'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _titleController,
          autofocus: widget.existing == null,
          decoration: InputDecoration(
            labelText: 'عنوان جلسه',
            hintText: 'مثلاً حل تمرین فصل اول',
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _subjectController,
          decoration: InputDecoration(labelText: 'درس'),
        ),
        SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _weekday,
          decoration: InputDecoration(labelText: 'روز هفته'),
          items: weekDayOrder.map(
            (day) => DropdownMenuItem(value: day, child: Text(widget.weekDays[day])),
          ).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _weekday = value);
          },
        ),
        SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('ساعت شروع'),
          subtitle: Text(_formatTime(_startMinutes)),
          trailing: Icon(Icons.schedule_rounded),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: _startMinutes ~/ 60,
                minute: _startMinutes % 60,
              ),
            );
            if (picked != null && mounted) {
              setState(() => _startMinutes = picked.hour * 60 + picked.minute);
            }
          },
        ),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: InputDecoration(labelText: 'مدت جلسه (دقیقه)', helperText: 'مدت دلخواهت را از ۱ تا ۱۴۴۰ دقیقه وارد کن.'),
          onChanged: (value) => _durationMinutes = int.tryParse(value) ?? 0,
        ),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('انصراف'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.existing == null ? 'افزودن' : 'ذخیره تغییرات'),
      ),
    ],
  );

  String _formatTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  void _submit() {
    final title = _titleController.text.trim();
    _durationMinutes = int.tryParse(_durationController.text) ?? 0;
    if (_durationMinutes < 1 || _durationMinutes > 1440) { _showMessage('مدت جلسه باید بین ۱ تا ۱۴۴۰ دقیقه باشد.'); return; }
    if (title.isEmpty) {
      _showMessage('عنوان جلسه را وارد کن.');
      return;
    }
    if (_startMinutes + _durationMinutes > 1440) {
      _showMessage('جلسه نباید از نیمه‌شب عبور کند؛ ساعت شروع را تغییر بده.');
      return;
    }
    final candidate = StudySession(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      subject: _subjectController.text.trim().isEmpty
          ? 'عمومی'
          : _subjectController.text.trim(),
      weekday: _weekday,
      startMinutes: _startMinutes,
      durationMinutes: _durationMinutes,
      completed: widget.existing?.completed ?? false,
    );
    if (widget.hasOverlap(candidate)) {
      _showMessage('این زمان با یک جلسهٔ دیگر در همین روز تداخل دارد.');
      return;
    }
    Navigator.pop(context, candidate);
  }

  void _showMessage(String message) {
    final now = DateTime.now();
    if (_lastError == message && _lastErrorAt != null &&
        now.difference(_lastErrorAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastError = message;
    _lastErrorAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }
}
