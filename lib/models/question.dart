import 'package:flutter/material.dart';

class Question {
  int id;
  String name;
  String description;
  int order;
  int traitID;
  String imageName;
  bool show;
  List<Choice> choices;

  Question(
    this.id,
    this.name,
    this.description,
    this.order,
    this.traitID,
    this.imageName,
    this.show,
    this.choices,
  );

  static List<Question> questions = [
    Question(
        0,
        'Energy Level',
        'Do you want your dog to be lazy or full of energy? Or maybe somewhere in between?  Think about how much time you can spend with your dog. If he is full of energy, you will need to spend much more time.',
        1,
        10,
        'energy_level.gif',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Lazy', 1, 1, 6),
      Choice('Moderate Energy', 2, 2, 5),
      Choice('Medium Energy', 3, 3, 4),
      Choice('Medium/High Energy', 4, 4, 3),
      Choice('Full of Energy', 5, 5, 2),
    ]),
    Question(
        1,
        'Exercise',
        'Your dog'
            's breed heavily influences the level of physical activity he needs. High-energy breeds, such as Border Collies and Belgian Malinois, require a lot more exercise than low-energy breeds like the Bulldog or Basset Hound. A breed'
            's exercise requirements are important to keep in mind when choosing a puppy.',
        1,
        10,
        '',
        true,
        [
          Choice("Doesn't Matter", 0, 5, 1),
          Choice('Tranquil', 1, 1, 6),
          Choice('Calm', 2, 2, 5),
          Choice('Regular Exercise', 3, 3, 4),
          Choice('Medium/High Exercise', 4, 4, 3),
          Choice('Needs Lots Of Exercise', 5, 5, 2),
        ]),
    Question(
        2,
        'Playfullness',
        'How playfull do you want your dog to be?  Most dogs are at least somewhat playful, but some are very playful.  So do you want to play with your dog much, or do you want hum relaxed and laid back?',
        1,
        10,
        '',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Mellow', 1, 1, 6),
      Choice('Relaxed', 2, 2, 5),
      Choice('Medium', 3, 3, 4),
      Choice('Playfull', 4, 4, 3),
      Choice('Very Playfull', 5, 5, 2),
    ]),
    Question(
        3,
        'Affection',
        'Showing your dog affection is an important part of establishing your bond.',
        1,
        10,
        '',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Not Affectionate', 1, 1, 6),
      Choice('A Little Affectionate', 2, 2, 5),
      Choice('Medium', 3, 3, 4),
      Choice('Passionate', 4, 4, 3),
      Choice('Adoring', 5, 5, 2),
    ]),
    Question(
        4,
        'Friendlyness To Dogs',
        'How well do you want your dog to get along with other dogs?  If your dog does not get along with other dogs then you may have a problem if you have other dogs or walking your dog in the park.',
        1,
        10,
        '',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Dog Aggressive', 1, 1, 6),
      Choice('Dog Indifferent', 2, 2, 5),
      Choice('Dog Tolerant', 3, 3, 4),
      Choice('Dog Selective', 4, 4, 3),
      Choice('Dog Social', 5, 5, 2),
    ]),
    Question(
        5,
        'Friendylness To Other Pets',
        'How well do you want your dog to get along wiht other pets?  This is important if you have other animals like other dogs in your house hold or outside.',
        1,
        10,
        '',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Other Pet Aggressive', 1, 1, 6),
      Choice('Other Pet Indifferent', 2, 2, 5),
      Choice('Other Pet Tolerant', 3, 3, 4),
      Choice('Gets Along With Other Pets', 4, 4, 3),
      Choice('Loves Other Pets', 5, 5, 2),
    ]),
    Question(
        6,
        'Friendylness To Strangers',
        'How well do you want your dog to get along with strangers?  This is something to think about, for instance, if you entertain a lot and also if you take the dog for walks in the park.',
        1,
        10,
        '',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Territorial ', 1, 1, 6),
      Choice('Apprehensive', 2, 2, 5),
      Choice('Indifferent', 3, 3, 4),
      Choice('Social', 4, 4, 3),
      Choice('Loves', 5, 5, 2),
    ]),
    Question(
        7,
        'Watchfullness',
        'Are you adopting a dog to be a guard dog?  If that is the case some dog breeds are better suited to that than others.',
        1,
        10,
        '',
        true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Unobservant', 1, 1, 6),
      Choice('Inattentive', 2, 2, 5),
      Choice('Medium', 3, 3, 4),
      Choice('Vigilant', 4, 4, 3),
      Choice('Hypervigilant', 5, 5, 2),
    ]),
    Question(8, 'Training', 'Some dog breeds are easier to train than others.',
        1, 10, '', true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Stubborn', 1, 1, 6),
      Choice('May be stubborn', 2, 2, 5),
      Choice('Agreeable', 3, 3, 4),
      Choice('Eager To Please', 4, 4, 3),
      Choice('Easy Training', 5, 5, 2),
    ]),
    Question(9, 'Grooming', '', 1, 10, '', true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('Not Much', 1, 1, 6),
      Choice('Infrequently', 2, 2, 5),
      Choice('Regularly', 3, 3, 4),
      Choice('Frequently', 4, 4, 3),
      Choice('Much', 5, 5, 2),
    ]),
    Question(10, 'Barking Level', '', 1, 10, '', true, [
      Choice("Doesn't Matter", 0, 5, 1),
      Choice('When Necessary', 1, 1, 6),
      Choice('Infrequently', 2, 2, 5),
      Choice('Medium', 3, 3, 4),
      Choice('Frequent', 4, 4, 3),
      Choice('Likes To Be Vocal', 5, 5, 2),
    ]),
  ];
  //https://www.dogthelove.com/category/?alphabet=A
  //Coat Type: Hairless, Short, Medium, Long, Smooth, Wire
  //Shedding: Infrequent, Seasonal, Occasional, Frequent, Regurally
  //Size: XSmall, Small, Medium, Large, XLarge 
}

class Choice {
  String name;
  int lowRange;
  int highRange;
  int order;

  Choice(this.name, this.lowRange, this.highRange, this.order);
}
