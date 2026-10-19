// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../posts/details/routes.dart';
import '../router.dart';

const _kMaxForwardEntries = 20;

/// Stacks the user went back from, most recent first, so they can be
/// reopened like a browser's forward button. Any new navigation clears it.
final navigationForwardProvider =
    NotifierProvider<NavigationForwardNotifier, List<RouteMatchList>>(
      NavigationForwardNotifier.new,
    );

class NavigationForwardNotifier extends Notifier<List<RouteMatchList>> {
  RouteMatchList? _last;
  int? _pendingRestore;

  @override
  List<RouteMatchList> build() {
    final delegate = ref.watch(routerProvider).routerDelegate;
    _last = delegate.currentConfiguration;

    void listener() => _onChanged(delegate.currentConfiguration);
    delegate.addListener(listener);
    ref.onDispose(() => delegate.removeListener(listener));

    return const [];
  }

  void _onChanged(RouteMatchList current) {
    final previous = _last;
    _last = current;
    if (previous == null || identical(previous, current)) return;

    if (_pendingRestore case final consumed?) {
      _pendingRestore = null;
      state = state.sublist(consumed);
      return;
    }

    state = switch (_compare(previous, current)) {
      _StackChange.popped => [
        previous,
        ...state,
      ].take(_kMaxForwardEntries).toList(),
      _StackChange.same => state,
      _StackChange.navigated => const [],
    };
  }

  void goForward(int index) {
    if (index < 0 || index >= state.length) return;

    _pendingRestore = index + 1;
    ref.read(routerProvider).restore(state[index]);
  }

  void goBack(int levels) {
    final router = ref.read(routerProvider);
    for (var i = 0; i < levels && router.canPop(); i++) {
      router.pop();
    }
  }
}

enum _StackChange { popped, same, navigated }

_StackChange _compare(RouteMatchList previous, RouteMatchList current) {
  final before = previous.matches;
  final after = current.matches;
  final shared = after.length < before.length ? after.length : before.length;

  for (var i = 0; i < shared; i++) {
    if (before[i].pageKey != after[i].pageKey) return _StackChange.navigated;
  }

  return switch (after.length - before.length) {
    < 0 => _StackChange.popped,
    0 => _StackChange.same,
    _ => _StackChange.navigated,
  };
}

/// Long-press target for back buttons: lists pages to jump back to and pages
/// the user went back from.
Future<void> showNavigationHistorySheet(BuildContext context, WidgetRef ref) {
  final router = ref.read(routerProvider);
  final forward = ref.read(navigationForwardProvider);
  final backMatches = router.routerDelegate.currentConfiguration.matches;
  final back = [
    for (var i = backMatches.length - 2; i >= 0; i--) backMatches[i],
  ];

  if (forward.isEmpty && back.isEmpty) return Future.value();

  return Kurumi.showAppModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      void close() => Navigator.of(sheetContext).pop();

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (forward.isNotEmpty) ...[
              _SectionHeader(context.t.navigation_history.forward),
              for (final (index, entry) in forward.indexed)
                ListTile(
                  leading: const Icon(Symbols.arrow_forward),
                  title: Text(_describeList(context, entry)),
                  onTap: () {
                    close();
                    ref
                        .read(navigationForwardProvider.notifier)
                        .goForward(index);
                  },
                ),
            ],
            if (back.isNotEmpty) ...[
              _SectionHeader(context.t.navigation_history.back),
              for (final (index, match) in back.indexed)
                ListTile(
                  leading: const Icon(Symbols.arrow_back),
                  title: Text(_describeMatch(context, match, null)),
                  onTap: () {
                    close();
                    ref
                        .read(navigationForwardProvider.notifier)
                        .goBack(index + 1);
                  },
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Kurumi.themeOf(context).textTheme.labelLarge,
      ),
    );
  }
}

String _describeList(BuildContext context, RouteMatchList list) =>
    switch (list.lastOrNull) {
      null => list.uri.path,
      final match => _describeMatch(context, match, list),
    };

String _describeMatch(
  BuildContext context,
  RouteMatchBase match,
  RouteMatchList? owner,
) {
  if (match is ImperativeRouteMatch) {
    return _describeList(context, match.matches);
  }

  final name = match is RouteMatch ? match.route.name : null;
  final uri = owner?.uri ?? Uri.parse(match.matchedLocation);
  final extra = owner?.extra;
  final query =
      uri.queryParameters[kInitialQueryKey] ?? uri.queryParameters['tags'];

  return switch (name) {
    '/details' || '/posts' => switch (extra) {
      DetailsRouteContext(:final posts, :final initialIndex)
          when initialIndex < posts.length =>
        '${context.t.navigation_history.post} #${posts[initialIndex].id}',
      _ => context.t.navigation_history.post,
    },
    '/search' || '/search_result' => switch (query) {
      final q? when q.isNotEmpty =>
        '${context.t.navigation_history.search}: $q',
      _ => context.t.navigation_history.search,
    },
    null || '/' => context.t.navigation_history.home,
    final n => _titleCase(n.split('/').last.replaceAll('_', ' ')),
  };
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
