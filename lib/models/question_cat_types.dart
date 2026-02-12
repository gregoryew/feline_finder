
class Question_Cat_Types {
  int id;
  String name;
  String description;
  int order;
  int traitID;
  String imageName;
  bool show;
  List<Choice> choices;

  Question_Cat_Types(
    this.id,
    this.name,
    this.description,
    this.order,
    this.traitID,
    this.imageName,
    this.show,
    this.choices,
  );

  static List<Question_Cat_Types> questions = [
    Question_Cat_Types(
        1,
        'Energy Level',
        'How active do you want your cat to be? Some cats are naturally lazy and prefer to lounge around, while others are full of energy and need lots of playtime. Consider how much time you can dedicate to interactive play and exercise.',
        1,
        10,
        'energy_level.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Very Low', 1, 1, 6),
      Choice('Low', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('High', 4, 4, 3),
      Choice('Very High', 5, 5, 2),
    ]),
    Question_Cat_Types(
        2,
        'Playfulness',
        'How playful should your cat be? Some cats love interactive games, toys, and playtime, while others prefer to observe or relax. Think about how much you enjoy playing with your cat.',
        2,
        1,
        'fun_loving.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Not Playful', 1, 1, 6),
      Choice('Slightly Playful', 2, 2, 5),
      Choice('Moderately Playful', 3, 3, 4),
      Choice('Very Playful', 4, 4, 3),
      Choice('Extremely Playful', 5, 5, 2),
    ]),
    Question_Cat_Types(
        3,
        'Affection Level',
        'How cuddly do you want your cat to be? Some cats seek constant snuggles and physical affection, while others prefer affection on their own terms. Think about whether you want a lap cat, occasional cuddles, or a more hands-off companion.',
        3,
        2,
        'tlc.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Minimal', 1, 1, 6),
      Choice('Low', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('High', 4, 4, 3),
      Choice('Very High', 5, 5, 2),
    ]),
    Question_Cat_Types(
        4,
        'Independence',
        'How independent should your cat be? Independent cats are happy entertaining themselves and may prefer more personal space. Less independent cats tend to follow you around, seek attention, and want to be involved in whatever you’re doing.',
        4,
        3,
        'autonomy.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Very Independent', 1, 1, 6),
      Choice('Somewhat Independent', 2, 2, 5),
      Choice('Balanced', 3, 3, 4),
      Choice('Somewhat Affectionate', 4, 4, 3),
      Choice('Very Affectionate', 5, 5, 2),
    ]),
    Question_Cat_Types(
        5,
        'Sociability',
        'How social should your cat be? Social cats enjoy meeting new people, hanging out in busy spaces, and being part of the action. Less social cats may be shy, prefer quieter environments, and take longer to warm up to visitors.',
        6,
        9,
        'talkative.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Very Unsocial', 1, 1, 6),
      Choice('Unsocial', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('Social', 4, 4, 3),
      Choice('Very Social', 5, 5, 2),
    ]),
    Question_Cat_Types(
        6,
        'Vocalization',
        'How vocal should your cat be? Some breeds, like Siamese and Bengals, are known for being very talkative and will meow frequently to communicate. Others, like Ragdolls, are typically quiet. Do you enjoy a chatty cat or prefer a quieter companion?',
        6,
        9,
        'talkative.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Very Quiet', 1, 1, 6),
      Choice('Quiet', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('Talkative', 4, 4, 3),
      Choice('Very Talkative', 5, 5, 2),
    ]),
    Question_Cat_Types(
        7,
        'Confidence',
        'How confident should your cat be? Confident cats are bold, curious, and adapt quickly to new places and experiences. Less confident cats may be cautious or easily startled and often do best with predictable routines and gentle introductions.',
        7,
        4,
        'petting.gif',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Unconfident', 1, 1, 6),
      Choice('Somewhat Unconfident', 2, 2, 5),
      Choice('Neutral', 3, 3, 4),
      Choice('Somewhat Confident', 4, 4, 3),
      Choice('Confident', 5, 5, 2),
    ]),
    Question_Cat_Types( 
        8,
        'Sensitivity',
        'How sensitive should your cat be? Sensitive cats may react strongly to loud noises, sudden changes, or hectic households. Less sensitive cats are typically more easygoing and comfortable with activity, visitors, and day-to-day changes.',
        11,
        7,
        '',
        true,
        [
          Choice('Doesn\'t Matter', 0, 4, 1),
          Choice('Minimal', 1, 1, 5),
          Choice('Low', 2, 2, 4),
          Choice('Moderate', 3, 3, 3),
          Choice('High', 4, 4, 2),
        ]),
    Question_Cat_Types(
        9,
        'Adaptability',
        'How adaptable should your cat be? Adaptable cats handle changes—like moving, travel, new pets, or schedule shifts—more easily. Less adaptable cats may need extra time and a steady routine to feel comfortable when things change.',
        13,
        11,
        '',
        true, [
      Choice('Doesn\'t Matter', 0, 5, 1),
      Choice('Not Adaptable', 1, 1, 6),
      Choice('Somewhat Adaptable', 2, 2, 5),
      Choice('Moderate', 3, 3, 4),
      Choice('Adaptable', 4, 4, 3),
      Choice('Very Adaptable', 5, 5, 2),
    ]),
    Question_Cat_Types(
        10,
        'Intelligence',
        'How intelligent should your cat be? Some breeds are highly intelligent and enjoy learning tricks, solving puzzles, and interactive games. Others are more laid-back and less interested in mental stimulation. Consider if you want a cat that can learn and problem-solve.',
        8,
        5,
        'smart_cat.gif',
        true,
        [
          Choice('Doesn\'t Matter', 0, 5, 1),
          Choice('Low Intelligence', 1, 1, 6),
          Choice('Below Average', 2, 2, 5),
          Choice('Average', 3, 3, 4),
      Choice('Above Average', 4, 4, 3),
          Choice('Very Intelligent', 5, 5, 2),
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