import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catapp/Models/question.dart';

import '/models/breed.dart';
import '/screens/breedDetail.dart';
import 'globals.dart' as globals;
import '../theme.dart';
import '../widgets/design_system.dart';
import '../gold_frame/gold_frame_panel.dart';

class Fit extends StatefulWidget {
  const Fit({Key? key}) : super(key: key);

  @override
  FitState createState() {
    return FitState();
  }
}

/// Rounded rectangle balloon that displays a GIF inside.
/// Black fill, gold border, with a gold tail centered horizontally.
/// Can be flipped so tail points upward instead of downward.
class RoundedBalloon extends StatelessWidget {
  final String gifAssetPath;
  final double width;
  final double height;
  final bool flipped; // If true, tail points upward (balloon below card)

  const RoundedBalloon({
    Key? key,
    required this.gifAssetPath,
    this.width = 200,
    this.height = 160, // slightly taller to nicely fit the GIF
    this.flipped = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoundedBalloonPainter(
        bubbleColor: Colors.black,
        borderColor: AppTheme.goldBase,
        borderRadius: 22.0,
        flipped: flipped,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Image.asset(
              gifAssetPath,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) {
                return const Icon(Icons.pets, color: Colors.white54, size: 40);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundedBalloonPainter extends CustomPainter {
  final Color bubbleColor;
  final Color borderColor;
  final double borderRadius;
  final bool flipped; // If true, tail points upward

  _RoundedBalloonPainter({
    required this.bubbleColor,
    required this.borderColor,
    this.borderRadius = 20.0,
    this.flipped = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    const double tailHeight = 22.0;
    final double bubbleHeight = h - tailHeight;
    final double centerX = w / 2;
    const double tailWidth = 28.0;

    // Create a single path that combines the rounded rectangle with an open side
    // that seamlessly connects to the tail (top if flipped, bottom if not)
    final Path combinedPath = Path();

    if (flipped) {
      // Tail at top (balloon below card)
      // Create a single path that combines the rounded rectangle with an open top
      // that seamlessly connects to the tail
      final double roundedRectTop = tailHeight;
      final double roundedRectBottom = h;
      
      // Start at top-left corner (after rounded corner)
      combinedPath.moveTo(borderRadius, roundedRectTop);

      // Top edge (left side, up to where tail connects)
      combinedPath.lineTo(centerX - tailWidth / 2, roundedRectTop);

      // Tail: upward-pointing triangle
      combinedPath.lineTo(centerX, 0);
      combinedPath.lineTo(centerX + tailWidth / 2, roundedRectTop);

      // Top edge (right side, after tail)
      combinedPath.lineTo(w - borderRadius, roundedRectTop);

      // Top-right rounded corner
      combinedPath.arcToPoint(
        Offset(w, roundedRectTop + borderRadius),
        radius: Radius.circular(borderRadius),
      );

      // Right edge
      combinedPath.lineTo(w, roundedRectBottom - borderRadius);

      // Bottom-right rounded corner
      combinedPath.arcToPoint(
        Offset(w - borderRadius, roundedRectBottom),
        radius: Radius.circular(borderRadius),
      );

      // Bottom edge
      combinedPath.lineTo(borderRadius, roundedRectBottom);

      // Bottom-left rounded corner
      combinedPath.arcToPoint(
        Offset(0, roundedRectBottom - borderRadius),
        radius: Radius.circular(borderRadius),
      );

      // Left edge
      combinedPath.lineTo(0, roundedRectTop + borderRadius);

      // Top-left rounded corner
      combinedPath.arcToPoint(
        Offset(borderRadius, roundedRectTop),
        radius: Radius.circular(borderRadius),
      );

      combinedPath.close();
    } else {
      // Tail at bottom (balloon above card) - original code
      // Start at top-left corner (after rounded corner)
      combinedPath.moveTo(borderRadius, 0);

      // Top edge
      combinedPath.lineTo(w - borderRadius, 0);

      // Top-right rounded corner
      combinedPath.arcToPoint(
        Offset(w, borderRadius),
        radius: Radius.circular(borderRadius),
      );

      // Right edge
      combinedPath.lineTo(w, bubbleHeight - borderRadius);

      // Bottom-right rounded corner (partial - only the right half)
      combinedPath.arcToPoint(
        Offset(w - borderRadius, bubbleHeight),
        radius: Radius.circular(borderRadius),
      );

      // Right side of bottom opening (where tail connects)
      combinedPath.lineTo(centerX + tailWidth / 2, bubbleHeight);

      // Tail: downward-pointing triangle
      final double tailBottomY = h;
      combinedPath.lineTo(centerX, tailBottomY);
      combinedPath.lineTo(centerX - tailWidth / 2, bubbleHeight);

      // Left side of bottom opening
      combinedPath.lineTo(borderRadius, bubbleHeight);

      // Bottom-left rounded corner (partial - only the left half)
      combinedPath.arcToPoint(
        Offset(0, bubbleHeight - borderRadius),
        radius: Radius.circular(borderRadius),
      );

      // Left edge
      combinedPath.lineTo(0, borderRadius);

      // Top-left rounded corner
      combinedPath.arcToPoint(
        Offset(borderRadius, 0),
        radius: Radius.circular(borderRadius),
      );
    }

    combinedPath.close();

    final Paint fill = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;

    final Paint stroke = Paint()
      ..color = borderColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(combinedPath, fill);
    canvas.drawPath(combinedPath, stroke);
  }

  @override
  bool shouldRepaint(covariant _RoundedBalloonPainter oldDelegate) {
    return oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.flipped != flipped;
  }
}

/// Animated wrapper that gives the balloon a "pop" scale-in effect.
class _BalloonAnimated extends StatefulWidget {
  final String gifAssetPath;

  const _BalloonAnimated({Key? key, required this.gifAssetPath}) : super(key: key);

  @override
  State<_BalloonAnimated> createState() => _BalloonAnimatedState();
}

class _BalloonAnimatedState extends State<_BalloonAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const SizedBox(
        // Outer sizing is handled by RoundedBalloon itself; this wrapper only scales it.
        child: null,
      ),
    );
  }
}

/// Controller to manage the floating balloon overlay that appears above the active trait card.
class BubbleOverlayController {
  OverlayEntry? _entry;
  Timer? _timer;
  GlobalKey? _currentCardKey;
  String? _currentGifAssetPath;
  BuildContext? _currentContext;

  static const double _balloonWidth = 200.0;
  static const double _balloonHeight = 160.0;

  void showBubble({
    required BuildContext context,
    required GlobalKey cardKey,
    required String gifAssetPath,
    Duration duration = const Duration(seconds: 5),
  }) {
    hideBubble();
    
    _currentCardKey = cardKey;
    _currentGifAssetPath = gifAssetPath;
    _currentContext = context;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderObject = cardKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;

    final cardPos = renderObject.localToGlobal(Offset.zero);
    final cardSize = renderObject.size;
    final screenSize = MediaQuery.of(context).size;

    // Left trait column width (screen width - gap - fixed 130px right column).
    // This ensures the balloon stays over the left column (B3).
    const double gapBetweenColumns = 10.0;
    const double rightColumnWidth = 130.0;
    final double leftColumnWidth =
        screenSize.width - gapBetweenColumns - rightColumnWidth;

    final double cardLeft = cardPos.dx;
    final double cardRight = cardPos.dx + cardSize.width;

    // Center over the card horizontally.
    final double cardCenterX = cardPos.dx + cardSize.width / 2;
    double left = cardCenterX - _balloonWidth / 2;

    // Clamp left so balloon stays within the width of the trait column.
    final double leftColumnLeft = cardLeft; // card is in the column
    final double leftColumnRight = cardLeft + leftColumnWidth;

    final double minLeft = leftColumnLeft;
    final double maxLeft = leftColumnRight - _balloonWidth;

    if (left < minLeft) {
      left = minLeft;
    } else if (left > maxLeft) {
      left = maxLeft;
    }

    // Check if balloon would go off the top of the screen
    final double topIfAbove = cardPos.dy - _balloonHeight;
    final bool wouldGoOffTop = topIfAbove < 0;

    double top;
    bool flipped = false;

    if (wouldGoOffTop) {
      // Position below the card and flip the balloon
      top = cardPos.dy + cardSize.height;
      flipped = true;
    } else {
      // Position above the card (normal)
      top = topIfAbove;
      flipped = false;
    }

    _entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            ignoring: true, // never block touches on the slider
            child: RoundedBalloon(
              gifAssetPath: gifAssetPath,
              width: _balloonWidth,
              height: _balloonHeight,
              flipped: flipped,
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, hideBubble);
  }

  void hideBubble() {
    _timer?.cancel();
    _timer = null;
    _currentCardKey = null;
    _currentGifAssetPath = null;
    _currentContext = null;

    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
  }
  
  bool get isVisible => _entry != null;

  void dispose() {
    hideBubble();
  }
}

class FitState extends State<Fit> {
  // Track which question's card should glow as "active"
  int? _activeAnimationQuestionId;

  // Counter to force ListView rebuild when breeds are sorted
  int _breedListKey = 0;

  // Local state for slider values to ensure reactivity
  final Map<int, double> _sliderValues = {};

  // Track if instructions are dismissed
  bool _instructionsDismissed = false;

  // GlobalKeys for each question card to position the balloon
  late final Map<int, GlobalKey> _questionCardKeys;

  // Controller for the floating balloon overlay
  final BubbleOverlayController _bubbleController = BubbleOverlayController();
  
  // ScrollController for the trait cards list
  final ScrollController _questionsScrollController = ScrollController();

  // Map question names to stat names (for name mismatches)
  static const Map<String, String> _questionToStatName = {
    'Energy Level': 'Energy Level',
    'Playfulness': 'Fun-loving',
    'Care & Attention': 'TLC',
    'Companionship': 'Companion',
    'Vocalization': '"Talkative"',
    'Handling & Affection': 'Willingness to be petted',
    'Intelligence': 'Brains',
    'Grooming Needs': 'Grooming Needs',
    'Good with Children': 'Good with Children',
    'Good with Other Pets': 'Good with other pets',
  };

  @override
  void initState() {
    super.initState();

    // Initialize slider values from global state
    for (var question in Question.questions) {
      _sliderValues[question.id] = globals.FelineFinderServer.instance
          .sliderValue[question.id]
          .toDouble();
    }

    // Create a GlobalKey per question card
    _questionCardKeys = {
      for (var q in Question.questions) q.id: GlobalKey()
    };
    
    // Add scroll listener to track when list scrolls
    _questionsScrollController.addListener(_onQuestionsScroll);
    
    // Load saved instructions dismissal state
    _loadInstructionsState();
    
    // TEMPORARY: Uncomment the line below to reset instructions for testing
    _resetInstructions();
  }
  
  Future<void> _loadInstructionsState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _instructionsDismissed = prefs.getBool('fit_instructions_dismissed') ?? false;
    });
  }
  
