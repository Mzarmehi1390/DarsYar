import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/modal_content.dart';

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
  Widget build(BuildContext context) {
    final scrollData = ScrollControllerProvider.of(context);
        return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollData?.controller,
            physics: scrollData?.physics,
            child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'بازیابی نسخه پشتیبان',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'محتوای فایل پشتیبان را اینجا جای‌گذاری کن. اطلاعات فعلی پس از تأیید جایگزین می‌شوند.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.45,
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
          ),
        ),
            ],
          ),
        ),
      ),
      const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
            child: Row(
          children: [
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => Navigator.of(context).pop(),
                child: const DarsYarModalButtonLabel(child: Text('انصراف')),
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
                child: const DarsYarModalButtonLabel(
                  primary: true,
                  child: Text('بررسی نسخه'),
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ],
    );
  }
}
