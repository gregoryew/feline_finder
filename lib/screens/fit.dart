import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import 'package:catapp/Models/question.dart';

import '/models/breed.dart';
import '/screens/breedDetail.dart' show BreedDetail, WidgetMarker;
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

class FitState extends State<Fit> {
  // Track which question's card should glow as "active"
  int? _activeAnimationQuestionId;

  // Counter to force ListView rebuild when breeds are sorted
  int _breedListKey = 0;

  // Local state for slider values to ensure reactivity
  final Map<int, double> _sliderValues = {};

  // Track if instructions are dismissed
  bool _instructionsDismissed = false;

  // GlobalKeys for each question card
  late final Map<int, GlobalKey> _questionCardKeys;

  // ScrollController for the trait cards list
  final ScrollController _questionsScrollController = ScrollController();
  
  // GlobalKey for capturing the screen as an image
  final GlobalKey _fitScreenKey = GlobalKey();
  
  // Flag to track if we're capturing for sharing
  final bool _isCapturing = false;

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
    
    // Load Breed Fit instructions dismissed state (separate key from personality_fit_instructions_dismissed)
    _loadInstructionsState();
  }
  
  static const String _instructionsDismissedKey = 'breed_fit_instructions_dismissed';

  Future<void> _loadInstructionsState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _instructionsDismissed = prefs.getBool(_instructionsDismissedKey) ?? false;
    });
  }
  
  Future<void> _saveInstructionsState(bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_instructionsDismissedKey, dismissed);
  }
  
  // Temporary method to reset instructions for testing
  Future<void> _resetInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_instructionsDismissedKey);
    setState(() {
      _instructionsDismissed = false;
    });
  }
  
  void _onQuestionsScroll() {}

  @override
  void dispose() {
    _questionsScrollController.removeListener(_onQuestionsScroll);
    _questionsScrollController.dispose();
    super.dispose();
  }

  void _showQuestionDescription(BuildContext context, Question question) {
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
            child: SingleChildScrollView(
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
                            decoration: TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
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
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.clip,
                    maxLines: 20,
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
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ],
              ),
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
        key: _fitScreenKey,
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
    
    return Scaffold(
      appBar: const GradientAppBar(
        title: "Breed Fit",
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.purpleGradient,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RepaintBoundary(
              key: _fitScreenKey,
              child: buildRows(),
            );
          },
        ),
      ),
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
        itemCount: Question.questions.length,
        itemBuilder: (BuildContext context, int index) {
          return buildQuestionCard(Question.questions[index], index);
        },
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              question.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              question.choices[(_sliderValues[question.id] ?? 0.0).round()].name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
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
                              maxLines: 1,
                              overflow: TextOverflow.clip,
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
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              gradient: AppTheme.purpleGradient,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust sliders to see top breed matches',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
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
                  Get.to(() => BreedDetail(
                        breed: breeds[index],
                        initialTab: WidgetMarker.stats,
                        showUserComparison: true,
                      ),
                      transition: Transition.circularReveal,
                      duration: const Duration(seconds: 1));
                },
                child: buildBreedCard(breeds[index], cardWidth: 140),
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

  /// True when every Breed Fit slider is set to "Flexible" (value 0).
  bool _allSlidersSetToDontMatter() {
    final sv = globals.FelineFinderServer.instance.sliderValue;
    return Question.questions.every((q) => q.id < sv.length && sv[q.id] == 0);
  }

  /// Creates a label widget showing breed match percentage
  /// Shows "Set Your Preference" when all sliders are Flexible; otherwise
  /// text labels: "Purrfect" (95-100), "Excellent" (90-95), "Great" (85-90), etc.
  Widget _buildDotIndicator(double percentMatch, {bool allSlidersDontMatter = false}) {
    final label = allSlidersDontMatter ? 'Set Your Preference' : _getMatchLabel(percentMatch);
    
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
            fontSize: AppTheme.fontSizeS,
            decoration: TextDecoration.none,
          ),
          overflow: TextOverflow.clip,
          maxLines: 1,
        ),
      ),
    );
  }

  /// Build dot indicator for capture only (with overflow protection to remove yellow underlines)
  Widget _buildDotIndicatorForCapture(double percentMatch, {bool allSlidersDontMatter = false}) {
    final label = allSlidersDontMatter ? 'Set Your Preference' : _getMatchLabel(percentMatch);
    
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
            decoration: TextDecoration.none,
          ),
          overflow: TextOverflow.clip,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget buildBreedCard(Breed breed, {double? cardWidth}) {
    final double availableWidth = cardWidth ?? 210;

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
              breed.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF4A2C00),
                fontWeight: FontWeight.w600,
                fontSize: AppTheme.fontSizeS, // Explicit font size to match screen version
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          ClipRect(
            clipBehavior: Clip.hardEdge,
            child: _buildDotIndicator(breed.percentMatch, allSlidersDontMatter: _allSlidersSetToDontMatter()),
          ),
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

  // Build breed card for capture with correct width constraints
  Widget _buildBreedCardForCapture(Breed breed) {
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
              breed.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4A2C00),
                fontWeight: FontWeight.w600,
                fontSize: 12.0, // Explicit font size to match screen version
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.clip,
              maxLines: 2,
              softWrap: true,
            ),
          ),
          _buildDotIndicatorForCapture(breed.percentMatch, allSlidersDontMatter: _allSlidersSetToDontMatter()),
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

  Future<String> _getFilePath() async {
    Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
    String appDocumentsPath = appDocumentsDirectory.path;
    var userID = const Uuid();
    // Use .jpg extension since we're now converting to JPG
    String filePath = '$appDocumentsPath/${userID.v1()}.jpg';
    return filePath;
  }

  // Build a question card for capture (without GlobalKey to avoid duplicates)
  Widget _buildQuestionCardForCapture(Question question, int index) {
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              question.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              question.choices[(_sliderValues[question.id] ?? 0.0).round()].name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
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

  // Build full content for capture - all question cards and matching breed cards
  Widget _buildFullContentForCapture() {
    // Show only the top 6 breed cards in the generated image
    const int maxBreedCardsToShow = 6;
    final int breedCardsToShow = maxBreedCardsToShow.clamp(0, breeds.length);
    
    // Get the top breed name (breeds are already sorted by percentMatch)
    final String topBreedName = breeds.isNotEmpty ? breeds[0].name : 'Unknown';
    final String shareText = 'My purrfect match is $topBreedName! What\'s yours? Find out:';
    
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
                        decoration: TextDecoration.none,
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
                children: Question.questions.asMap().entries.map((entry) {
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
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
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
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Adjust sliders to see top breed matches',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  // Show only the top 6 breed cards in the generated image
                  // Use capture-specific breed card builder with correct width
                  ...breeds.take(breedCardsToShow).map((breed) => _buildBreedCardForCapture(breed)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> shareFitScreen() async {
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
        print('📸 Resizing from ${decodedImage.width}x${decodedImage.height} to ${newWidth}x$newHeight');
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
        subject: 'My Top Cat Breed Match',
      );
    } catch (e) {
      print('Error sharing fit screen: $e');
      // Fallback to text-only sharing
      final String topBreedName = breeds.isNotEmpty ? breeds[0].name : 'Unknown';
      final String shareText = 'My purrfect match is $topBreedName! What\'s yours? Find out:';
      await Share.share(
        shareText,
        subject: 'My Purrfect Cat Breed Match',
      );
    }
  }
}
