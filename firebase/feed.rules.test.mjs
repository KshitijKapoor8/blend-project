import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, where } from 'firebase/firestore';
import { test } from 'node:test';

test('ratings are readable by their owner and accepted friends only', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-blend-feed',
    firestore: { rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8') },
  });

  try {
    await env.clearFirestore();
    const db = Object.fromEntries(['alex', 'blair', 'casey', 'drew'].map(id => [id, env.authenticatedContext(id).firestore()]));
    const ratings = (actor) => collection(actor, 'ratings');

    await env.withSecurityRulesDisabled(async context => {
      const admin = context.firestore();
      for (const id of ['alex', 'blair', 'casey', 'drew']) {
        await setDoc(doc(admin, 'ratings', id + '_epoch'), { userId: id, shopName: 'Epoch', score: 4 });
      }
      // alex and blair are friends; alex has only a pending request to casey.
      await setDoc(doc(admin, 'friendConnections', 'alex:blair'), { sender: 'alex', recipient: 'blair', status: 'accepted' });
      await setDoc(doc(admin, 'friendConnections', 'alex:casey'), { sender: 'alex', recipient: 'casey', status: 'pending' });
    });

    // Profile: own ratings.
    await assertSucceeds(getDocs(query(ratings(db.alex), where('userId', '==', 'alex'))));
    await assertSucceeds(getDoc(doc(db.alex, 'ratings', 'alex_new-shop')));

    // Feed: accepted friends, in both directions.
    await assertSucceeds(getDocs(query(ratings(db.alex), where('userId', 'in', ['blair']))));
    await assertSucceeds(getDocs(query(ratings(db.blair), where('userId', 'in', ['alex']))));
    await assertSucceeds(getDoc(doc(db.alex, 'ratings', 'blair_epoch')));

    // Not friends yet, or never connected.
    await assertFails(getDocs(query(ratings(db.alex), where('userId', 'in', ['blair', 'casey']))));
    await assertFails(getDocs(query(ratings(db.alex), where('userId', '==', 'drew'))));
    await assertFails(getDoc(doc(db.alex, 'ratings', 'drew_epoch')));

    // Listing everything is no longer allowed.
    await assertFails(getDocs(ratings(db.alex)));

    // Friends can read but not change each other's ratings.
    await assertFails(setDoc(doc(db.alex, 'ratings', 'blair_epoch'), { userId: 'blair', score: 1 }));
  } finally {
    await env.cleanup();
  }
});
