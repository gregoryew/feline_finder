import 'package:flutter/material.dart';
import 'package:recipes/Models/question.dart';
import '/models/breed.dart';
import '/screens/breedDetail.dart';

class Fit extends StatefulWidget {

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
  final _descriptionVisible = [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false];

  @override
  Widget build(BuildContext context) {
    return Container(child: buildRows());
  }

Widget buildRows() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Expanded(
        flex: 7,
        child: buildQuestions()
      ),
      Expanded(
        flex: 3,
        child: buildMatches()
      ),
  ],);
}

Widget buildQuestions() {
  return ListView.builder(
          itemCount: Question.questions.length,
          itemBuilder: (BuildContext context, int index) {
            return buildQuestionCard(Question.questions[index]);
          }
  );
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
  return Container(
    child:Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            margin: new EdgeInsets.all(10.0),
            child: Row(children: [Text(question.name), Spacer(), IconButton(icon: Icon(_descriptionVisible[question.id] ? Icons.help : Icons.help_outline), onPressed: () => showDescription(question.id),)],)
        ),
    Slider(
      // 10
      min: 0,
      max: question.choices.length.toDouble() - 1.0,
      divisions: question.choices.length - 1,
      // 11
      label: question.choices[_sliderValue[question.id]].name,
      // 12
      value: _sliderValue[question.id].toDouble(),
      // 13
      onChanged: (newValue) {
        setState(() {
          _sliderValue[question.id] = newValue.round();

          final desired = <StatValue>[];
          for (var i = 0; i < Question.questions.length; i++) {
            if (_sliderValue[i] > 0) {
              desired.add(StatValue(Question.questions[i].name, true, _sliderValue[i].toDouble()));
            }
          }

          for (var i = 0; i < Breed.breeds.length; i++) {
            double sum = 0;
            for (var j = 0; j < desired.length; j++) {
              StatValue stat = Breed.breeds[i].stats.firstWhere((element) => element.name == desired[j].name);
              Question q = Question.questions.firstWhere((element) => element.name == desired[j].name);
              if (stat.isPercent) {
                sum += 1.0 - (desired[j].value - stat.value).abs() / q.choices.length;
              } else {
                if (desired[j].value == stat.value) {
                  sum += 1;
                }
              }
            }
            if (desired.isEmpty) {
              Breed.breeds[i].percentMatch = 1.0;
            } else {
              Breed.breeds[i].percentMatch = ((sum / desired.length) * 100).floorToDouble() / 100;
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
          Breed.breeds = new List.from(Breed.breeds.reversed);
        });
      },
      // 14
      activeColor: Colors.green,
      inactiveColor: Colors.black,
    ),
    Visibility (
      visible: _descriptionVisible[question.id],
      child: Container(
        margin: new EdgeInsets.all(10.0),
        child: Row(children: [Expanded(flex: 7, child: Text(question.description),),
        Spacer(),
        Expanded(flex: 3, child: Image( image: AssetImage("assets/Animation/${question.imageName}"))),
        ])),
      )
  ],));
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
    elevation: 2.0,
    // 2
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0)),
    // 3
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      // 4
      child: Column(
        children: <Widget>[
          Image(image: AssetImage('assets/Cartoon/Cartoon_${breed.pictureHeadShotName.replaceAll(' ', '_')}.png')),
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
          Text(
            '${(breed.percentMatch * 100).toString()}%',
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
}