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

class FitState extends State<Fit> {
  // Track which questions are currently showing GIF (true) or PNG (false)
  final Map<int, bool> _showingGif = {};
  // Track timers for switching back to PNG after 5 seconds
  final Map<int, Timer> _gifTimers = {};

  @override
  void initState() {
    super.initState();
    // Initialize all questions to show PNG (false = PNG, true = GIF)
    for (var question in Question.questions) {
      _showingGif[question.id] = false;
    }
  }

  @override
  void dispose() {
    // Cancel all timers
    for (var timer in _gifTimers.values) {
      timer.cancel();
    }
    _gifTimers.clear();
    super.dispose();
  }

  void _triggerGifAnimation(int questionId) {
    // Cancel existing timer if any
    if (_gifTimers.containsKey(questionId)) {
      _gifTimers[questionId]!.cancel();
    }

    // Switch to GIF
    setState(() {
      _showingGif[questionId] = true;
    });

    // Set timer to switch back to PNG after 5 seconds
    _gifTimers[questionId] = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showingGif[questionId] = false;
        });
        _gifTimers.remove(questionId);
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
              Padding(
                padding: const EdgeInsets.only(right: 100), // Space for GIF on the right
                child: Container(
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
                    SfSliderTheme(
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
                      
                      // Trigger GIF animation when slider changes
                      _triggerGifAnimation(question.id);

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
                                  final desiredValue = desired[j]['value'] as double;
                                  
                                  // Stats are in the same order as questions, so use questionId as index
                                  if (questionId >= breeds[i].stats.length) {
                                    continue; // Skip if stat index is out of bounds
                                  }
                                  
                                  StatValue stat = breeds[i].stats[questionId];
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
                  ],
                ),
              ),
              ),
              // GIF on the right side - fixed width 100px, full height
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 100,
                child: Image(
                  image: getExampleImage(question),
                  fit: BoxFit.cover, // Cover to fill the 100px width and full height
                  width: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }

  AssetImage getExampleImage(Question q) {
    switch (q.id) {
      case 11:
        {
          return AssetImage(
              "assets/Fit_Examples/Body/${q.choices[globals.FelineFinderServer.instance.sliderValue[q.id]].name.replaceAll("/", "-").replaceAll("'", "").replaceAll(" ", "_")}.jpg");
        }
      case 12:
        {
          return AssetImage(
              "assets/Fit_Examples/Hair/${q.choices[globals.FelineFinderServer.instance.sliderValue[q.id]].name.replaceAll(" ", "_").replaceAll("/", "-").replaceAll("'", "")}.jpg");
        }
      case 13:
        {
          return AssetImage(
              "assets/Fit_Examples/Size/${q.choices[globals.FelineFinderServer.instance.sliderValue[q.id]].name.replaceAll(" ", "_").replaceAll("/", "-").replaceAll("'", "")}.jpg");
        }
      case 14:
        {
          return AssetImage(
              "assets/Fit_Examples/Zodicat/${q.choices[globals.FelineFinderServer.instance.sliderValue[q.id]].name.replaceAll("'", "")}.png");
        }
      default:
        {
          // For animation questions, show PNG by default, GIF when _showingGif is true
          if (_showingGif[q.id] == true) {
            // Show GIF
            return AssetImage("assets/Animation/${q.imageName}");
          } else {
            // Show PNG (replace .gif with .png)
            String pngName = q.imageName.replaceAll('.gif', '.png');
            return AssetImage("assets/Animation/$pngName");
          }
        }
    }
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
