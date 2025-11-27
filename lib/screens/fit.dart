import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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
  Timer? timer;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) {
      showDescription(0);
      timer!.cancel();
    });
  }

  final itemController = ItemScrollController();
  int _priorVisibleQuestion = -1;
  final _descriptionVisible = [
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false
  ];

  @override
  Widget build(BuildContext context) {
    return Container(child: buildRows());
  }

  Widget buildRows() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: buildQuestions()),
        SizedBox(width: 120, child: buildMatches()),
      ],
    );
  }

  Widget buildQuestions() {
    return ScrollablePositionedList.builder(
        itemCount: Question.questions.length,
        itemScrollController: itemController,
        itemBuilder: (BuildContext context, int index) {
          return buildQuestionCard(Question.questions[index]);
        });
  }

  showDescription(int i) {
    setState(() {
      if (_descriptionVisible[i]) {
        _descriptionVisible[i] = false;
      } else {
        if (_priorVisibleQuestion > -1) {
          _descriptionVisible[_priorVisibleQuestion] = false;
        }
        _priorVisibleQuestion = i;
        _descriptionVisible[i] = true;
        itemController.jumpTo(index: i);
      }
    });
  }

  Widget buildQuestionCard(Question question) {
    return AnimatedSize(
      curve: _descriptionVisible[question.id]
          ? Curves.fastLinearToSlowEaseIn
          : Curves.fastLinearToSlowEaseIn,
      duration: const Duration(milliseconds: 1000),
        child: Container(
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
              // Background animated gif - embedded effect
              Positioned.fill(
                child: Opacity(
                  opacity: 0.2, // Semi-transparent for embedded look
                  child: Image(
                    image: getExampleImage(question),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              // Gradient overlay on top of gif
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
                    Row(
                children: [
                  Expanded(
                      child: Text(
                          "${question.name}: ${question
                                  .choices[globals.FelineFinderServer.instance
                                      .sliderValue[question.id]]
                                  .name}",
                          style: const TextStyle(fontSize: 13))),
                  IconButton(
                    icon: AnimatedRotation(
                        turns:
                            _descriptionVisible[question.id] ? -1 * (1 / 2) : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.expand_less)),
                    onPressed: () => {showDescription(question.id)},
                  )
                    ],
                  ),
                    const Divider(
                color: Colors.grey,
                thickness: 1,
                indent: 5,
                endIndent: 5,
                    ),
                    SfSliderTheme(
                data: const SfSliderThemeData(
                  inactiveTrackColor: Color.fromARGB(255, 193, 186, 186),
                  activeTrackColor: Color.fromARGB(255, 193, 186, 186),
                  inactiveDividerColor: Color(0xff2196F2),
                  activeDividerColor: Color(0xff2196F2),
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
                  showDividers: true,
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
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.blue, shape: BoxShape.circle),
                      margin: const EdgeInsets.all(3),
                    ),
                  ),
                  onChanged: (newValue) {
                    setState(() {
                      globals.FelineFinderServer.instance
                          .sliderValue[question.id] = newValue.round();

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
                    Visibility(
                visible: _descriptionVisible[question.id],
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      const Divider(
                        color: Colors.grey,
                        thickness: 1,
                        indent: 5,
                        endIndent: 5,
                      ),
                      Text(question.description,
                          style: const TextStyle(fontSize: 10)),
                      const SizedBox(height: 20),
                      SizedBox(
                          width: 200,
                          height: 200,
                          child: Image(image: getExampleImage(question))),
                    ],
                  ),
                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          return AssetImage("assets/Animation/${q.imageName}");
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
    // Calculate available width: column width (200) minus margins
    // With reduced margins, use full column width minus minimal margins
    const double availableWidth = 200;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 0.0, // Reduced left/right margins
        vertical: 12.0, // Increased spacing between breed cards
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
                // Reduce width by 15px total (5px on top, 5px on left, 5px on right)
                final double imageWidth = constraints.maxWidth - 10;
                return Padding(
                  // Add padding on top, left, and right by 10px each (top is 15px to move image down)
                  padding: const EdgeInsets.only(
                    top: 15.0,
                    left: 10.0,
                    right: 10.0,
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
