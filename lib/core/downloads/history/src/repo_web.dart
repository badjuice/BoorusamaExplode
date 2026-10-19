// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../types.dart';

final downloadedPostRepoProvider = FutureProvider<DownloadedPostRepository>(
  (ref) => InMemoryDownloadedPostRepository(),
);
