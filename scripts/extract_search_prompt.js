#!/usr/bin/env node
/**
 * Extracts the search AI system prompt from lib/services/search_ai_service.dart
 * and writes functions/src/searchPrompt.txt for the Cloud Function.
 * Run from repo root: node scripts/extract_search_prompt.js
 */
const fs = require('fs');
const path = require('path');

const dartPath = path.join(__dirname, '..', 'lib', 'services', 'search_ai_service.dart');
const outPath = path.join(__dirname, '..', 'functions', 'src', 'searchPrompt.txt');

const dart = fs.readFileSync(dartPath, 'utf8');

// schemaDefinition is between "const schemaDefinition = '''" and "''';\n\n    const systemPrompt"
const schemaStart = "const schemaDefinition = '''\n";
const schemaEnd = "\n''';\n\n    const systemPrompt = '''";
const schemaIdx = dart.indexOf(schemaStart);
const schemaEndIdx = dart.indexOf(schemaEnd);
if (schemaIdx === -1 || schemaEndIdx === -1) {
  console.error('Could not find schemaDefinition in Dart file');
  process.exit(1);
}
const schemaDefinition = dart.slice(schemaIdx + schemaStart.length, schemaEndIdx);

// systemPrompt is between "const systemPrompt = '''" and "''';\n\n    try"
const promptStart = "const systemPrompt = '''\n";
const promptEnd = "\n''';\n\n    try";
const promptIdx = dart.indexOf(promptStart);
const promptEndIdx = dart.indexOf(promptEnd);
if (promptIdx === -1 || promptEndIdx === -1) {
  console.error('Could not find systemPrompt in Dart file');
  process.exit(1);
}
let systemPrompt = dart.slice(promptIdx + promptStart.length, promptEndIdx);
// Replace $schemaDefinition with actual schema (Dart interpolates this)
systemPrompt = systemPrompt.replace(/\$schemaDefinition/g, schemaDefinition);

fs.writeFileSync(outPath, systemPrompt, 'utf8');
console.log('Wrote', outPath, '(' + systemPrompt.length + ' chars)');
