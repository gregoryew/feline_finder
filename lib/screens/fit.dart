import 'package:flutter/material.dart';
import 'package:recipes/Models/question.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:crop/crop.dart';
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
  final _sliderValue = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
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
    return ListView.builder(
        itemCount: Question.questions.length,
        itemBuilder: (BuildContext context, int index) {
          return buildQuestionCard(Question.questions[index]);
        });
  }

  showDescription(int i) {
    setState(() {
      if (_descriptionVisible[i]) {
        _descriptionVisible[i] = false;
      } else {
        _descriptionVisible[i] = true;
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
                Expanded(child: Text(question.name)),
                IconButton(
                  icon: Icon(_descriptionVisible[question.id]
                      ? Icons.help
                      : Icons.help_outline),
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
                enableTooltip: true,
                value: _sliderValue[question.id].toDouble(),
                tooltipTextFormatterCallback:
                    (dynamic actualValue, String formattedText) {
                  return question.choices[_sliderValue[question.id]].name;
                },
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
                    _sliderValue[question.id] = newValue.round();

                    final desired = <StatValue>[];
                    for (var i = 0; i < Question.questions.length; i++) {
                      if (_sliderValue[i] > 0) {
                        desired.add(StatValue(Question.questions[i].name, true,
                            _sliderValue[i].toDouble()));
                      }
                    }

                    for (var i = 0; i < Breed.breeds.length; i++) {
                      double sum = 0;
                      for (var j = 0; j < desired.length; j++) {
                        StatValue stat = Breed.breeds[i].stats.firstWhere(
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
                        Breed.breeds[i].percentMatch = 1.0;
                      } else {
                        Breed.breeds[i].percentMatch =
                            ((sum / desired.length) * 100).floorToDouble() /
                                100;
                      }
                    }

                    Breed.breeds.sort((a, b) {
                      if (a.percentMatch.compareTo(b.percentMatch) == -1) {
                        return -1;
                      }

                      if (a.percentMatch.compareTo(b.percentMatch) == 0) {
                        return -1 * a.name.compareTo(b.name);
                      }

                      return 1;
                    });
                    Breed.breeds = List.from(Breed.breeds.reversed);
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
                    Image(
                        image: AssetImage(
                            "assets/Animation/${question.imageName}")),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

//Animation/${question.imageName}

  Widget buildMatches() {
    return ListView.builder(
      itemCount: Breed.breeds.length,
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
                  return BreedDetail(breed: Breed.breeds[index]);
                },
              ),
            );
          },
          child: buildBreedCard(Breed.breeds[index]),
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
