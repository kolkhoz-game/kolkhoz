import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:page_flip/page_flip.dart';

import 'design_tokens.dart';

const _notebookPageTurnDuration = Duration(milliseconds: 560);

class _NotebookBindingSuppression extends InheritedWidget {
  const _NotebookBindingSuppression({
    required this.suppressed,
    required super.child,
  });

  final bool suppressed;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_NotebookBindingSuppression>()
          ?.suppressed ??
      false;

  @override
  bool updateShouldNotify(_NotebookBindingSuppression oldWidget) =>
      oldWidget.suppressed != suppressed;
}

/// Lazily retains visited menu pages while exposing a single active child API.
/// This keeps expensive menu destinations out of the tree until first use.
class NotebookMenuSwitcher extends StatefulWidget {
  const NotebookMenuSwitcher({
    super.key,
    required this.pageCount,
    required this.pageIndex,
    required this.child,
    required this.tokens,
    this.showBinding = false,
    this.compactBinding = false,
    this.keyPrefix = 'notebook',
    this.animate = true,
    this.retainedPages = const {},
    this.showBindingWhileTurning = false,
  }) : assert(pageCount > 0),
       assert(pageIndex >= 0 && pageIndex < pageCount);

  final int pageCount;
  final int pageIndex;
  final Widget child;
  final DesignTokens tokens;
  final bool showBinding;
  final bool compactBinding;
  final String keyPrefix;
  final bool animate;
  final Map<int, Widget> retainedPages;
  final bool showBindingWhileTurning;

  @override
  State<NotebookMenuSwitcher> createState() => _NotebookMenuSwitcherState();
}

class _NotebookMenuSwitcherState extends State<NotebookMenuSwitcher> {
  late List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(widget.pageCount, null);
    for (final entry in widget.retainedPages.entries) {
      _pages[entry.key] = entry.value;
    }
    _pages[widget.pageIndex] = widget.child;
  }

  @override
  void didUpdateWidget(covariant NotebookMenuSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageCount != oldWidget.pageCount) {
      final resized = List<Widget?>.filled(widget.pageCount, null);
      for (
        var index = 0;
        index < math.min(_pages.length, resized.length);
        index += 1
      ) {
        resized[index] = _pages[index];
      }
      _pages = resized;
    }
    for (final entry in widget.retainedPages.entries) {
      _pages[entry.key] = entry.value;
    }
    _pages[widget.pageIndex] = widget.child;
  }

  @override
  Widget build(BuildContext context) => NotebookPageSwitcher(
    pageIndex: widget.pageIndex,
    pages: [for (final page in _pages) page ?? const SizedBox.shrink()],
    tokens: widget.tokens,
    showBinding: widget.showBinding,
    compactBinding: widget.compactBinding,
    keyPrefix: widget.keyPrefix,
    animate: widget.animate,
    showBindingWhileTurning: widget.showBindingWhileTurning,
  );
}

/// Turns substantial menu panels as ordered notebook pages while preserving
/// every page's state offstage.
class NotebookPageSwitcher extends StatefulWidget {
  const NotebookPageSwitcher({
    super.key,
    required this.pageIndex,
    required this.pages,
    required this.tokens,
    this.showBinding = false,
    this.compactBinding = false,
    this.keyPrefix = 'notebook',
    this.animate = true,
    this.showBindingWhileTurning = false,
  }) : assert(pageIndex >= 0 && pageIndex < pages.length);

  final int pageIndex;
  final List<Widget> pages;
  final DesignTokens tokens;
  final bool showBinding;
  final bool compactBinding;
  final String keyPrefix;
  final bool animate;
  final bool showBindingWhileTurning;

  @override
  State<NotebookPageSwitcher> createState() => _NotebookPageSwitcherState();
}

