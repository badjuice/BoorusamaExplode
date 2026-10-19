// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../foundation/networking.dart';
import 'network_unavailable_indicator.dart';

class NetworkUnavailableIndicatorWithState extends ConsumerWidget {
  const NetworkUnavailableIndicatorWithState({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNetworkUnavailable = ref.watch(
      networkStateProvider.select((state) => state is NetworkDisconnectedState),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom + 72,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: isNetworkUnavailable ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Center(
            child: NetworkUnavailableIndicator(),
          ),
        ),
      ),
    );
  }
}
