import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_button.dart';
import '../../../design_system/glass_surface.dart';
import '../../../design_system/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.animationsEnabled,
    required this.onAnimationsChanged,
    required this.onExportBackup,
    required this.onImportBackup,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  final bool animationsEnabled;
  final ValueChanged<bool> onAnimationsChanged;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;

@override
  Widget build(BuildContext context) => ListView(key: const PageStorageKey<String>('settings-scroll'), padding: const EdgeInsets.fromLTRB(20, 20, 20, DarsYarTokens.pageBottomClearance), children: [
    const DarsYarPageHeader(
      title: 'تنظیمات',
      subtitle: 'ظاهر و نگهداری اطلاعات برنامه را مدیریت کن.',
      icon: Icons.tune_rounded,
    ),
    SizedBox(height: 18),
    DarsYarContentSurface(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.all(8), child: Text('پوسته برنامه', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      GlassSegmentedControl(
        segments: const [
          GlassSegment(label: 'سیستم', semanticLabel: 'مطابق دستگاه'),
          GlassSegment(label: 'روشن', semanticLabel: 'پوسته روشن'),
          GlassSegment(label: 'تیره', semanticLabel: 'پوسته تیره'),
        ],
        selectedIndex: mode == ThemeMode.system
            ? 0
            : mode == ThemeMode.light
                ? 1
                : 2,
        onSegmentSelected: (index) => onModeChanged(
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
    Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onAnimationsChanged(!animationsEnabled),
        child: DarsYarContentSurface(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: DarsYarTokens.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    animationsEnabled
                        ? Icons.motion_photos_on_rounded
                        : Icons.motion_photos_off_rounded,
                    color: DarsYarTokens.accent,
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
                        animationsEnabled
                            ? 'حرکت‌ها و جابه‌جایی‌های نرم فعال هستند.'
                            : 'حالت سبک: حرکت‌های کوتاه و کم‌جلوه اجرا می‌شوند.',
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
                IgnorePointer(
                  child: GlassSwitch(
                    value: animationsEnabled,
                    activeColor: DarsYarTokens.accent,
                    semanticLabel: 'روشن یا خاموش کردن انیمیشن‌های برنامه',
                    quality: GlassQuality.standard,
                    onChanged: onAnimationsChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    SizedBox(height: 12),
    DarsYarContentSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: DarsYarTokens.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.phone_android_rounded, color: DarsYarTokens.accent, size: 21),
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
    DarsYarContentSurface(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.backup_outlined, color: DarsYarTokens.accent),
          SizedBox(width: 8),
          Expanded(child: Text('پشتیبان‌گیری و بازیابی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        SizedBox(height: 6),
        Text('از وظایف، برنامه مطالعه، پاسخ‌برگ‌ها و نتایج آزمون نسخه پشتیبان بساز یا آن‌ها را بازیابی کن.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: DarsYarGlassButton(
            height: 48,
            radius: 16,
            quality: GlassQuality.standard,
            style: GlassButtonStyle.prominent,
            onTap: onExportBackup,
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
          child: DarsYarGlassButton(
            height: 48,
            radius: 16,
            quality: GlassQuality.standard,
            style: GlassButtonStyle.filled,
            onTap: onImportBackup,
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
}
