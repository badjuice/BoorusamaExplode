// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../foundation/info/device_info.dart';
import '../../../../../foundation/permissions.dart';
import '../../../../../foundation/picker.dart';
import '../../../../../foundation/platform.dart';
import '../../../../router.dart';
import '../../../../settings/providers.dart';
import '../../../path/types.dart';

enum _LocationChoice { useDefault, choose }

/// Makes sure downloads have somewhere they can be written to.
///
/// Returns the folder to download into, an empty string for the default
/// folder, or null when the user backed out.
Future<String?> resolveDownloadLocation(
  Ref ref, {
  String? requestedPath,
}) async {
  if (!isAndroid()) return requestedPath;

  final context = ref
      .read(appNavigationProvider)
      .navigatorKey
      .currentState
      ?.context;
  if (context == null || !context.mounted) return requestedPath;

  final settings = ref.read(settingsProvider);
  var path = requestedPath ?? settings.downloadPath ?? '';

  if (path.isEmpty && !settings.downloadPathPrompted) {
    final choice = await showDialog<_LocationChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.download.location.title),
        content: Text(
          context.t.download.location.default_description.replaceAll(
            '{path}',
            kDefaultAndroidDownloadPath,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LocationChoice.choose),
            child: Text(context.t.download.location.choose),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_LocationChoice.useDefault),
            child: Text(context.t.download.location.use_default),
          ),
        ],
      ),
    );
    if (!context.mounted) return null;

    String? picked;
    switch (choice) {
      case null:
        return null;
      case _LocationChoice.useDefault:
        break;
      case _LocationChoice.choose:
        await pickDirectoryPathToastOnError(
          context: context,
          picker: ref.read(appFilePickerProvider),
          onPick: (p) => picked = p,
        );
        if (picked == null) return null;
    }

    path = picked ?? '';
    await ref
        .read(settingsNotifierProvider.notifier)
        .updateSettings(
          ref
              .read(settingsProvider)
              .copyWith(
                downloadPathPrompted: true,
                downloadPath: picked,
              ),
        );
  }

  if (!context.mounted) return null;

  final granted = await ensureDownloadFolderAccess(
    context,
    path,
    sdkInt: ref.read(deviceInfoProvider).androidDeviceInfo?.version.sdkInt,
  );

  return granted ? path : null;
}

/// Asks for "All files access" when [path] is outside the shared folders on
/// Android 11+. Returns whether the app can write to [path].
Future<bool> ensureDownloadFolderAccess(
  BuildContext context,
  String path, {
  required int? sdkInt,
}) async {
  final needsAccess = switch (PathInfo.from(path)) {
    final AndroidPathInfo info => info.requiresPublicDirectory(sdkInt),
    _ => false,
  };
  if (!needsAccess || await hasAllFilesAccess()) return true;
  if (!context.mounted) return false;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.download.location.all_files_title),
      content: Text(
        context.t.download.location.all_files_description.replaceAll(
          '{path}',
          path,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.t.download.location.all_files_continue),
        ),
      ],
    ),
  );

  final granted = (proceed ?? false) && await requestAllFilesAccess();
  if (!granted && context.mounted) {
    Kurumi.showErrorToast(
      context,
      context.t.download.location.all_files_denied.replaceAll('{path}', path),
      duration: const Duration(seconds: 5),
    );
  }

  return granted;
}
