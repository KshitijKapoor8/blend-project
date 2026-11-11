import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, limit, or, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';
import assert from 'node:assert/strict';
import { test } from 'node:test';

test('friend discovery and connections enforce the beta privacy and request flow', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-blend-friends',
    firestore: { rules: readFileSync(new URL('./firestore.rules', import.meta.url), 'utf8') },
  });

  try {
    await env.clearFirestore();
    const db = Object.fromEntries(['alex', 'blair', 'casey'].map(id => [id, env.authenticatedContext(id).firestore()]));
    const signedOut = env.unauthenticatedContext().firestore();
    const publicProfile = (id) => ({ name: id[0].toUpperCase() + id.slice(1), username: id });
    const directoryProfile = (id) => ({ ...publicProfile(id), usernameLower: id });
    const directory = (actor, uid) => doc(actor, 'friendDirectory', uid);
    const connection = (actor, id = 'alex:blair') => doc(actor, 'friendConnections', id);
    const requestData = (sender, recipient) => ({
      sender, recipient, status: 'pending', createdAt: serverTimestamp(),
      senderProfile: publicProfile(sender), recipientProfile: publicProfile(recipient),
    });

    await env.withSecurityRulesDisabled(async context => {
      for (const id of Object.keys(db)) {
        await setDoc(doc(context.firestore(), 'users', id), {
          ...directoryProfile(id), email: id + '@example.test', phone: 'private',
        });
      }
    });

    await assertFails(setDoc(directory(db.alex, 'blair'), directoryProfile('blair')));
    await assertFails(setDoc(directory(db.alex, 'alex'), { ...directoryProfile('alex'), email: 'private' }));
    await assertFails(setDoc(directory(db.alex, 'alex'), { ...directoryProfile('alex'), name: 'Fake' }));
    await assertFails(getDoc(doc(db.alex, 'users', 'blair')));
    await assertSucceeds(setDoc(directory(db.alex, 'alex'), directoryProfile('alex')));
    await assertFails(getDoc(directory(signedOut, 'alex')));
    await assertFails(getDocs(collection(db.blair, 'friendDirectory')));
    const find = (actor, username) => getDocs(query(collection(actor, 'friendDirectory'), where('usernameLower', '==', username), limit(10)));
    assert.equal((await assertSucceeds(find(db.blair, 'alex'))).size, 1);
    assert.equal((await assertSucceeds(find(db.alex, 'blair'))).size, 0);
    await assertFails(setDoc(connection(db.alex), requestData('alex', 'blair')));

    await assertSucceeds(setDoc(directory(db.blair, 'blair'), directoryProfile('blair')));
    await assertFails(setDoc(connection(db.alex, 'alex:alex'), requestData('alex', 'alex')));
    await assertFails(setDoc(connection(db.casey), requestData('alex', 'blair')));
    await assertFails(setDoc(connection(db.alex, 'blair:alex'), requestData('alex', 'blair')));
    await assertFails(setDoc(connection(db.alex), { ...requestData('alex', 'blair'), status: 'accepted' }));
    await assertFails(setDoc(connection(db.alex), { ...requestData('alex', 'blair'), recipientProfile: publicProfile('casey') }));
    await assertSucceeds(setDoc(connection(db.alex), requestData('alex', 'blair')));
    await assertFails(setDoc(connection(db.blair), requestData('blair', 'alex')));
    await assertFails(getDoc(connection(db.casey)));
    await assertFails(deleteDoc(connection(db.casey)));
    await assertFails(getDocs(collection(db.alex, 'friendConnections')));

    const links = (id) => getDocs(query(collection(db[id], 'friendConnections'),
      or(where('sender', '==', id), where('recipient', '==', id))));
    assert.equal((await assertSucceeds(links('alex'))).size, 1);
    assert.equal((await assertSucceeds(links('blair'))).size, 1);
    assert.equal((await assertSucceeds(links('casey'))).size, 0);
    await assertFails(updateDoc(connection(db.alex), { status: 'accepted' }));
    await assertFails(updateDoc(connection(db.blair), { status: 'accepted', sender: 'casey' }));
    await assertSucceeds(updateDoc(connection(db.blair), { status: 'accepted' }));
    assert.equal((await assertSucceeds(getDoc(connection(db.alex)))).data().status, 'accepted');

    await assertSucceeds(deleteDoc(directory(db.blair, 'blair')));
    assert.equal((await assertSucceeds(find(db.alex, 'blair'))).size, 0);
    assert.equal((await assertSucceeds(getDoc(connection(db.alex)))).data().recipientProfile.name, 'Blair');
    await assertSucceeds(deleteDoc(connection(db.alex)));

    await assertSucceeds(setDoc(directory(db.blair, 'blair'), directoryProfile('blair')));
    await assertSucceeds(setDoc(connection(db.blair), requestData('blair', 'alex')));
    await assertSucceeds(deleteDoc(connection(db.blair))); // sender cancels
    await assertSucceeds(setDoc(connection(db.blair), requestData('blair', 'alex')));
    await assertSucceeds(deleteDoc(connection(db.alex))); // recipient declines
  } finally {
    await env.cleanup();
  }
});
