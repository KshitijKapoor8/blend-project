import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, writeBatch } from 'firebase/firestore';
import { test } from 'node:test';

test('usernames are claimed once, together with a matching profile', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-blend-usernames',
    firestore: { rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8') },
  });

  try {
    await env.clearFirestore();
    const db = Object.fromEntries(['alex', 'blair', 'old'].map(id => [id, env.authenticatedContext(id).firestore()]));
    const profile = (username) => ({ name: 'Test', username, usernameLower: username.toLowerCase() });
    const signUp = (actor, uid, username) => {
      const batch = writeBatch(actor);
      batch.set(doc(actor, 'users', uid), profile(username));
      batch.set(doc(actor, 'usernames', username.toLowerCase()), { uid });
      return batch.commit();
    };

    // Sign-up: check, then claim with the profile in one batch.
    await assertSucceeds(getDoc(doc(db.alex, 'usernames', 'sejal')));
    await assertSucceeds(signUp(db.alex, 'alex', 'Sejal'));

    // Same name, any case, is refused, and the profile isn't written either.
    await assertFails(signUp(db.blair, 'blair', 'sejal'));
    let left;
    await env.withSecurityRulesDisabled(async c => { left = await getDoc(doc(c.firestore(), 'users', 'blair')); });
    if (left.exists()) throw new Error('rejected sign-up still wrote a profile');

    // Can't claim for someone else, a name that isn't yours, or a malformed name.
    await assertFails(setDoc(doc(db.blair, 'usernames', 'blair'), { uid: 'alex' }));
    await assertFails(setDoc(doc(db.blair, 'usernames', 'other'), { uid: 'blair' }));
    await assertFails(setDoc(doc(db.blair, 'usernames', 'Bad.Name'), { uid: 'blair' }));
    await assertSucceeds(signUp(db.blair, 'blair', 'blair'));

    // Login backfill: an older account with a profile but no registry entry.
    await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'users', 'old'), profile('aarnawa')));
    await assertSucceeds(setDoc(doc(db.old, 'usernames', 'aarnawa'), { uid: 'old' }));
    await assertFails(setDoc(doc(db.old, 'usernames', 'aarnawa'), { uid: 'old' }));
  } finally {
    await env.cleanup();
  }
});
