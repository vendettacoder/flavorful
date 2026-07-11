import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// A numbered method step: a mono orange number beside the step body.
class MethodStep extends StatelessWidget {
  const MethodStep({super.key, required this.number, required this.body});

  /// Zero-padded step number, e.g. "01".
  final String number;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: 26,
            child: Text(number, style: AppText.stepNumber()),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(body, style: AppText.methodBody())),
      ],
    );
  }
}
