import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show RenderObjectToWidgetAdapter, WidgetsBinding;
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

import '/models/catType.dart';
import '/models/question_cat_types.dart';
import 'globals.dart' as globals;
import '../config.dart';
import '../theme.dart';
import '../widgets/design_system.dart';
import '../gold_frame/gold_frame_panel.dart';

class _CatTypeVideoThenImage extends StatefulWidget {
  final String baseName; // e.g. "Professional_Napper"
  final double size;

  const _CatTypeVideoThenImage({
    Key? key,
    required this.baseName,
    this.size = 220,
  }) : super(key: key);

  @override
  State<_CatTypeVideoThenImage> createState() => _CatTypeVideoThenImageState();
}

class _CatTypeVideoThenImageState extends State<_CatTypeVideoThenImage> {
  VideoPlayerController? _controller;
  bool _showImage = false;
  bool _initialized = false;

  // Video name matches the image name (base name) except extension.
  String get _videoAssetPath => 'assets/cat_types/${widget.baseName}.mp4';
  String get _imageAssetPath => 'assets/cat_types/${widget.baseName}.jpg';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.asset(_videoAssetPath);
      _controller = controller;
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(_onTick);
      await controller.play();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showImage = true;
          _initialized = true;
        });
      }
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    if (_showImage) return;
    if (!c.value.isInitialized) return;

    // Swap to image once the video completes.
    final isCompleted = c.value.isCompleted ||
        (c.value.duration.inMilliseconds > 0 &&
            c.value.position >= c.value.duration);
    if (isCompleted) {
      c.pause();
      if (mounted) {
        setState(() {
          _showImage = true;
        });
      }
    }
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onTick);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, widget.size)
            : widget.size;

        return Center(
          child: SizedBox.square(
            dimension: dimension,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: const BoxDecoration(gradient: AppTheme.purpleGradient),
                child: _showImage
                    ? Image.asset(
                        _imageAssetPath,
                        fit: BoxFit.cover,
                        width: dimension,
                        height: dimension,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.pets, color: AppTheme.offWhite, size: 48),
                          );
                        },
                      )
                    : (!_initialized || c == null || !c.value.isInitialized)
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.goldBase),
                              ),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: c.value.size.width,
                              height: c.value.size.height,
                              child: VideoPlayer(c),
                            ),
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PersonalityFit extends StatefulWidget {
  const PersonalityFit({Key? key}) : super(key: key);

  @override
  PersonalityFitState createState() {
    return PersonalityFitState();
  }
}

class PersonalityFitState extends State<PersonalityFit> {
  // Counter to force ListView rebuild when cat types are re-sorted
  int _catTypeListKey = 0;

  // Local state for slider values to ensure reactivity
  final Map<int, double> _sliderValues = {};

  // Track if instructions are dismissed
  bool _instructionsDismissed = false;

  // Display order (cat type ids) and match % — avoid mutating global catType
  late List<int> _displayOrder;
  late Map<int, double> _displayPercentMatch;

  // True when at least one slider is not "Doesn't Matter"; when false, show "Unknown" instead of match label
  bool _hasAnyPreference = false;

  // ScrollController for the trait cards list
  final ScrollController _questionsScrollController = ScrollController();
  
  // GlobalKey for capturing the screen as an image
  final GlobalKey _personalityFitScreenKey = GlobalKey();
  
  // Flag to track if we're capturing for sharing
  bool _isCapturing = false;

  // Map Question_Cat_Types names to CatType stat names
  static const Map<String, String> _questionToStatName = {
    'Energy Level': 'Energy Level',
    'Playfulness': 'Playfulness',
    'Affection Level': 'Affection Level',
    'Independence': 'Independence',
    'Sociability': 'Sociability',
    'Vocalization': 'Vocality',
    'Confidence': 'Confidence',
    'Sensitivity': 'Sensitivity',
    'Adaptability': 'Adaptability',
    'Intelligence': 'Intelligence',
  };

