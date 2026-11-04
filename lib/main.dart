import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app_preferences.dart';
import 'answer_scoring.dart';
import 'backup_codec.dart';
import 'darsyar_storage.dart';
import 'design_system/darsyar_theme.dart';
import 'design_system/glass_surface.dart';
import 'design_system/modal_content.dart';
import 'design_system/page_header.dart';
import 'exam_result.dart';
import 'exam_sheet.dart';
import 'study_session.dart';
import 'models/study_task.dart';
import 'planner_summary.dart';

void showDarsYarGlassSnackBar(
  BuildContext context,
  SnackBar snackBar, {
  Duration? duration,
}) {
  final colors = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: GlassContainer.card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const LiquidRoundedSuperellipse(borderRadius: 18),
          quality: GlassQuality.standard,
          useOwnLayer: true,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            child: snackBar.content,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: duration ?? snackBar.duration,
        action: snackBar.action,
        onVisible: snackBar.onVisible,
      ),
    );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LiquidGlassWidgets.initialize();
  } catch (_) {
    // The adaptive glass widgets retain their standard fallback if shader
    // prewarming is unavailable on a particular device or renderer.
  }
  runApp(const DarsYarApp());
}

const accent = DarsYarTokens.accent;

class DarsYarApp extends StatefulWidget {
  const DarsYarApp({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<DarsYarApp> createState() => _DarsYarAppState();
}

class _DarsYarAppState extends State<DarsYarApp> {
  final AppPreferences _preferences = AppPreferences();
  ThemeMode mode = ThemeMode.system;
  bool animationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadAnimationPreference();
  }

  Future<void> _loadAnimationPreference() async {
    try {
      final restored = await _preferences.loadAnimationsEnabled();
      if (mounted) setState(() => animationsEnabled = restored);
    } catch (_) {
      // Keep animations enabled when preferences cannot be read.
    }
  }

  Future<void> _setAnimationsEnabled(bool value) async {
    setState(() => animationsEnabled = value);
    try {
      await _preferences.saveAnimationsEnabled(value);
    } catch (_) {
      // The current session still uses the selected performance mode.
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final restored = await _preferences.loadThemeMode();
      if (mounted) setState(() => mode = restored);
    } catch (_) {
      // Theme preferences are optional; keep the system default if unavailable.
    }
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() => mode = value);
    try {
      await _preferences.saveThemeMode(value);
    } catch (_) {
      // The selected theme remains active for this run even if persistence fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassWidgets.wrap(
      theme: const GlassThemeData.ios27(),
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'درس‌یار',
        themeMode: mode,
        theme: DarsYarTheme.light,
        darkTheme: DarsYarTheme.dark,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations: media.disableAnimations || !animationsEnabled,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox.expand(child: child ?? const SizedBox()),
            ),
          );
        },
        home: DarsYarHome(
          initialTab: widget.initialTab,
          mode: mode,
          onModeChanged: _setThemeMode,
          animationsEnabled: animationsEnabled,
          onAnimationsChanged: _setAnimationsEnabled,
        ),
      ),
    );
  }
}

class DarsYarHome extends StatefulWidget {
  const DarsYarHome({
    required this.mode,
    required this.onModeChanged,
    required this.animationsEnabled,
    required this.onAnimationsChanged,
    this.initialTab = 0,
    super.key,
  });
  final int initialTab;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  final bool animationsEnabled;
  final ValueChanged<bool> onAnimationsChanged;
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
  Future<void> _saveQueue = Future<void>.value();
  final DarsYarStorage _storage = DarsYarStorage();
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
  final ValueNotifier<int> _timerDisplaySeconds = ValueNotifier<int>(0);
  int examSection = 0;
  bool isTakingExam = false;
  int currentQuestionNumber = 1;
  bool _examTimerRunning = false;
  bool _savingExamResult = false;
  String? _timerExamId;
  DateTime? _examDeadline;

  void _setRemainingExamSeconds(int value) {
    _remainingExamSeconds = value;
    _timerDisplaySeconds.value = value;
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _timerDisplaySeconds.dispose();
    super.dispose();
  }

  ExamSheet get activeExam => exams.firstWhere((exam) => exam.id == activeExamId, orElse: () => exams.first);
  int get count => activeExam.questionCount;
  set count(int value) => activeExam.questionCount = value;
  Map<int, int> get answers => activeExam.answers;
  Map<int, int> get answerKey => activeExam.answerKey;
  Set<int> get marked => activeExam.marked;

