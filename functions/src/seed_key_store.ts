import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

type EnvMap = Record<string, string>;

function parseEnvFile(filePath: string): EnvMap {
  const raw = fs.readFileSync(filePath, 'utf8');
  const out: EnvMap = {};

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;

    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1);

    // Strip surrounding quotes if present.
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    out[key] = value;
  }

  return out;
}

function readDefaultProjectId(): string | undefined {
  // functions/ -> ../.firebaserc
  const firebasercPath = path.resolve(__dirname, '..', '..', '.firebaserc');
  if (!fs.existsSync(firebasercPath)) return undefined;

  try {
    const raw = fs.readFileSync(firebasercPath, 'utf8');
    const json = JSON.parse(raw) as { projects?: { default?: string } };
    return json.projects?.default;
  } catch {
    return undefined;
  }
}

async function main() {
  const projectId = readDefaultProjectId();
  if (!projectId) {
    throw new Error(
      'Could not determine Firebase project id from ../.firebaserc (expected projects.default).',
    );
  }

  // Read env from flutter app root: ../.env
  const envPath = path.resolve(__dirname, '..', '..', '.env');
  if (!fs.existsSync(envPath)) {
    throw new Error(`Missing .env file at: ${envPath}`);
  }

  const env = parseEnvFile(envPath);

  const keyNames = [
    'GEMINI_API_KEY',
    'YOUTUBE_API_KEY',
    'GOOGLE_MAPS_API_KEY',
    'RESCUE_GROUPS_API_KEY',
  ] as const;

  const toWrite = keyNames
    .map((name) => ({ name, value: (env[name] ?? '').trim() }))
    .filter((kv) => kv.value.length > 0);

  const missing = keyNames.filter((name) => !(env[name] ?? '').trim());

  if (toWrite.length === 0) {
    throw new Error(
      `No keys found in .env. Expected one or more of: ${keyNames.join(', ')}`,
    );
  }

  // Uses Application Default Credentials:
  // - either set GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
  // - or run: gcloud auth application-default login
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });

  const db = admin.firestore();
  const batch = db.batch();
  const col = db.collection('key_store');

  for (const kv of toWrite) {
    const ref = col.doc(kv.name);
    batch.set(
      ref,
      {
        key_name: kv.name,
        key_value: kv.value,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await batch.commit();

  // Only print key names (never values)
  // eslint-disable-next-line no-console
  console.log(
    `✅ Seeded key_store in project "${projectId}": ${toWrite
      .map((k) => k.name)
      .join(', ')}`,
  );

  if (missing.length) {
    // eslint-disable-next-line no-console
    console.log(`ℹ️ Missing from .env (not written): ${missing.join(', ')}`);
  }
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(`❌ Seed failed: ${err?.message ?? String(err)}`);
  process.exitCode = 1;
});

