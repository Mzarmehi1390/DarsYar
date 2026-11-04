import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class BackupImportDialog extends StatefulWidget {
  const BackupImportDialog({super.key});

  @override
  State<BackupImportDialog> createState() => BackupImportDialogState();
}

class BackupImportDialogState extends State<BackupImportDialog> {
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