  Future<void> _saveInstructionsState(bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fit_instructions_dismissed', dismissed);
  }
  
  // Temporary method to reset instructions for testing
  Future<void> _resetInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fit_instructions_dismissed');
    setState(() {
      _instructionsDismissed = false;
    });
  }
  
  void _onQuestionsScroll() {
    // Hide balloon when list scrolls
    if (_activeAnimationQuestionId != null && _bubbleController.isVisible) {
      _bubbleController.hideBubble();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _questionsScrollController.removeListener(_onQuestionsScroll);
    _questionsScrollController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  void _showQuestionDescription(BuildContext context, Question question) {
    // Hide the animation balloon when help button is pressed
    if (_activeAnimationQuestionId != null && _bubbleController.isVisible) {
      _bubbleController.hideBubble();
      _activeAnimationQuestionId = null;
      setState(() {});
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: AppTheme.purpleGradient,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        question.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  question.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.goldBase.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppTheme.goldBase, width: 1),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: AppTheme.goldBase,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: buildRows());
  }

  Widget buildRows() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: buildQuestions()),
        const SizedBox(width: 10), // margin between trait cards and breed cards
        SizedBox(width: 130, child: buildMatches()),
      ],
    );
  }

  Widget buildQuestions() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Hide balloon when list scrolls
        if (notification is ScrollUpdateNotification) {
          if (_activeAnimationQuestionId != null && _bubbleController.isVisible) {
            _bubbleController.hideBubble();
            _activeAnimationQuestionId = null;
            setState(() {});
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _questionsScrollController,
        itemCount: Question.questions.length,
        itemBuilder: (BuildContext context, int index) {
          return buildQuestionCard(Question.questions[index], index);
        },
      ),
    );
  }

  Widget buildQuestionCard(Question question, int index) {
    final bool isActive = _activeAnimationQuestionId == question.id;
    final cardKey = _questionCardKeys[question.id]!;

    return Container(
      key: cardKey,
      child: AnimatedScale(
        scale: isActive ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.only(
            left: 10.0,
            right: 10.0,
            top: index == 0
                ? 10.0
                : (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
            bottom: 16.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            gradient: AppTheme.purpleGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
              if (isActive)
                BoxShadow(
                  color: AppTheme.goldBase.withOpacity(0.7),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
              if (isActive)
                BoxShadow(
                  color: AppTheme.goldHighlight.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 0),
                ),
              if (isActive)
                BoxShadow(
                  color: AppTheme.goldBase.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with question name and help button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "${question.name}: ${question.choices[(_sliderValues[question.id] ?? 0.0).round()].name}",
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showQuestionDescription(context, question),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.goldBase.withOpacity(0.2),
                            border: Border.all(
                              color: AppTheme.goldBase,
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.goldBase,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SfSliderTheme(
                    data: SfSliderThemeData(
                      inactiveTrackColor: AppTheme.deepPurple,
                      activeTrackColor: AppTheme.goldBase,
                      inactiveDividerColor: Colors.transparent,
                      activeDividerColor: Colors.transparent,
                      activeTrackHeight: 12,
                      inactiveTrackHeight: 12,
                      activeDividerRadius: 2,
                      inactiveDividerRadius: 2,
                    ),
                    child: SfSlider(
                      min: 0,
                      max: question.choices.length.toDouble() - 1.0,
                      interval: 1,
                      showTicks: false,
                      showDividers: false,
                      enableTooltip: false,
                      value: _sliderValues[question.id] ?? 0.0,
                      thumbIcon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.goldHighlight,
                              AppTheme.goldBase,
                              AppTheme.goldShadow,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.goldBase.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                      onChanged: (newValue) {
                        try {
                          final roundedValue = newValue.round();
                          _sliderValues[question.id] = newValue;
                          globals.FelineFinderServer.instance
                              .sliderValue[question.id] = roundedValue;

                          _activeAnimationQuestionId = question.id;

                          // question.imageName already includes ".gif"
                          final gifPath =
                              "assets/Animation/${question.imageName}";
                          _bubbleController.showBubble(
                            context: context,
                            cardKey: cardKey,
                            gifAssetPath: gifPath,
                          );

                          // Build desired list
                          final desired = <Map<String, dynamic>>[];
                          for (var q in Question.questions) {
                            final sliderVal = globals.FelineFinderServer
                                .instance.sliderValue[q.id];
                            if (sliderVal > 0) {
                              desired.add({
                                'questionId': q.id,
                                'name': q.name,
                                'value': sliderVal.toDouble(),
                              });
                            }
                          }

                          // Calculate percentMatch for each breed
                          for (var i = 0; i < breeds.length; i++) {
                            double sum = 0;
                            for (var j = 0; j < desired.length; j++) {
                              try {
                                final questionId =
                                    desired[j]['questionId'] as int;
                                final questionName =
                                    desired[j]['name'] as String;
                                final desiredValue =
                                    desired[j]['value'] as double;

                                StatValue? stat;
                                try {
                                  final statName =
                                      _questionToStatName[questionName] ??
                                          questionName;
                                  stat = breeds[i].stats.firstWhere(
                                    (s) => s.name == statName,
                                  );
                                } catch (_) {
                                  continue;
                                }

                                Question? q;
                                try {
                                  q = Question.questions.firstWhere(
                                    (q) => q.id == questionId,
                                  );
                                } catch (_) {
                                  continue;
                                }

                                if (stat.isPercent) {
                                  sum += 1.0 -
                                      (desiredValue - stat.value).abs() /
                                          (q.choices.length - 1);
                                } else {
                                  if (desiredValue == stat.value) {
                                    sum += 1;
                                  }
                                }
                              } catch (_) {
                                continue;
                              }
                            }
                            if (desired.isEmpty) {
                              breeds[i].percentMatch = 1.0;
                            } else {
                              breeds[i].percentMatch =
                                  ((sum / desired.length) * 100)
                                          .floorToDouble() /
                                      100;
                            }
                          }

                          // Sort breeds
                          breeds.sort((a, b) {
                            final matchComparison =
                                b.percentMatch.compareTo(a.percentMatch);
                            if (matchComparison != 0) {
                              return matchComparison;
                            }
                            return a.name.compareTo(b.name);
                          });

                          _breedListKey++;
                          setState(() {});
                        } catch (e, stackTrace) {
                          // Log errors but don't crash the UI
                          // ignore: avoid_print
                          print(
                              'ERROR in onChanged for question ${question.id}: $e');
                          // ignore: avoid_print
                          print('Stack trace: $stackTrace');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMatches() {
    // Right column now only shows the breed cards (no animation square)
    return Column(
      children: [
        // Instructions at the top (if not dismissed)
        if (!_instructionsDismissed)
          Container(
            margin: const EdgeInsets.only(bottom: 12.0, left: 5.0, right: 5.0),
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 12.0, bottom: 12.0),
            decoration: BoxDecoration(
              gradient: AppTheme.purpleGradient,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 28.0),
                    child: Text(
                      'Adjust sliders to see your top breed matches',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // X button in top right
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _instructionsDismissed = true;
                      });
                      _saveInstructionsState(true);
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Breed cards list
        Expanded(
          child: ListView.builder(
            key: ValueKey(_breedListKey),
            itemCount: breeds.length,
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                onTap: () {
                  Get.to(() => BreedDetail(breed: breeds[index]),
                      transition: Transition.circularReveal,
                      duration: const Duration(seconds: 1));
                },
                child: buildBreedCard(breeds[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildBreedCard(Breed breed) {
    const double availableWidth = 210;

    return Container(
      margin: const EdgeInsets.only(
        left: 0.0,
        right: 5.0,
        top: 12.0,
        bottom: 12.0,
      ),
      width: availableWidth,
      child: GoldFramedPanel(
        plaqueLines: [
          breed.name,
          '${(breed.percentMatch * 100).toStringAsFixed(1)}%',
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final double imageWidth = constraints.maxWidth - 16;
                return Padding(
                  padding: const EdgeInsets.only(
                    top: 5.0,
                    left: 8.0,
                    right: 8.0,
                  ),
                  child: Container(
                    width: imageWidth,
                    height: AppTheme.breedCardImageHeight - 15,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.purpleGradient,
                    ),
                    child: Image.asset(
                      'assets/Cartoon/${breed.pictureHeadShotName.replaceAll(' ', '_')}.png',
                      fit: BoxFit.fill,
                      width: imageWidth,
                      height: AppTheme.breedCardImageHeight - 15,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.purpleGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.pets,
                              color: AppTheme.offWhite,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
