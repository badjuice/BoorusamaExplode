// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/info/app_info.dart';
import '../../../../foundation/info/package_info.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    final appInfo = ref.watch(appInfoProvider);

    return AboutDialog(
      applicationIcon: Image.asset(
        'assets/icon/icon-512x512.png',
        width: 64,
        height: 64,
      ),
      applicationVersion: packageInfo.version,
      applicationLegalese: _legaleseFromAppInfo(appInfo),
      applicationName: appInfo.appName,
    );
  }
}

String _legaleseFromAppInfo(AppInfo appInfo) =>
    'A fork of Boorusama, \u{a9} ${appInfo.copyrightYearRange.start}-${appInfo.copyrightYearRange.end} ${appInfo.author}.\n'
    'Fork: ${appInfo.githubUrl}';
