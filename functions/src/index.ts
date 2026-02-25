import * as crypto from 'crypto';
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

function sha256Hex(text: string): string {
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

const TRAIT_NAMES = [
  'Energy Level',
  'Playfulness',
  'Affection Level',
  'Independence',
  'Sociability',
  'Vocality',
  'Confidence',
  'Sensitivity',
  'Adaptability',
  'Intelligence',
] as const;

const COLLECTION_ID = 'animal_fit_scores';

/** Firestore collection for API keys (same as client KeyStoreService). */
const KEY_STORE_COLLECTION = 'key_store';

/**
 * AI guide: all 30 cat types and their trait profiles (same order as TRAIT_NAMES).
 * Used in the Gemini prompt so the model knows valid suggestedCatTypeName values
 * and can pick the type whose profile is closest to the inferred traits.
 */
const CAT_TYPE_PROFILES: ReadonlyArray<{ name: string; traits: number[] }> = [
  { name: 'Professional Napper', traits: [1, 1, 2, 5, 2, 1, 4, 1, 4, 2] },
  { name: 'Lap Legend', traits: [2, 2, 5, 2, 4, 2, 3, 2, 4, 3] },
  { name: 'Zen Companion', traits: [2, 2, 3, 4, 3, 1, 4, 1, 5, 3] },
  { name: 'Old Soul', traits: [2, 2, 3, 4, 2, 1, 5, 1, 4, 3] },
  { name: 'Quiet Shadow', traits: [1, 1, 2, 4, 1, 1, 3, 3, 2, 2] },
  { name: 'Zoomie Rocket', traits: [5, 5, 3, 2, 4, 3, 4, 2, 4, 3] },
  { name: 'Parkour Cat', traits: [5, 4, 2, 3, 3, 2, 5, 2, 3, 3] },
  { name: 'Toy Addict', traits: [4, 5, 3, 3, 3, 2, 3, 2, 4, 4] },
  { name: 'Chaos Sprite', traits: [5, 5, 3, 1, 4, 5, 3, 3, 3, 2] },
  { name: 'Forever Kitten', traits: [4, 5, 5, 2, 4, 3, 4, 2, 4, 3] },
  { name: 'Velcro Cat', traits: [3, 3, 5, 1, 5, 3, 4, 2, 4, 3] },
  { name: 'Cuddle Ambassador', traits: [3, 3, 5, 2, 5, 2, 4, 1, 5, 4] },
  { name: 'Welcome Committee', traits: [4, 4, 4, 2, 5, 3, 5, 1, 5, 4] },
  { name: 'Therapy Cat', traits: [2, 2, 5, 2, 4, 2, 5, 1, 5, 4] },
  { name: 'Heart Healer', traits: [3, 3, 4, 2, 4, 2, 4, 1, 5, 4] },
  { name: 'Solo Artist', traits: [2, 2, 2, 5, 2, 1, 4, 2, 3, 3] },
  { name: 'Dignified Observer', traits: [2, 1, 2, 4, 2, 1, 5, 1, 4, 3] },
  { name: 'Window Philosopher', traits: [2, 1, 2, 4, 1, 1, 4, 2, 3, 2] },
  { name: 'Private Thinker', traits: [2, 1, 2, 5, 1, 1, 3, 4, 2, 2] },
  { name: 'Gentle Hermit', traits: [1, 1, 2, 4, 1, 1, 3, 3, 2, 2] },
  { name: 'Drama Monarch', traits: [3, 3, 4, 2, 4, 5, 4, 3, 3, 2] },
  { name: 'Opinionated Roommate', traits: [3, 3, 3, 3, 4, 5, 5, 2, 3, 3] },
  { name: 'Soap Opera Star', traits: [3, 3, 5, 2, 4, 5, 4, 2, 4, 3] },
  { name: 'Mood Ring Cat', traits: [3, 3, 3, 2, 3, 3, 3, 5, 2, 2] },
  { name: 'Attention Magnet', traits: [4, 4, 4, 1, 5, 4, 4, 2, 4, 3] },
  { name: 'Routine Master', traits: [2, 2, 3, 3, 3, 1, 4, 1, 1, 5] },
  { name: 'Puzzle Pro', traits: [3, 4, 3, 3, 3, 2, 4, 2, 4, 5] },
  { name: 'Social Learner', traits: [3, 3, 4, 2, 5, 2, 4, 1, 5, 5] },
  { name: 'Explorer Brain', traits: [4, 4, 3, 2, 3, 2, 5, 1, 5, 4] },
  { name: 'Little Professor', traits: [2, 2, 3, 4, 2, 1, 4, 1, 4, 5] },
];

if (!admin.apps.length) {
  admin.initializeApp();
}

/** One trait: score (1–5 or null), confidence (0–1), evidence (verbatim phrases). */
interface TraitDetail {
  score: number | null;
  confidence: number;
  evidence: string[];
}
/** Gemini returns traits as object with 10 keys (trait names), each value is TraitDetail. */
interface GeminiExtractionResponse {
  traits: Record<string, TraitDetail>;
  notes?: { summary_tags?: string[]; data_quality?: string };
}

/**
 * Try to parse Gemini JSON response; fix common issues (trailing commas, markdown, truncation).
 */
function parseGeminiExtractionResponse(raw: string): GeminiExtractionResponse {
  let s = raw.replace(/```json\s*/gi, '').replace(/```\s*/g, '').trim();
  const start = s.indexOf('{');
  if (start === -1) throw new Error('No JSON object in response');
  let depth = 0;
  let end = -1;
  for (let i = start; i < s.length; i++) {
    if (s[i] === '{') depth++;
    else if (s[i] === '}') {
      depth--;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }
  if (end === -1) throw new Error('Unbalanced braces (response may be truncated)');
  s = s.slice(start, end + 1);
  s = s.replace(/,(\s*[}\]])/g, '$1');
  return JSON.parse(s) as GeminiExtractionResponse;
}

