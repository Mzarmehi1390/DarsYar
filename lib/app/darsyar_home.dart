import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../design_system/darsyar_theme.dart';
import '../design_system/glass_surface.dart';
import '../design_system/glass_modal_sheet.dart';
import '../design_system/glass_dialog.dart';
import '../design_system/glass_snackbar.dart';
import '../design_system/glass_tokens.dart';
import '../design_system/glass_selector.dart';
import '../design_system/glass_ambient_background.dart';
import '../features/exams/application/exam_timer_controller.dart';
import '../features/exams/application/exam_taking_session_controller.dart';
import '../features/exams/application/exam_controller.dart';
import '../features/exams/presentation/answer_key_editor_sheet.dart';
import '../features/exams/presentation/exam_page.dart';
import '../features/exams/presentation/exam_taking_view.dart';
import '../features/exams/presentation/saved_exam_card.dart';
import '../features/exams/presentation/exam_history_page.dart';
import '../features/exams/presentation/saved_exams_view.dart';
import '../features/settings/presentation/backup_import_dialog.dart';
import '../features/planner/presentation/study_session_editor.dart';
import '../features/planner/presentation/task_details_dialog.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/planner/presentation/planner_page.dart';
import '../features/planner/presentation/planner_week_overview_card.dart';
import '../features/planner/presentation/planner_weekly_report_card.dart';
import '../features/planner/presentation/planner_item_tiles.dart';
import '../features/planner/application/planner_controller.dart';
import '../features/planner/application/task_controller.dart';
import '../backup_codec.dart';
import '../features/exams/domain/models/exam_result.dart';
import '../features/exams/domain/models/exam_sheet.dart';
import '../features/planner/domain/models/study_session.dart';
import '../features/planner/domain/models/study_task.dart';
import '../features/planner/domain/models/planner_summary.dart';
import 'data/darsyar_repository.dart';
import '../design_system/input_focus_behavior.dart';
import 'presentation/home_shell.dart';

