// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/downloads/urls/types.dart';
import '../client_provider.dart';
import 'file_url_extractor.dart';

final gelbooruV2ThumbnailOnlyDownloadFileUrlExtractorProvider =
    Provider.family<DownloadFileUrlExtractor, BooruConfigAuth>((ref, config) {
      return GelbooruV2ThumbnailOnlyDownloadFileUrlExtractor(
        client: ref.watch(gelbooruV2ClientProvider(config)),
      );
    });