class _NotebookPageSwitcherState extends State<NotebookPageSwitcher>
    with SingleTickerProviderStateMixin {
  late List<GlobalKey> _pageBoundaryKeys;
  late final AnimationController _curlController;
  late int _visiblePageIndex;
  int? _targetPageIndex;
  int? _preparingBackwardTargetIndex;
  ui.Image? _pageSnapshot;
  bool _capturing = false;
  bool _turningBackward = false;

  bool get _animating => _capturing || _pageSnapshot != null;

  @override
  void initState() {
    super.initState();
    _visiblePageIndex = widget.pageIndex;
    _pageBoundaryKeys = List.generate(widget.pages.length, (_) => GlobalKey());
    _curlController = AnimationController(
      value: 1,
      duration: _notebookPageTurnDuration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant NotebookPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pages.length != oldWidget.pages.length) {
      _pageBoundaryKeys = List.generate(
        widget.pages.length,
        (_) => GlobalKey(),
      );
    }
    if (widget.pageIndex != _visiblePageIndex && !_animating) {
      if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
        _visiblePageIndex = widget.pageIndex;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _turnTo(widget.pageIndex);
        }
      });
    }
  }

  Future<void> _turnTo(int targetPageIndex) async {
    if (_animating || targetPageIndex == _visiblePageIndex) {
      return;
    }
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      setState(() => _visiblePageIndex = targetPageIndex);
      return;
    }
    final turningBackward = targetPageIndex < _visiblePageIndex;
    setState(() {
      _capturing = true;
      _preparingBackwardTargetIndex = turningBackward ? targetPageIndex : null;
    });
    if (turningBackward) {
      // Paint the previous page behind the current one for one frame so it can
      // be captured, then unfold that page back over the current page.
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) {
      return;
    }
    final boundary =
        _pageBoundaryKeys[targetPageIndex < _visiblePageIndex
                ? targetPageIndex
                : _visiblePageIndex]
            .currentContext
            ?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      setState(() {
        _capturing = false;
        _preparingBackwardTargetIndex = null;
        _visiblePageIndex = targetPageIndex;
      });
      return;
    }
    final snapshot = await boundary.toImage(
      pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 1.5),
    );
    if (!mounted) {
      snapshot.dispose();
      return;
    }
    _curlController.value = turningBackward ? 0 : 1;
    setState(() {
      _capturing = false;
      _preparingBackwardTargetIndex = null;
      _targetPageIndex = targetPageIndex;
      _pageSnapshot = snapshot;
      _turningBackward = turningBackward;
    });
    if (turningBackward) {
      await _curlController.forward();
    } else {
      await _curlController.reverse();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _visiblePageIndex = targetPageIndex;
      _targetPageIndex = null;
      _turningBackward = false;
      _pageSnapshot?.dispose();
      _pageSnapshot = null;
      _curlController.value = 1;
    });
    if (widget.pageIndex != _visiblePageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _turnTo(widget.pageIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageSnapshot?.dispose();
    _curlController.dispose();
    super.dispose();
  }

  Widget _pageLayer(
    int pageIndex, {
    required bool onstage,
    bool excludeSemantics = false,
  }) {
    return KeyedSubtree(
      key: ValueKey('notebook-page-layer-$pageIndex'),
      child: Offstage(
        offstage: !onstage,
        child: TickerMode(
          enabled: onstage,
          child: ExcludeSemantics(
            excluding: excludeSemantics,
            child: RepaintBoundary(
              key: _pageBoundaryKeys[pageIndex],
              child: _NotebookBindingSuppression(
                suppressed: _animating,
                child: widget.pages[pageIndex],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageViewport({required bool showBinding, required bool compact}) {
    final snapshot = _pageSnapshot;
    final presentedPageIndex = snapshot != null && !_turningBackward
        ? _targetPageIndex!
        : _visiblePageIndex;
    final preparingBackwardTargetIndex = _preparingBackwardTargetIndex;
    final onstageIndices = {presentedPageIndex, ?preparingBackwardTargetIndex};
    final bindingWidth = compact ? 30.0 : 44.0;
    return ClipRect(
      key: Key('${widget.keyPrefix}-page-viewport'),
      child: AbsorbPointer(
        key: Key('${widget.keyPrefix}-page-turn-input-guard'),
        absorbing: _animating,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < widget.pages.length; index += 1)
              if (!onstageIndices.contains(index))
                _pageLayer(index, onstage: false),
            if (preparingBackwardTargetIndex != null)
              _pageLayer(
                preparingBackwardTargetIndex,
                onstage: true,
                excludeSemantics: true,
              ),
            _pageLayer(presentedPageIndex, onstage: true),
            if (showBinding)
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                width: bindingWidth,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: Key('${widget.keyPrefix}-binding-rear'),
                      painter: _NotebookBindingRearPainter(
                        widget.tokens,
                        compact,
                      ),
                    ),
                  ),
                ),
              ),
            if (snapshot != null)
              ExcludeSemantics(
                child: CustomPaint(
                  key: Key('${widget.keyPrefix}-page-curl'),
                  painter: PageFlipEffect(
                    amount: _curlController,
                    image: snapshot,
                    backgroundColor: widget.tokens.colors.panel,
                    // Back navigation advances the curl controller to unfold
                    // the previous page. isRightSwipe changes reading order.
                    isRightSwipe: false,
                  ),
                ),
              ),
            if (showBinding && snapshot != null)
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                width: bindingWidth,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: Key('${widget.keyPrefix}-binding-contact'),
                      painter: _NotebookBindingContactPainter(
                        widget.tokens,
                        compact,
                        _curlController,
                        turningBackward: _turningBackward,
                      ),
                    ),
                  ),
                ),
              ),
            if (showBinding)
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                width: bindingWidth,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: Key('${widget.keyPrefix}-notebook-binding'),
                      painter: _NotebookBindingFrontPainter(
                        widget.tokens,
                        compact,
                        _curlController,
                        turnActive: snapshot != null,
                        turningBackward: _turningBackward,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bindingSuppressed = _NotebookBindingSuppression.of(context);
    final showBinding =
        !bindingSuppressed &&
        (widget.showBinding || (widget.showBindingWhileTurning && _animating));
    if (!showBinding) {
      return _pageViewport(showBinding: false, compact: false);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = widget.compactBinding || constraints.maxWidth < 720;
        return _pageViewport(showBinding: true, compact: compact);
      },
    );
  }
}

