import 'dart:async';

import 'package:flutter/widgets.dart';

class DeadlineCountdownBuilder extends StatefulWidget {
  const DeadlineCountdownBuilder({
    required this.deadlineEpochSeconds,
    required this.builder,
    this.maxSeconds = 999,
    this.now = DateTime.now,
    super.key,
  });

  final double? deadlineEpochSeconds;
  final int maxSeconds;
  final DateTime Function() now;
  final Widget Function(BuildContext context, int? seconds) builder;

  @override
  State<DeadlineCountdownBuilder> createState() =>
      _DeadlineCountdownBuilderState();
}

class _DeadlineCountdownBuilderState extends State<DeadlineCountdownBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(DeadlineCountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadlineEpochSeconds != widget.deadlineEpochSeconds) {
      _reset();
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _scheduleNextTick();
  }

  int? get _seconds {
    final deadline = widget.deadlineEpochSeconds;
    if (deadline == null) {
      return null;
    }
    final remaining =
        (deadline * Duration.millisecondsPerSecond).round() -
        widget.now().millisecondsSinceEpoch;
    return (remaining / Duration.millisecondsPerSecond).ceil().clamp(
      0,
      widget.maxSeconds,
    );
  }

  void _scheduleNextTick() {
    final deadline = widget.deadlineEpochSeconds;
    if (deadline == null) {
      return;
    }
    final remaining =
        (deadline * Duration.millisecondsPerSecond).round() -
        widget.now().millisecondsSinceEpoch;
    if (remaining <= 0) {
      return;
    }
    final partialSecond = remaining % Duration.millisecondsPerSecond;
    _timer = Timer(
      Duration(
        milliseconds: partialSecond == 0
            ? Duration.millisecondsPerSecond
            : partialSecond + 1,
      ),
      () {
        if (!mounted) {
          return;
        }
        setState(() {});
        _scheduleNextTick();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _seconds);
}
