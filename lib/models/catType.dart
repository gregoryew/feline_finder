class CatType {
  int id;
  String name;
  String description;
  String tagline;
  int sortOrder;
  String imageName;
  double percentMatch;
  List<StatValue> stats;
  List<String> positives;
  List<String> negatives;

  CatType(
      this.id,
      this.name,
      this.description,
      this.tagline,
      this.sortOrder,
      this.imageName,
      this.percentMatch,
      this.stats,
      this.positives,
      this.negatives);
}

class StatValue {
  String name;
  bool isPercent;
  double value;
  StatValue(this.name, this.isPercent, this.value);
}

List<CatType> catType = [
  // 1–5 values: Energy, Playfulness, Affection, Independence, Sociability,
  //             Vocality, Confidence, Sensitivity, Adaptability, Intelligence

  CatType(1,
    'Professional Napper',
      'A calm, low-energy cat who loves sleeping and relaxing most of the day.',
      'Sleep first, everything else later.',
      1, 'Professional_Napper', 1.0, [
    StatValue('Energy Level', false, 1),
    StatValue('Playfulness', false, 1),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 5),
    StatValue('Sociability', false, 2),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 2),
  ], [
    'Low maintenance; won\'t need constant play or stimulation.',
    'Quiet and undemanding—ideal for small spaces or busy schedules.',
    'Easy to live with; adapts to calm routines.',
  ], [
    'May seem aloof or uninterested in active bonding.',
    'Might not suit someone wanting a highly interactive cat.',
  ]),

  CatType(2, 'Lap Legend',
      'A devoted cuddle companion who loves sitting on laps and being close to people.',
      'Your lap is home.',
      2, 'Lap_Legend', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 5),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Very affectionate and comforting; great for emotional support.',
    'Strong bond and loyal companionship.',
    'Moderate energy—enjoys play but also downtime.',
  ], [
    'May become anxious or needy if left alone often.',
    'Might demand more lap time than you can give.',
  ]),

  CatType(3, 'Zen Companion',
      'An easygoing, peaceful cat that adapts well to calm homes and routines.',
      'Calm vibes only.',
      3, 'Zen_Companion', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 3),
  ], [
    'Highly adaptable; handles moves, travel, and change well.',
    'Calm and quiet—good for apartments or shared housing.',
    'Balanced affection; not clingy but still social.',
  ], [
    'May be too low-key for someone wanting a lively playmate.',
    'Can seem reserved compared to very outgoing types.',
  ]),

  CatType(4, 'Old Soul',
      'A mature, thoughtful cat with a steady temperament and gentle presence.',
      'Wise beyond their whiskers.',
      4, 'Old_Soul', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 2),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Steady and predictable; great for first-time or nervous owners.',
    'Confident and unflappable; handles stress well.',
    'Gentle presence; good with calm households.',
  ], [
    'May prefer less excitement than kids or busy homes provide.',
    'Can be slow to warm up to frequent guests.',
  ]),

  CatType(5, 'Quiet Shadow',
      'A low-profile cat who stays nearby without demanding attention.',
      'Always near, never loud.',
      5, 'Quiet_Shadow', 1.0, [
    StatValue('Energy Level', false, 1),
    StatValue('Playfulness', false, 1),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 1),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 3),
    StatValue('Adaptability', false, 2),
    StatValue('Intelligence', false, 2),
  ], [
    'Very quiet and unobtrusive; ideal for strict noise environments.',
    'Content to be near you without demanding interaction.',
    'Low energy; minimal destruction or mischief.',
  ], [
    'Can be hard to read or bond with; may hide often.',
    'Might not suit someone wanting obvious affection.',
  ]),

  CatType(6, 'Zoomie Rocket',
      'A high-energy cat who loves running, jumping, and nonstop movement.',
      'Fueled by pure chaos.',
      6, 'Zoomie_Rocket', 1.0, [
    StatValue('Energy Level', false, 5),
    StatValue('Playfulness', false, 5),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 3),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Endlessly entertaining; great for active households.',
    'Loves play and exercise; can be a real companion in fun.',
    'Confident and outgoing; often friendly with people.',
  ], [
    'Needs lots of play and space; can be destructive if bored.',
    'May be too much for quiet or frail owners.',
  ]),

  CatType(7, 'Parkour Cat',
      'An athletic climber who turns furniture into an obstacle course.',
      'The floor is optional.',
      7, 'Parkour_Cat', 1.0, [
    StatValue('Energy Level', false, 5),
    StatValue('Playfulness', false, 4),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 3),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 3),
    StatValue('Intelligence', false, 3),
  ], [
    'Very athletic and impressive; fun to watch and play with.',
    'Confident and bold; often fearless in new situations.',
    'Enjoys vertical space; cat trees and shelves are a hit.',
  ], [
    'Can damage furniture and knock things over; needs cat-proofing.',
    'Requires outlets for climbing or may create chaos.',
  ]),

  CatType(8, 'Toy Addict',
      'A playful cat obsessed with toys, games, and interactive play.',
      'Playtime is serious business.',
      8, 'Toy_Addict', 1.0, [
    StatValue('Energy Level', false, 4),
    StatValue('Playfulness', false, 5),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 3),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 4),
  ], [
    'Easy to entertain and bond with through play.',
    'Smart and engaged; learns tricks and games quickly.',
    'Adaptable; thrives with puzzle toys and variety.',
  ], [
    'Needs regular play sessions or may become bored or mischievous.',
    'Can be noisy or demanding when they want to play.',
  ]),

  CatType(9, 'Chaos Sprite',
      'A mischievous whirlwind of energy who keeps life entertaining.',
      'May cause laughter.',
      9, 'Chaos_Sprite', 1.0, [
    StatValue('Energy Level', false, 5),
    StatValue('Playfulness', false, 5),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 1),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 5),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 3),
    StatValue('Adaptability', false, 3),
    StatValue('Intelligence', false, 2),
  ], [
    'Never a dull moment; highly entertaining and social.',
    'Very vocal and expressive; easy to "read" and engage with.',
    'Loves people and activity; great for lively homes.',
  ], [
    'Can be overwhelming; very loud and high-energy.',
    'May get into trouble or disrupt routines if understimulated.',
  ]),

  CatType(10, 'Forever Kitten',
      'A youthful, playful cat who never quite grows out of kitten behavior.',
      'Young at heart forever.',
      10, 'Forever_Kitten', 1.0, [
    StatValue('Energy Level', false, 4),
    StatValue('Playfulness', false, 5),
    StatValue('Affection Level', false, 5),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 3),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Combines playfulness with strong affection; best of both worlds.',
    'Stays fun and engaging for years; great for families.',
    'Adaptable and social; usually good with other pets.',
  ], [
    'Needs ongoing play and attention even as an adult.',
    'May be too rambunctious for very calm or elderly owners.',
  ]),

  CatType(11, 'Velcro Cat',
      'An extremely affectionate cat who wants to be with you at all times.',
      'Personal space is overrated.',
      11, 'Velcro_Cat', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 5),
    StatValue('Independence', false, 1),
    StatValue('Sociability', false, 5),
    StatValue('Vocality', false, 3),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Deeply devoted; constant companionship and love.',
    'Very social and people-oriented; rarely aloof.',
    'Strong emotional bond; can be very comforting.',
  ], [
    'May develop separation anxiety if left alone often.',
    'Can be underfoot or demanding of attention.',
  ]),

  CatType(12, 'Cuddle Ambassador',
      'A friendly cat who bonds easily with people and enjoys affection.',
      'Certified hug expert.',
      12, 'Cuddle_Ambassador', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 5),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 5),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 4),
  ], [
    'Warm and welcoming; great with guests and new people.',
    'Highly adaptable; handles change and new environments well.',
    'Balanced energy; affectionate without being overwhelming.',
  ], [
    'May seek attention from everyone; not a one-person-only cat.',
    'Needs social interaction; not ideal for long solo days.',
  ]),

  CatType(13, 'Welcome Committee',
      'A social cat who happily greets guests and new experiences.',
      'Nice to meet you!',
      13, 'Welcome_Committee', 1.0, [
    StatValue('Energy Level', false, 4),
    StatValue('Playfulness', false, 4),
    StatValue('Affection Level', false, 4),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 5),
    StatValue('Vocality', false, 3),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 4),
  ], [
    'Confident and outgoing; great for busy or social households.',
    'Adapts quickly to new people, places, and routines.',
    'Friendly and engaging; rarely shy or fearful.',
  ], [
    'May be too bold or intrusive for very private or quiet homes.',
    'Needs stimulation and interaction; can get bored alone.',
  ]),

  CatType(14, 'Therapy Cat',
      'An emotionally intuitive cat who provides comfort and reassurance.',
      'Always knows when you need them.',
      14, 'Therapy_Cat', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 5),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 4),
  ], [
    'Calm and comforting; can be a real emotional support.',
    'Confident and adaptable; good in many settings.',
    'Tuned in to people; often responsive to mood and need.',
  ], [
    'May seek to be involved in all emotional moments.',
    'Needs a stable, supportive home to thrive.',
  ]),

  CatType(15, 'Heart Healer',
      'A deeply bonded companion who forms strong emotional connections.',
      'Love, delivered daily.',
      15, 'Heart_Healer', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 4),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 4),
  ], [
    'Forms strong, lasting bonds; very loyal and loving.',
    'Adaptable to new homes and changes when with their person.',
    'Balanced energy; affectionate and playful in moderation.',
  ], [
    'Can be deeply affected by rehoming or long absences.',
    'May bond most strongly to one person.',
  ]),

  CatType(16, 'Solo Artist',
      'An independent cat who enjoys companionship on their own terms.',
      'Together, separately.',
      16, 'Solo_Artist', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 5),
    StatValue('Sociability', false, 2),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 3),
    StatValue('Intelligence', false, 3),
  ], [
    'Low maintenance; content with alone time and own space.',
    'Confident and self-sufficient; good for busy or travel-heavy owners.',
    'Quiet and undemanding; won\'t guilt-trip you for being away.',
  ], [
    'May seem distant or uninterested in cuddles.',
    'Affection may be rare or on their schedule only.',
  ]),

  CatType(17, 'Dignified Observer',
      'A calm, confident cat who prefers to watch rather than participate.',
      'Poised and unbothered.',
      17, 'Dignified_Observer', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 1),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 2),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Very calm and predictable; easy to live with.',
    'Confident and unfazed by noise or commotion.',
    'Adapts well to new environments; not easily stressed.',
  ], [
    'May rarely seek play or cuddles; can feel distant.',
    'Might not suit someone wanting a hands-on, interactive cat.',
  ]),

  CatType(18, 'Window Philosopher',
      'A thoughtful cat who enjoys quietly observing the world.',
      'Contemplating life, bird by bird.',
      18, 'Window_Philosopher', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 1),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 1),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 3),
    StatValue('Intelligence', false, 2),
  ], [
    'Quiet and low-key; ideal for peaceful, low-traffic homes.',
    'Content with window watching and simple routines.',
    'Independent; fine with owners who work or travel.',
  ], [
    'Can be shy or slow to warm up to new people.',
    'May hide or avoid interaction when stressed.',
  ]),

  CatType(19, 'Private Thinker',
      'A reserved, sensitive cat who bonds slowly but deeply.',
      'Trust takes time.',
      19, 'Private_Thinker', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 1),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 5),
    StatValue('Sociability', false, 1),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 4),
    StatValue('Adaptability', false, 2),
    StatValue('Intelligence', false, 2),
  ], [
    'Once bonded, can be very loyal and devoted.',
    'Quiet and unobtrusive; good for calm households.',
    'Low energy; minimal demands on time or space.',
  ], [
    'Needs patience; can take weeks or months to feel safe.',
    'May be stressed by change, guests, or loud environments.',
  ]),

  CatType(20, 'Gentle Hermit',
      'A shy but sweet cat who thrives in quiet, predictable environments.',
      'Soft-hearted and cautious.',
      20, 'Gentle_Hermit', 1.0, [
    StatValue('Energy Level', false, 1),
    StatValue('Playfulness', false, 1),
    StatValue('Affection Level', false, 2),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 1),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 3),
    StatValue('Adaptability', false, 2),
    StatValue('Intelligence', false, 2),
  ], [
    'Sweet and gentle once comfortable; rewarding to earn trust.',
    'Very quiet and low maintenance; good for quiet homes.',
    'Unlikely to be destructive or demanding.',
  ], [
    'Needs a calm, stable home; can be easily overwhelmed.',
    'May hide often; not ideal for highly social or noisy households.',
  ]),

  CatType(21, 'Drama Monarch',
      'A highly expressive cat who makes sure their feelings are known.',
      'Every moment is a performance.',
      21, 'Drama_Monarch', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 4),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 5),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 3),
    StatValue('Adaptability', false, 3),
    StatValue('Intelligence', false, 2),
  ], [
    'Very expressive; easy to read their mood and needs.',
    'Affectionate and social; loves attention and interaction.',
    'Confident and engaging; rarely boring.',
  ], [
    'Can be loud and demanding; may not suit quiet households.',
    'May overreact to changes or perceived slights.',
  ]),

  CatType(22, 'Opinionated Roommate',
      'A vocal cat with strong preferences and plenty to say about them.',
      'I have notes.',
      22, 'Opinionated_Roommate', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 3),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 5),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 3),
    StatValue('Intelligence', false, 3),
  ], [
    'You always know what they want; clear communication.',
    'Confident and self-assured; good with new people.',
    'Balanced energy; social but not clingy.',
  ], [
    'Can be very loud; may not suit apartments or light sleepers.',
    'Strong opinions may mean finicky habits or routines.',
  ]),

  CatType(23, 'Soap Opera Star',
      'An affectionate but dramatic cat who feels everything intensely.',
      'Tears, cuddles, repeat.',
      23, 'Soap_Opera_Star', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 5),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 4),
    StatValue('Vocality', false, 5),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Very affectionate; loves cuddles and close contact.',
    'Expressive and engaging; never a dull moment.',
    'Adaptable; can thrive in many homes with attention.',
  ], [
    'Can be loud and emotionally intense; may overwhelm some owners.',
    'May be sensitive to routine changes or perceived neglect.',
  ]),

  CatType(24, 'Mood Ring Cat',
      'A sensitive cat whose emotions can change quickly with their environment.',
      'Feeling everything, always.',
      24, 'Mood_Ring_Cat', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 3),
    StatValue('Confidence', false, 3),
    StatValue('Sensitivity', false, 5),
    StatValue('Adaptability', false, 2),
    StatValue('Intelligence', false, 2),
  ], [
    'Deeply attuned to people and environment; can be very loving.',
    'Expressive; you\'ll know how they feel.',
    'Moderate energy; enjoys play and affection in balance.',
  ], [
    'Needs a calm, stable home; can be easily stressed by change.',
    'May be reactive to loud noises, guests, or schedule changes.',
  ]),

  CatType(25, 'Attention Magnet',
      'A charismatic cat who loves being noticed and admired.',
      'Eyes on me, please.',
      25, 'Attention_Magnet', 1.0, [
    StatValue('Energy Level', false, 4),
    StatValue('Playfulness', false, 4),
    StatValue('Affection Level', false, 4),
    StatValue('Independence', false, 1),
    StatValue('Sociability', false, 5),
    StatValue('Vocality', false, 4),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 3),
  ], [
    'Very social and engaging; great for people who want interaction.',
    'Adaptable and confident; handles new people and places well.',
    'Playful and affectionate; lots of personality.',
  ], [
    'Needs a lot of attention; can be demanding or underfoot.',
    'May not suit owners who are often away or prefer a low-key cat.',
  ]),

  CatType(26, 'Routine Master',
      'A structured cat who thrives on schedules and predictability.',
      'On time, every time.',
      26, 'Routine_Master', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 3),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 1),
    StatValue('Intelligence', false, 5),
  ], [
    'Predictable and reliable; easy to plan around.',
    'Very intelligent; enjoys learning and mental challenges.',
    'Quiet and confident; low drama.',
  ], [
    'Struggles with change; moves or schedule shifts can be stressful.',
    'May become anxious or upset if routines are disrupted.',
  ]),

  CatType(27, 'Puzzle Pro',
      'A clever cat who enjoys problem-solving and mental challenges.',
      'Brains before brawn.',
      27, 'Puzzle_Pro', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 4),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 3),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 2),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 5),
  ], [
    'Smart and engaging; great for puzzle toys and training.',
    'Adaptable; enjoys new challenges and environments.',
    'Balanced energy; play and affection in moderation.',
  ], [
    'Needs mental stimulation or may become bored and mischievous.',
    'Can figure out how to get into things you\'d rather they didn\'t.',
  ]),

  CatType(28, 'Social Learner',
      'An adaptable cat who learns quickly from people and other pets.',
      'Always picking things up.',
      28, 'Social_Learner', 1.0, [
    StatValue('Energy Level', false, 3),
    StatValue('Playfulness', false, 3),
    StatValue('Affection Level', false, 4),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 5),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 5),
  ], [
    'Highly adaptable; great for multi-pet or busy households.',
    'Very intelligent and social; learns quickly and bonds well.',
    'Confident and easygoing; good with new people and places.',
  ], [
    'Needs social and mental stimulation; not ideal for long solo days.',
    'May get into trouble if left bored or understimulated.',
  ]),

  CatType(29, 'Explorer Brain',
      'A curious cat driven by discovery and new experiences.',
      'What’s over there?',
      29, 'Explorer_Brain', 1.0, [
    StatValue('Energy Level', false, 4),
    StatValue('Playfulness', false, 4),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 2),
    StatValue('Sociability', false, 3),
    StatValue('Vocality', false, 2),
    StatValue('Confidence', false, 5),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 5),
    StatValue('Intelligence', false, 4),
  ], [
    'Very adaptable; thrives on change and new environments.',
    'Confident and curious; fun and engaging companion.',
    'Smart and active; great for interactive play and exploration.',
  ], [
    'Needs outlets for curiosity; can get into cabinets, doors, etc.',
    'May be too active or exploratory for very calm homes.',
  ]),

  CatType(30, 'Little Professor',
      'An intelligent, observant cat who seems to understand everything.',
      'Quietly brilliant.',
      30, 'Little_Professor', 1.0, [
    StatValue('Energy Level', false, 2),
    StatValue('Playfulness', false, 2),
    StatValue('Affection Level', false, 3),
    StatValue('Independence', false, 4),
    StatValue('Sociability', false, 2),
    StatValue('Vocality', false, 1),
    StatValue('Confidence', false, 4),
    StatValue('Sensitivity', false, 1),
    StatValue('Adaptability', false, 4),
    StatValue('Intelligence', false, 5),
  ], [
    'Very intelligent; enjoys puzzles, training, and quiet observation.',
    'Calm and adaptable; good for stable, low-drama homes.',
    'Independent but affectionate; low maintenance with high reward.',
  ], [
    'May prefer calm and routine; not ideal for chaotic households.',
    'Can be reserved; may not seek constant interaction.',
  ]),
];

/// Returns a comma-separated list of cat type names from [types].
String catTypeNamesCommaSeparated(List<CatType> types) {
  return types.map((c) => c.name).join(', ');
}