const accent = DarsYarTokens.accent;

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
  Widget? _cachedAmbientBackground;
  bool? _cachedAmbientBrightness;

  Widget _ambientBackgroundFor(bool isDark) {
    if (_cachedAmbientBackground == null ||
        _cachedAmbientBrightness != isDark) {
      _cachedAmbientBrightness = isDark;
      _cachedAmbientBackground = GlassAmbientBackground(isDark: isDark);
    }
    return _cachedAmbientBackground!;
  }
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 3);
    load();
  }
  bool loading = true;
  // Serialize writes so a slower older save cannot overwrite newer state.
  Future<void> _saveQueue = Future<void>.value();
  final DarsYarRepository _repository = DarsYarRepository();
  final PlannerController _plannerController = PlannerController();
  final TaskController _taskController = TaskController();
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

  final ExamTimerController _examTimerController = ExamTimerController();
  final ExamController _examController = ExamController();
  int examSection = 0;
  bool isTakingExam = false;
  final ExamTakingSessionController _examTakingSessionController =
      ExamTakingSessionController();
  bool _savingExamResult = false;

  @override
  void dispose() {
    _examTimerController.dispose();
    super.dispose();
  }

  ExamSheet get activeExam => exams.firstWhere((exam) => exam.id == activeExamId, orElse: () => exams.first);
  int get count => activeExam.questionCount;
  set count(int value) => activeExam.questionCount = value;
  Map<int, int> get answers => activeExam.answers;
  Map<int, int> get answerKey => activeExam.answerKey;
  Set<int> get marked => activeExam.marked;

  Future<void> load() async {
    try {
      final snapshot = await _repository.load();
      tasks
        ..clear()
        ..addAll(snapshot.tasks);
      studySessions
        ..clear()
        ..addAll(snapshot.studySessions);
      results
        ..clear()
        ..addAll(snapshot.results);
      exams
        ..clear()
        ..addAll(snapshot.exams);
      activeExamId = snapshot.activeExamId;
    } catch (_) {
      // Keep the app usable with empty in-memory defaults if storage is damaged.
    }

    if (mounted) {
      setState(() => loading = false);
      if (tab == 1) _revealSelectedDay();
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
    try {
      final saved = await _repository.save(
        sections: sections,
        tasks: tasks,
        studySessions: studySessions,
        exams: exams,
        results: results,
        activeExamId: activeExamId,
      );
      if (saved) return true;
      if (mounted) {
        _showSnackBar(
          const SnackBar(
            content: Text('ذخیره‌سازی کامل نشد؛ تلاش شد اطلاعات قبلی حفظ شوند.'),
          ),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          const SnackBar(
            content: Text('ذخیره‌سازی با خطا مواجه شد؛ تلاش شد اطلاعات قبلی حفظ شوند.'),
          ),
        );
      }
      return false;
    }
  }

  int get completed => _taskController.completedCount(tasks);

  @override
  Widget build(BuildContext context) {
    // Build only the active page to avoid constructing three unused page trees
    // during every state update.
    final page = switch (tab) {
      0 => _dashboardPage(),
      1 => _plannerPage(),
      2 => _examPage(),
      3 => SettingsPage(
            mode: widget.mode,
            onModeChanged: widget.onModeChanged,
            animationsEnabled: widget.animationsEnabled,
            onAnimationsChanged: widget.onAnimationsChanged,
            onExportBackup: exportBackup,
            onImportBackup: importBackup,
          ),
      _ => _dashboardPage(),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liteMotion = !widget.animationsEnabled ||
        MediaQuery.of(context).disableAnimations;

    return DarsYarHomeShell(
      page: page,
      loading: loading,
      background: _ambientBackgroundFor(isDark),
      selectedIndex: tab,
      liteMotion: liteMotion,
      onTabSelected: (index) {
        if (index == 1) {
          _openPlanner();
        } else {
          setState(() => tab = index);
        }
      },
    );
  }

  void _openPlanner() {
    setState(() => tab = 1);
    _revealSelectedDay();
  }

  void _revealSelectedDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tab != 1) return;
      // Reveal the selected weekday chip once. Calling ensureVisible for
      // both the chip and the week card starts two competing animations on
      // their shared vertical scrollable, which can cause a visible scroll
      // hitch when changing days.
      final target = _plannerDayKeys[selectedStudyDay]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 160),
        alignment: 0.5,
      );
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
    final result = await showDarsYarGlassDialog<bool>(
      context: context,
      title: title,
      message: message,
      maxWidth: 340,
      quality: GlassQuality.standard,
      barrierDismissible: false,
      reduceMotion: !widget.animationsEnabled,
      barrierColor: DarsYarGlassTokens.dialogBarrierColor,
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
      return await showDarsYarGlassDialog<String>(
        context: context,
        title: isRename ? 'تغییر نام آزمون' : 'پاسخ‌برگ جدید',
        maxWidth: 360,
        quality: GlassQuality.standard,
        reduceMotion: !widget.animationsEnabled,
        barrierColor: DarsYarGlassTokens.dialogBarrierColor,
        content: GlassFormField(
          label: 'نام آزمون',
          child: DarsYarInputFocusBehavior(
            controller: controller,
            child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: controller,
            placeholder: isRename ? 'نام جدید آزمون' : 'مثلاً آزمون ریاضی فصل اول',
            maxLength: 60,
            // Avoid opening the keyboard during the glass dialog entrance;
            // focus remains available on the first tap and the sheet stays stable.
            autofocus: false,
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


  Future<Map<int, int>?> _showAnswerKeyEditor({
    required String title,
    required int questionCount,
    required Map<int, int> initialAnswers,
    required String clearLabel,
    required String saveLabel,
  }) {
    return showDarsYarGlassSheet<Map<int, int>>(
      context: context,
      builder: (_) => AnswerKeyEditorSheet(
        title: title,
        questionCount: questionCount,
        initialAnswers: initialAnswers,
        clearLabel: clearLabel,
        saveLabel: saveLabel,
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      fillThreshold: 1.0,
      maintainContentGlass: true,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      barrierColor: DarsYarGlassTokens.sheetBarrierColor,
    );
  }

  Widget _dashboardPage() => DashboardPage(
        tasks: tasks,
        onOpenPlanner: _openPlanner,
        onOpenExam: () => setState(() => tab = 2),
        taskTileBuilder: taskTile,
        emptyStateBuilder: emptyState,
      );

  Widget _plannerPage() {
    // Group sessions in one pass. The seven overview cards previously each
    // filtered the complete session list during every planner rebuild.
    final sessionsByDay = <int, List<StudySession>>{
      for (final day in weekDayOrder) day: <StudySession>[],
    };
    for (final session in studySessions) {
      sessionsByDay.putIfAbsent(session.weekday, () => <StudySession>[]).add(session);
    }

    return PlannerPage(
      sessions: studySessions,
      tasks: tasks,
      selectedDay: selectedStudyDay,
      onSelectedDayChanged: (day) {
        setState(() => selectedStudyDay = day);
        _revealSelectedDay();
      },
      daysOrder: weekDayOrder,
      dayLabels: weekDays,
      dayKeys: _plannerDayKeys,
      weekKeys: _plannerWeekKeys,
      summaryBuilder: summary,
      weekOverviewCardBuilder: (day) => weekOverviewCard(
        day,
        sessionsByDay[day] ?? const <StudySession>[],
      ),
      weeklyReportCardBuilder: weeklyReportCard,
      studySessionTileBuilder: studySessionTile,
      taskTileBuilder: taskTile,
      emptyStateBuilder: emptyState,
      onAddStudySession: addStudySession,
      onAddTask: () => addTask(),
      onCopySelectedDayTo: copySelectedDayTo,
    );
  }

  Widget weeklyReportCard({required PlannerSummary summary}) =>
      PlannerWeeklyReportCard(summary: summary, sessions: studySessions);
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

  Future<void> copySelectedDayTo(int targetDay) async {
    if (targetDay == selectedStudyDay) return;
    final sourceSessions = _plannerController.sessionsForDay(
      studySessions,
      selectedStudyDay,
    );
    if (sourceSessions.isEmpty) {
      _showSnackBar(
        SnackBar(content: Text('برای کپی‌کردن، ابتدا در این روز جلسه‌ای بساز.')),
      );
      return;
    }
    final copyTimestamp = DateTime.now().microsecondsSinceEpoch;
    final copies = _plannerController.copyDay(
      sessions: sourceSessions,
      sourceDay: selectedStudyDay,
      targetDay: targetDay,
      createId: (session) => '$copyTimestamp-${session.id}-$targetDay',
    );
    final conflicts = copies.any(
      (candidate) => _plannerController.hasOverlap(studySessions, candidate),
    );
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

  Widget weekOverviewCard(int day, List<StudySession> sessions) =>
      PlannerWeekOverviewCard(
    dayLabel: weekDays[day],
    sessions: sessions,
    selected: day == selectedStudyDay,
    animationsEnabled: widget.animationsEnabled,
    onTap: () {
      setState(() => selectedStudyDay = day);
      _revealSelectedDay();
    },
  );

  Widget studySessionTile(StudySession session) => StudySessionTile(
    session: session,
    onToggle: () async {
      setState(() => _plannerController.toggleCompletion(studySessions, session.id));
      await save(sections: {'studySessions'});
    },
    onEdit: () => editStudySession(session),
    onDelete: () async {
      final confirmed = await _confirmGlass(
        title: 'حذف جلسه مطالعه',
        message: 'جلسه «${session.title}» حذف شود؟',
        confirmLabel: 'حذف',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      setState(() => _plannerController.removeById(studySessions, session.id));
      await save(sections: {'studySessions'});
    },
  );

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

  Widget taskTile(StudyTask task) => StudyTaskTile(
    task: task,
    onToggle: () async {
      setState(() => _taskController.toggleCompletion(task));
      await save(sections: {'tasks'});
    },
    onEdit: () => addTask(task),
    onDelete: () async {
      final confirmed = await _confirmGlass(
        title: 'حذف وظیفه',
        message: 'وظیفه «${task.title}» حذف شود؟',
        confirmLabel: 'حذف',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      setState(() => _taskController.removeById(tasks, task.id));
      await save(sections: {'tasks'});
    },
  );

  Widget _examPage() => ExamPage(
        isTakingExam: isTakingExam,
        examSection: examSection,
        onExamSectionChanged: (value) => setState(() => examSection = value),
        onCreate: _createExamFromSetup,
        onMessage: (message) => _showSnackBar(SnackBar(content: Text(message))),
        takingExamBuilder: _takingExamView,
        myExamsBuilder: _myExamsView,
      );

  Widget _savedExamCard(ExamSheet exam) => SavedExamCard(
    exam: exam,
    durationLabel: _formatDuration(exam.durationSeconds),
    onRename: () {
      setState(() => activeExamId = exam.id);
      renameExam();
    },
    onEditAnswerKey: () {
      setState(() => activeExamId = exam.id);
      editAnswerKey();
    },
    onDelete: () {
      setState(() => activeExamId = exam.id);
      deleteExam();
    },
    onBegin: () => _beginExam(exam),
  );

  Widget _myExamsView() => SavedExamsView(
        exams: exams,
        savedExamCardBuilder: _savedExamCard,
        emptyStateBuilder: emptyState,
        resultsHistoryBuilder: resultsHistory,
      );

  Widget _takingExamView() {
    final exam = activeExam;
    final question = _examTakingSessionController.currentQuestionNumber
        .clamp(1, exam.questionCount)
        .toInt();
    final remaining = _examTimerController.examId == activeExamId
        ? _examTimerController.remainingSeconds
        : exam.durationSeconds;

    return ExamTakingView(
      exam: exam,
      currentQuestion: question,
      remainingSeconds: remaining,
      timerDisplay: _examTimerController.displaySeconds,
      timerExamMatches: _examTimerController.examId == activeExamId,
      timerRunning: _examTimerController.isRunning,
      showQuestionNavigator:
          _examTakingSessionController.showQuestionNavigator,
      onBack: () => setState(() => isTakingExam = false),
      onToggleNavigator: () => setState(
        _examTakingSessionController.toggleQuestionNavigator,
      ),
      onToggleTimer: _toggleExamTimer,
      onQuestionSelected: (number) => setState(
        () => _examTakingSessionController.selectQuestion(
          number,
          questionCount: exam.questionCount,
        ),
      ),
      onAnswerSelected: _answerQuestion,
      onToggleMarked: () => _toggleQuestionMarked(question),
      onPrevious: () {
        if (question > 1) {
          setState(
            () => _examTakingSessionController.previousQuestion(
              questionCount: exam.questionCount,
            ),
          );
        }
      },
      onNext: question < exam.questionCount
          ? () => setState(
              () => _examTakingSessionController.nextQuestion(
                questionCount: exam.questionCount,
              ),
            )
          : _finishExam,
      onFinish: _finishExam,
      formatDuration: _formatDuration,
    );
  }

  Future<void> _answerQuestion(int option) async {
    setState(() {
      final question = _examTakingSessionController.currentQuestionNumber;
      activeExam.answers[question] = option;
      activeExam.marked.remove(question);
      _examTakingSessionController.nextQuestion(
        questionCount: activeExam.questionCount,
      );
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
    if (_examTimerController.examId != exam.id) {
      _examTimerController.stop();
      _examTimerController.isRunning = false;
      _examTimerController.deadline = null;
      _examTimerController.setRemaining(exam.durationSeconds);
      _examTimerController.examId = exam.id;
    } else if (_examTimerController.remainingSeconds == 0) {
      _examTimerController.setRemaining(exam.durationSeconds);
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
      _examTakingSessionController.selectQuestion(
        firstUnansweredQuestion,
        questionCount: exam.questionCount,
      );
    });
    if (!_examTimerController.isRunning) _toggleExamTimer();
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
    _examTimerController.stop();
    setState(() {
      activeExam.isCompleted = true;
      isTakingExam = false;
      _examTimerController.isRunning = false;
      _examTimerController.deadline = null;
      examSection = 1;
    });
    await saveExamResult();
  }

  Future<void> saveExamResult() async {
    if (_savingExamResult) return;
    final exam = activeExam;
    final completedAt = DateTime.now();
    final result = _examController.createResult(
      exam: exam,
      id: completedAt.microsecondsSinceEpoch.toString(),
      completedAt: completedAt,
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
        content: Text(result.percentage == null
          ? 'پاسخ‌ها ذخیره شدند؛ برای محاسبه درصد بعداً کلید را وارد کن.'
          : 'نتیجه آزمون در تاریخچه ذخیره شد.'),
      ));
    }
  }

  Widget resultsHistory() => ExamHistoryPage(
    results: results,
    summaryBuilder: summary,
    emptyState: _resultsEmptyIllustration(),
    onAddAnswerKey: editResultAnswerKey,
  );
  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startExamTimer() {
    setState(() {
      _examTimerController.start(
        examId: activeExamId,
        durationSeconds: activeExam.durationSeconds,
        onExpired: _handleExamTimerExpired,
      );
    });
  }

  void _handleExamTimerExpired() {
    if (!mounted) return;
    if (isTakingExam) {
      _finishExam(automatic: true);
    } else {
      setState(() {});
      _showSnackBar(SnackBar(content: Text('زمان‌سنج به پایان رسید.')));
    }
  }

  void _toggleExamTimer() {
    if (_examTimerController.isRunning) {
      final remaining = _examTimerController.pause();
      setState(() {});
      if (remaining <= 0) {
        _showSnackBar(SnackBar(content: Text('زمان آزمون به پایان رسید.')));
      }
      return;
    }

    if (_examTimerController.remainingSeconds > 0 &&
        _examTimerController.examId == activeExamId) {
      setState(() {
        _examTimerController.resume(onExpired: _handleExamTimerExpired);
      });
    } else {
      _startExamTimer();
    }
  }

  Widget legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);

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
        _examController.syncResults(results: results, exam: linkedExam);
      } else {
        results[index] = _examController.recalculateResult(result, updatedKey);
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
    final result = await showDarsYarGlassDialog<({int? answer, bool marked})>(
      context: context,
      title: 'سؤال $number',
      maxWidth: 360,
      quality: GlassQuality.standard,
      reduceMotion: !widget.animationsEnabled,
      barrierColor: DarsYarGlassTokens.dialogBarrierColor,
      content: StatefulBuilder(
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
                  DarsYarGlassChoiceChip(
                    label: ['الف', 'ب', 'ج', 'د'][i],
                    semanticLabel: 'سؤال $number، گزینه ${['الف', 'ب', 'ج', 'د'][i]}',
                    selected: answer == i,
                    selectedColor: accent.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
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
              child: DarsYarGlassChoiceChip(
                label: 'پاک کردن پاسخ',
                semanticLabel: 'پاک کردن پاسخ سؤال $number',
                selected: false,
                selectedColor: accent.withValues(alpha: 0.16),
                labelStyle: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                quality: GlassQuality.standard,
                onTap: () => dialogSet(() => answer = null),
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
      _examController.syncResults(results: results, exam: activeExam);
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
    final raw = await showDarsYarGlassSheet<String>(
      context: context,
      builder: (_) => const BackupImportDialog(),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      // Keep the full-height sheet refractive instead of letting the package's
      // default fill transition flatten it into an opaque panel.
      fillThreshold: 1.0,
      maintainContentGlass: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      barrierColor: DarsYarGlassTokens.sheetBarrierColor,
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
    _examTimerController.stop();
    setState(() {
      _examTimerController.isRunning = false;
      _examTimerController.setRemaining(0);
      _examTimerController.examId = null;
      _examTimerController.deadline = null;
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
    return _plannerController.hasOverlap(
      studySessions,
      candidate,
      excludingId: excludingId,
    );
  }

  Future<void> addStudySession() => editStudySession();

  Future<void> editStudySession([StudySession? existing]) async {
    final result = await showDarsYarGlassSheet<StudySession>(
      context: context,
      builder: (_) => StudySessionEditorDialog(
        existing: existing,
        initialWeekday: selectedStudyDay,
        weekDays: weekDays,
        hasOverlap: (candidate) => _hasOverlappingSession(
          candidate,
          excludingId: existing?.id,
        ),
        onMessage: (message) => _showSnackBar(SnackBar(content: Text(message))),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      barrierColor: DarsYarGlassTokens.sheetBarrierColor,
    );
    if (result == null || !mounted) return;
    setState(() {
      _plannerController.upsert(studySessions, result);
      selectedStudyDay = result.weekday;
    });
    _revealSelectedDay();
    await save(sections: {'studySessions'});
  }

  Future<void> addTask([StudyTask? existing]) async {
    final result = await showTaskDetailsDialog(
      context: context,
      existing: existing,
      reduceMotion: !widget.animationsEnabled,
    );
    if (result == null || !mounted) return;
    setState(() {
      _taskController.upsert(
        tasks: tasks,
        title: result.$1,
        subject: result.$2,
        existing: existing,
        createId: () => DateTime.now().microsecondsSinceEpoch.toString(),
      );
    });
    await save(sections: {'tasks'});
  }
}
