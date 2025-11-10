// Script to initialize content moderation keywords in Firestore
// Run with: node scripts/init_content_moderation.js

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up service account)
// For local testing, you can use the Firebase emulator or set GOOGLE_APPLICATION_CREDENTIALS

const keywords = [
  // Profanity
  'damn',
  'hell',
  'crap',
  'piss',
  'asshole',
  'bastard',
  'bitch',
  'shit',
  'fuck',
  'fucking',
  'fucked',
  'dick',
  'cock',
  'pussy',
  'cunt',
  // Threats/Violence
  'kill',
  'die',
  'death',
  'murder',
  'harm',
  'hurt',
  'violence',
  'attack',
  'assault',
  'beat',
  'punch',
  'stab',
  'shoot',
  'gun',
  'weapon',
  // Sexual content
  'porn',
  'pornography',
  'nude',
  'naked',
  'orgasm',
  'masturbat',
  // Scam/Spam
  'scam',
  'fraud',
  'steal',
  'rob',
  'cheat',
  'phishing',
  'click here',
  'buy now',
  'free money',
  'winner',
  'prize',
  // Aggressive insults
  'stupid',
  'idiot',
  'moron',
  'retard',
  'dumb',
  'loser',
  'pathetic',
  // Common misspellings
  'f*ck',
  'f**k',
  'f***',
  'sh*t',
  's***',
  'a**',
  'a$$',
  'b*tch',
];

async function initContentModeration() {
  try {
    // Initialize Firebase Admin if not already initialized
    if (!admin.apps.length) {
      admin.initializeApp();
    }

    const db = admin.firestore();
    const docRef = db.collection('app_config').doc('content_moderation');

    await docRef.set({
      keywords: keywords,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      version: 1,
    }, { merge: true });

    console.log('✅ Content moderation keywords initialized in Firestore');
    console.log(`   Total keywords: ${keywords.length}`);
  } catch (error) {
    console.error('❌ Error initializing content moderation:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  initContentModeration()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { initContentModeration, keywords };