  @override
  void initState() {
    super.initState();

    // Initialize slider values from PersonalityFit-specific storage (not shared with Fit)
    final server = globals.FelineFinderServer.instance;
    for (var question in Question_Cat_Types.questions) {
      _sliderValues[question.id] = server.getPersonalityFitSliderValue(question.id).toDouble();
    }

    // Initialize display order and match % from catType (no mutation of global list)
    _displayOrder = catType.map((c) => c.id).toList();
    _displayPercentMatch = { for (var c in catType) c.id: 1.0 };
    _hasAnyPreference = Question_Cat_Types.questions.any(
        (q) => server.getPersonalityFitSliderValue(q.id) > 0);
    
    // Load saved instructions dismissal state
    _loadInstructionsState();
    
    // TEMPORARY: Uncomment the line below to reset instructions for testing
    _resetInstructions();
  }
  
  Future<void> _loadInstructionsState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _instructionsDismissed = prefs.getBool('personality_fit_instructions_dismissed') ?? false;
    });
  }
  
  Future<void> _saveInstructionsState(bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('personality_fit_instructions_dismissed', dismissed);
  }
  
  // Temporary method to reset instructions for testing
  Future<void> _resetInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('personality_fit_instructions_dismissed');
    setState(() {
      _instructionsDismissed = false;
    });
  }
  
  @override
  void dispose() {
    _questionsScrollController.dispose();
    super.dispose();
  }

  void _showQuestionDescription(BuildContext context, Question_Cat_Types question) {
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

  void _showCatTypeDetail(BuildContext context, CatType type) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        type.name,
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
                if (type.tagline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    type.tagline,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.goldBase,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  type.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _CatTypeVideoThenImage(baseName: type.imageName, size: 220),
                const SizedBox(height: 24),
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
    if (_isCapturing) {
      // When capturing, use UnconstrainedBox to allow full expansion
      final screenWidth = MediaQuery.of(context).size.width;
      return RepaintBoundary(
        key: _personalityFitScreenKey,
        child: UnconstrainedBox(
          alignment: Alignment.topCenter,
          constrainedAxis: Axis.horizontal,
          child: Container(
            width: screenWidth,
            decoration: const BoxDecoration(
              gradient: AppTheme.purpleGradient,
            ),
            child: _buildFullContentForCapture(),
          ),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
          key: _personalityFitScreenKey,
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: const BoxDecoration(
              gradient: AppTheme.purpleGradient,
            ),
            child: buildRows(),
          ),
        );
      },
    );
  }

  Widget buildRows() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: buildQuestions()),
        const SizedBox(width: 10), // margin between trait cards and breed cards
        SizedBox(width: 140, child: buildMatches()),
      ],
    );
  }

  Widget buildQuestions() {
    return ListView.builder(
      controller: _questionsScrollController,
      itemCount: Question_Cat_Types.questions.length,
      itemBuilder: (BuildContext context, int index) {
        return buildQuestionCard(Question_Cat_Types.questions[index], index);
      },
    );
  }

  int _clampedChoiceIndex(Question_Cat_Types question) {
    final raw = (_sliderValues[question.id] ?? 0.0).round();
    return raw.clamp(0, question.choices.length - 1);
  }

  Widget buildQuestionCard(Question_Cat_Types question, int index) {
    final choiceIndex = _clampedChoiceIndex(question);

    return Container(
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
                        "${question.name}: ${question.choices[choiceIndex].name}",
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
                                decoration: TextDecoration.none,
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
                      value: (_sliderValues[question.id] ?? 0.0).clamp(0.0, question.choices.length - 1.0),
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
                          final roundedValue = newValue.round().clamp(0, question.choices.length - 1);
                          _sliderValues[question.id] = newValue;
                          globals.FelineFinderServer.instance
                              .setPersonalityFitSliderValue(question.id, roundedValue);

                          // Build desired list from PersonalityFit slider storage
                          final desired = <Map<String, dynamic>>[];
                          final server = globals.FelineFinderServer.instance;
                          for (var q in Question_Cat_Types.questions) {
                            final sliderVal = server.getPersonalityFitSliderValue(q.id);
                            if (sliderVal > 0 && sliderVal < q.choices.length) {
                              final choice = q.choices[sliderVal];
                              desired.add({
                                'questionId': q.id,
                                'name': q.name,
                                'value': choice.lowRange.toDouble(),
                              });
                            }
                          }

                          // Calculate percentMatch for each cat type (store in local state, do not mutate global catType)
                          final newPercentMatch = <int, double>{};
                          for (var i = 0; i < catType.length; i++) {
                            final ct = catType[i];
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
                                  stat = ct.stats.firstWhere(
                                    (s) => s.name == statName,
                                  );
                                } catch (_) {
                                  continue;
                                }

                                Question_Cat_Types? q;
                                try {
                                  q = Question_Cat_Types.questions.firstWhere(
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
                                  // Distance-based partial credit for trait scale (e.g. 1-5)
                                  // so "High" energy (4) matches Zoomie Rocket (5) well, not "Not a Match"
                                  final traitValues = q.choices
                                      .where((c) => c.lowRange > 0)
                                      .map((c) => c.lowRange.toDouble())
                                      .toList();
                                  final range = traitValues.isEmpty
                                      ? 4.0
                                      : (traitValues.reduce((a, b) => a > b ? a : b) -
                                          traitValues.reduce((a, b) => a < b ? a : b));
                                  final maxDistance = range < 1.0 ? 1.0 : range;
                                  final score = maxDistance <= 0
                                      ? (desiredValue == stat.value ? 1.0 : 0.0)
                                      : (1.0 -
                                              (desiredValue - stat.value).abs() / maxDistance)
                                          .clamp(0.0, 1.0);
                                  sum += score;
                                }
                              } catch (_) {
                                continue;
                              }
                            }
                            if (desired.isEmpty) {
                              newPercentMatch[ct.id] = 1.0;
                            } else {
                              newPercentMatch[ct.id] =
                                  ((sum / desired.length) * 100)
                                          .floorToDouble() /
                                      100;
                            }
                          }

                          _hasAnyPreference = desired.isNotEmpty;
                          _displayPercentMatch = newPercentMatch;
                          _displayOrder = List.from(catType.map((c) => c.id));
                          _displayOrder.sort((a, b) {
                            final matchComparison =
                                (newPercentMatch[b] ?? 0.0).compareTo(newPercentMatch[a] ?? 0.0);
                            if (matchComparison != 0) return matchComparison;
                            final nameA = catType.firstWhere((c) => c.id == a).name;
                            final nameB = catType.firstWhere((c) => c.id == b).name;
                            return nameA.compareTo(nameB);
                          });

                          _catTypeListKey++;
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
                      'Adjust sliders to see your top personality matches',
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
        // Cat type cards list (order from _displayOrder, match % from _displayPercentMatch)
        Expanded(
          child: ListView.builder(
            key: ValueKey(_catTypeListKey),
            itemCount: _displayOrder.length,
            itemBuilder: (BuildContext context, int index) {
              final id = _displayOrder[index];
              final type = catType.firstWhere((c) => c.id == id);
              final percentMatch = _displayPercentMatch[id] ?? 1.0;
              return GestureDetector(
                onTap: () {
                  _showCatTypeDetail(context, type);
                },
                child: buildCatTypeCard(type, percentMatch),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Gets the match label based on percentage range
  /// Match label ranges optimized for breed matching
  /// Most breeds cluster in 80-100% range, so finer granularity at high end
  /// Ranges: Purrfect (95-100), Excellent (90-95), Great (85-90), Very Good (75-85),
  /// Good (65-75), Fair (55-65), Okay (45-55), Poor (35-45), Not a Match (0-35)
  String _getMatchLabel(double percentMatch) {
    final percentage = percentMatch * 100;
    
    if (percentage >= 95) {
      return 'Purrfect';      // 95-100% (5% range)
    } else if (percentage >= 90) {
      return 'Excellent';     // 90-95% (5% range)
    } else if (percentage >= 85) {
      return 'Great';         // 85-90% (5% range)
    } else if (percentage >= 75) {
      return 'Very Good';     // 75-85% (10% range)
    } else if (percentage >= 65) {
      return 'Good';          // 65-75% (10% range)
    } else if (percentage >= 55) {
      return 'Fair';          // 55-65% (10% range)
    } else if (percentage >= 45) {
      return 'Okay';          // 45-55% (10% range)
    } else if (percentage >= 35) {
      return 'Poor';          // 35-45% (10% range)
    } else {
      return 'Not a Match';    // 0-35% (35% range)
    }
  }

  /// Creates a label widget showing breed match percentage
  /// Shows text labels: "Purrfect" (95-100), "Excellent" (90-95), "Great" (85-90),
  /// "Very Good" (75-85), "Good" (65-75), "Fair" (55-65), "Okay" (45-55),
  /// "Poor" (35-45), "Not a Match" (0-35)
  Widget _buildDotIndicator(double percentMatch) {
    final label =
        _hasAnyPreference ? _getMatchLabel(percentMatch) : 'Set Your Preferences';
    
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFF4A2C00),
        fontWeight: FontWeight.w600,
        fontSize: AppTheme.fontSizeS,
      ),
    );
  }

  /// Build dot indicator for capture only (with overflow protection to remove yellow underlines)
  Widget _buildDotIndicatorForCapture(double percentMatch) {
    final label =
        _hasAnyPreference ? _getMatchLabel(percentMatch) : 'Set Your Preferences';
    
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF4A2C00),
            fontWeight: FontWeight.w600,
            fontSize: AppTheme.fontSizeS * 0.9,
          ),
          overflow: TextOverflow.clip,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget buildCatTypeCard(CatType catTypeItem, double percentMatch) {
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
        plaqueWidgets: [
          Text(
            catTypeItem.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF4A2C00),
              fontWeight: FontWeight.w600,
              fontSize: AppTheme.fontSizeS,
            ),
          ),
          _buildDotIndicator(percentMatch),
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
                      'assets/cat_types/${catTypeItem.imageName}.jpg',
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

  // Build cat type card for capture with correct width constraints
  Widget _buildCatTypeCardForCapture(CatType catTypeItem, double percentMatch) {
    const double availableWidth = 140; // Match the capture column width

    return Container(
      margin: const EdgeInsets.only(
        left: 0.0,
        right: 5.0,
        top: 12.0,
        bottom: 12.0,
      ),
      width: availableWidth,
      child: GoldFramedPanel(
        plaqueWidgets: [
          ClipRect(
            clipBehavior: Clip.hardEdge,
            child: Text(
              catTypeItem.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4A2C00),
                fontWeight: FontWeight.w600,
                fontSize: 12.0,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.clip,
              maxLines: 2,
              softWrap: true,
            ),
          ),
          _buildDotIndicatorForCapture(percentMatch),
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
                      'assets/cat_types/${catTypeItem.imageName}.jpg',
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

  Future<String> _getFilePath() async {
    Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
    String appDocumentsPath = appDocumentsDirectory.path;
    var userID = const Uuid();
    // Use .jpg extension since we're now converting to JPG
    String filePath = '$appDocumentsPath/${userID.v1()}.jpg';
    return filePath;
  }

  // Build a question card for capture (without GlobalKey to avoid duplicates)
  Widget _buildQuestionCardForCapture(Question_Cat_Types question, int index) {
    final bool isActive = false; // No animations during capture
    
    return Container(
      child: AnimatedScale(
        scale: 1.0,
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
                          "${question.name}: ${question.choices[_clampedChoiceIndex(question)].name}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
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
                        child: ClipRect(
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.goldBase,
                                  ),
                                  overflow: TextOverflow.clip,
                                  maxLines: 1,
                                ),
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
                      value: (_sliderValues[question.id] ?? 0.0).clamp(0.0, question.choices.length - 1.0),
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
                        // No-op during capture
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

  // Build full content for capture - all question cards and matching cat type cards
  Widget _buildFullContentForCapture() {
    // Show only the top 6 cat type cards in the generated image
    const int maxCatTypeCardsToShow = 6;
    final int catTypeCardsToShow = maxCatTypeCardsToShow.clamp(0, _displayOrder.length);
    
    // Get the top cat type name from display order (no mutation of global catType)
    final String topCatTypeName = _displayOrder.isNotEmpty
        ? catType.firstWhere((c) => c.id == _displayOrder[0], orElse: () => catType.first).name
        : (catType.isNotEmpty ? catType[0].name : 'Unknown');
    final String shareText = 'My purrfect personality match is $topCatTypeName! What\'s yours? Find out:';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Black text box at the TOP (so it's visible in Facebook feed preview)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.black,
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      shareText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.clip,
                      softWrap: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Main content row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - ALL question cards
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: Question_Cat_Types.questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  return _buildQuestionCardForCapture(question, index);
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),
            // Right column - enough breed cards to match height
            SizedBox(
              width: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions if not dismissed
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
                                'Adjust sliders to see your top personality matches',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.visible,
                                softWrap: true,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
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
                        ],
                      ),
                    ),
                  // Show only the top 6 breed cards in the generated image
                  // Use capture-specific breed card builder with correct width
                  ..._displayOrder.take(catTypeCardsToShow).map((id) {
                    final type = catType.firstWhere((c) => c.id == id);
                    final percentMatch = _displayPercentMatch[id] ?? 1.0;
                    return _buildCatTypeCardForCapture(type, percentMatch);
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> sharePersonalityFitScreen() async {
    try {
      final screenWidth = MediaQuery.of(context).size.width;
      final GlobalKey captureKey = GlobalKey();
      
      // Build the full content widget
      final fullContentWidget = Container(
        width: screenWidth,
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: _buildFullContentForCapture(),
      );
      
      // Create an overlay entry to render off-screen
      final OverlayEntry overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000, // Position far off-screen
          top: 0,
          child: RepaintBoundary(
            key: captureKey,
            child: fullContentWidget,
          ),
        ),
      );
      
      // Insert overlay
      Overlay.of(context).insert(overlayEntry);
      
      // Wait for rendering
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get the RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = 
          captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        print('Error: Could not find render boundary');
        overlayEntry.remove();
        return;
      }
      
      // Get the size of the boundary
      final size = boundary.size;
      print('📸 Capturing image: ${size.width}x${size.height}');
      
      // Capture the image with lower pixel ratio to reduce file size
      // Using 1.5 instead of 2.0 to keep file size manageable for social media (Facebook limit ~4MB)
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      print('📸 Captured image dimensions: ${image.width}x${image.height}');
      
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      // Remove overlay
      overlayEntry.remove();
      
      if (byteData == null) {
        print('Error: Could not convert image to byte data');
        return;
      }
      
      // Convert PNG to JPG with compression and resizing for Facebook compatibility
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      print('📸 PNG size: ${(pngBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // Decode PNG image
      final img.Image? decodedImage = img.decodeImage(pngBytes);
      if (decodedImage == null) {
        print('Error: Could not decode PNG image');
        return;
      }
      
      // Resize if dimensions exceed Facebook's recommended max (2048px)
      img.Image processedImage = decodedImage;
      const int maxDimension = 2048;
      if (decodedImage.width > maxDimension || decodedImage.height > maxDimension) {
        final double scale = (decodedImage.width > decodedImage.height)
            ? maxDimension / decodedImage.width
            : maxDimension / decodedImage.height;
        final int newWidth = (decodedImage.width * scale).round();
        final int newHeight = (decodedImage.height * scale).round();
        print('📸 Resizing from ${decodedImage.width}x${decodedImage.height} to ${newWidth}x${newHeight}');
        processedImage = img.copyResize(
          decodedImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }
      
      // Convert to JPG with quality 85 (good balance between quality and file size)
      Uint8List jpgBytes = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: 85)
      );
      print('📸 JPG size: ${(jpgBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // If still too large (>4MB), reduce quality further
      const int maxFileSize = 4 * 1024 * 1024; // 4MB
      if (jpgBytes.length > maxFileSize) {
        print('📸 File too large, reducing quality to 70');
        jpgBytes = Uint8List.fromList(
          img.encodeJpg(processedImage, quality: 70)
        );
        print('📸 JPG size after quality reduction: ${(jpgBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      // Save as JPG with correct extension
      final String filepath = await _getFilePath();
      final File file = File(filepath);
      await file.writeAsBytes(jpgBytes);
      
      // Share the image (text is now embedded in the image at the top)
      await Share.shareXFiles(
        [XFile(filepath)],
        subject: 'My Top Cat Personality Match',
      );
    } catch (e) {
      print('Error sharing personality fit screen: $e');
      // Fallback to text-only sharing
      final String topCatTypeName = _displayOrder.isNotEmpty
          ? catType.firstWhere((c) => c.id == _displayOrder[0], orElse: () => catType.first).name
          : (catType.isNotEmpty ? catType[0].name : 'Unknown');
      final String shareText = 'My purrfect personality match is $topCatTypeName! What\'s yours? Find out:';
      await Share.share(
        shareText,
        subject: 'My Purrfect Cat Personality Match',
      );
    }
  }
}
