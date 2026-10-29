import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'answer_scoring.dart';
import 'exam_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DarsYarApp());
}

const purple = Color(0xFF7357D9);
const ink = Color(0xFF24213A);
const muted = Color(0xFF77748B);
const canvas = Color(0xFFF7F5FC);

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
  const DarsYarApp({super.key});
  @override
  State<DarsYarApp> createState() => _DarsYarAppState();
}

class _DarsYarAppState extends State<DarsYarApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(seedColor: purple);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'درس‌یار',
      themeMode: mode,
      theme: ThemeData(useMaterial3: true, colorScheme: lightScheme, scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink),
        cardTheme: CardThemeData(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)))),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark), brightness: Brightness.dark),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      home: DarsYarHome(mode: mode, onModeChanged: (value) => setState(() => mode = value)),
    );
  }
}

class DarsYarHome extends StatefulWidget {
  const DarsYarHome({required this.mode, required this.onModeChanged, super.key});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  @override
  State<DarsYarHome> createState() => _DarsYarHomeState();
}

class _DarsYarHomeState extends State<DarsYarHome> {
  int tab = 0;
  bool loading = true;
  final tasks = <StudyTask>[];
  final exams = <ExamSheet>[
    ExamSheet(id: 'default', name: 'آزمون اول'),
  ];
  String activeExamId = 'default';

