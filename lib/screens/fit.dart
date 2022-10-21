import 'package:crop/crop.dart';
import 'package:flutter/material.dart';
import 'package:recipes/Models/question.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import 'globals.dart' as globals;
import '/models/breed.dart';
import '/screens/breedDetail.dart';

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
        Expanded(flex: 7, child: buildQuestions()),
        Expanded(flex: 3, child: buildMatches()),
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
    return Card(
      margin: EdgeInsets.all(8.0),
      elevation: 5,
      child: Padding(
        // Even Padding On All Sides
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(
                        question.name +
                            ": " +
                            question
                                .choices[globals.FelineFinderServer.instance
                                    .sliderValue[question.id]]
                                .name,
                        style: const TextStyle(fontSize: 13))),
                IconButton(
                  icon: Icon(
                      _descriptionVisible[question.id]
                          ? Icons.arrow_drop_down
                          : Icons.arrow_right,
                      size: 50),
                  onPressed: () => showDescription(question.id),
                ),
              ],
            ),
            const Divider(
              color: Colors.grey,
              thickness: 1,
              indent: 5,
              endIndent: 5,
            ),
            SfSliderTheme(
              data: SfSliderThemeData(
                inactiveTrackColor: Color.fromARGB(255, 193, 186, 186),
                activeTrackColor: Color.fromARGB(255, 193, 186, 186),
                inactiveDividerColor: const Color(0xff2196F2),
                activeDividerColor: const Color(0xff2196F2),
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

                    final desired = <StatValue>[];
                    for (var i = 0; i < Question.questions.length; i++) {
                      if (globals.FelineFinderServer.instance.sliderValue[i] >
                          0) {
                        desired.add(StatValue(
                            Question.questions[i].name,
                            true,
                            globals.FelineFinderServer.instance.sliderValue[i]
                                .toDouble()));
                      }
                    }

                    for (var i = 0; i < breeds.length; i++) {
                      double sum = 0;
                      for (var j = 0; j < desired.length; j++) {
                        StatValue stat = breeds[i].stats.firstWhere(
                            (element) => element.name == desired[j].name);
                        Question q = Question.questions.firstWhere(
                            (element) => element.name == desired[j].name);
                        if (stat.isPercent) {
                          sum += 1.0 -
                              (desired[j].value - stat.value).abs() /
                                  q.choices.length;
                        } else {
                          if (desired[j].value == stat.value) {
                            sum += 1;
                          }
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
          // 8
          onTap: () {
            // 9
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  // 10
                  return BreedDetail(breed: breeds[index]);
                },
              ),
            );
          },
          child: buildBreedCard(breeds[index]),
        );
      },
    );
  }

  Widget buildBreedCard(Breed breed) {
    return Card(
      // 1
      elevation: 5.0,
      // 2
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      shadowColor: Colors.grey,
      margin: const EdgeInsets.all(5),
      child: Column(
        children: <Widget>[
          Image(
              image: AssetImage(
                  'assets/Cartoon/Cartoon_${breed.pictureHeadShotName.replaceAll(' ', '_')}.png')),
          // 5
          const SizedBox(
            height: 5.0,
          ),
          // 6
          Text(
            breed.name,
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 5.0,
          ),
          SizedBox(
            height: 30,
            width: 200,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(
                  10,
                ),
                bottomRight: Radius.circular(
                  10,
                ),
              ),
              child: Container(
                color: const Color.fromARGB(255, 210, 198, 198),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '${(breed.percentMatch * 100)..toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
