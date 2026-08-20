import 'package:flutter/material.dart';

import '../design/tokens.dart';

class SvnlyWordmark extends StatelessWidget {
  const SvnlyWordmark({super.key, this.fontSize = 28, this.centered = false});
  final double fontSize;
  final bool centered;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SVNLY',
    header: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Text(
          'S',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        Text(
          'V',
          style: TextStyle(
            color: SvnlyColors.lime,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        Text(
          'NLY',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ],
    ),
  );
}

class RuleChips extends StatelessWidget {
  const RuleChips({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _RuleChip('7 seconds'),
      _RuleChip('1 take'),
      _RuleChip('no uploads'),
      _RuleChip('no edits'),
    ],
  );
}

class _RuleChip extends StatelessWidget {
  const _RuleChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: SvnlyColors.surface,
      borderRadius: BorderRadius.circular(SvnlyRadius.pill),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class AsyncActionButton extends StatefulWidget {
  const AsyncActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.destructive = false,
  });
  final String label;
  final Future<void> Function() onPressed;
  final bool destructive;

  @override
  State<AsyncActionButton> createState() => _AsyncActionButtonState();
}

class _AsyncActionButtonState extends State<AsyncActionButton> {
  bool loading = false;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: widget.destructive
        ? FilledButton.styleFrom(
            backgroundColor: SvnlyColors.error,
            foregroundColor: SvnlyColors.text,
          )
        : null,
    onPressed: loading
        ? null
        : () async {
            setState(() => loading = true);
            try {
              await widget.onPressed();
            } finally {
              if (mounted) setState(() => loading = false);
            }
          },
    child: loading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(widget.label),
  );
}