  ExamSheet get activeExam => exams.firstWhere((exam) => exam.id == activeExamId, orElse: () => exams.first);
  int get count => activeExam.questionCount;
  set count(int value) => activeExam.questionCount = value;
  Map<int, int> get answers => activeExam.answers;
  Map<int, int> get answerKey => activeExam.answerKey;
  Set<int> get marked => activeExam.marked;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('darsyar.tasks');
      if (raw != null) {
        tasks.addAll((jsonDecode(raw) as List<dynamic>).map((e) => StudyTask.fromJson(Map<String, dynamic>.from(e as Map))));
      }
      final rawExams = prefs.getString('darsyar.exams');
      if (rawExams != null) {
        final decoded = jsonDecode(rawExams) as List<dynamic>;
        exams
          ..clear()
          ..addAll(decoded.map((item) => ExamSheet.fromJson(
            Map<String, dynamic>.from(item as Map),
          )));
      } else {
        // Migrate existing single-sheet data without losing the user's answers.
        final legacyAnswers = _readIntMap(prefs.getString('darsyar.answers'));
        final legacyKey = _readIntMap(prefs.getString('darsyar.answerKey'));
        final legacyMarkedRaw = prefs.getString('darsyar.marked');
        final legacyMarked = legacyMarkedRaw == null
            ? <int>{}
            : (jsonDecode(legacyMarkedRaw) as List<dynamic>).cast<int>().toSet();
        final legacyCount = prefs.getInt('darsyar.count') ?? 20;
        exams
          ..clear()
          ..add(ExamSheet(
            id: 'default',
            name: 'آزمون اول',
            questionCount: legacyCount.clamp(1, 200).toInt(),
            answers: legacyAnswers,
            answerKey: legacyKey,
            marked: legacyMarked,
          ));
      }
      if (exams.isEmpty) {
        exams.add(ExamSheet(id: 'default', name: 'آزمون اول'));
      }
      activeExamId = prefs.getString('darsyar.activeExamId') ?? exams.first.id;
      if (!exams.any((exam) => exam.id == activeExamId)) activeExamId = exams.first.id;
    } catch (_) {
      // Corrupt local data must not stop the app from starting.
    }
    if (exams.isEmpty) {
      exams.add(ExamSheet(id: 'default', name: 'آزمون اول'));
    }
    if (!exams.any((exam) => exam.id == activeExamId)) {
      activeExamId = exams.first.id;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('darsyar.tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
    await prefs.setString('darsyar.exams', jsonEncode(exams.map((exam) => exam.toJson()).toList()));
    await prefs.setString('darsyar.activeExamId', activeExamId);
  }

  int get completed => tasks.where((e) => e.done).length;

  @override
  Widget build(BuildContext context) {
    final pages = [dashboard(), planner(), answerSheet(), settings()];
    return Scaffold(
      body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator()) : pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'برنامه‌ریزی'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'پاسخ‌برگ'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'تنظیمات'),
        ],
      ),
      floatingActionButton: tab == 1 ? FloatingActionButton.extended(
        onPressed: addTask, backgroundColor: purple, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: const Text('وظیفه جدید')) : null,
    );
  }

  Widget dashboard() => ListView(padding: const EdgeInsets.all(20), children: [
    const Row(children: [
      CircleAvatar(backgroundColor: Color(0xFFECE7FF), child: Icon(Icons.auto_stories_rounded, color: purple)),
      SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('درس‌یار', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        Text('برنامه‌ریزی هوشمند برای یادگیری بهتر', style: TextStyle(fontSize: 12, color: muted)),
      ]),
    ]),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF8067E8), Color(0xFF5D43BD)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('هر روز، یک قدم به هدفت نزدیک‌تر', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('برنامه‌ات را ساده نگه دار و با استمرار پیش برو.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 22),
        Text('وظایف انجام‌شده: $completed از ${tasks.length}', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(
          minHeight: 7, value: tasks.isEmpty ? 0 : completed / tasks.length, backgroundColor: Colors.white30, color: Colors.white)),
      ]),
    ),
    const SizedBox(height: 24),
    const Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: quickAction(Icons.calendar_month_rounded, 'برنامه‌ریزی درسی', 'مدیریت وظایف', () => setState(() => tab = 1), const Color(0xFFECE7FF))),
      const SizedBox(width: 12),
      Expanded(child: quickAction(Icons.fact_check_rounded, 'پاسخ‌برگ آزمون', 'ثبت پاسخ‌ها', () => setState(() => tab = 2), const Color(0xFFE0F5ED))),
    ]),
    const SizedBox(height: 24),
    Row(children: [const Expanded(child: Text('وظایف پیش رو', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink))),
      TextButton(onPressed: () => setState(() => tab = 1), child: const Text('مشاهده همه'))]),
    if (tasks.where((e) => !e.done).isEmpty)
      emptyState(Icons.event_available_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'از بخش برنامه‌ریزی، اولین وظیفه‌ات را اضافه کن.')
    else ...tasks.where((e) => !e.done).take(3).map(taskTile),
  ]);

  Widget quickAction(IconData icon, String title, String subtitle, VoidCallback action, Color tint) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(22), child: InkWell(
      onTap: action, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: purple)),
          const SizedBox(height: 14), Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
        ]))));

  Widget planner() => ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 90), children: [
    const Text('برنامه‌ریزی درسی', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 6), const Text('کارهایت را ثبت کن و پیشرفتت را دنبال کن.', style: TextStyle(color: muted)),
    const SizedBox(height: 20),
    Row(children: [
      Expanded(child: summary('همه وظایف', tasks.length, Icons.list_alt_rounded)),
      const SizedBox(width: 8), Expanded(child: summary('انجام‌شده', completed, Icons.check_circle_outline)),
      const SizedBox(width: 8), Expanded(child: summary('باقی‌مانده', tasks.length - completed, Icons.pending_actions)),
    ]),
    const SizedBox(height: 20),
    if (tasks.isEmpty) emptyState(Icons.edit_calendar_rounded, 'برنامه‌ات را بساز', 'با دکمه «وظیفه جدید» یک کار درسی اضافه کن.')
    else ...tasks.map(taskTile),
  ]);

  Widget summary(String label, int value, IconData icon) => Container(padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: purple), const SizedBox(height: 8),
      Text(value.toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
    ]));

  Widget taskTile(StudyTask task) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      Checkbox(value: task.done, activeColor: purple, onChanged: (value) async { setState(() => task.done = value ?? false); await save(); }),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: task.done ? TextDecoration.lineThrough : null)),
        const SizedBox(height: 4), Text(task.subject, style: const TextStyle(fontSize: 12, color: muted)),
      ])),
      IconButton(tooltip: 'حذف', onPressed: () async { setState(() => tasks.removeWhere((e) => e.id == task.id)); await save(); },
        icon: const Icon(Icons.delete_outline_rounded, color: muted)),
    ]));

  Widget answerSheet() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('پاسخ‌برگ آزمون', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 6), const Text('برای هر آزمون پاسخ‌ها و کلید جداگانه نگه‌داری می‌شود.', style: TextStyle(color: muted, height: 1.6)),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(activeExam.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        PopupMenuButton<String>(
          tooltip: 'مدیریت آزمون',
          onSelected: (action) {
            if (action == 'rename') renameExam();
            if (action == 'delete') deleteExam();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('تغییر نام آزمون')),
            PopupMenuItem(value: 'delete', child: Text('حذف آزمون')),
          ],
        ),
      ]),
      DropdownButtonFormField<String>(
        initialValue: activeExamId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'آزمون فعال', border: OutlineInputBorder()),
        items: exams.map((exam) => DropdownMenuItem(value: exam.id, child: Text(exam.name, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) async {
          if (value == null) return;
          setState(() => activeExamId = value);
          await save();
        },
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: addExam, icon: const Icon(Icons.add_rounded), label: const Text('ساخت پاسخ‌برگ جدید')),
    ]))),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      const Expanded(child: Text('تعداد سؤال‌ها', style: TextStyle(fontWeight: FontWeight.w700))),
      IconButton(onPressed: count > 1 ? () => resize(count - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
      Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
      IconButton(onPressed: count < 200 ? () => resize(count + 1) : null, icon: const Icon(Icons.add_circle_outline)),
    ]))),
    const SizedBox(height: 12),
    Wrap(spacing: 12, children: [
      legend(const Color(0xFFDCF4E8), 'پاسخ‌داده‌شده'),
      legend(const Color(0xFFFFE9CF), 'نیازمند مرور'),
      legend(Theme.of(context).cardColor, 'بدون پاسخ'),
    ]),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('کلید و نتیجه آزمون', style: TextStyle(fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: editAnswerKey, icon: const Icon(Icons.key_rounded), label: const Text('تنظیم کلید')),
      ]),
      Text('کلید ثبت‌شده: ${answerKey.length} از $count سؤال', style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 10),
      Builder(builder: (context) {
        final score = calculateAnswerScore(answers: answers, answerKey: answerKey, questionCount: count);
        return Row(children: [
          Expanded(child: _scoreMetric('درست', score.correct, const Color(0xFF198754))),
          Expanded(child: _scoreMetric('غلط', score.wrong, const Color(0xFFD94841))),
          Expanded(child: _scoreMetric('بی‌پاسخ', score.unanswered, muted)),
          Expanded(child: _scoreMetric('درصد', score.percentage.round(), purple, suffix: '%')),
        ]);
      }),
    ]))),
    const SizedBox(height: 16),
    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 1.35),
      itemBuilder: (context, index) {
        final n = index + 1;
        final isMarked = marked.contains(n);
        final answered = answers.containsKey(n);
        final bg = isMarked ? const Color(0xFFFFE9CF) : answered ? const Color(0xFFDCF4E8) : Theme.of(context).cardColor;
        return Material(color: bg, borderRadius: BorderRadius.circular(14), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => editAnswer(n),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (answered) Text(['الف', 'ب', 'ج', 'د'][answers[n]!], style: const TextStyle(fontSize: 11, color: muted)),
            if (isMarked) const Icon(Icons.flag_rounded, size: 12, color: Color(0xFFB86C11)),
          ])));
      }),
    const SizedBox(height: 16),
    Text('پاسخ‌ها: ${answers.length} از $count  •  علامت مرور: ${marked.length}',
      style: const TextStyle(color: muted, fontSize: 13)),
  ]);

  Widget legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, color: muted)),
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

  Future<void> addExam() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('پاسخ‌برگ جدید'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'نام آزمون', hintText: 'مثلاً آزمون ریاضی فصل اول'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          final value = nameController.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        }, child: const Text('ساختن')),
      ],
    ));
    nameController.dispose();
    if (name == null || name.trim().isEmpty) return;
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
    final controller = TextEditingController(text: activeExam.name);
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('تغییر نام آزمون'),
      content: TextField(controller: controller, autofocus: true, maxLength: 60,
        decoration: const InputDecoration(labelText: 'نام آزمون')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          final value = controller.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        }, child: const Text('ذخیره')),
      ],
    ));
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    setState(() => activeExam.name = name.trim());
    await save();
  }

  Future<void> deleteExam() async {
    if (exams.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک پاسخ‌برگ باید باقی بماند.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('حذف پاسخ‌برگ'),
      content: Text('«${activeExam.name}» و تمام پاسخ‌ها و کلید آن حذف شوند؟ این کار قابل بازگشت نیست.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
      ],
    ));
    if (confirmed != true) return;
    setState(() {
      final index = exams.indexWhere((exam) => exam.id == activeExamId);
      exams.removeWhere((exam) => exam.id == activeExamId);
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
        title: Text('سؤال $number'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(alignment: Alignment.centerRight, child: Text('گزینهٔ پاسخ')),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: List.generate(4, (i) => ChoiceChip(
            label: Text(['الف', 'ب', 'ج', 'د'][i]), selected: answer == i,
            onSelected: (_) => dialogSet(() => answer = answer == i ? null : i)))),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: flag, title: const Text('نیاز به مرور دارد'),
            onChanged: (value) => dialogSet(() => flag = value ?? false)),
          TextButton(onPressed: () => dialogSet(() => answer = null), child: const Text('پاک کردن پاسخ')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, (answer: answer, marked: flag)), child: const Text('ذخیره')),
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

  Widget _scoreMetric(String label, int value, Color color, {String suffix = ''}) => Column(children: [
    Text('$value$suffix', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: muted)),
  ]);

  Future<void> editAnswerKey() async {
    if (answerKey.length < count) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('تنظیم کلید پاسخ'),
        content: Text('برای محاسبه نتیجه، گزینه صحیح هر سؤال را وارد کن. فعلاً برای $count سؤال، کلید ${answerKey.length} سؤال ثبت شده است.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('بعداً')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('شروع')),
        ],
      ));
      if (!mounted || confirmed != true) return;
    }
    final result = await showDialog<Map<int, int>>(context: context, builder: (context) {
      final draft = Map<int, int>.from(answerKey);
      return StatefulBuilder(builder: (context, dialogSet) => AlertDialog(
        title: const Text('کلید پاسخ‌ها'),
        content: SizedBox(width: 420, height: 420, child: ListView.builder(
          itemCount: count,
          itemBuilder: (context, index) {
            final n = index + 1;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
              SizedBox(width: 52, child: Text('سؤال $n', style: const TextStyle(fontWeight: FontWeight.w700))),
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
          TextButton(onPressed: () => dialogSet(() => draft.clear()), child: const Text('پاک‌کردن کلید')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, draft), child: const Text('ذخیره کلید')),
        ],
      ));
    });
    if (result == null) return;
    setState(() { answerKey..clear()..addAll(result); });
    await save();
  }

  Widget settings() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('تنظیمات', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 6), const Text('ظاهر برنامه را مطابق سلیقه‌ات تنظیم کن.', style: TextStyle(color: muted)),
    const SizedBox(height: 18),
    Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.all(8), child: Text('پوسته برنامه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      RadioGroup<ThemeMode>(
        groupValue: widget.mode,
        onChanged: (value) {
          if (value != null) widget.onModeChanged(value);
        },
        child: const Column(children: [
          RadioListTile<ThemeMode>(contentPadding: EdgeInsets.zero, value: ThemeMode.system, title: Text('مطابق دستگاه')),
          RadioListTile<ThemeMode>(contentPadding: EdgeInsets.zero, value: ThemeMode.light, title: Text('روشن')),
          RadioListTile<ThemeMode>(contentPadding: EdgeInsets.zero, value: ThemeMode.dark, title: Text('تیره')),
        ]),
      ),
    ]))),
    const SizedBox(height: 12),
    const Card(child: ListTile(leading: Icon(Icons.phone_android_rounded, color: purple), title: Text('ذخیره‌سازی محلی'),
      subtitle: Text('وظایف و پاسخ‌ها روی همین دستگاه ذخیره می‌شوند.'))),
  ]);

  Widget emptyState(IconData icon, String title, String subtitle) => Container(padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(22)),
    child: Column(children: [
      Icon(icon, color: purple, size: 38), const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12, height: 1.6)),
    ]));

  Future<void> addTask() async {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final result = await showDialog<(String, String)>(context: context, builder: (context) => AlertDialog(
      title: const Text('وظیفه جدید'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'عنوان وظیفه')),
        const SizedBox(height: 10),
        TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'درس')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          final title = titleController.text.trim();
          if (title.isNotEmpty) Navigator.pop(context, (title, subjectController.text.trim()));
        }, child: const Text('افزودن')),
      ],
    ));
    titleController.dispose();
    subjectController.dispose();
    if (result == null) return;
    setState(() => tasks.add(StudyTask(DateTime.now().microsecondsSinceEpoch.toString(), result.$1, result.$2.isEmpty ? 'عمومی' : result.$2)));
    await save();
  }
}
