// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../foundation/riverpod/riverpod.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';

final postCommentCountProvider = FutureProvider.autoDispose
    .family<int?, (BooruConfigAuth, int)>((ref, params) async {
      ref.cacheFor(const Duration(minutes: 5));

      final (auth, postId) = params;
      final repo = ref.watch(booruRepoProvider(auth))?.comment(auth);
      if (repo == null) return null;

      return (await repo.getComments(postId)).length;
    });

class CommentPostButton extends ConsumerWidget {
  const CommentPostButton({
    super.key,
    this.onPressed,
    this.postId,
    this.auth,
  });

  final VoidCallback? onPressed;
  final int? postId;
  final BooruConfigAuth? auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = switch ((auth, postId)) {
      (final a?, final id?) =>
        ref.watch(postCommentCountProvider((a, id))).valueOrNull,
      _ => null,
    };

    return KurumiTooltip(
      message: context.t.comment.comments,
      child: IconButton(
        splashRadius: 16,
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: count != null && count > 0,
          label: Text(count != null && count > 99 ? '99+' : '$count'),
          child: const Icon(
            Symbols.mode_comment,
          ),
        ),
      ),
    );
  }
}
