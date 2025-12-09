#!/usr/bin/env python3
"""
Script to fetch Wikipedia articles for all breeds and generate AI summaries.
Updates the breed.dart file with pre-computed summaries.
"""

import re
import requests
import time
import urllib.parse
from google import generativeai as genai
from pathlib import Path

# Configuration
GEMINI_API_KEY = 'AIzaSyCW9hT-FVf1Xsj4eXHMPZrMeRGgRz4pTzQ'
WIKIPEDIA_API_URL = 'https://en.wikipedia.org/w/api.php'
BREED_DART_FILE = Path(__file__).parent.parent / 'lib' / 'models' / 'breed.dart'
BACKUP_FILE = Path(__file__).parent.parent / 'lib' / 'models' / 'breed.dart.backup'
SUMMARIES_OUTPUT_FILE = Path(__file__).parent.parent / 'breed_summaries.txt'

# Initialize Gemini
genai.configure(api_key=GEMINI_API_KEY)

# Try different models in order
MODEL_NAMES = ['gemini-2.0-flash-exp', 'gemini-1.5-pro', 'gemini-1.5-flash-latest']
model = None
for model_name in MODEL_NAMES:
    try:
        model = genai.GenerativeModel(model_name)
        print(f'✅ Using model: {model_name}')
        break
    except Exception as e:
        print(f'⚠️ Failed to initialize {model_name}: {e}')
        continue

if model is None:
    print('❌ Failed to initialize any AI model')
    exit(1)


