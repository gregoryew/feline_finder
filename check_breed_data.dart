import 'dart:io';
import 'package:flutter/material.dart';

// Expected stat names (from _questionToStatName mapping)
const expectedStats = [
  'Energy Level',
  'Fun-loving',
  'TLC',
  'Companion',
  '"Talkative"',
  'Willingness to be petted',
  'Brains',
  'Grooming Needs',
  'Good with Children',
  'Good with other pets',
];

void main() {
  // Read the breed.dart file
  final file = File('lib/models/breed.dart');
  final content = file.readAsStringSync();
  
  // Find all breed definitions
  final breedPattern = RegExp(r"Breed\(\s*(\d+),\s*'([^']+)',");
  final statPattern = RegExp(r"StatValue\('([^']+)',\s*(true|false),\s*([\d.]+)\)");
  
  final breeds = breedPattern.allMatches(content);
  final allStats = statPattern.allMatches(content);
  
  print('Expected stats: ${expectedStats.length}');
  print('Expected stat names: $expectedStats\n');
  
  // Group stats by breed
  int breedIndex = 0;
  int statIndex = 0;
  final breedMatches = breeds.toList();
  final statMatches = allStats.toList();
  
  final issues = <String>[];
  int totalBreeds = 0;
  int breedsWithAllStats = 0;
  int breedsWithMissingStats = 0;
  
  // Find breed boundaries by looking for StatValue patterns between Breed( declarations
  for (int i = 0; i < breedMatches.length; i++) {
    final breedMatch = breedMatches[i];
    final breedId = breedMatch.group(1);
    final breedName = breedMatch.group(2);
    totalBreeds++;
    
    // Find the start and end of this breed's stat list
    final breedStart = breedMatch.end;
    final breedEnd = i < breedMatches.length - 1 
        ? breedMatches[i + 1].start 
        : content.length;
    
    final breedSection = content.substring(breedStart, breedEnd);
    
    // Extract all StatValue entries for this breed
    final breedStats = statPattern.allMatches(breedSection);
    final statNames = breedStats.map((m) => m.group(1)).toList();
    
    // Check for missing stats
    final missingStats = expectedStats.where((expected) => !statNames.contains(expected)).toList();
    final extraStats = statNames.where((stat) => !expectedStats.contains(stat)).toList();
    
    if (missingStats.isNotEmpty || extraStats.isNotEmpty) {
      breedsWithMissingStats++;
      issues.add('Breed #$breedId "$breedName":');
      if (missingStats.isNotEmpty) {
        issues.add('  Missing: ${missingStats.join(", ")}');
      }
      if (extraStats.isNotEmpty) {
        issues.add('  Extra: ${extraStats.join(", ")}');
      }
      issues.add('  Total stats: ${statNames.length} (expected: ${expectedStats.length})');
      issues.add('');
    } else {
      breedsWithAllStats++;
    }
  }
  
  print('=== BREED DATA COMPLETENESS CHECK ===\n');
  print('Total breeds: $totalBreeds');
  print('Breeds with all ${expectedStats.length} stats: $breedsWithAllStats');
  print('Breeds with missing/extra stats: $breedsWithMissingStats\n');
  
  if (issues.isNotEmpty) {
    print('=== ISSUES FOUND ===\n');
    issues.forEach(print);
  } else {
    print('✓ All breeds have complete data!');
  }
}



