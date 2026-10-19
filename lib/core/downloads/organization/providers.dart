// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search pages register their query here while open, so downloads started
/// from them (or from posts opened from them) can be filed by search.
final activeSearchesProvider =
    NotifierProvider<ActiveSearchesNotifier, List<(Object, String)>>(
      ActiveSearchesNotifier.new,
    );

final activeSearchQueryProvider = Provider<String?>(
  (ref) => switch (ref.watch(activeSearchesProvider)) {
    [..., (_, final query)] when query.trim().isNotEmpty => query,
    _ => null,
  },
);

class ActiveSearchesNotifier extends Notifier<List<(Object, String)>> {
  @override
  List<(Object, String)> build() => const [];

  void set(Object owner, String query) {
    final index = state.indexWhere((e) => identical(e.$1, owner));

    state = switch (index) {
      -1 => [...state, (owner, query)],
      final i => [...state]..[i] = (owner, query),
    };
  }

  void remove(Object owner) {
    state = [
      for (final entry in state)
        if (!identical(entry.$1, owner)) entry,
    ];
  }
}