/**
 * Callable: compute personality fit for one animal from description using Gemini.
 * Writes to Firestore animal_fit_scores/<id> and returns traits + metadata.
 */
export const computeAnimalPersonalityFit = functions.https.onCall(
  async (data, context) => {
    const id = data?.id as string | undefined;
    const description = data?.description as string | undefined;
    const name = data?.name as string | undefined;
    const shelterName = data?.shelterName as string | undefined;
    const updatedDate = data?.updatedDate as string | undefined;

    if (!id || typeof id !== 'string' || id.trim() === '') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing or invalid id'
      );
    }
    if (!description || typeof description !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing or invalid description'
      );
    }

    const db = admin.firestore();
    const docRef = db.collection(COLLECTION_ID).doc(id);

    const getStoredUpdatedAtMs = (raw: unknown): number | null => {
      if (raw == null) return null;
      if (typeof raw === 'string') return new Date(raw).getTime();
      const t = raw as { toMillis?: () => number; _seconds?: number };
      if (typeof t.toMillis === 'function') return t.toMillis();
      if (typeof t._seconds === 'number') return t._seconds * 1000;
      return null;
    };

    const isExistingDocFresh = (d: Record<string, unknown>): boolean => {
      const storedUpdatedAtMs = getStoredUpdatedAtMs(d.updatedAt);
      const storedAnimalUpdatedDate = d.animalUpdatedDate as string | undefined;
      if (updatedDate != null && updatedDate.trim() !== '' && storedAnimalUpdatedDate) {
        const clientMs = new Date(updatedDate).getTime();
        const storedMs = new Date(storedAnimalUpdatedDate).getTime();
        if (!isNaN(clientMs) && !isNaN(storedMs) && clientMs > storedMs) return false;
      } else if (storedUpdatedAtMs != null) {
        const ageMs = Date.now() - storedUpdatedAtMs;
        if (ageMs > 30 * 24 * 60 * 60 * 1000) return false;
      }
      return true;
    };

    const existingDoc = await docRef.get();
    if (existingDoc.exists && existingDoc.data()) {
      const d = existingDoc.data() as Record<string, unknown>;
      const descriptionHash = sha256Hex(description);
      const hashMatches = typeof d.descriptionHash !== 'string' || d.descriptionHash === descriptionHash;
      if (isExistingDocFresh(d) && hashMatches && typeof d.traits === 'object' && d.traits != null) {
        const raw = d.traits as Record<string, unknown>;
        const traitsOut: Record<string, TraitDetail> = {};
        const isNewFormat = Object.keys(raw).length > 0 && typeof Object.values(raw)[0] === 'object' && Object.values(raw)[0] !== null && 'score' in (Object.values(raw)[0] as object);
        for (const name of TRAIT_NAMES) {
          const v = raw[name];
          if (isNewFormat && v && typeof v === 'object' && v !== null) {
            const o = v as Record<string, unknown>;
            traitsOut[name] = {
              score: o.score != null && typeof o.score === 'number' ? o.score : null,
              confidence: typeof o.confidence === 'number' ? o.confidence : 0,
              evidence: Array.isArray(o.evidence) ? o.evidence.filter((e): e is string => typeof e === 'string') : [],
            };
          } else if (typeof v === 'number') {
            traitsOut[name] = { score: v, confidence: 0, evidence: [] };
          } else {
            traitsOut[name] = { score: null, confidence: 0, evidence: [] };
          }
        }
        const updatedAtStr = typeof d.updatedAt === 'string' ? d.updatedAt : new Date().toISOString();
        return {
          traits: traitsOut,
          suggestedCatTypeName: (d.suggestedCatTypeName as string) ?? null,
          updatedAt: updatedAtStr,
          dataQuality: (d.dataQuality as string) ?? null,
        };
      }
    }

    // Get Gemini API key from Firestore key_store (same as client KeyStoreService).
    const keyStoreSnap = await admin
      .firestore()
      .collection(KEY_STORE_COLLECTION)
      .doc('GEMINI_API_KEY')
      .get();
    const keyValue = keyStoreSnap.exists && keyStoreSnap.data()?.key_value;
    const apiKey =
      typeof keyValue === 'string' && keyValue.trim() !== ''
        ? keyValue.trim()
        : null;
    if (!apiKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Gemini API key not configured. Add GEMINI_API_KEY to Firestore key_store collection (same as client).'
      );
    }

    const descriptionBlock = description.slice(0, 8000);
    const prompt = `You are an information extraction system for animal adoption profiles.

You MUST ONLY use the provided cat description text as evidence.
Do NOT use outside knowledge, breed stereotypes, or assumptions.
If the description does not support a trait, you MUST return:
  "score": null,
  "confidence": 0.0,
  "evidence": []

MANDATORY: For every trait where you set "score" to a number (1–5), you MUST also set "confidence" to a number 0.0–1.0 and "evidence" to an array of 1–3 verbatim words or phrases from the description (a sentence or less each). Do NOT leave evidence empty or confidence at 0 when you have assigned a score. Only use score: null, confidence: 0.0, evidence: [] when there is truly no evidence for that trait.

Do NOT guess. Be conservative.

TASK:
Analyze the cat description and score each trait on a 1–5 scale:
1 = very low
3 = neutral / average
5 = very high

For each trait return:
- score: 1–5 or null
- confidence: 0.0–1.0 — how confident you are in this evaluation (see CONFIDENCE GUIDELINES below)
- evidence: one or two words or phrases (a sentence or less) that provide evidence for the trait being evaluated. Copy EXACTLY from the description; do not paraphrase. Use 0–3 items; each item should be a short phrase or sentence (max ~15 words). Empty array [] when there is no evidence.

Evidence must be verbatim excerpts from the description that support why you assigned this score and confidence.
Do NOT paraphrase.

CONFIDENCE GUIDELINES (how confident you are in this evaluation):
0.90–1.00 = explicitly stated in the description
0.60–0.89 = strongly implied by specific behaviors or wording
0.30–0.59 = weakly implied / ambiguous
0.00 = no evidence

IMPORTANT RULES:
- For each trait, extract one or two words or phrases (a sentence or less) as evidence; state how confident you are in that evaluation (confidence 0.0–1.0).
- Generic praise words like "sweet", "loving", "nice" are NOT strong evidence by themselves.
- For "Intelligence" and "Adaptability", require explicit evidence (e.g., "learns quickly", "easy to train", "adjusted fast").
- Prefer null over guessing.
- Keep scoring conservative.
- Output MUST be valid JSON ONLY: a single object. No trailing commas in arrays or objects (JSON does not allow them). No markdown, no code fence, no backticks, no text before or after the JSON. Use compact formatting (minimal whitespace) so the response is not truncated.
- In "evidence" strings, escape any double quote as \\" so the output stays valid JSON.

TRAITS (exactly 10; use these exact keys in the "traits" object):
Energy Level
Playfulness
Affection Level
Independence
Sociability
Vocality
Confidence
Sensitivity
Adaptability
Intelligence

OUTPUT JSON FORMAT. "traits" must be a single object with exactly these 10 keys. Each value is an object with score, confidence, and evidence. When you assign a score, always include confidence and evidence:

{
  "traits": {
    "Energy Level": { "score": 2, "confidence": 0.7, "evidence": ["loves napping", "low key"] },
    "Playfulness": { "score": null, "confidence": 0.0, "evidence": [] },
    "Affection Level": { "score": null, "confidence": 0.0, "evidence": [] },
    "Independence": { "score": null, "confidence": 0.0, "evidence": [] },
    "Sociability": { "score": null, "confidence": 0.0, "evidence": [] },
    "Vocality": { "score": null, "confidence": 0.0, "evidence": [] },
    "Confidence": { "score": null, "confidence": 0.0, "evidence": [] },
    "Sensitivity": { "score": null, "confidence": 0.0, "evidence": [] },
    "Adaptability": { "score": null, "confidence": 0.0, "evidence": [] },
    "Intelligence": { "score": null, "confidence": 0.0, "evidence": [] }
  },
  "notes": {
    "summary_tags": [],
    "data_quality": "low"
  }
}

DATA QUALITY:
- low: fewer than 4 traits have score != null
- medium: 4–9 traits have score != null
- high: 10+ traits have score != null

CAT DESCRIPTION (ONLY SOURCE OF TRUTH):
<<<
${descriptionBlock}
>>>
${name ? `\nCat name: ${name}` : ''}${shelterName ? `\nShelter/Organization: ${shelterName}` : ''}`;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${apiKey}`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 4096,
          responseMimeType: 'application/json',
        },
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      console.error('Gemini API error', res.status, text);
      throw new functions.https.HttpsError(
        'internal',
        'Personality analysis failed'
      );
    }

    const json = (await res.json()) as {
      candidates?: Array<{
        content?: { parts?: Array<{ text?: string }> };
      }>;
      promptFeedback?: { blockReason?: string };
    };
    const text =
      json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
    if (!text) {
      const blockReason = json.promptFeedback?.blockReason ?? 'none';
      console.error('Gemini empty response', {
        hasCandidates: (json.candidates?.length ?? 0) > 0,
        blockReason,
        responseKeys: Object.keys(json),
      });
      throw new functions.https.HttpsError(
        'internal',
        'Empty response from personality analysis'
      );
    }

    let parsed: GeminiExtractionResponse;
    try {
      parsed = parseGeminiExtractionResponse(text);
    } catch (e) {
      functions.logger.error('Gemini response not JSON', {
        error: e instanceof Error ? e.message : String(e),
        responseLength: text.length,
        responseStart: text.slice(0, 600),
      });
      throw new functions.https.HttpsError(
        'internal',
        'Invalid personality analysis response'
      );
    }

    const rawTraits = parsed.traits && typeof parsed.traits === 'object' ? parsed.traits as Record<string, unknown> : {};
    const traits: Record<string, TraitDetail> = {};
    for (const name of TRAIT_NAMES) {
      const raw = rawTraits[name];
      if (raw && typeof raw === 'object' && raw !== null) {
        const o = raw as Record<string, unknown>;
        const score = o.score != null && typeof o.score === 'number' && o.score >= 1 && o.score <= 5 ? Math.round(o.score) : null;
        const confidence = typeof o.confidence === 'number' ? o.confidence : 0;
        const evidence = Array.isArray(o.evidence) ? o.evidence.filter((e): e is string => typeof e === 'string') : [];
        traits[name] = { score, confidence, evidence };
      } else {
        traits[name] = { score: null, confidence: 0, evidence: [] };
      }
    }

    const updatedAt = new Date().toISOString();
    const validTypeNames = new Set(CAT_TYPE_PROFILES.map((t) => t.name));
    const traitVector = TRAIT_NAMES.map((n) => {
      const s = traits[n]?.score;
      return s != null && s >= 1 && s <= 5 ? s : 3;
    });
    let suggestedName: string | null = null;
    let bestDist = Infinity;
    for (const profile of CAT_TYPE_PROFILES) {
      let dist = 0;
      for (let i = 0; i < TRAIT_NAMES.length; i++) {
        dist += (traitVector[i] - profile.traits[i]) ** 2;
      }
      if (dist < bestDist) {
        bestDist = dist;
        suggestedName = profile.name;
      }
    }
    const dataQuality = parsed.notes?.data_quality?.trim();
    const doc: Record<string, unknown> = {
      animalId: id,
      traits,
      descriptionHash: sha256Hex(description),
      updatedAt,
      animalUpdatedDate: updatedDate ?? null,
      catName: name?.trim() || null,
      shelterName: shelterName?.trim() || null,
    };
    if (suggestedName && validTypeNames.has(suggestedName)) {
      doc.suggestedCatTypeName = suggestedName;
    }
    if (dataQuality) {
      doc.dataQuality = dataQuality;
    }

    const projectId = process.env.GCLOUD_PROJECT ?? admin.app().options.projectId ?? 'unknown';
    const path = `${COLLECTION_ID}/${id}`;

    const beforeWrite = await docRef.get();
    if (beforeWrite.exists && beforeWrite.data()) {
      const d = beforeWrite.data() as Record<string, unknown>;
      const hashMatchesBeforeWrite = typeof d.descriptionHash !== 'string' || d.descriptionHash === sha256Hex(description);
      if (isExistingDocFresh(d) && hashMatchesBeforeWrite && typeof d.traits === 'object' && d.traits != null) {
        const raw = d.traits as Record<string, unknown>;
        const traitsOut: Record<string, TraitDetail> = {};
        const vals = Object.values(raw);
        const isNewFormat = vals.length > 0 && typeof vals[0] === 'object' && vals[0] !== null && 'score' in (vals[0] as object);
        for (const name of TRAIT_NAMES) {
          const v = raw[name];
          if (isNewFormat && v && typeof v === 'object' && v !== null) {
            const o = v as Record<string, unknown>;
            traitsOut[name] = {
              score: o.score != null && typeof o.score === 'number' ? o.score : null,
              confidence: typeof o.confidence === 'number' ? o.confidence : 0,
              evidence: Array.isArray(o.evidence) ? o.evidence.filter((e): e is string => typeof e === 'string') : [],
            };
          } else if (typeof v === 'number') {
            traitsOut[name] = { score: v, confidence: 0, evidence: [] };
          } else {
            traitsOut[name] = { score: null, confidence: 0, evidence: [] };
          }
        }
        const updatedAtStr = typeof d.updatedAt === 'string' ? d.updatedAt : new Date().toISOString();
        return {
          traits: traitsOut,
          suggestedCatTypeName: (d.suggestedCatTypeName as string) ?? null,
          updatedAt: updatedAtStr,
          dataQuality: (d.dataQuality as string) ?? null,
        };
      }
    }

    try {
      await docRef.set(doc, { merge: true });
      functions.logger.info('animal_fit_scores: wrote doc', {
        projectId,
        path,
        animalId: id,
      });
    } catch (err) {
      functions.logger.error('animal_fit_scores: Firestore write failed', {
        projectId,
        path,
        animalId: id,
        error: err instanceof Error ? err.message : String(err),
      });
      throw new functions.https.HttpsError(
        'internal',
        'Failed to save personality fit to Firestore'
      );
    }

    return {
      traits,
      suggestedCatTypeName: suggestedName && validTypeNames.has(suggestedName) ? suggestedName : null,
      updatedAt,
      dataQuality: dataQuality ?? null,
    };
  }
);

/** Days after which a fit doc is considered stale and removed. */
const STALE_DAYS = 90;

/**
 * Scheduled (daily): remove animal_fit_scores docs older than STALE_DAYS.
 * Keeps the collection from growing indefinitely with adopted/unlisted cats.
 */
export const batchCleanupStaleFitScores = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('America/Los_Angeles')
  .onRun(async () => {
    const db = admin.firestore();
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - STALE_DAYS);
    const cutoffIso = cutoff.toISOString();

    let totalDeleted = 0;
    const limit = 100;

    while (true) {
      const snap = await db
        .collection(COLLECTION_ID)
        .where('updatedAt', '<', cutoffIso)
        .limit(limit)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      totalDeleted += snap.size;
      if (snap.size < limit) break;
    }

    console.log(`batchCleanupStaleFitScores: deleted ${totalDeleted} stale docs`);
    return null;
  });

/**
 * Callable (optional): run the same stale cleanup manually.
 * Returns { deleted: number }.
 */
export const batchCleanupStaleFitScoresManual = functions.https.onCall(
  async (_data, _context) => {
    const db = admin.firestore();
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - STALE_DAYS);
    const cutoffIso = cutoff.toISOString();

    let totalDeleted = 0;
    const limit = 100;

    while (true) {
      const snap = await db
        .collection(COLLECTION_ID)
        .where('updatedAt', '<', cutoffIso)
        .limit(limit)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      totalDeleted += snap.size;
      if (snap.size < limit) break;
    }

    return { deleted: totalDeleted };
  }
);
