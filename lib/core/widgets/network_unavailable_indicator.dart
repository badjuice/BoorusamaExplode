// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class NetworkUnavailableIndicator extends StatelessWidget {
  const NetworkUnavailableIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final message = context.t.network.unavailable;

    return Semantics(
      label: message,
      liveRegion: true,
      excludeSemantics: true,
      child: Material(
        color: colorScheme.inverseSurface.withValues(alpha: 0.9),
        shape: const StadiumBorder(),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.wifi_off,
                size: 14,
                color: colorScheme.onInverseSurface,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  message,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
