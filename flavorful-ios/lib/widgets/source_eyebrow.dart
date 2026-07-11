import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Mono uppercase orange label showing a recipe's source hostname.
class SourceEyebrow extends StatelessWidget {
  const SourceEyebrow(this.hostname, {super.key});

  final String hostname;

  @override
  Widget build(BuildContext context) {
    return Text(
      hostname.toUpperCase(),
      style: AppText.sourceEyebrow(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
