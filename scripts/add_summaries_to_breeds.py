#!/usr/bin/env python3
"""
Script to add summaries from breed_summaries.txt to the breed.dart file.
Reads the summaries file and updates each Breed() constructor call with the summary parameter.
"""

import re
from pathlib import Path

BREED_DART_FILE = Path(__file__).parent.parent / 'lib' / 'models' / 'breed.dart'
BACKUP_FILE = Path(__file__).parent.parent / 'lib' / 'models' / 'breed.dart.backup'
SUMMARIES_FILE = Path(__file__).parent.parent / 'breed_summaries.txt'


def read_summaries():
    """Read summaries from file, handling multi-line format. Returns dict mapping breed name to summary."""
    if not SUMMARIES_FILE.exists():
        print(f'❌ Summaries file not found: {SUMMARIES_FILE}')
        return None
    
    with open(SUMMARIES_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by double newline (blank line separator)
    sections = content.split('\n\n')
    summaries_dict = {}
    
    for section in sections:
        lines = section.split('\n')
        breed_name = None
        summary_lines = []
        
        for line in lines:
            line = line.strip()
            if line.startswith('#'):
                # Extract breed name from comment
                breed_name = line[1:].strip()
            elif line:
                summary_lines.append(line)
        
        if breed_name:
            summary = '\n'.join(summary_lines).strip()
            summaries_dict[breed_name] = summary if summary else 'null'
    
    return summaries_dict


def find_breed_instances(content):
    """Find all Breed( instances in the file."""
    breeds = []
    
    # Find all Breed( patterns
    pattern = r'Breed\s*\('
    for match in re.finditer(pattern, content):
        start = match.start()
        
        # Find the breed name (second parameter)
        pos = match.end()
        # Skip whitespace and first number
        while pos < len(content) and (content[pos].isspace() or content[pos].isdigit() or content[pos] == ','):
            pos += 1
        
        # Now find the breed name in quotes
        if pos < len(content) and content[pos] == "'":
            pos += 1
            name_start = pos
            while pos < len(content) and content[pos] != "'":
                if content[pos] == '\\':
                    pos += 2  # Skip escaped character
                else:
                    pos += 1
            breed_name = content[name_start:pos]
            
            # Find htmlUrl (4th parameter)
            pos += 1
            while pos < len(content) and (content[pos].isspace() or content[pos] == ','):
                pos += 1
            while pos < len(content) and (content[pos].isdigit() or content[pos] == ',' or content[pos].isspace()):
                pos += 1
            if pos < len(content) and content[pos] == "'":
                pos += 1
                url_start = pos
                while pos < len(content) and content[pos] != "'":
                    if content[pos] == '\\':
                        pos += 2
                    else:
                        pos += 1
                html_url = content[url_start:pos]
                
                # Find the end of this Breed( ... ) call
                pos = match.end()
                paren_count = 1
                bracket_count = 0
                
                while pos < len(content) and paren_count > 0:
                    if content[pos] == '(':
                        paren_count += 1
                    elif content[pos] == ')':
                        paren_count -= 1
                    elif content[pos] == '[':
                        bracket_count += 1
                    elif content[pos] == ']':
                        bracket_count -= 1
                    pos += 1
                
                end = pos - 1
                
                breeds.append({
                    'name': breed_name,
                    'htmlUrl': html_url,
                    'start': start,
                    'end': end,
                })
    
    return breeds


def add_summary_to_breed(content, breed, summary):
    """Add summary parameter to a breed instance."""
    breed_text = content[breed['start']:breed['end']]
    
    # Check if already has summary (non-null)
    has_summary = re.search(r"'[^']+',\s*\)", breed_text[-300:]) is not None
    if has_summary:
        # Already has a summary, skip
        return content, False
    
    # Find the last ) before the end
    breed_text_clean = breed_text.rstrip()
    if breed_text_clean.endswith(')'):
        breed_text_clean = breed_text_clean[:-1].rstrip()
        if breed_text_clean.endswith(','):
            breed_text_clean = breed_text_clean[:-1].rstrip()
    
    # Add summary
    if summary and summary != 'null':
        # Escape for Dart string: escape backslashes, single quotes, and preserve newlines
        summary_escaped = summary.replace('\\', '\\\\').replace("'", "\\'")
        # For multi-line, use triple quotes or escape newlines
        # Using escaped newlines for compatibility
        summary_escaped = summary_escaped.replace('\n', '\\n')
        new_text = f"{breed_text_clean},\n    '{summary_escaped}',\n  )"
    else:
        new_text = f"{breed_text_clean},\n    null,\n  )"
    
    # Replace in content
    return content[:breed['start']] + new_text + content[breed['end']:], True


def main():
    print('📖 Reading summaries file...')
    summaries_dict = read_summaries()
    if summaries_dict is None:
        return
    
    print(f'Found {len(summaries_dict)} summaries\n')
    
    print('📖 Reading breed.dart file...')
    with open(BREED_DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    with open(BACKUP_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'✅ Backup created: {BACKUP_FILE}\n')
    
    print('📋 Finding breed instances...')
    breeds = find_breed_instances(content)
    print(f'Found {len(breeds)} breeds\n')
    
    updated_content = content
    updated_count = 0
    skipped_count = 0
    not_found_count = 0
    
    for i, breed in enumerate(breeds):
        breed_name = breed['name']
        print(f'[{i+1}/{len(breeds)}] Processing {breed_name}...')
        
        # Match by breed name
        if breed_name not in summaries_dict:
            print(f'  ⚠️  No summary found for {breed_name}')
            not_found_count += 1
            continue
        
        summary = summaries_dict[breed_name]
        updated_content, was_updated = add_summary_to_breed(updated_content, breed, summary)
        
        if was_updated:
            print(f'  ✅ Added summary')
            updated_count += 1
        else:
            print(f'  ⏭️  Already has summary, skipped')
            skipped_count += 1
    
    # Write updated content
    print(f'\n💾 Writing updated breed.dart file...')
    with open(BREED_DART_FILE, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    
    print(f'✅ Done!')
    print(f'📊 Results: {updated_count} updated, {skipped_count} skipped, {not_found_count} not found in summaries file')
    print(f'💾 Backup saved to: {BACKUP_FILE}')


if __name__ == '__main__':
    main()