def fetch_wikipedia_article(html_url):
    """Fetch Wikipedia article extract for a breed."""
    # URL decode the html_url if needed, then re-encode properly for Wikipedia API
    decoded_url = urllib.parse.unquote(html_url)
    # Replace spaces with underscores (Wikipedia page title format)
    page_title = decoded_url.replace(' ', '_')
    # Properly encode for URL
    encoded_title = urllib.parse.quote(page_title, safe='_')
    
    # Wikipedia API requires a User-Agent header
    url = f"{WIKIPEDIA_API_URL}?action=query&prop=extracts&explaintext&format=json&titles={encoded_title}"
    
    try:
        response = requests.get(url, headers={
            'User-Agent': 'FelineFinder/1.0 (https://github.com/yourusername/felinefinder; contact@example.com)',
            'Content-Type': 'application/json;charset=UTF-8',
        }, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            pages = data.get('query', {}).get('pages', {})
            for page_id, page_data in pages.items():
                # Check if page exists (page_id != -1 means page not found)
                if page_id == '-1':
                    continue
                extract = page_data.get('extract', '')
                if extract and len(extract.strip()) > 50:
                    return extract
        else:
            print(f'  HTTP {response.status_code}: {response.text[:200]}')
        return None
    except Exception as e:
        print(f'  Error fetching Wikipedia article: {e}')
        return None


def generate_summary(full_text, max_retries=3):
    """Generate AI summary of Wikipedia article with automatic retry on rate limits."""
    if not full_text or len(full_text.strip()) < 50:
        return None
    
    # Limit text to avoid token limits
    text_to_summarize = full_text[:5000] if len(full_text) > 5000 else full_text
    
    prompt = f'''Please provide a concise summary of the following Wikipedia article about a cat breed. 
The summary should be 2-3 sentences, highlighting the breed's key characteristics, temperament, and notable features. 
Keep it informative but brief:

{text_to_summarize}

Summary:'''

    for attempt in range(max_retries):
        try:
            response = model.generate_content(prompt)
            if response.text:
                return response.text.strip()
        except Exception as e:
            error_str = str(e)
            
            # Check if it's a rate limit error (429)
            if '429' in error_str or 'quota' in error_str.lower() or 'rate' in error_str.lower():
                # Try to extract retry delay from error message
                retry_seconds = 60  # Default to 60 seconds
                
                # Look for retry_delay in the error
                import re
                delay_match = re.search(r'retry_delay\s*{\s*seconds:\s*(\d+)', error_str)
                if delay_match:
                    retry_seconds = int(delay_match.group(1)) + 5  # Add 5 second buffer
                
                if attempt < max_retries - 1:
                    print(f'  ⏳ Rate limit hit. Waiting {retry_seconds} seconds before retry {attempt + 2}/{max_retries}...')
                    time.sleep(retry_seconds)
                    continue
                else:
                    print(f'  ⚠️ Rate limit exceeded after {max_retries} attempts')
                    return None
            else:
                # Other error, don't retry
                print(f'  Error generating summary: {e}')
                return None
    
    return None


def find_breed_instances(content):
    """Find all Breed( instances in the file."""
    breeds = []
    
    # Find all Breed( patterns
    pattern = r'Breed\s*\('
    for match in re.finditer(pattern, content):
        start = match.start()
        
        # Find the breed name (second parameter)
        # Skip to first quote after Breed(
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
            
            # Find htmlUrl (4th parameter, after name, sortOrder)
            # Skip past name, comma, sortOrder, comma
            pos += 1
            while pos < len(content) and (content[pos].isspace() or content[pos] == ','):
                pos += 1
            # Skip sortOrder (number)
            while pos < len(content) and (content[pos].isdigit() or content[pos] == ',' or content[pos].isspace()):
                pos += 1
            # Now at htmlUrl
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
                # Count parentheses and brackets
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
    
    # Check if already has summary
    if 'summary' in breed_text or breed_text.rstrip().endswith('null'):
        return content
    
    # Find the last ) before the end
    # Remove trailing whitespace and )
    breed_text_clean = breed_text.rstrip()
    if breed_text_clean.endswith(')'):
        breed_text_clean = breed_text_clean[:-1].rstrip()
        if breed_text_clean.endswith(','):
            breed_text_clean = breed_text_clean[:-1].rstrip()
    
    # Add summary
    if summary:
        # Escape for Dart string
        summary_escaped = summary.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n')
        new_text = f"{breed_text_clean},\n    '{summary_escaped}',\n  )"
    else:
        new_text = f"{breed_text_clean},\n    null,\n  )"
    
    # Replace in content
    return content[:breed['start']] + new_text + content[breed['end']:]


def main():
    print('📖 Reading breed.dart file...')
    
    with open(BREED_DART_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print('📋 Finding breed instances...')
    breeds = find_breed_instances(content)
    print(f'Found {len(breeds)} breeds\n')
    
    # Read existing summaries if file exists
    existing_summaries = {}
    if SUMMARIES_OUTPUT_FILE.exists():
        with open(SUMMARIES_OUTPUT_FILE, 'r', encoding='utf-8') as f:
            content = f.read()
            # Split by double newline (blank line separator)
            sections = content.split('\n\n')
            for idx, section in enumerate(sections):
                if idx < len(breeds):
                    # Remove comment line if present
                    lines = [l for l in section.split('\n') if not l.strip().startswith('#')]
                    summary = '\n'.join(lines).strip()
                    if summary and summary != 'null':
                        existing_summaries[idx] = summary
    
    summaries = []
    successful = 0
    failed = 0
    skipped = 0
    
    for i, breed in enumerate(breeds):
        # Check if we already have a summary for this breed
        if i in existing_summaries:
            print(f'[{i+1}/{len(breeds)}] Skipping {breed["name"]} (already has summary)')
            summaries.append(existing_summaries[i])
            skipped += 1
            continue
        
        print(f'[{i+1}/{len(breeds)}] Processing {breed["name"]}...')
        
        # Fetch Wikipedia article
        print(f'  📥 Fetching Wikipedia article...')
        wiki_text = fetch_wikipedia_article(breed['htmlUrl'])
        
        if not wiki_text:
            print(f'  ⚠️ No Wikipedia article found')
            summaries.append('null')
            failed += 1
            continue
        
        # Generate summary
        print(f'  🤖 Generating AI summary...')
        summary = generate_summary(wiki_text)
        
        if summary:
            print(f'  ✅ Summary: {summary[:80]}...')
            summaries.append(summary)
            successful += 1
        else:
            print(f'  ⚠️ Failed to generate summary')
            summaries.append('null')
            failed += 1
        
        # Rate limiting - wait 7 seconds between requests to stay under 10/min limit
        # (10 requests per minute = 6 seconds between requests, using 7 for safety)
        if i < len(breeds) - 1:
            time.sleep(7)
    
    # Write all summaries to output file (multi-line format with blank line separators)
    print(f'\n💾 Writing summaries to {SUMMARIES_OUTPUT_FILE}...')
    with open(SUMMARIES_OUTPUT_FILE, 'w', encoding='utf-8') as f:
        for i, summary in enumerate(summaries):
            # Write breed name as comment for reference
            if i < len(breeds):
                f.write(f'# {breeds[i]["name"]}\n')
            
            # Write summary (can be multi-line)
            if summary == 'null':
                f.write('null\n')
            else:
                f.write(f'{summary}\n')
            
            # Blank line separator (except after last breed)
            if i < len(summaries) - 1:
                f.write('\n')
    
    print(f'✅ Done!')
    print(f'📊 Results: {successful} successful, {failed} failed, {skipped} skipped (already had summaries)')
    print(f'💾 Summaries saved to: {SUMMARIES_OUTPUT_FILE}')
    print(f'📝 Total summaries: {len(summaries)} (one per line, in breed array order)')


if __name__ == '__main__':
    main()
