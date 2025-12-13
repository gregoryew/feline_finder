
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
        'How active do you want your cat to be? Some cats are naturally lazy and prefer to lounge around, while others are full of energy and need lots of playtime. Consider how much time you can dedicate to interactive play and exercise.',
        1,
        10,
        'energy_level.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Very Low', 1, 1, 6),
      Choice('Low', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('High', 4, 4, 3),
      Choice('Very High', 5, 5, 2),
    ]),
    Question(
        1,
        'Playfulness',
        'How playful should your cat be? Some cats love interactive games, toys, and playtime, while others prefer to observe or relax. Think about how much you enjoy playing with your cat.',
        2,
        1,
        'fun_loving.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Not Playful', 1, 1, 6),
      Choice('Slightly Playful', 2, 2, 5),
      Choice('Moderately Playful', 3, 3, 4),
      Choice('Very Playful', 4, 4, 3),
      Choice('Extremely Playful', 5, 5, 2),
    ]),
    Question(
        2,
        'Care & Attention',
        'How much daily care and attention can you provide? Some cats need frequent grooming, health monitoring, and special care, while others are more independent and low-maintenance. Consider your schedule and availability.',
        3,
        2,
        'tlc.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Minimal', 1, 1, 6),
      Choice('Low', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('High', 4, 4, 3),
      Choice('Very High', 5, 5, 2),
    ]),
    Question(
        3,
        'Companionship',
        'How much companionship do you want from your cat? Some cats are very independent and prefer their own space, while others love to be near you and seek constant attention. Choose what fits your lifestyle.',
        4,
        3,
        'autonomy.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Very Independent', 1, 1, 6),
      Choice('Somewhat Independent', 2, 2, 5),
      Choice('Balanced', 3, 3, 4),
      Choice('Somewhat Affectionate', 4, 4, 3),
      Choice('Very Affectionate', 5, 5, 2),
    ]),
    Question(
        4,
        'Vocalization',
        'How vocal should your cat be? Some breeds, like Siamese and Bengals, are known for being very talkative and will meow frequently to communicate. Others, like Ragdolls, are typically quiet. Do you enjoy a chatty cat or prefer a quieter companion?',
        6,
        9,
        'talkative.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Very Quiet', 1, 1, 6),
      Choice('Quiet', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('Talkative', 4, 4, 3),
      Choice('Very Talkative', 5, 5, 2),
    ]),
    Question(
        5,
        'Handling & Affection',
        'How comfortable should your cat be with being handled, petted, and picked up? Some cats love physical affection and being held, while others prefer minimal handling. This is especially important if you have children or enjoy cuddling with your pet.',
        7,
        4,
        'petting.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Dislikes Handling', 1, 1, 6),
      Choice('Tolerates Handling', 2, 2, 5),
      Choice('Neutral', 3, 3, 4),
      Choice('Enjoys Handling', 4, 4, 3),
      Choice('Loves Handling', 5, 5, 2),
    ]),
    Question(
        6,
        'Intelligence',
        'How intelligent should your cat be? Some breeds are highly intelligent and enjoy learning tricks, solving puzzles, and interactive games. Others are more laid-back and less interested in mental stimulation. Consider if you want a cat that can learn and problem-solve.',
        8,
        5,
        'smart_cat.gif',
        true,
        [
          Choice('Doesn' 't Matter', 0, 5, 1),
          Choice('Low Intelligence', 1, 1, 6),
          Choice('Below Average', 2, 2, 5),
          Choice('Average', 3, 3, 4),
      Choice('Above Average', 4, 4, 3),
          Choice('Very Intelligent', 5, 5, 2),
    ]),
    Question(
        8,
        'Grooming Needs',
        'How much grooming are you willing to do? Long-haired cats require daily brushing to prevent matting, while short-haired cats need minimal grooming. Some breeds need regular bathing or special care. Consider your time and commitment to grooming.',
        11,
        7,
        'grooming.gif',
        true,
        [
          Choice('Doesn' 't Matter', 0, 4, 1),
          Choice('Minimal', 1, 1, 5),
          Choice('Low', 2, 2, 4),
          Choice('Moderate', 3, 3, 3),
          Choice('High', 4, 4, 2),
        ]),
    Question(
        9,
        'Good with Children',
        'How well should your cat get along with children? Some breeds are patient, gentle, and tolerant of children\'s play, making them ideal family pets. Others may be less tolerant of loud noises or rough handling. This is important if you have or plan to have children.',
        13,
        11,
        'good_with_children.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Not Good', 1, 1, 6),
      Choice('Tolerates', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('Good', 4, 4, 3),
      Choice('Excellent', 5, 5, 2),
    ]),
    Question(
        10,
        'Good with Other Pets',
        'How well should your cat get along with other pets? Some breeds are social and adapt well to living with other cats, dogs, or pets. Others prefer to be the only pet in the household. This is crucial if you already have or plan to have other animals.',
        12,
        8,
        'good_with_pets.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Not Good', 1, 1, 6),
      Choice('Tolerates', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('Good', 4, 4, 3),
      Choice('Excellent', 5, 5, 2),
    ]),
  ];
}

class Choice {
  String name;
  int lowRange;
  int highRange;
  int order;

  Choice(this.name, this.lowRange, this.highRange, this.order);
}