  Future<void> load() async {
    late final DarsYarStorageSnapshot stored;
    try {
      stored = await _storage.readSnapshot();
    } catch (_) {
      if (mounted) setState(() => loading = false);
      return;
    }

    // Read each storage key independently: one damaged section must not hide
    // otherwise valid tasks, study sessions, exam sheets, or results.
    final rawTasks = _readStoredList(stored.stringValue('darsyar.tasks'));
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

    final rawSessions = _readStoredList(stored.stringValue('darsyar.studySessions'));
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

    final rawResults = _readStoredList(stored.stringValue('darsyar.results'));
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

    final storedExamsJson = stored.stringValue('darsyar.exams');
    final hasStoredExamsKey = stored.containsKey('darsyar.exams');
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
    } else if (!hasStoredExamsKey) {
      // Migrate legacy single-sheet data only when the current-format key
      // does not exist. Corrupt current data must never resurrect stale
      // legacy answers over the user's newer exam state.
      final legacyAnswers = _readIntMap(stored.stringValue('darsyar.answers'));
      final legacyKey = _readIntMap(stored.stringValue('darsyar.answerKey'));
      final legacyMarked = <int>{};
      final legacyMarkedRaw = stored.stringValue('darsyar.marked');
      final decodedMarked = _readStoredList(legacyMarkedRaw);
      if (decodedMarked != null) {
        for (final item in decodedMarked) {
          if (item is num) legacyMarked.add(item.toInt());
        }
      }
      final legacyCount = (stored.intValue('darsyar.count') ?? 20).clamp(1, 200).toInt();
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
    activeExamId = stored.stringValue('darsyar.activeExamId') ?? exams.first.id;
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

  static const _allStorageSections = <String>{
    'tasks',
    'exams',
    'activeExam',
    'results',
    'studySessions',
  };

  Future<bool> save({Set<String> sections = _allStorageSections}) {
    final requestedSections = Set<String>.unmodifiable(sections);
    final pending = _saveQueue.then(
      (_) => _saveCurrentState(requestedSections),
    );

    // Keep the internal queue healthy even if an unexpected exception escapes
    // a save. The caller still receives the original error from [pending],
    // while the next save is allowed to run normally.
    _saveQueue = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  Future<bool> _saveCurrentState(Set<String> sections) async {
    if (sections.isEmpty) return true;
    if (!_allStorageSections.containsAll(sections)) {
      throw ArgumentError.value(sections, 'sections', 'Unknown storage section');
    }
    try {
      // Encode only the sections changed by the caller. The storage layer
      // serializes writes and restores previous values if a write fails.
      final values = <String, String>{
        if (sections.contains('tasks'))
          'darsyar.tasks': jsonEncode(tasks.map((e) => e.toJson()).toList()),
        if (sections.contains('exams'))
          'darsyar.exams': jsonEncode(exams.map((exam) => exam.toJson()).toList()),
        if (sections.contains('activeExam'))
          'darsyar.activeExamId': activeExamId,
        if (sections.contains('results'))
          'darsyar.results': jsonEncode(results.map((result) => result.toJson()).toList()),
        if (sections.contains('studySessions'))
          'darsyar.studySessions': jsonEncode(studySessions.map((session) => session.toJson()).toList()),
      };

      final saved = await _storage.writeStrings(values);
      if (saved) return true;

      if (mounted) {
        _showSnackBar(
          SnackBar(content: Text('ذخیره‌سازی کامل نشد؛ تلاش شد اطلاعات قبلی حفظ شوند.')),
        );
      }
      return false;
    } catch (_) {
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
    // Build only the active page to avoid constructing three unused page trees
    // during every state update.
    final page = switch (tab) {
      0 => dashboard(),
      1 => planner(),
      2 => answerSheet(),
      3 => settings(),
      _ => dashboard(),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassScaffold(
        // Keep the decorative radial-gradient backdrop in its own
        // paint layer. Frequent page-state updates (including exam timer
        // ticks) should repaint the active content without repainting these
        // static glass-atmosphere layers.
        background: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isDark
                      ? const [
                          Color(0xFF101D30),
                          Color(0xFF0A1321),
                          Color(0xFF1A2034),
                        ]
                      : const [
                          Color(0xFFF5F8FD),
                          Color(0xFFE8F0F8),
                          Color(0xFFF0ECF8),
                        ],
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
                        (isDark
                                ? const Color(0xFF4F8EB8)
                                : const Color(0xFF8EBBE8))
                            .withValues(alpha: isDark ? 0.16 : 0.20),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 250,
              left: -150,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark
                                ? const Color(0xFF6673C8)
                                : const Color(0xFFB8A8EE))
                            .withValues(alpha: isDark ? 0.13 : 0.19),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : AnimatedSwitcher(
                  duration: !widget.animationsEnabled ||
                          MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 190),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.018),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(tab),
                    child: page,
                  ),
                ),
        ),
        bottomBar: loading
            ? null
            : GlassTabBar.bottom(
                tabs: const [
                  GlassTab(
                    icon: Icon(Icons.grid_view_rounded),
                    activeIcon: Icon(Icons.grid_view_rounded),
                    label: 'خانه',
                    semanticLabel: 'خانه',
                    glowColor: accent,
                  ),
                  GlassTab(
                    icon: Icon(Icons.calendar_month_outlined),
                    activeIcon: Icon(Icons.calendar_month_rounded),
                    label: 'برنامه‌ریزی',
                    semanticLabel: 'برنامه‌ریزی',
                    glowColor: accent,
                  ),
                  GlassTab(
                    icon: Icon(Icons.fact_check_outlined),
                    activeIcon: Icon(Icons.fact_check_rounded),
                    label: 'پاسخ‌برگ',
                    semanticLabel: 'پاسخ‌برگ',
                    glowColor: accent,
                  ),
                  GlassTab(
                    icon: Icon(Icons.tune_outlined),
                    activeIcon: Icon(Icons.tune_rounded),
                    label: 'تنظیمات',
                    semanticLabel: 'تنظیمات',
                    glowColor: accent,
                  ),
                ],
                selectedIndex: tab,
                onTabSelected: (index) {
                  if (index == 1) {
                    _openPlanner();
                  } else {
                    setState(() => tab = index);
                  }
                },
                selectedIconColor: isDark
                    ? DarsYarTokens.accentLight
                    : DarsYarTokens.accent,
                unselectedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                selectedLabelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                iconSize: 23,
                labelFontSize: 10.5,
                magnification: 1.12,
              ),
      ),
    );
  }

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
            duration: const Duration(milliseconds: 160),
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
    showDarsYarGlassSnackBar(
      context,
      snackBar,
      duration: const Duration(seconds: 2),
    );
  }

  Future<bool> _confirmGlass({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'انصراف',
    bool destructive = false,
  }) async {
    final result = await GlassDialog.show<bool>(
      context: context,
      title: title,
      message: message,
      maxWidth: 340,
      quality: GlassQuality.standard,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      actions: [
        GlassDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlassDialogAction(
          label: confirmLabel,
          isPrimary: !destructive,
          isDestructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result == true;
  }

  Future<String?> _requestExamName({
    String initialName = '',
    bool isRename = false,
  }) async {
    final controller = TextEditingController(text: initialName);
    try {
      return await GlassDialog.show<String>(
        context: context,
        title: isRename ? 'تغییر نام آزمون' : 'پاسخ‌برگ جدید',
        maxWidth: 360,
        quality: GlassQuality.standard,
        barrierColor: Colors.black.withValues(alpha: 0.30),
        content: DarsYarModalContent(
          child: GlassFormField(
            label: 'نام آزمون',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: controller,
            placeholder: isRename ? 'نام جدید آزمون' : 'مثلاً آزمون ریاضی فصل اول',
            maxLength: 60,
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
        ),
        ),
        actions: [
          GlassDialogAction(
            label: 'انصراف',
            onPressed: () => Navigator.of(context).pop(),
          ),
          GlassDialogAction(
            label: isRename ? 'ذخیره' : 'ساختن',
            isPrimary: true,
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
          ),
        ],
      );
    } finally {
      controller.dispose();
    }
  }

  Future<(String, String)?> _requestTaskDetails([StudyTask? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subjectController = TextEditingController(text: existing?.subject ?? '');
    try {
      return await GlassDialog.show<(String, String)>(
        context: context,
        title: existing == null ? 'وظیفه جدید' : 'ویرایش وظیفه',
        maxWidth: 360,
        quality: GlassQuality.standard,
        barrierColor: Colors.black.withValues(alpha: 0.30),
        content: DarsYarModalContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            GlassFormField(
              label: 'عنوان وظیفه',
              child: GlassTextField(
                surfaceStyle: GlassSurfaceStyle.solid,
                controller: titleController,
                placeholder: 'مثلاً مرور فصل دوم',
                maxLength: 100,
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 14),
            GlassFormField(
              label: 'درس',
              child: GlassTextField(
                surfaceStyle: GlassSurfaceStyle.solid,
                controller: subjectController,
                placeholder: 'مثلاً ریاضی',
                maxLength: 50,
                textInputAction: TextInputAction.done,
              ),
            ),
            ],
          ),
        ),
        actions: [
          GlassDialogAction(
            label: 'انصراف',
            onPressed: () => Navigator.of(context).pop(),
          ),
          GlassDialogAction(
            label: existing == null ? 'افزودن' : 'ذخیره',
            isPrimary: true,
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(context).pop((
                  title,
                  subjectController.text.trim(),
                ));
              }
            },
          ),
        ],
      );
    } finally {
      titleController.dispose();
      subjectController.dispose();
    }
  }

  Future<Map<int, int>?> _showAnswerKeyEditor({
    required String title,
    required int questionCount,
    required Map<int, int> initialAnswers,
    required String clearLabel,
    required String saveLabel,
  }) {
    return GlassModalSheet.show<Map<int, int>>(
      context: context,
      builder: (_) => DarsYarModalContent(
        child: _AnswerKeyEditorSheet(
          title: title,
          questionCount: questionCount,
          initialAnswers: initialAnswers,
          clearLabel: clearLabel,
          saveLabel: saveLabel,
        ),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      barrierColor: Colors.black.withValues(alpha: 0.32),
    );
  }

  Widget dashboard() => ListView(key: const PageStorageKey<String>('dashboard-scroll'), padding: const EdgeInsets.fromLTRB(20, 20, 20, DarsYarTokens.pageBottomClearance), children: [
    const DarsYarPageHeader(
      title: 'درس‌یار',
      subtitle: 'برنامه‌ریزی هوشمند برای یادگیری بهتر',
      icon: Icons.auto_stories_rounded,
    ),
    SizedBox(height: 24),
    GlassContainer.card(
      padding: EdgeInsets.zero,
      shape: const LiquidRoundedSuperellipse(borderRadius: 30),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A restrained specular rim makes the shader material read as glass
          // without washing out the Persian copy inside the hero.
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.34
                            : 0.72,
                      ),
                      Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.20
                            : 0.48,
                      ),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 1,
            left: 22,
            child: IgnorePointer(
              child: Container(
                width: 112,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.10
                            : 0.20,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -66,
            left: -42,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF72C9E9).withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.19 : 0.25,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -58,
            bottom: -100,
            child: IgnorePointer(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF55C8A5).withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.28,
                      ),
                      Colors.transparent,
                    ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'تمرکز امروز',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Text(
                            'هر روز، یک قدم به هدفت نزدیک‌تر',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 25,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'برنامه‌ات را ساده نگه دار و با استمرار پیش برو.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tasks.isEmpty
                            ? 'هنوز وظیفه‌ای ثبت نشده است'
                            : 'وظایف انجام‌شده: $completed از ${tasks.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      tasks.isEmpty ? '۰٪' : '${(completed / tasks.length * 100).round()}٪',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: tasks.isEmpty ? 0 : completed / tasks.length),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => LinearProgressIndicator(
                      minHeight: 8,
                      value: progress,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.09),
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    SizedBox(height: 24),
    Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
    SizedBox(height: 12),
    LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final actionHeight = compact ? 116.0 : 172.0;
        final plannerAction = quickAction(
          Icons.calendar_month_rounded,
          'برنامه‌ریزی درسی',
          'مدیریت وظایف',
          _openPlanner,
          const Color(0xFFDDF5E9),
          compact: compact,
          height: actionHeight,
        );
        final examAction = quickAction(
          Icons.fact_check_rounded,
          'پاسخ‌برگ آزمون',
          'ثبت پاسخ‌ها',
          () => setState(() => tab = 2),
          const Color(0xFFD5F0E8),
          compact: compact,
          height: actionHeight,
        );
        if (compact) {
          return Column(
            children: [
              plannerAction,
              const SizedBox(height: 10),
              examAction,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: plannerAction),
            const SizedBox(width: 12),
            Expanded(child: examAction),
          ],
        );
      },
    ),
    SizedBox(height: 14),
    Row(children: [Expanded(child: Text('وظایف پیش رو', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
      GlassButton.custom(
        height: 36,
        shape: const LiquidRoundedSuperellipse(borderRadius: 12),
        quality: GlassQuality.standard,
        style: GlassButtonStyle.transparent,
        onTap: _openPlanner,
        child: const Text('مشاهده همه'),
      )]),
    if (tasks.where((e) => !e.done).isEmpty)
      emptyState(Icons.event_available_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'از بخش برنامه‌ریزی، اولین وظیفه‌ات را اضافه کن.')
    else ...tasks.where((e) => !e.done).take(3).map(taskTile),
  ]);

  Widget quickAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
    Color tint, {
    bool compact = false,
    double height = 172,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconTop = isDark
        ? Color.lerp(tint, const Color(0xFF18372B), 0.58)!
        : Color.lerp(tint, Colors.white, 0.34)!;
    final iconBottom = isDark
        ? Color.lerp(tint, const Color(0xFF0B1B14), 0.72)!
        : Color.lerp(tint, const Color(0xFFB5DDC9), 0.30)!;
    final iconColor = isDark
        ? DarsYarTokens.accentLight
        : const Color(0xFF12664A);

    return GlassButton.custom(
      width: double.infinity,
      height: height,
      shape: const LiquidRoundedSuperellipse(borderRadius: 23),
      quality: GlassQuality.standard,
      style: GlassButtonStyle.filled,
      onTap: action,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: compact
            ? Row(
                children: [
                  _quickActionIcon(icon, iconTop, iconBottom, iconColor, isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 20),
                ],
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _quickActionIcon(icon, iconTop, iconBottom, iconColor, isDark),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionIcon(
    IconData icon,
    Color iconTop,
    Color iconBottom,
    Color iconColor,
    bool isDark,
  ) {
    return Container(
      width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iconTop, iconBottom],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.76),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
      child: Icon(icon, color: iconColor),
    );
  }

  Widget planner() {
    final plannerSummary = PlannerSummary.fromSessions(studySessions);
    final daySessions = plannerSummary.sessionsForDay(selectedStudyDay);
    final completedSessions = plannerSummary.completedSessionCount;
    final totalMinutes = plannerSummary.minutesForDay(selectedStudyDay);
    return ListView(key: const PageStorageKey<String>('planner-scroll'), padding: const EdgeInsets.fromLTRB(20, 22, 20, DarsYarTokens.pageBottomClearance), children: [
      const DarsYarPageHeader(
        title: 'برنامه‌ریزی درسی',
        subtitle: 'برای هر روز، جلسه مطالعه با زمان و مدت مشخص بچین.',
        icon: Icons.calendar_month_rounded,
      ),
      SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final width = compact ? (constraints.maxWidth - 10) / 2 : null;
          final cards = [
            summary('جلسه‌ها', studySessions.length, Icons.calendar_month_rounded),
            summary('انجام‌شده', completedSessions, Icons.check_circle_outline),
            summary('دقیقه امروز', totalMinutes, Icons.timer_outlined),
          ];
          if (compact) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  SizedBox(width: width, child: card),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: cards[i]),
              ],
            ],
          );
        },
      ),
      SizedBox(height: 20),
      Text('انتخاب روز', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 10),
      SizedBox(
        height: 44,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: weekDayOrder.map((day) => Padding(
          key: _plannerDayKeys[day],
          padding: const EdgeInsets.only(left: 8),
          child: GlassChip(
            key: ValueKey<String>('planner-day-$day'),
            label: weekDays[day],
            semanticLabel: weekDays[day],
            selected: selectedStudyDay == day,
            selectedColor: accent.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.18,
            ),
            labelStyle: TextStyle(
              color: selectedStudyDay == day
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: selectedStudyDay == day
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: 13,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            quality: GlassQuality.standard,
            onTap: () {
              setState(() => selectedStudyDay = day);
              _revealSelectedDay();
            },
          ),
        )).toList(),
          ),
        ),
      ),
      SizedBox(height: 20),
      Text('نمای کلی هفته', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 10),
      SizedBox(
        height: 124,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: weekDayOrder.map((day) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: SizedBox(
                key: _plannerWeekKeys[day],
                width: 190,
                child: weekOverviewCard(day),
              ),
            )).toList(),
          ),
        ),
      ),
      SizedBox(height: 16),
      weeklyReportCard(),
      SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            weekDays[selectedStudyDay],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          GlassButton.custom(
            width: 132,
            height: 44,
            shape: const LiquidRoundedSuperellipse(borderRadius: 15),
            quality: GlassQuality.standard,
            style: GlassButtonStyle.filled,
            onTap: addStudySession,
            child: const Text(
              'جلسه جدید',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          GlassPullDownButton(
            icon: const Icon(Icons.copy_all_rounded),
            semanticLabel: 'کپی برنامه این روز',
            quality: GlassQuality.standard,
            menuWidth: 230,
            items: [
              for (var day = 0; day < 7; day++)
                GlassMenuItem(
                  title: 'کپی برنامه به ${weekDays[day]}',
                  icon: const Icon(Icons.calendar_today_rounded),
                  enabled: day != selectedStudyDay,
                  onTap: () => copySelectedDayTo(day),
                ),
            ],
          ),
        ],
      ),
      if (daySessions.isEmpty)
        emptyState(Icons.event_available_rounded, 'برای این روز جلسه‌ای نداری', 'با دکمه «جلسه جدید» یک زمان مطالعه اضافه کن.')
      else ...daySessions.map(studySessionTile),
      SizedBox(height: 22),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            'فهرست وظایف',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          GlassButton.custom(
            width: 126,
            height: 44,
            shape: const LiquidRoundedSuperellipse(borderRadius: 15),
            quality: GlassQuality.standard,
            style: GlassButtonStyle.filled,
            onTap: addTask,
            child: const Text(
              'ثبت وظیفه',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      SizedBox(height: 10),
      if (tasks.isEmpty)
        emptyState(Icons.edit_calendar_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'برای یادآوری تکالیف، دکمه «افزودن وظیفه» را بزن.')
      else ...tasks.map(taskTile),
    ]);
  }

  Widget weeklyReportCard() {
    final summary = PlannerSummary.fromSessions(studySessions);
    final plannedMinutes = summary.plannedMinutes;
    final completedMinutes = summary.completedMinutes;
    final completion = summary.completion;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _glassSurface(
      radius: 24,
      tint: isDark
          ? const Color(0xFF20392D)
          : const Color(0xFFF1FAF4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'گزارش هفتگی مطالعه',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final metrics = [
                  _weeklyMetric('برنامه‌ریزی‌شده', plannedMinutes, 'دقیقه'),
                  _weeklyMetric('مطالعه تکمیل‌شده', completedMinutes, 'دقیقه'),
                  _weeklyMetric('پیشرفت', (completion * 100).round(), '٪'),
                ];
                if (constraints.maxWidth < 340) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final metric in metrics)
                        SizedBox(width: itemWidth, child: metric),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (final metric in metrics) Expanded(child: metric),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GlassProgressIndicator.linear(
                height: 7,
                minWidth: 0,
                value: completion,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: accent,
                quality: GlassQuality.standard,
                semanticLabel: 'پیشرفت هفتگی مطالعه',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              studySessions.isEmpty
                  ? 'با افزودن جلسه‌ها، گزارش اینجا نمایش داده می‌شود.'
                  : '${studySessions.where((session) => session.completed).length} از ${studySessions.length} جلسه تکمیل شده است.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassSurface({
    required Widget child,
    double radius = 20,
    Color? tint,
  }) =>
      DarsYarContentSurface(
        radius: radius,
        tint: tint,
        child: child,
      );

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
    await save(sections: {'studySessions'});
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
    final cardContent = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() => selectedStudyDay = day);
        _revealSelectedDay();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    weekDays[day],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? accent : null,
                    ),
                  ),
                ),
                if (selected)
                  Semantics(
                    label: 'روز انتخاب‌شده',
                    child: Container(
                      key: const ValueKey<String>('planner-week-selected-indicator'),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 7,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${sessions.length} جلسه • $minutes دقیقه',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: sessions.isEmpty ? 0 : done / sessions.length,
                ),
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => GlassProgressIndicator.linear(
                  height: 5,
                  minWidth: 0,
                  value: progress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: accent,
                  quality: GlassQuality.standard,
                  semanticLabel: 'پیشرفت روز ${weekDays[day]}',
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sessions.isEmpty
                  ? 'بدون برنامه'
                  : '$done از ${sessions.length} انجام‌شده',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (selected) {
      return GlassContainer.card(
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        quality: GlassQuality.standard,
        useOwnLayer: false,
        child: cardContent,
      );
    }
    return _glassSurface(radius: 18, child: cardContent);
  }

  Widget studySessionTile(StudySession session) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _glassSurface(
      radius: 21,
      tint: session.completed ? accent.withValues(alpha: 0.07) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GlassIconButton(
                  icon: Icon(
                    session.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: session.completed
                        ? accent
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    final index = studySessions.indexWhere((item) => item.id == session.id);
                    if (index < 0) return;
                    setState(
                      () => studySessions[index] =
                          session.copyWith(completed: !session.completed),
                    );
                    await save(sections: {'studySessions'});
                  },
                  size: 38,
                  shape: GlassIconButtonShape.circle,
                  quality: GlassQuality.standard,
                  semanticLabel: session.completed
                      ? 'علامت‌گذاری جلسه به‌عنوان انجام‌نشده'
                      : 'علامت‌گذاری جلسه به‌عنوان انجام‌شده',
                ),
                const SizedBox(width: 9),
                Container(
                  width: 3,
                  height: 38,
                  decoration: BoxDecoration(
                    color: session.completed
                        ? accent.withValues(alpha: 0.55)
                        : accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      decoration: session.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 58, top: 8),
              child: Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _plannerMetaPill(
                    Icons.menu_book_rounded,
                    session.subject,
                  ),
                  _plannerMetaPill(
                    Icons.schedule_rounded,
                    _formatStudyTime(session.startMinutes),
                  ),
                  _plannerMetaPill(
                    Icons.timelapse_rounded,
                    '${session.durationMinutes} دقیقه',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassIconButton(
                  icon: Icon(Icons.edit_outlined, color: accent),
                  onPressed: () => editStudySession(session),
                  size: 36,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: 'ویرایش جلسه',
                ),
                const SizedBox(width: 6),
                GlassIconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    final confirmed = await _confirmGlass(
                      title: 'حذف جلسه مطالعه',
                      message: 'جلسه «${session.title}» حذف شود؟',
                      confirmLabel: 'حذف',
                      destructive: true,
                    );
                    if (!confirmed || !mounted) return;
                    setState(() => studySessions.removeWhere((item) => item.id == session.id));
                    await save(sections: {'studySessions'});
                  },
                  size: 36,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: 'حذف جلسه',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _plannerMetaPill(IconData icon, String label) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.48 : 0.72,
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.42),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: accent),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  String _formatStudyTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  Widget summary(String label, int? value, IconData icon) => _glassSurface(
    radius: 19,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.11,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.13),
                  ),
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const Spacer(),
              Text(
                value?.toString() ?? '—',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  Widget taskTile(StudyTask task) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _glassSurface(
      radius: 21,
      tint: task.done ? accent.withValues(alpha: 0.07) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GlassIconButton(
                  icon: Icon(
                    task.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: task.done
                        ? accent
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    setState(() => task.done = !task.done);
                    await save(sections: {'tasks'});
                  },
                  size: 38,
                  shape: GlassIconButtonShape.circle,
                  quality: GlassQuality.standard,
                  semanticLabel: task.done
                      ? 'علامت‌گذاری وظیفه به‌عنوان انجام‌نشده'
                      : 'علامت‌گذاری وظیفه به‌عنوان انجام‌شده',
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: Theme.of(context).colorScheme.onSurface,
                          decoration: task.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _plannerMetaPill(Icons.menu_book_rounded, task.subject),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassIconButton(
                  icon: Icon(Icons.edit_outlined, color: accent),
                  onPressed: () => addTask(task),
                  size: 36,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: 'ویرایش وظیفه',
                ),
                const SizedBox(width: 6),
                GlassIconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    final confirmed = await _confirmGlass(
                      title: 'حذف وظیفه',
                      message: 'وظیفه «${task.title}» حذف شود؟',
                      confirmLabel: 'حذف',
                      destructive: true,
                    );
                    if (!confirmed || !mounted) return;
                    setState(() => tasks.removeWhere((item) => item.id == task.id));
                    await save(sections: {'tasks'});
                  },
                  size: 36,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: 'حذف وظیفه',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget answerSheet() {
    if (isTakingExam) return _takingExamView();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const DarsYarPageHeader(
            title: 'پاسخ‌برگ آزمون',
            subtitle: 'آزمون بساز، پاسخ‌ها را ثبت کن و نتیجه‌ها را بررسی کن.',
            icon: Icons.fact_check_rounded,
          ),
          SizedBox(height: 14),
          GlassSegmentedControl(
            segments: const [
              GlassSegment(
                label: 'ساخت آزمون جدید',
                semanticLabel: 'ساخت آزمون جدید',
              ),
              GlassSegment(
                label: 'آزمون‌های من',
                semanticLabel: 'آزمون‌های من',
              ),
            ],
            selectedIndex: examSection,
            onSegmentSelected: (value) =>
                setState(() => examSection = value),
            height: 46,
            borderRadius: 20,
            useOwnLayer: true,
            quality: GlassQuality.standard,
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            unselectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
        ]),
      ),
      Expanded(child: examSection == 0
        ? _ExamSetupPanel(onCreate: _createExamFromSetup)
        : _myExamsView()),
    ]);
  }

  Widget _savedExamCard(ExamSheet exam) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: Colors.transparent,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    child: _glassSurface(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    exam.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                GlassPullDownButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  semanticLabel: 'مدیریت آزمون ${exam.name}',
                  quality: GlassQuality.standard,
                  menuWidth: 220,
                  items: [
                    GlassMenuItem(
                      title: 'تغییر نام',
                      icon: const Icon(Icons.edit_rounded),
                      onTap: () {
                        setState(() => activeExamId = exam.id);
                        renameExam();
                      },
                    ),
                    GlassMenuItem(
                      title: 'ویرایش کلید پاسخ',
                      icon: const Icon(Icons.key_rounded),
                      onTap: () {
                        setState(() => activeExamId = exam.id);
                        editAnswerKey();
                      },
                    ),
                    GlassMenuItem(
                      title: 'حذف آزمون',
                      icon: const Icon(Icons.delete_outline_rounded),
                      isDestructive: true,
                      onTap: () {
                        setState(() => activeExamId = exam.id);
                        deleteExam();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${exam.questionCount} سؤال  •  ${_formatDuration(exam.durationSeconds)}  •  ${exam.answers.length} پاسخ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: exam.isCompleted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 17, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          'آزمون پایان یافته',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : GlassButton.custom(
                      width: 142,
                      height: 44,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 15),
                      quality: GlassQuality.standard,
                      style: GlassButtonStyle.filled,
                      onTap: () => _beginExam(exam),
                      child: Text(
                        exam.answers.isEmpty ? 'شروع آزمون' : 'ادامه آزمون',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _myExamsView() {
    final savedExams = exams.reversed.toList(growable: false);
    final empty = savedExams.isEmpty;
    final itemCount = empty ? 7 : savedExams.length + 6;

    return CustomScrollView(
      key: const PageStorageKey<String>('my-exams-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            DarsYarTokens.pageBottomClearance,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return const Text(
                    'پاسخ‌برگ‌های ذخیره‌شده',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  );
                }
                if (index == 1) return const SizedBox(height: 10);

                if (empty) {
                  switch (index) {
                    case 2:
                      return emptyState(
                        Icons.assignment_outlined,
                        'هنوز آزمونی نساخته‌ای',
                        'از بخش ساخت آزمون جدید، اولین پاسخ‌برگت را ایجاد کن.',
                      );
                    case 3:
                      return const SizedBox(height: 14);
                    case 4:
                      return const Text(
                        'نتایج آزمون‌ها',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      );
                    case 5:
                      return const SizedBox(height: 8);
                    case 6:
                      return resultsHistory();
                  }
                } else {
                  final examIndex = index - 2;
                  if (examIndex < savedExams.length) {
                    return _savedExamCard(savedExams[examIndex]);
                  }
                  switch (examIndex - savedExams.length) {
                    case 0:
                      return const SizedBox(height: 14);
                    case 1:
                      return const Text(
                        'نتایج آزمون‌ها',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      );
                    case 2:
                      return const SizedBox(height: 8);
                    case 3:
                      return resultsHistory();
                  }
                }
                return const SizedBox.shrink();
              },
              childCount: itemCount,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }

  bool _showQuestionNavigator = false;
  Widget _takingExamView() {
    final exam = activeExam;
    final q = currentQuestionNumber.clamp(1, exam.questionCount).toInt();
    final remaining =
        _timerExamId == activeExamId ? _remainingExamSeconds : exam.durationSeconds;
    final answered = exam.answers.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markerBackground = isDark
        ? const Color(0xFF244D39)
        : const Color(0xFFB8EBD2);
    final markerForeground = isDark
        ? DarsYarTokens.accentLight
        : const Color(0xFF155C3D);
    final selectedAnswerBackground = markerBackground;

    return Column(
      children: [
        GlassContainer.card(
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 430;
                    final backButton = GlassIconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => setState(() => isTakingExam = false),
                      size: 40,
                      shape: GlassIconButtonShape.roundedSquare,
                      quality: GlassQuality.standard,
                      semanticLabel: 'بازگشت به پاسخ‌برگ',
                    );
                    final timerBadge = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 17,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          ValueListenableBuilder<int>(
                            valueListenable: _timerDisplaySeconds,
                            builder: (context, seconds, _) => Text(
                              _formatDuration(
                                _timerExamId == activeExamId ? seconds : remaining,
                              ),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    final navigatorButton = GlassIconButton(
                      icon: Icon(
                        Icons.format_list_numbered_rounded,
                        color: _showQuestionNavigator
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      onPressed: () => setState(
                        () => _showQuestionNavigator = !_showQuestionNavigator,
                      ),
                      size: 40,
                      shape: GlassIconButtonShape.roundedSquare,
                      quality: GlassQuality.standard,
                      semanticLabel: 'فهرست سؤال‌ها',
                    );
                    final timerButton = GlassIconButton(
                      icon: Icon(
                        _examTimerRunning ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: _toggleExamTimer,
                      size: 40,
                      shape: GlassIconButtonShape.roundedSquare,
                      quality: GlassQuality.standard,
                      semanticLabel: _examTimerRunning
                          ? 'توقف زمان‌سنج'
                          : 'ادامه زمان‌سنج',
                    );
                    final examTitle = Expanded(
                      child: Text(
                        exam.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              backButton,
                              const SizedBox(width: 6),
                              examTitle,
                              const SizedBox(width: 6),
                              timerBadge,
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              navigatorButton,
                              const SizedBox(width: 6),
                              timerButton,
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        backButton,
                        const SizedBox(width: 8),
                        examTitle,
                        const SizedBox(width: 8),
                        timerBadge,
                        const SizedBox(width: 4),
                        navigatorButton,
                        timerButton,
                      ],
                    );
                  },
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GlassProgressIndicator.linear(
                    value: exam.questionCount == 0
                        ? 0
                        : answered / exam.questionCount,
                    height: 7,
                    minWidth: 0,
                    color: accent,
                    backgroundColor:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    quality: GlassQuality.standard,
                    semanticLabel: 'پیشرفت آزمون',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'پاسخ داده‌شده: $answered از ${exam.questionCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'سؤال $q از ${exam.questionCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showQuestionNavigator)
                SizedBox(
                  width: (MediaQuery.of(context).size.width * 0.34)
                      .clamp(112.0, 190.0)
                      .toDouble(),
                  child: _glassSurface(
                    radius: 18,
                    child: ListView.builder(
                      key: const PageStorageKey<String>('exam-question-navigator'),
                      // The floating tab bar overlays the lower edge of the
                      // exam workspace. Reserve the same dock clearance as
                      // the question body so the final question shortcuts can
                      // always scroll fully above it.
                      padding: const EdgeInsets.fromLTRB(
                        8,
                        8,
                        8,
                        DarsYarTokens.pageBottomClearance,
                      ),
                      itemCount: exam.questionCount,
                      itemBuilder: (context, index) {
                        final number = index + 1;
                        final current = number == q;
                        final markedQuestion = exam.marked.contains(number);
                        final hasAnswer = exam.answers.containsKey(number);
                        final itemColor = markedQuestion
                            ? markerBackground
                            : current
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: isDark ? 0.22 : 0.13)
                                : hasAnswer
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                    : Theme.of(context).colorScheme.surface;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(
                                () => currentQuestionNumber = number,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'سؤال $number',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: current || markedQuestion
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: markedQuestion
                                              ? markerForeground
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (markedQuestion)
                                      Icon(
                                        Icons.flag_rounded,
                                        size: 15,
                                        color: markerForeground,
                                      )
                                    else if (hasAnswer)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, DarsYarTokens.pageBottomClearance),
                  children: [
                    _glassSurface(
                      radius: 24,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    Icons.quiz_outlined,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'سؤال $q',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (exam.marked.contains(q))
                                  Icon(
                                    Icons.flag_rounded,
                                    color: markerForeground,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'گزینه پاسخ را انتخاب کن',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var option = 0; option < 4; option++)
                                  GlassChip(
                                    label: 'گزینه ${option + 1}',
                                    semanticLabel: 'سؤال $q، گزینه ${option + 1}',
                                    selected: exam.answers[q] == option,
                                    selectedColor: selectedAnswerBackground,
                                    labelStyle: TextStyle(
                                      color: exam.answers[q] == option
                                          ? markerForeground
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                    quality: GlassQuality.standard,
                                    onTap: () => _answerQuestion(option),
                                  ),
                              ],
                            ),
                            GlassButton.custom(
                              height: 42,
                              shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                              quality: GlassQuality.standard,
                              style: GlassButtonStyle.transparent,
                              onTap: () => _toggleQuestionMarked(q),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    exam.marked.contains(q)
                                        ? Icons.flag_rounded
                                        : Icons.flag_outlined,
                                    size: 18,
                                    color: exam.marked.contains(q)
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      exam.marked.contains(q)
                                          ? 'حذف علامت مرور'
                                          : 'علامت برای مرور',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final previousButton = GlassButton.custom(
                          width: double.infinity,
                          height: 48,
                          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
                          quality: GlassQuality.standard,
                          style: GlassButtonStyle.filled,
                          onTap: () {
                            if (q > 1) {
                              setState(() => currentQuestionNumber--);
                            }
                          },
                          child: const Text('قبلی'),
                        );
                        final nextButton = GlassButton.custom(
                          width: double.infinity,
                          height: 48,
                          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
                          quality: GlassQuality.standard,
                          style: GlassButtonStyle.prominent,
                          onTap: q < exam.questionCount
                              ? () => setState(() => currentQuestionNumber++)
                              : _finishExam,
                          child: Text(
                            q == exam.questionCount ? 'پایان آزمون' : 'بعدی',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );

                        // GlassButton has a comfortable intrinsic width. Stack
                        // the controls when the question pane is narrowed by
                        // a compact viewport or the open question navigator.
                        if (constraints.maxWidth < 340) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              previousButton,
                              const SizedBox(height: 8),
                              nextButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: previousButton),
                            const SizedBox(width: 8),
                            Expanded(child: nextButton),
                          ],
                        );
                      },
                    ),
                    Center(
                      child: GlassButton.custom(
                        height: 42,
                        shape: const LiquidRoundedSuperellipse(borderRadius: 13),
                        quality: GlassQuality.standard,
                        style: GlassButtonStyle.transparent,
                        onTap: _finishExam,
                        child: const Text('ثبت پایان آزمون'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _answerQuestion(int option) async {
    setState(() {
      activeExam.answers[currentQuestionNumber] = option;
      activeExam.marked.remove(currentQuestionNumber);
      if (currentQuestionNumber < activeExam.questionCount) currentQuestionNumber++;
    });
    await save(sections: {'exams'});
  }

  Future<void> _toggleQuestionMarked(int question) async {
    setState(() {
      if (!activeExam.marked.add(question)) activeExam.marked.remove(question);
    });
    await save(sections: {'exams'});
  }

  void _beginExam(ExamSheet exam) {
    if (_timerExamId != exam.id) {
      _examTimer?.cancel();
      _examTimerRunning = false;
      _examDeadline = null;
      _setRemainingExamSeconds(exam.durationSeconds);
      _timerExamId = exam.id;
    } else if (_remainingExamSeconds == 0) {
      _setRemainingExamSeconds(exam.durationSeconds);
    }
    var firstUnansweredQuestion = 1;
    for (var question = 1; question <= exam.questionCount; question++) {
      if (!exam.answers.containsKey(question)) {
        firstUnansweredQuestion = question;
        break;
      }
    }
    setState(() {
      activeExamId = exam.id;
      isTakingExam = true;
      currentQuestionNumber = firstUnansweredQuestion;
    });
    if (!_examTimerRunning) _toggleExamTimer();
    save(sections: {'exams', 'activeExam'});
  }

  Future<void> _finishExam({bool automatic = false}) async {
    if (!isTakingExam) return;
    if (!automatic) {
      final ok = await _confirmGlass(
        title: 'پایان آزمون؟',
        message: 'پاسخ‌ها ذخیره و نتیجه ثبت می‌شود.',
        confirmLabel: 'پایان',
        cancelLabel: 'ادامه',
      );
      if (!ok || !mounted || !isTakingExam) return;
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
    final saved = await save(sections: {'exams', 'results'});
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
                          child: GlassProgressIndicator.linear(
                            height: 12,
                            minWidth: 0,
                            value: ((chartResults[i].percentage ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
                            color: accent,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            quality: GlassQuality.standard,
                            semanticLabel: 'درصد نتیجه آزمون',
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _glassSurface(
                radius: 21,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Icon(
                              Icons.assignment_turned_in_outlined,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              result.examName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: result.percentage == null
                                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                                  : accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: result.percentage == null
                                    ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)
                                    : accent.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              result.percentage == null
                                  ? 'بدون کلید'
                                  : '${result.percentage!.round()}٪',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: result.percentage == null
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : accent,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _plannerMetaPill(
                            Icons.calendar_today_rounded,
                            '${result.dateTime.day.toString().padLeft(2, '0')}/${result.dateTime.month.toString().padLeft(2, '0')}/${result.dateTime.year}',
                          ),
                          _plannerMetaPill(
                            Icons.quiz_outlined,
                            '${result.questionCount} سؤال',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _plannerMetaPill(Icons.check_circle_outline_rounded, 'درست: ${result.correct}'),
                          _plannerMetaPill(Icons.close_rounded, 'غلط: ${result.wrong}'),
                          _plannerMetaPill(Icons.remove_circle_outline_rounded, 'بی‌پاسخ: ${result.unanswered}'),
                        ],
                      ),
                      if (result.percentage == null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: GlassButton.custom(
                            height: 40,
                            shape: const LiquidRoundedSuperellipse(borderRadius: 13),
                            quality: GlassQuality.standard,
                            style: GlassButtonStyle.transparent,
                            onTap: () => editResultAnswerKey(result),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.key_rounded, size: 17),
                                SizedBox(width: 7),
                                Text('ثبت کلید و محاسبه درصد'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
      _setRemainingExamSeconds(activeExam.durationSeconds);
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
        _setRemainingExamSeconds(0);
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
      _setRemainingExamSeconds(remaining);
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
        _setRemainingExamSeconds(remaining.clamp(0, 24 * 60 * 60).toInt());
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
    final updatedKey = await _showAnswerKeyEditor(
      title: 'کلید پاسخ: ${result.examName}',
      questionCount: result.questionCount,
      initialAnswers: result.answerKey,
      clearLabel: 'پاک‌کردن',
      saveLabel: 'محاسبه نتیجه',
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
    await save(sections: {'exams', 'results'});
  }

  Widget _resultsEmptyIllustration() => _glassSurface(
    radius: 22,
    child: Padding(
      padding: const EdgeInsets.all(24),
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
    ),
  );

  Future<void> addExam() async {
    final name = await _requestExamName();
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
    await save(sections: {'exams', 'activeExam'});
  }

  Future<void> renameExam() async {
    final name = await _requestExamName(
      initialName: activeExam.name,
      isRename: true,
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
    await save(sections: {'exams', 'results', 'activeExam'});
  }

  Future<void> deleteExam() async {
    if (exams.length == 1) {
      _showSnackBar(
        SnackBar(content: Text('حداقل یک پاسخ‌برگ باید باقی بماند.')),
      );
      return;
    }
    final confirmed = await _confirmGlass(
      title: 'حذف پاسخ‌برگ',
      message: '«${activeExam.name}» و تمام پاسخ‌ها و کلید آن حذف شوند؟ این کار قابل بازگشت نیست.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed) return;
    final deletedExam = activeExam;
    setState(() {
      final index = exams.indexWhere((exam) => exam.id == activeExamId);
      exams.removeWhere((exam) => exam.id == activeExamId);
      results.removeWhere((result) => result.examId == deletedExam.id || (result.examId == null && result.examName == deletedExam.name));
      activeExamId = exams[(index - 1).clamp(0, exams.length - 1).toInt()].id;
    });
    await save(sections: {'exams', 'results', 'activeExam'});
  }

  Future<void> resize(int value) async {
    setState(() { count = value; answers.removeWhere((key, _) => key > count); answerKey.removeWhere((key, _) => key > count); marked.removeWhere((key) => key > count); });
    await save(sections: {'exams'});
  }

  Future<void> editAnswer(int number) async {
    int? answer = answers[number];
    bool flag = marked.contains(number);
    final result = await GlassDialog.show<({int? answer, bool marked})>(
      context: context,
      title: 'سؤال $number',
      maxWidth: 360,
      quality: GlassQuality.standard,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      content: DarsYarModalContent(
        child: StatefulBuilder(
          builder: (dialogContext, dialogSet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'گزینهٔ پاسخ',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  GlassChip(
                    label: ['الف', 'ب', 'ج', 'د'][i],
                    semanticLabel: 'سؤال $number، گزینه ${['الف', 'ب', 'ج', 'د'][i]}',
                    selected: answer == i,
                    selectedColor: accent.withValues(alpha: 0.18),
                    quality: GlassQuality.standard,
                    onTap: () => dialogSet(
                      () => answer = answer == i ? null : i,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'نیاز به مرور دارد',
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GlassSwitch(
                  value: flag,
                  activeColor: accent,
                  semanticLabel: 'علامت‌گذاری سؤال برای مرور',
                  quality: GlassQuality.standard,
                  onChanged: (value) => dialogSet(() => flag = value),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GlassChip(
                label: 'پاک کردن پاسخ',
                selected: false,
                quality: GlassQuality.standard,
                onTap: () => dialogSet(() => answer = null),
              ),
            ),
          ],
          ),
        ),
      ),
      actions: [
        GlassDialogAction(
          label: 'انصراف',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: 'ذخیره',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(
            (answer: answer, marked: flag),
          ),
        ),
      ],
    );
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
    await save(sections: {'exams'});
  }

  Future<void> editAnswerKey() async {
    if (answerKey.length < count) {
      final confirmed = await _confirmGlass(
        title: 'تنظیم کلید پاسخ',
        message: 'برای محاسبه نتیجه، گزینه صحیح هر سؤال را وارد کن. فعلاً برای $count سؤال، کلید ${answerKey.length} سؤال ثبت شده است.',
        confirmLabel: 'شروع',
        cancelLabel: 'بعداً',
      );
      if (!mounted || !confirmed) return;
    }
    final result = await _showAnswerKeyEditor(
      title: 'کلید پاسخ‌ها',
      questionCount: count,
      initialAnswers: answerKey,
      clearLabel: 'پاک‌کردن کلید',
      saveLabel: 'ذخیره کلید',
    );
    if (result == null) return;
    setState(() {
      answerKey
        ..clear()
        ..addAll(result);
      _syncExamResults(activeExam);
    });
    await save(sections: {'exams', 'results', 'activeExam'});
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
    final raw = await GlassModalSheet.show<String>(
      context: context,
      builder: (_) => const DarsYarModalContent(
        child: _BackupImportDialog(),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      barrierColor: Colors.black.withValues(alpha: 0.32),
    );
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

    final confirmed = await _confirmGlass(
      title: 'جایگزینی اطلاعات؟',
      message: 'در نسخه پشتیبان ${importedTasks.length} وظیفه، ${importedSessions.length} جلسه مطالعه، '
          '${importedExams.length} پاسخ‌برگ و ${importedResults.length} نتیجه آزمون وجود دارد. '
          'اطلاعات فعلی با این داده‌ها جایگزین می‌شوند.',
      confirmLabel: 'بازیابی',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

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
      _setRemainingExamSeconds(0);
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

  Widget settings() => ListView(key: const PageStorageKey<String>('settings-scroll'), padding: const EdgeInsets.fromLTRB(20, 20, 20, DarsYarTokens.pageBottomClearance), children: [
    const DarsYarPageHeader(
      title: 'تنظیمات',
      subtitle: 'ظاهر و نگهداری اطلاعات برنامه را مدیریت کن.',
      icon: Icons.tune_rounded,
    ),
    SizedBox(height: 18),
    _glassSurface(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.all(8), child: Text('پوسته برنامه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      GlassSegmentedControl(
        segments: const [
          GlassSegment(label: 'سیستم', semanticLabel: 'مطابق دستگاه'),
          GlassSegment(label: 'روشن', semanticLabel: 'پوسته روشن'),
          GlassSegment(label: 'تیره', semanticLabel: 'پوسته تیره'),
        ],
        selectedIndex: widget.mode == ThemeMode.system
            ? 0
            : widget.mode == ThemeMode.light
                ? 1
                : 2,
        onSegmentSelected: (index) => widget.onModeChanged(
          [ThemeMode.system, ThemeMode.light, ThemeMode.dark][index],
        ),
        height: 46,
        quality: GlassQuality.standard,
        useOwnLayer: true,
        selectedTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        unselectedTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ]))),
    SizedBox(height: 12),
    _glassSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.animationsEnabled
                    ? Icons.motion_photos_on_rounded
                    : Icons.motion_photos_off_rounded,
                color: accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'انیمیشن‌های برنامه',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.animationsEnabled
                        ? 'حرکت‌ها و جابه‌جایی‌های نرم فعال هستند.'
                        : 'حرکت‌های غیرضروری غیرفعال شده‌اند تا رابط سبک‌تر اجرا شود.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GlassSwitch(
              value: widget.animationsEnabled,
              activeColor: accent,
              semanticLabel: 'روشن یا خاموش کردن انیمیشن‌های برنامه',
              quality: GlassQuality.standard,
              onChanged: widget.onAnimationsChanged,
            ),
          ],
        ),
      ),
    ),
    SizedBox(height: 12),
    _glassSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.phone_android_rounded, color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ذخیره‌سازی محلی',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'وظایف و پاسخ‌ها روی همین دستگاه ذخیره می‌شوند.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
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
        SizedBox(
          width: double.infinity,
          child: GlassButton.custom(
            height: 48,
            shape: const LiquidRoundedSuperellipse(borderRadius: 16),
            quality: GlassQuality.standard,
            style: GlassButtonStyle.prominent,
            onTap: exportBackup,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_all_rounded, size: 19),
                SizedBox(width: 9),
                Text('ساخت فایل پشتیبان', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: GlassButton.custom(
            height: 48,
            shape: const LiquidRoundedSuperellipse(borderRadius: 16),
            quality: GlassQuality.standard,
            style: GlassButtonStyle.filled,
            onTap: importBackup,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restore_rounded, size: 19, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 9),
                Text(
                  'بازیابی فایل پشتیبان',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    )),
  ]);

  Widget emptyState(IconData icon, String title, String subtitle) =>
      _glassSurface(
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(icon, color: accent, size: 38),
            SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ]),
        ),
      );

  bool _hasOverlappingSession(StudySession candidate, {String? excludingId}) {
    return studySessions.any((session) {
      if (session.id == excludingId || session.weekday != candidate.weekday) return false;
      return studySessionsOverlap(candidate, session);
    });
  }

  Future<void> addStudySession() => editStudySession();

  Future<void> editStudySession([StudySession? existing]) async {
    final result = await GlassModalSheet.show<StudySession>(
      context: context,
      builder: (_) => DarsYarModalContent(
        child: _StudySessionEditorDialog(
          existing: existing,
          initialWeekday: selectedStudyDay,
          weekDays: weekDays,
          hasOverlap: (candidate) => _hasOverlappingSession(
            candidate,
            excludingId: existing?.id,
          ),
        ),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      barrierColor: Colors.black.withValues(alpha: 0.32),
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
    await save(sections: {'studySessions'});
  }

  Future<void> addTask([StudyTask? existing]) async {
    final result = await _requestTaskDetails(existing);
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
    await save(sections: {'tasks'});
  }
}


class _LiquidGlassPanel extends StatelessWidget {
  const _LiquidGlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DarsYarContentSurface(
        radius: DarsYarTokens.radiusLarge,
        child: child,
      );
}

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      2026,
      1,
      1,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'انتخاب ساعت شروع',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 178,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: _selected,
          use24hFormat: true,
          onDateTimeChanged: (value) => setState(() => _selected = value),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GlassButton.custom(
              height: 46,
              shape: const LiquidRoundedSuperellipse(borderRadius: 15),
              quality: GlassQuality.standard,
              onTap: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassButton.custom(
              height: 46,
              shape: const LiquidRoundedSuperellipse(borderRadius: 15),
              quality: GlassQuality.standard,
              style: GlassButtonStyle.filled,
              onTap: () => Navigator.of(context).pop(
                TimeOfDay(hour: _selected.hour, minute: _selected.minute),
              ),
              child: const Text(
                'انتخاب',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _AnswerKeyEditorSheet extends StatefulWidget {
  const _AnswerKeyEditorSheet({
    required this.title,
    required this.questionCount,
    required this.initialAnswers,
    required this.clearLabel,
    required this.saveLabel,
  });

  final String title;
  final int questionCount;
  final Map<int, int> initialAnswers;
  final String clearLabel;
  final String saveLabel;

  @override
  State<_AnswerKeyEditorSheet> createState() => _AnswerKeyEditorSheetState();
}

class _AnswerKeyEditorSheetState extends State<_AnswerKeyEditorSheet> {
  late final Map<int, int> _draft;

  static const _options = ['الف', 'ب', 'ج', 'د'];

  @override
  void initState() {
    super.initState();
    _draft = Map<int, int>.from(widget.initialAnswers);
  }

  Widget _questionRow(int question) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              'سؤال $question',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (var option = 0; option < _options.length; option++)
                  GlassChip(
                    label: _options[option],
                    semanticLabel: 'سؤال $question، گزینه ${_options[option]}',
                    selected: _draft[question] == option,
                    selectedColor: accent.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: _draft[question] == option
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    quality: GlassQuality.standard,
                    onTap: () => setState(() {
                      if (_draft[question] == option) {
                        _draft.remove(question);
                      } else {
                        _draft[question] = option;
                      }
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerActions() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        GlassButton.custom(
          width: 96,
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
          quality: GlassQuality.standard,
          onTap: () => setState(_draft.clear),
          child: Text(widget.clearLabel),
        ),
        GlassButton.custom(
          width: 96,
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
          quality: GlassQuality.standard,
          onTap: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        GlassButton.custom(
          width: 122,
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
          quality: GlassQuality.standard,
          style: GlassButtonStyle.filled,
          onTap: () => Navigator.of(context).pop(Map<int, int>.from(_draft)),
          child: Text(
            widget.saveLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final questionCount = widget.questionCount.clamp(0, 200);
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: questionCount + 4,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_draft.length} از $questionCount سؤال دارای کلید پاسخ است.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GlassProgressIndicator.linear(
                height: 5,
                minWidth: 0,
                value: questionCount == 0
                    ? 0
                    : (_draft.length / questionCount).clamp(0.0, 1.0).toDouble(),
                color: accent,
                backgroundColor:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                quality: GlassQuality.standard,
                semanticLabel: 'پیشرفت ورود کلید پاسخ',
              ),
            ),
          );
        }
        if (index == questionCount + 3) {
          return _footerActions();
        }
        return _questionRow(index - 2);
      },
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
    showDarsYarGlassSnackBar(
      context,
      SnackBar(content: Text(message)),
      duration: const Duration(seconds: 2),
    );
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
    final updated = await GlassModalSheet.show<Duration>(
      context: context,
      builder: (_) => DarsYarModalContent(
        child: _ExamDurationDialog(initialDuration: _duration),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.82,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      barrierColor: Colors.black.withValues(alpha: 0.32),
    );
    if (updated != null && mounted) setState(() => _duration = updated);
  }

  Future<void> _editSetupAnswerKey() async {
    final count = int.tryParse(_count.text)?.clamp(1, 200).toInt() ?? 20;
    final updated = await GlassModalSheet.show<Map<int, int>>(
      context: context,
      builder: (_) => DarsYarModalContent(
        child: _AnswerKeyEditorSheet(
          title: 'کلید پاسخ آزمون',
          questionCount: count,
          initialAnswers: _answerKey,
          clearLabel: 'پاک‌کردن',
          saveLabel: 'ذخیره کلید',
        ),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      barrierColor: Colors.black.withValues(alpha: 0.32),
    );
    if (updated != null && mounted) {
      setState(() {
        _answerKey
          ..clear()
          ..addAll(updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, DarsYarTokens.pageBottomClearance),
    children: [
      _LiquidGlassPanel(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مشخصات آزمون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 14),
          GlassFormField(
            label: 'نام آزمون',
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: _name,
              maxLength: 60,
              placeholder: 'مثلاً آزمون فصل اول ریاضی',
              quality: GlassQuality.standard,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 12),
          GlassFormField(
            label: 'تعداد سؤال (۱ تا ۲۰۰)',
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: _count,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              quality: GlassQuality.standard,
              textInputAction: TextInputAction.next,
            ),
          ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 300;
                final timerIcon = Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.timer_outlined, color: accent),
                );
                final durationLabel = Column(
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
                );
                final editButton = GlassButton.custom(
                  width: 112,
                  height: 42,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                  quality: GlassQuality.standard,
                  style: GlassButtonStyle.filled,
                  onTap: _editDuration,
                  child: const Text('تغییر زمان'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        timerIcon,
                        SizedBox(width: 12),
                        Expanded(child: durationLabel),
                      ]),
                      SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft, child: editButton),
                    ],
                  );
                }
                return Row(children: [
                  timerIcon,
                  SizedBox(width: 12),
                  Expanded(child: durationLabel),
                  editButton,
                ]);
              },
            ),
          ),
          SizedBox(height: 12),
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('کلید پاسخ اختیاری', style: TextStyle(fontWeight: FontWeight.w700)), Text(_answerKey.isEmpty ? 'هنوز کلیدی ثبت نشده' : 'کلید ${_answerKey.length} سؤال وارد شده', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])), GlassButton.custom(
                      width: 112,
                      height: 40,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 13),
                      quality: GlassQuality.standard,
                      style: GlassButtonStyle.filled,
                      onTap: _editSetupAnswerKey,
                      child: const Text('ورود کلید'),
                    )]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('محاسبه با نمره منفی', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      'هر سه پاسخ غلط، معادل یک پاسخ درست کسر می‌شود.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              GlassSwitch(
                value: _negativeMarking,
                activeColor: accent,
                semanticLabel: 'محاسبه با نمره منفی',
                quality: GlassQuality.standard,
                onChanged: (value) => setState(() => _negativeMarking = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GlassButton.custom(
              height: 52,
              shape: const LiquidRoundedSuperellipse(borderRadius: 17),
              quality: GlassQuality.standard,
              style: GlassButtonStyle.prominent,
              onTap: _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'ساخت پاسخ‌برگ و شروع آزمون',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
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
      showDarsYarGlassSnackBar(
        context,
        const SnackBar(
          content: Text('ساعت باید حداکثر ۲۴ و دقیقه و ثانیه کمتر از ۶۰ باشند.'),
        ),
      );
      return;
    }
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    if (duration.inSeconds < 1) {
      showDarsYarGlassSnackBar(
        context,
        const SnackBar(content: Text('زمان آزمون باید حداقل یک ثانیه باشد.')),
      );
      return;
    }
    Navigator.of(context).pop(duration);
  }

  Widget _timeField(String label, TextEditingController controller) =>
      Expanded(
        child: GlassFormField(
          label: label,
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            maxLength: 2,
            quality: GlassQuality.standard,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'تنظیم زمان آزمون',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'زمان را به ساعت، دقیقه و ثانیه وارد کن.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        if (MediaQuery.sizeOf(context).width < 460)
          Column(
            children: [
              GlassFormField(
                label: 'ساعت',
                child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  quality: GlassQuality.standard,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              GlassFormField(
                label: 'دقیقه',
                child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  quality: GlassQuality.standard,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              GlassFormField(
                label: 'ثانیه',
                child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _seconds,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  quality: GlassQuality.standard,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              _timeField('ساعت', _hours),
              const SizedBox(width: 8),
              _timeField('دقیقه', _minutes),
              const SizedBox(width: 8),
              _timeField('ثانیه', _seconds),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'زمان‌های پیشنهادی',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in [15, 30, 45, 60, 90, 120])
              GlassChip(
                label: '$preset دقیقه',
                selected: _hours.text == (preset ~/ 60).toString() &&
                    _minutes.text == (preset % 60).toString() &&
                    _seconds.text == '0',
                selectedColor: accent.withValues(alpha: 0.16),
                quality: GlassQuality.standard,
                onTap: () => _setPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => Navigator.of(context).pop(),
                child: const Text('انصراف'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                style: GlassButtonStyle.filled,
                onTap: _submit,
                child: const Text(
                  'ذخیره زمان',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BackupImportDialog extends StatefulWidget {
  const _BackupImportDialog();

  @override
  State<_BackupImportDialog> createState() => _BackupImportDialogState();
}

class _BackupImportDialogState extends State<_BackupImportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'بازیابی نسخه پشتیبان',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'محتوای فایل پشتیبان را اینجا جای‌گذاری کن. اطلاعات فعلی پس از تأیید جایگزین می‌شوند.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        GlassFormField(
          label: 'محتوای نسخه پشتیبان',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _controller,
            minLines: 4,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            placeholder: 'محتوای نسخه پشتیبان…',
            quality: GlassQuality.standard,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => Navigator.of(context).pop(),
                child: const Text('انصراف'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                style: GlassButtonStyle.filled,
                onTap: () => Navigator.of(context).pop(_controller.text),
                child: const Text(
                  'بررسی نسخه',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.existing == null ? 'جلسه مطالعه جدید' : 'ویرایش جلسه مطالعه',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GlassFormField(
          label: 'عنوان جلسه',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _titleController,
            autofocus: widget.existing == null,
            placeholder: 'مثلاً حل تمرین فصل اول',
            quality: GlassQuality.standard,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 14),
        GlassFormField(
          label: 'درس',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _subjectController,
            placeholder: 'مثلاً ریاضی',
            quality: GlassQuality.standard,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'روز هفته',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GlassSegmentedControl.scrollable(
          segments: [
            for (final day in weekDayOrder)
              GlassSegment(
                label: widget.weekDays[day],
                semanticLabel: widget.weekDays[day],
              ),
          ],
          selectedIndex: weekDayOrder.indexOf(_weekday),
          onSegmentSelected: (index) =>
              setState(() => _weekday = weekDayOrder[index]),
          height: 44,
          quality: GlassQuality.standard,
          selectedTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          unselectedTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ساعت شروع',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GlassButton.custom(
          width: 250,
          height: 50,
          shape: const LiquidRoundedSuperellipse(borderRadius: 16),
          quality: GlassQuality.standard,
          onTap: () async {
            final picked = await GlassModalSheet.show<TimeOfDay>(
              context: context,
              builder: (_) => DarsYarModalContent(
                child: _TimePickerSheet(
                  initialTime: TimeOfDay(
                    hour: _startMinutes ~/ 60,
                    minute: _startMinutes % 60,
                  ),
                ),
              ),
              initialState: GlassSheetState.half,
              halfSize: 0.54,
              fullSize: 0.64,
              quality: GlassQuality.standard,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              barrierColor: Colors.black.withValues(alpha: 0.30),
            );
            if (picked != null && mounted) {
              setState(() => _startMinutes = picked.hour * 60 + picked.minute);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 19),
              const SizedBox(width: 10),
              Text(_formatTime(_startMinutes)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassFormField(
          label: 'مدت جلسه (دقیقه)',
          helperText: 'مدت دلخواهت را از ۱ تا ۱۴۴۰ دقیقه وارد کن.',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _durationController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            maxLength: 4,
            quality: GlassQuality.standard,
            onChanged: (value) => _durationMinutes = int.tryParse(value) ?? 0,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => Navigator.of(context).pop(),
                child: const Text('انصراف'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                style: GlassButtonStyle.filled,
                onTap: _submit,
                child: Text(
                  widget.existing == null ? 'افزودن' : 'ذخیره تغییرات',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
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
    showDarsYarGlassSnackBar(
      context,
      SnackBar(content: Text(message)),
      duration: const Duration(seconds: 2),
    );
  }
}
