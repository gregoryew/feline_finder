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
  // Track which question's animation is currently active (null if none)
  int? _activeAnimationQuestionId;
  // Track which slider was last changed (to restore when reopening square)
  int? _lastChangedQuestionId;
  // Track whether to show PNG or GIF for the active animation
  bool _showingGif = false;
  // Timer to switch from PNG to GIF
  Timer? _pngToGifTimer;
  // Track whether the animation square is visible (user can close it)
  bool _isSquareVisible = true;
  // Counter to force ListView rebuild when breeds are sorted
  int _breedListKey = 0;
  // Local state for slider values to ensure reactivity
  final Map<int, double> _sliderValues = {};
  
  // Map question names to stat names (for name mismatches)
  static const Map<String, String> _questionToStatName = {
    'Energy Level': 'Energy Level',
    'Playfulness': 'Fun-loving',
    'Care & Attention': 'TLC',
    'Companionship': 'Companion',
    'Vocalization': '"Talkative"',
    'Handling & Affection': 'Willingness to be petted',
    'Intelligence': 'Brains',
    'Grooming Needs': 'Grooming Needs',
    'Good with Children': 'Good with Children',
    'Good with Other Pets': 'Good with other pets',
  };

  @override
  void initState() {
    super.initState();
    // Initialize slider values from global state
    for (var question in Question.questions) {
      _sliderValues[question.id] = globals.FelineFinderServer.instance
          .sliderValue[question.id]
          .toDouble();
    }
  }

  @override
  void dispose() {
    _pngToGifTimer?.cancel();
    super.dispose();
  }

  void _showAnimation(int questionId) {
    // Only show animation if square is visible
    if (!_isSquareVisible) {
      return;
    }

    // Cancel existing timer if any
    _pngToGifTimer?.cancel();

    // Update animation state (don't call setState here - it will be called by onChanged)
    _activeAnimationQuestionId = questionId;
    _showingGif = false; // Start with PNG

    // Switch to GIF after a brief moment (300ms)
    _pngToGifTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _activeAnimationQuestionId == questionId) {
        setState(() {
          _showingGif = true;
        });
      }
    });
  }

  void _toggleSquareVisibility() {
    setState(() {
      _isSquareVisible = !_isSquareVisible;
      if (!_isSquareVisible) {
        // Clear animation when closing
        _activeAnimationQuestionId = null;
        _showingGif = false;
        _pngToGifTimer?.cancel();
      } else {
        // Restore last changed animation when reopening
        if (_lastChangedQuestionId != null) {
          _pngToGifTimer?.cancel();
          _activeAnimationQuestionId = _lastChangedQuestionId;
          _showingGif = false; // Start with PNG
          
          // Switch to GIF after a brief moment (300ms)
          _pngToGifTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && _activeAnimationQuestionId == _lastChangedQuestionId) {
              setState(() {
                _showingGif = true;
              });
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: buildRows());
  }

  Widget buildRows() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
    // Check if this card is currently active (showing animation)
    final bool isActive = _activeAnimationQuestionId == question.id;
    
    return AnimatedScale(
      scale: isActive ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(
          left: (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
          right: (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
          top: (AppTheme.spacingS - 10).clamp(0.0, double.infinity),
          bottom: 16.0, // Increased spacing between cards
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0), // Rounded corners for a polished look
          gradient: AppTheme.purpleGradient, // Purple gradient background
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            // Add gold glow that leaks out from the edges when active
            if (isActive)
              BoxShadow(
                color: AppTheme.goldBase.withOpacity(0.7),
                blurRadius: 12,
                spreadRadius: 2, // Positive spread makes it leak out
                offset: const Offset(0, 0),
              ),
            if (isActive)
              BoxShadow(
                color: AppTheme.goldHighlight.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 1, // Positive spread makes it leak out
                offset: const Offset(0, 0),
              ),
            // Additional outer glow for more visibility
            if (isActive)
              BoxShadow(
                color: AppTheme.goldBase.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 4, // Larger spread for more leak effect
                offset: const Offset(0, 0),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "${question.name}: ${question.choices[(_sliderValues[question.id] ?? 0.0).round()].name}",
                        style: const TextStyle(fontSize: 13, color: Colors.white)),
                    // Slider - always enabled, moving it cancels any playing animation
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
                  value: _sliderValues[question.id] ?? 0.0,
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
                    try {
                      print('Slider changed: question.id=${question.id}, question.name=${question.name}, newValue=$newValue');
                      
                      // Update both local state and global state
                      final roundedValue = newValue.round();
                      _sliderValues[question.id] = newValue;
                      globals.FelineFinderServer.instance
                          .sliderValue[question.id] = roundedValue;
                      print('Updated sliderValue[${question.id}] = $roundedValue');
                    
                      // Track the last changed slider
                      _lastChangedQuestionId = question.id;
                      
                      // Update animation state
                      if (_isSquareVisible) {
                        _pngToGifTimer?.cancel();
                        _activeAnimationQuestionId = question.id;
                        _showingGif = false; // Start with PNG
                        
                        // Switch to GIF after a brief moment (300ms)
                        _pngToGifTimer = Timer(const Duration(milliseconds: 300), () {
                          if (mounted && _activeAnimationQuestionId == question.id) {
                            setState(() {
                              _showingGif = true;
                            });
                          }
                        });
                      }

                      // Store question ID and value pairs (stats are ordered by question ID)
                      final desired = <Map<String, dynamic>>[];
                      for (var q in Question.questions) {
                        final sliderVal = globals.FelineFinderServer.instance.sliderValue[q.id];
                        print('  Checking question ${q.id} (${q.name}): sliderVal=$sliderVal');
                        if (sliderVal > 0) {
                          desired.add({
                            'questionId': q.id,
                            'name': q.name,
                            'value': sliderVal.toDouble(),
                          });
                          print('  Added to desired: ${q.name} = $sliderVal');
                        }
                      }
                      print('Total desired values: ${desired.length}');

                      // Calculate percentMatch for each breed
                      for (var i = 0; i < breeds.length; i++) {
                        double sum = 0;
                        for (var j = 0; j < desired.length; j++) {
                          try {
                            final questionId = desired[j]['questionId'] as int;
                            final questionName = desired[j]['name'] as String;
                            final desiredValue = desired[j]['value'] as double;
                            
                            // Find stat by matching question name (use mapping for name mismatches)
                            StatValue? stat;
                            try {
                              // Get the stat name from the mapping, or use question name if no mapping
                              final statName = _questionToStatName[questionName] ?? questionName;
                              stat = breeds[i].stats.firstWhere(
                                (s) => s.name == statName,
                              );
                            } catch (e) {
                              continue; // Skip if stat not found
                            }
                            
                            // Find question by ID (not by index, since IDs are non-sequential)
                            Question? q;
                            try {
                              q = Question.questions.firstWhere(
                                (q) => q.id == questionId,
                              );
                            } catch (e) {
                              continue; // Skip if question not found
                            }
                            
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

                      // Sort breeds by percentMatch (descending), then by name (ascending)
                      breeds.sort((a, b) {
                        // First compare by percentMatch (descending)
                        final matchComparison = b.percentMatch.compareTo(a.percentMatch);
                        if (matchComparison != 0) {
                          return matchComparison;
                        }
                        // If percentMatch is equal, sort by name (ascending)
                        return a.name.compareTo(b.name);
                      });
                      
                      print('After calculation: desired.length=${desired.length}, top breed=${breeds.isNotEmpty ? breeds[0].name : "none"} (${breeds.isNotEmpty ? breeds[0].percentMatch : 0})');
                      
                      // Increment key to force ListView rebuild
                      _breedListKey++;
                      
                      // Trigger rebuild with setState - this will update the slider value display
                      setState(() {});
                      print('setState called for question ${question.id}');
                    } catch (e, stackTrace) {
                      print('ERROR in onChanged for question ${question.id}: $e');
                      print('Stack trace: $stackTrace');
                    }
                  },
                  // 14
                ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget buildMatches() {
    // Don't sort here - breeds are already sorted in onChanged
    // Just display them as they are

    return Column(
      children: [
        // Square animation area or show button at the top
        _isSquareVisible ? _buildAnimationSquare() : _buildShowAnimationButton(),
        // Breed cards list
        Expanded(
          child: ListView.builder(
            key: ValueKey(_breedListKey),
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
          ),
        ),
      ],
    );
  }

  Widget _buildAnimationSquare() {
    return Stack(
      children: [
        // Square area: 130px x 130px to match column width
        Container(
          width: 130,
          height: 130,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2), // Background so border radius is visible
            borderRadius: const BorderRadius.all(Radius.circular(8)), // Explicitly set all corners to same radius
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)), // Explicitly set all corners to same radius
            child: _activeAnimationQuestionId == null
                ? _buildInstructionalText()
                : _buildAnimationImage(),
          ),
        ),
        // X button in upper right corner
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: _toggleSquareVisibility,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionalText() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Find Your Purrfect Match',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Adjust the sliders to start',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimationImage() {
    // Find the active question
    final activeQuestion = Question.questions.firstWhere(
      (q) => q.id == _activeAnimationQuestionId,
      orElse: () => Question.questions[0],
    );

    // Determine which image to show
    final String imagePath = _showingGif
        ? "assets/Animation/${activeQuestion.imageName}"
        : "assets/Animation/${activeQuestion.imageName.replaceAll('.gif', '.png')}";

    return Image(
      image: AssetImage(imagePath),
      fit: BoxFit.cover,
      width: 130,
      height: 130,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.image, color: Colors.white54, size: 48),
          ),
        );
      },
    );
  }

  Widget _buildShowAnimationButton() {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: _toggleSquareVisibility,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: const Text(
          'Show Animation',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
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
