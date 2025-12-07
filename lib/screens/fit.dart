import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:get/get.dart';

import 'package:catapp/Models/question.dart';

import '/models/breed.dart';
import '/screens/breedDetail.dart';
import 'globals.dart' as globals;
import '../theme.dart';
import '../widgets/design_system.dart';
import '../gold_frame/gold_frame_panel.dart';

class Fit extends StatefulWidget {
  const Fit({Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  @override
  FitState createState() {
    return FitState();
  }
}

enum AnimationState {
  hidden,      // Animation is hidden (not visible)
  slidingIn,  // PNG sliding in from right
  showingGif, // GIF playing (fully visible)
  slidingOut  // PNG sliding out to right
}

class FitState extends State<Fit> with TickerProviderStateMixin {
  // Track animation state for each question
  final Map<int, AnimationState> _animationStates = {};
  // Debounce timers for slider changes
  final Map<int, Timer> _debounceTimers = {};
  // Animation controllers for slide animations
  final Map<int, AnimationController> _slideControllers = {};
  // Timers for GIF duration (5 seconds)
  final Map<int, Timer> _gifCompletionTimers = {};

  @override
  void initState() {
    super.initState();
    // Initialize all questions to hidden state
    for (var question in Question.questions) {
      _animationStates[question.id] = AnimationState.hidden;
    }
  }

  @override
  void dispose() {
    // Cancel all timers
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    for (var timer in _gifCompletionTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _gifCompletionTimers.clear();
    
    // Dispose all animation controllers
    for (var controller in _slideControllers.values) {
      controller.dispose();
    }
    _slideControllers.clear();
    
    super.dispose();
  }

  AnimationController _getSlideController(int questionId) {
    if (!_slideControllers.containsKey(questionId)) {
      _slideControllers[questionId] = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1), // Slide animation duration (1 second)
      );
    }
    return _slideControllers[questionId]!;
  }

  void _triggerAnimation(int questionId) {
    // If animation is already playing, ignore new triggers
    if (_animationStates[questionId] != AnimationState.hidden) {
      return;
    }

    // Cancel existing debounce timer if any
    if (_debounceTimers.containsKey(questionId)) {
      _debounceTimers[questionId]!.cancel();
    }

    // Set debounce timer (500ms)
    _debounceTimers[questionId] = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _animationStates[questionId] == AnimationState.hidden) {
        _startSlideInAnimation(questionId);
      }
      _debounceTimers.remove(questionId);
    });
  }

  void _startSlideInAnimation(int questionId) {
    final controller = _getSlideController(questionId);
    
    setState(() {
      _animationStates[questionId] = AnimationState.slidingIn;
    });

    controller.reset();
    controller.forward().then((_) {
      if (mounted) {
        // Switch to GIF after slide-in completes
        setState(() {
          _animationStates[questionId] = AnimationState.showingGif;
        });

        // Set timer for 5 seconds, then slide out
        _gifCompletionTimers[questionId] = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _startSlideOutAnimation(questionId);
          }
        });
      }
    });
  }

  void _startSlideOutAnimation(int questionId) {
    final controller = _getSlideController(questionId);
    
    setState(() {
      _animationStates[questionId] = AnimationState.slidingOut;
    });

    // Controller is already at 1.0 from slide-in, so reverse will go 1.0 -> 0.0
    // But we want to animate from 0 (visible) to 100 (hidden), so we use a different approach
    controller.reset();
    // For slide-out, we animate from 0.0 to 1.0, but interpret it as going from visible to hidden
    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _animationStates[questionId] = AnimationState.hidden;
        });
        _gifCompletionTimers.remove(questionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: buildRows());
  }

  Widget buildRows() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: buildQuestions()),
        const SizedBox(width: 10), // 10px margin between trait cards and breed cards
        SizedBox(width: 130, child: buildMatches()),
      ],
    );
  }

  Widget buildQuestions() {
    return ListView.builder(
        itemCount: Question.questions.length,
        itemBuilder: (BuildContext context, int index) {
          return buildQuestionCard(Question.questions[index]);
        });
  }

  Widget buildQuestionCard(Question question) {
    return Container(
        margin: EdgeInsets.only(
          left: (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
          right: (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
          top: (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
          bottom: 16.0, // Increased spacing between cards
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0), // Rounded corners for a polished look
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
          child: Stack(
            children: [
              // Gradient background
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.goldShadow,   // Deep gold (start)
                        const Color(0xFF6B4E0A), // Deep dark gold (end)
                      ],
                    ),
                  ),
                ),
              ),
              // Content on top
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "${question.name}: ${question
                                .choices[globals.FelineFinderServer.instance
                                    .sliderValue[question.id]]
                                .name}",
                        style: const TextStyle(fontSize: 13, color: Colors.white)),
                    // Slider - disabled during animation
                    Opacity(
                      opacity: (_animationStates[question.id] != AnimationState.hidden) ? 0.5 : 1.0,
                      child: AbsorbPointer(
                        absorbing: _animationStates[question.id] != AnimationState.hidden,
                        child: SfSliderTheme(
                data: SfSliderThemeData(
                  inactiveTrackColor: AppTheme.deepPurple, // Dark purple on the right
                  activeTrackColor: AppTheme.goldBase, // Gold on the left
                  inactiveDividerColor: Colors.transparent,
                  activeDividerColor: Colors.transparent,
                  activeTrackHeight: 12,
                  inactiveTrackHeight: 12,
                  activeDividerRadius: 2,
                  inactiveDividerRadius: 2,
                ),
                child: SfSlider(
                  // 10
                  min: 0,
                  max: question.choices.length.toDouble() - 1.0,
                  interval: 1,
                  showTicks: false,
                  showDividers: false, // Removed slider dots
                  enableTooltip: false,
                  value: globals
                      .FelineFinderServer.instance.sliderValue[question.id]
                      .toDouble(),
                  /*
                tooltipTextFormatterCallback:
                    (dynamic actualValue, String formattedText) {
                  return question
                      .choices[globals
                          .FelineFinderServer.instance.sliderValue[question.id]]
                      .name;
                },*/
                  thumbIcon: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.goldHighlight, // Bright gold at top-left
                          AppTheme.goldBase,      // Medium gold in middle
                          AppTheme.goldShadow,    // Dark gold at bottom-right
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
                        color: Colors.white.withOpacity(0.3), // Subtle highlight overlay
                      ),
                    ),
                  ),
                  onChanged: (newValue) {
                    setState(() {
                      globals.FelineFinderServer.instance
                          .sliderValue[question.id] = newValue.round();
                      
                      // Trigger animation with debounce
                      _triggerAnimation(question.id);

                            // Store question ID and value pairs (stats are ordered by question ID)
                            final desired = <Map<String, dynamic>>[];
                            for (var i = 0; i < Question.questions.length; i++) {
                              if (globals.FelineFinderServer.instance.sliderValue[i] >
                                  0) {
                                desired.add({
                                  'questionId': i,
                                  'name': Question.questions[i].name,
                                  'value': globals.FelineFinderServer.instance.sliderValue[i]
                                      .toDouble(),
                                });
                              }
                            }

                            for (var i = 0; i < breeds.length; i++) {
                              double sum = 0;
                              for (var j = 0; j < desired.length; j++) {
                                try {
                                  final questionId = desired[j]['questionId'] as int;
                                  final questionName = desired[j]['name'] as String;
                                  final desiredValue = desired[j]['value'] as double;
                                  
                                  // Find stat by matching question name (more robust than using index)
                                  StatValue? stat;
                                  try {
                                    stat = breeds[i].stats.firstWhere(
                                      (s) => s.name == questionName,
                                    );
                                  } catch (e) {
                                    continue; // Skip if stat not found
                                  }
                                  
                                  Question q = Question.questions[questionId];
                                  
                                  if (stat.isPercent) {
                                    sum += 1.0 -
                                        (desiredValue - stat.value).abs() /
                                            q.choices.length;
                                  } else {
                                    if (desiredValue == stat.value) {
                                      sum += 1;
                                    }
                                  }
                                } catch (e) {
                                  // Skip this stat if there's any error
                                  continue;
                                }
                              }
                              if (desired.isEmpty) {
                                breeds[i].percentMatch = 1.0;
                              } else {
                                breeds[i].percentMatch =
                                    ((sum / desired.length) * 100).floorToDouble() /
                                        100;
                              }
                            }

                      breeds.sort((a, b) {
                        if (a.percentMatch.compareTo(b.percentMatch) == -1) {
                          return -1;
                        }

                        if (a.percentMatch.compareTo(b.percentMatch) == 0) {
                          return -1 * a.name.compareTo(b.name);
                        }

                        return 1;
                      });
                      breeds = List.from(breeds.reversed);
                    });
                  },
                  // 14
                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sliding animation - appears from right edge when triggered
              _buildSlidingAnimation(question),
            ],
          ),
        ),
      );
  }

  Widget _buildSlidingAnimation(Question question) {
    final state = _animationStates[question.id] ?? AnimationState.hidden;
    
    // Don't render anything if hidden
    if (state == AnimationState.hidden) {
      return const SizedBox.shrink();
    }

    final controller = _getSlideController(question.id);
    
    // Determine which image to show
    final bool showGif = (state == AnimationState.showingGif);
    final String imagePath = showGif
        ? "assets/Animation/${question.imageName}"
        : "assets/Animation/${question.imageName.replaceAll('.gif', '.png')}";

    // Animation: starts at right edge of card (right: 0) and slides in
    // The image is 100px wide, so we use clipRect to reveal it progressively
    // Start: right: 0, clip to show 0px (hidden)
    // End: right: 0, clip to show 100px (fully visible)
    final animation = Tween<double>(begin: 0.0, end: 100.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        double clipWidth;
        if (state == AnimationState.slidingIn) {
          // Sliding in: reveal from 0px to 100px width
          clipWidth = animation.value;
        } else if (state == AnimationState.showingGif) {
          // Fully visible (100px width)
          clipWidth = 100.0;
        } else if (state == AnimationState.slidingOut) {
          // Sliding out: hide from 100px to 0px width
          clipWidth = 100.0 - animation.value;
        } else {
          clipWidth = 0.0; // Hidden
        }

        return Positioned(
          top: 0,
          right: 0, // Always at right edge of trait card
          bottom: 0,
          width: 100,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: clipWidth / 100.0, // Reveal progressively from right
              child: Image(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                width: 100,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildMatches() {
    breeds.sort((a, b) {
      if (a.percentMatch.compareTo(b.percentMatch) == -1) {
        return -1;
      }

      if (a.percentMatch.compareTo(b.percentMatch) == 0) {
        return -1 * a.name.compareTo(b.name);
      }

      return 1;
    });
    breeds = List.from(breeds.reversed);

    return ListView.builder(
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
    );
  }

  Widget buildBreedCard(Breed breed) {
    // Calculate available width: column width (130) minus margins
    // With reduced margins, use full column width minus minimal margins
    const double availableWidth = 210;
    
    return Container(
      margin: EdgeInsets.only(
        left: 0.0,
        right: 5.0, // 5px margin between right edge of card and right edge of screen
        top: 12.0,
        bottom: 12.0,
      ),
      // Constrain the frame to fit within the column
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
            // Top Section: Full-width image (reduced height by 15px)
            // Use LayoutBuilder to get the exact available width inside the frame
            LayoutBuilder(
              builder: (context, constraints) {
                // Get the exact width available after frame borders
                // Reduce width by 16px total (8px on left, 8px on right)
                final double imageWidth = constraints.maxWidth - 16;
                return Padding(
                  // Add padding on top, left, and right (reduced top padding to decrease margin)
                  padding: const EdgeInsets.only(
                    top: 5.0, // Reduced from 15.0 to decrease margin between image and top border
                    left: 8.0,
                    right: 8.0,
                  ),
                  child: Container(
                    width: imageWidth,
                    height: AppTheme.breedCardImageHeight - 15, // Increased by 15px from -30
                    decoration: const BoxDecoration(
                      gradient: AppTheme.purpleGradient,
                    ),
                    child: Image.asset(
                      'assets/Cartoon/${breed.pictureHeadShotName.replaceAll(' ', '_')}.png',
                      fit: BoxFit.fill, // Use fill to fill entire width inside frame
                      width: imageWidth,
                      height: AppTheme.breedCardImageHeight - 15, // Increased by 15px from -30
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.purpleGradient,
                          ),
                          child: const Center(
                            child: Icon(Icons.pets, color: AppTheme.offWhite, size: 48),
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