double _bindingSeamX(Size size) => size.width * 0.62;

Iterable<double> _bindingRingYs(Size size, bool compact) sync* {
  final spacing = compact ? 58.0 : 72.0;
  final start = math.max(32.0, (size.height % spacing) / 2 + 16);
  for (var y = start; y < size.height - 22; y += spacing) {
    yield y;
  }
}

Offset _bindingHoleCenter(Size size, bool compact, double y) =>
    Offset(_bindingSeamX(size) + (compact ? 4 : 6), y);

Path _rearRingPath(Size size, bool compact, double y) {
  final seamX = _bindingSeamX(size);
  final holeCenter = _bindingHoleCenter(size, compact, y);
  final halfHeight = compact ? 7.0 : 9.0;
  final ringEndX = holeCenter.dx + (compact ? 3 : 4);
  return Path()
    ..moveTo(ringEndX + 4, y)
    ..cubicTo(
      ringEndX + 5,
      y + halfHeight,
      seamX + 2,
      y + halfHeight,
      seamX - 4,
      y + halfHeight,
    )
    ..lineTo(2, y + halfHeight);
}

Path _frontRingPath(Size size, bool compact, double y) {
  final seamX = _bindingSeamX(size);
  final holeCenter = _bindingHoleCenter(size, compact, y);
  final halfHeight = compact ? 7.0 : 9.0;
  final ringEndX = holeCenter.dx + (compact ? 3 : 4);
  return Path()
    ..moveTo(2, y - halfHeight)
    ..lineTo(seamX - 4, y - halfHeight)
    ..cubicTo(
      ringEndX + 5,
      y - halfHeight,
      ringEndX + 5,
      y - 1,
      ringEndX + 4,
      y + 1,
    );
}

