
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
        'Do you want your cat to be lazy or full of energy? Or maybe somewhere in between?  Think about how much time you can spend with your cat. If he is full of energy, you will need to spend much more time.',
        1,
        10,
        'energy_level.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Lazy', 1, 1, 6),
      Choice('Moderate Energy', 2, 2, 5),
      Choice('Medium Energy', 3, 3, 4),
      Choice('Medium/High Energy', 4, 4, 3),
      Choice('Full of Energy', 5, 5, 2),
    ]),
    Question(
        1,
        'Fun-loving',
        'How playful do you want your cat to be?  Most cats are at least somewhat playful, but some are very frisky.  So, do you want to play with your cat much, or do you want him relaxed and laid back?',
        2,
        1,
        'fun_loving.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Not Frisky', 1, 1, 6),
      Choice('Kind of Frisky', 2, 2, 5),
      Choice('Medium', 3, 3, 4),
      Choice('Frisky', 4, 4, 3),
      Choice('Very Frisky', 5, 5, 2),
    ]),
    Question(
        2,
        'TLC',
        'How much care and attention can you give your cat daily?  Some cats need lots of care and attention on one end of the spectrum, and others require very little.  How much time and attention are you willing to give?',
        3,
        2,
        'tlc.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Little', 1, 1, 6),
      Choice('Some', 2, 2, 5),
      Choice('Medium', 3, 3, 4),
      Choice('A Lot', 4, 4, 3),
      Choice('Constant', 5, 5, 2),
    ]),
    Question(
        3,
        'Companion',
        'Do you want a cat that is constantly at your side, or would you want an independent one?  Or maybe somewhere in-between?',
        4,
        3,
        'autonomy.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Independent', 1, 1, 6),
      Choice('Mostly Independent', 2, 2, 5),
      Choice('Inbetween', 3, 3, 4),
      Choice('Mostly Companion', 4, 4, 3),
      Choice('Companion', 5, 5, 2),
    ]),
    Question(
        4,
        '"Talkative"',
        'How often do you want your cat to meow and/or chirp, i.e., "talk"?  Some cats like to talk very much, for example, a Bengal, and some hardly make a sound like a Rag Doll.',
        6,
        9,
        'talkative.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Mostly Silent', 1, 1, 6),
      Choice('Talk a Little Bit', 2, 2, 5),
      Choice('Average', 3, 3, 4),
      Choice('Somewhat Talkative', 4, 4, 3),
      Choice('Chatty Cathy', 5, 5, 2),
    ]),
    Question(
        5,
        'Willingness to be petted',
        'This indicates how willing the breed is to being handled and petted.  Some cats can be picked up, petted, and cared for very easily, while some do not like to be handled.  How should the cat feel about handling and petting?',
        7,
        4,
        'petting.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Does Not Like It', 1, 1, 6),
      Choice('Tolerates It', 2, 2, 5),
      Choice('Doesn' 't Mind It', 3, 3, 4),
      Choice('Likes It', 4, 4, 3),
      Choice('Loves It', 5, 5, 2),
    ]),
    Question(
        6,
        'Brains',
        'How smart should the cat be?  Some cat breeds are very intelligent and can learn tricks like fetching balls of paper by watching people and small animals, and some breeds don'
            't care to do this.',
        8,
        5,
        'smart_cat.gif',
        true,
        [
          Choice('Doesn' 't Matter', 0, 5, 1),
          Choice('He Could Careless', 1, 1, 6),
          Choice('Sometimes', 2, 2, 5),
          Choice('Average', 3, 3, 4),
          Choice('Likes To Do Things', 4, 4, 3),
          Choice('Loves To Do Things', 5, 5, 2),
        ]),
    Question(
        7,
        'Fitness',
        'Some cats live longer than others. So how long do you want your cat to live?',
        10,
        15,
        'fitness.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Shortest', 1, 1, 6),
      Choice('Below Average', 2, 2, 5),
      Choice('Average', 3, 3, 4),
      Choice('Above Average', 4, 4, 3),
      Choice('Longest', 5, 5, 2),
    ]),
    Question(
        8,
        'Grooming Needs',
        'How much time and attention needs to be paid to the cat'
            's hygiene?  Some cats require much, and some require very little.  How much time and attention?',
        11,
        7,
        'grooming.gif',
        true,
        [
          Choice('Doesn' 't Matter', 0, 4, 1),
          Choice('A Little', 1, 1, 5),
          Choice('Average', 2, 2, 4),
          Choice('Some', 3, 3, 3),
          Choice('Much', 4, 4, 2),
        ]),
    Question(
        9,
        'Good with Children',
        'Some cats are better with children than others. So how well should the cat get along with children?',
        13,
        11,
        'good_with_children.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Doesn' 't Tolerate', 1, 1, 6),
      Choice('Tolerates Children', 2, 2, 5),
      Choice('Average', 3, 3, 4),
      Choice('Well', 4, 4, 3),
      Choice('Very Well', 5, 5, 2),
    ]),
    Question(
        10,
        'Good with other pets',
        'Some cat breeds live quite well with other animals in the household, while other cats need to be the only animal in the home.  How well should he get along with other pets in your household?',
        12,
        8,
        'good_with_pets.gif',
        true, [
      Choice('Doesn' 't Matter', 0, 5, 1),
      Choice('Doesn' 't Tolerate Pets', 1, 1, 6),
      Choice('Tolerates Them', 2, 2, 5),
      Choice('Average', 3, 3, 4),
      Choice('Well', 4, 4, 3),
      Choice('Very Well', 5, 5, 2),
    ]),
    Question(11, 'Build', 'What body type should your cat be?', 14, 12, 'Build',
        true, [
      Choice('Doesn' 't Matter', 1, 11, 1),
      Choice('Oriental', 1, 1, 2),
      Choice('Foreign', 2, 2, 3),
      Choice('Semi-Foreign', 3, 3, 4),
      Choice('Semi-Coby', 4, 4, 5),
      Choice('Cobby', 5, 5, 6),
      Choice('Drawf', 6, 6, 7),
      Choice('Large', 7, 7, 7),
      Choice('Medium', 8, 8, 8),
      Choice('Moderate', 9, 9, 9),
      Choice('Normal', 10, 10, 10),
      Choice('Small', 11, 11, 11),
    ]),
    Question(12, 'Hair Type', 'What type of coat should your cat have?', 15, 13,
        'Type of Hair', true, [
      Choice('Doesn' 't Matter', 1, 7, 1),
      Choice('Hairless', 1, 1, 2),
      Choice('Short', 2, 2, 3),
      Choice('Rex', 3, 3, 4),
      Choice('Medium', 4, 4, 5),
      Choice('Long Hair', 5, 5, 6),
      Choice('Short/Long Hair', 6, 6, 7),
    ]),
    Question(13, 'Size', 'What size would you prefer for your cat?', 16, 14,
        'size.gif', true, [
      Choice('Doesn' 't Matter', 1, 4, 1),
      Choice('Small', 1, 1, 2),
      Choice('Average', 2, 2, 3),
      Choice('Biggish', 3, 3, 4),
    ]),
    Question(
        14,
        'Zodicat',
        'For fun, see which breeds of cat are a match with your Zodicat sign?',
        17,
        17,
        'zodicat.jpg',
        true, [
      Choice('Doesn' 't Matter', 0, 12, 1),
      Choice('♒ Aquarius (Jan 20 - Feb 18)', 1, 1, 2),
      Choice('♓ Pisces (Feb 19 - March 20)', 2, 2, 3),
      Choice('♈ Aries (March 21 - Apr 19)', 3, 3, 4),
      Choice('♉ Taurus (Apr 20 - May 20)', 4, 4, 5),
      Choice('♊ Gemini (May 21 - Jun 20)', 5, 5, 6),
      Choice('♋ Cancer (Jun 21 - July 22)', 6, 6, 7),
      Choice('♌ Leo (July 23 - Aug 22)', 7, 7, 8),
      Choice('♍ Virgo (Aug 23 - Sep 22)', 8, 8, 9),
      Choice('♎ Libra (Sep 23 - Oct 22)', 9, 9, 10),
      Choice('♏ Scorpio (Oct 23 - Nov 21)', 10, 10, 11),
      Choice('♐ Sagittarius (Nov 22 - Dec 21)', 11, 11, 12),
      Choice('♑ Capricorn (Dec 22 - Jan 19)', 12, 12, 13),
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
