# Content Moderation Setup

## Overview
The app uses keyword-based content moderation to filter offensive language from availability notes submitted by adopters.

## Firestore Configuration

The keyword list is stored in Firestore at:
- Collection: `app_config`
- Document: `content_moderation`
- Field: `keywords` (array of strings)

## Initial Setup

### Option 1: Using Firebase Console
1. Go to Firebase Console → Firestore Database
2. Create collection `app_config` if it doesn't exist
3. Create document `content_moderation`
4. Add field `keywords` as an array
5. Add the keywords from the list below

### Option 2: Using Node.js Script
1. Install Firebase Admin SDK: `npm install firebase-admin`
2. Set up Firebase Admin credentials
3. Run: `node scripts/init_content_moderation.js`

### Option 3: Using Flutter/Firebase CLI
You can manually add the document using Firebase CLI or any Firebase admin tool.

## Default Keywords List

The default keywords include:
- Profanity (damn, hell, crap, etc.)
- Threats/Violence (kill, harm, attack, etc.)
- Sexual content (porn, nude, etc.)
- Scam/Spam indicators
- Aggressive insults
- Common misspellings

See `scripts/init_content_moderation.js` for the complete list.

## How It Works

1. When an adopter submits an availability note:
   - Text is sanitized (HTML tags removed)
   - Checked against keyword list from Firestore
   - If offensive: flagged and stored for review, email NOT sent
   - If clean: stored in adopter document and email sent to shelter

2. Adopter Document Structure:
   ```json
   {
     "hasOffensiveContent": boolean,
     "notes": [
       {
         "note": "sanitized text",
         "originalNote": "original text",
         "timestamp": Timestamp,
         "catId": string,
         "catName": string,
         "organizationId": string,
         "organizationName": string,
         "isUpdate": boolean,
         "isOffensive": boolean,
         "emailSent": boolean,
         "emailSentAt": Timestamp (if sent)
       }
     ]
   }
   ```

## Updating Keywords

You can update the keyword list in Firestore at any time. The app caches keywords for 1 hour, so changes may take up to 1 hour to take effect.

To force immediate update, you can:
1. Clear the app cache
2. Wait for cache expiration (1 hour)
3. Or modify the cache duration in `ContentModerator` class

## Testing

To test content moderation:
1. Submit a note with offensive keywords
2. Check that it's flagged and email is not sent
3. Check adopter document in Firestore for `hasOffensiveContent: true`
4. Submit a clean note
5. Verify email is sent and note is stored

## Notes

- Keywords are case-insensitive
- Context-aware: "kill shelter" is allowed (legitimate term)
- Always offensive phrases are checked first
- Original note is preserved for review even if offensive