Paint _ringPaint(
  DesignTokens tokens,
  bool compact,
  Rect shaderRect, {
  double highlight = 0,
}) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(tokens.colors.goldBright, Colors.white, highlight)!,
      tokens.colors.gold,
      tokens.colors.black.withValues(alpha: 0.68),
      tokens.colors.gold,
    ],
    stops: const [0, 0.3, 0.64, 1],
  ).createShader(shaderRect)
  ..style = PaintingStyle.stroke
  ..strokeWidth = compact ? 4 : 5
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _NotebookBindingRearPainter extends CustomPainter {
  const _NotebookBindingRearPainter(this.tokens, this.compact);

  final DesignTokens tokens;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final seamX = _bindingSeamX(size);
    canvas.drawLine(
      Offset(seamX, 8),
      Offset(seamX, size.height - 8),
      Paint()
        ..color = tokens.colors.black.withValues(alpha: 0.48)
        ..strokeWidth = compact ? 1.5 : 2,
    );
    for (final y in _bindingRingYs(size, compact)) {
      final holeCenter = _bindingHoleCenter(size, compact, y);
      canvas.drawCircle(
        holeCenter.translate(1.5, 2),
        compact ? 6.5 : 8,
        Paint()..color = tokens.colors.black.withValues(alpha: 0.34),
      );
      canvas.drawCircle(
        holeCenter,
        compact ? 5.5 : 7,
        Paint()..color = tokens.colors.black.withValues(alpha: 0.78),
      );
      canvas.drawCircle(
        holeCenter,
        compact ? 3.5 : 4.5,
        Paint()..color = tokens.colors.panel.withValues(alpha: 0.72),
      );
      final halfHeight = compact ? 7.0 : 9.0;
      final rearRing = _rearRingPath(size, compact, y);
      canvas.drawPath(
        rearRing.shift(const Offset(1.5, 2.5)),
        Paint()
          ..color = tokens.colors.black.withValues(alpha: 0.58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 6 : 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        rearRing,
        _ringPaint(
          tokens,
          compact,
          Rect.fromLTRB(0, y - halfHeight, size.width, y + halfHeight),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_NotebookBindingRearPainter oldDelegate) =>
      oldDelegate.tokens != tokens || oldDelegate.compact != compact;
}

class _NotebookBindingFrontPainter extends CustomPainter {
  _NotebookBindingFrontPainter(
    this.tokens,
    this.compact,
    this.amount, {
    required this.turnActive,
    required this.turningBackward,
  }) : super(repaint: amount);

  final DesignTokens tokens;
  final bool compact;
  final Animation<double> amount;
  final bool turnActive;
  final bool turningBackward;

  double get _lift {
    if (!turnActive) return 0;
    final phase = turningBackward ? amount.value : 1 - amount.value;
    return math.sin(phase * math.pi).clamp(0, 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lift = _lift;
    for (final y in _bindingRingYs(size, compact)) {
      final halfHeight = compact ? 7.0 : 9.0;
      final frontRing = _frontRingPath(size, compact, y);
      canvas.drawPath(
        frontRing.shift(const Offset(1.5, 2.5)),
        Paint()
          ..color = tokens.colors.black.withValues(alpha: 0.58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 6 : 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        frontRing,
        _ringPaint(
          tokens,
          compact,
          Rect.fromLTRB(0, y - halfHeight, size.width, y + halfHeight),
          highlight: 0.18 * lift,
        ),
      );
      canvas.drawPath(
        Path()
          ..moveTo(3, y - halfHeight - 0.8)
          ..lineTo(_bindingSeamX(size) - 5, y - halfHeight - 0.8),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 + 0.28 * lift)
          ..strokeWidth = 1.1 + 0.35 * lift
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_NotebookBindingFrontPainter oldDelegate) =>
      oldDelegate.tokens != tokens ||
      oldDelegate.compact != compact ||
      oldDelegate.turnActive != turnActive ||
      oldDelegate.turningBackward != turningBackward;
}

class _NotebookBindingContactPainter extends CustomPainter {
  _NotebookBindingContactPainter(
    this.tokens,
    this.compact,
    this.amount, {
    required this.turningBackward,
  }) : super(repaint: amount);

  final DesignTokens tokens;
  final bool compact;
  final Animation<double> amount;
  final bool turningBackward;

  double get _contact {
    final phase = turningBackward ? amount.value : 1 - amount.value;
    final localPhase = turningBackward
        ? (phase / 0.48).clamp(0.0, 1.0)
        : ((phase - 0.52) / 0.48).clamp(0.0, 1.0);
    return math.sin(localPhase * math.pi).clamp(0, 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final contact = _contact;
    if (contact <= 0.001) return;
    final seamX = _bindingSeamX(size);
    final shadowRect = Rect.fromLTWH(
      seamX - (turningBackward ? 3 : 9),
      6,
      16,
      size.height - 12,
    );
    canvas.drawRect(
      shadowRect,
      Paint()
        ..shader = LinearGradient(
          begin: turningBackward ? Alignment.centerRight : Alignment.centerLeft,
          end: turningBackward ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            tokens.colors.black.withValues(alpha: 0.24 * contact),
            tokens.colors.goldBright.withValues(alpha: 0.16 * contact),
            Colors.transparent,
          ],
          stops: const [0, 0.28, 1],
        ).createShader(shadowRect),
    );
    for (final y in _bindingRingYs(size, compact)) {
      final center = _bindingHoleCenter(size, compact, y);
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(turningBackward ? -2 : 2, 1.5),
          width: compact ? 17 : 21,
          height: compact ? 11 : 14,
        ),
        Paint()
          ..color = tokens.colors.black.withValues(alpha: 0.16 * contact)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(_NotebookBindingContactPainter oldDelegate) =>
      oldDelegate.tokens != tokens ||
      oldDelegate.compact != compact ||
      oldDelegate.turningBackward != turningBackward;
}
