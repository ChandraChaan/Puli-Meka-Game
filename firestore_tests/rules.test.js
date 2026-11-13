// Tests for firestore.rules, run against the Firestore emulator:
//   cd firestore_tests && npm install && npm test
// The emulator needs Java 21 or newer.
// The writes mirror lib/online/firestore_backend.dart.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;
const CODE = 'ABC234';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-puli-meka',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
const room = (uid, code = CODE) => doc(db(uid), 'rooms', code);

const newRoom = (overrides = {}) => ({
  code: CODE,
  hostUid: 'host',
  hostName: 'Asha',
  hostSide: 'goat',
  guestUid: null,
  guestName: null,
  goatUid: null,
  tigerUid: null,
  captureTarget: 5,
  moves: [],
  status: 'waiting',
  isPublic: false,
  round: 0,
  rematch: [],
  lastSeen: { host: serverTimestamp() },
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  expireAt: new Date(Date.now() + 2 * 864e5),
  ...overrides,
});

const join = (uid = 'guest') =>
  updateDoc(room(uid), {
    guestUid: uid,
    guestName: 'Ravi',
    goatUid: 'host',
    tigerUid: uid,
    status: 'playing',
    [`lastSeen.${uid}`]: serverTimestamp(),
    updatedAt: serverTimestamp(),
    expireAt: new Date(Date.now() + 2 * 864e5),
  });

const send = (uid, moves, extra = {}) =>
  updateDoc(room(uid), {
    moves,
    [`lastSeen.${uid}`]: serverTimestamp(),
    updatedAt: serverTimestamp(),
    expireAt: new Date(Date.now() + 2 * 864e5),
    ...extra,
  });

async function playingRoom() {
  await assertSucceeds(setDoc(room('host'), newRoom()));
  await assertSucceeds(join());
}

describe('creating rooms', () => {
  test('a signed-in player can create a room for themselves', async () => {
    await assertSucceeds(setDoc(room('host'), newRoom()));
  });

  test('not for someone else, or with a bad code or moves', async () => {
    await assertFails(setDoc(room('host'), newRoom({ hostUid: 'other' })));
    await assertFails(setDoc(room('host', 'abc234'), newRoom({ code: 'abc234' })));
    await assertFails(setDoc(room('host'), newRoom({ moves: ['p1'] })));
    await assertFails(setDoc(room('host'), newRoom({ captureTarget: 1 })));
    await assertFails(
      setDoc(doc(env.unauthenticatedContext().firestore(), 'rooms', CODE), newRoom()),
    );
  });
});

describe('joining', () => {
  test('a second player takes the empty seat', async () => {
    await setDoc(room('host'), newRoom());
    await assertSucceeds(join());
  });

  test('the host cannot join their own room, and a full room stays full', async () => {
    await setDoc(room('host'), newRoom());
    await assertFails(join('host'));
    await assertSucceeds(join('guest'));
    await assertFails(join('third'));
  });

  test('the joiner cannot pick the wrong sides', async () => {
    await setDoc(room('host'), newRoom());
    await assertFails(
      updateDoc(room('guest'), {
        guestUid: 'guest',
        guestName: 'Ravi',
        goatUid: 'guest',
        tigerUid: 'host',
        status: 'playing',
      }),
    );
  });
});

describe('moves', () => {
  test('players alternate, goats first', async () => {
    await playingRoom();
    await assertSucceeds(send('host', ['p12']));
    await assertSucceeds(send('guest', ['p12', '0-2']));
    await assertSucceeds(send('host', ['p12', '0-2', 'p20']));
  });

  test('nobody moves out of turn', async () => {
    await playingRoom();
    await assertFails(send('guest', ['0-2']));
    await assertSucceeds(send('host', ['p12']));
    await assertFails(send('host', ['p12', 'p13']));
  });

  test('past moves cannot be changed, and only one move is added at a time', async () => {
    await playingRoom();
    await assertSucceeds(send('host', ['p12']));
    await assertSucceeds(send('guest', ['p12', '0-2']));
    await assertFails(send('host', ['p13', '0-2', 'p20']));
    await assertFails(send('host', ['p12', '0-2', 'p20', '2-0']));
    await assertFails(send('host', ['p12']));
  });

  test('outsiders cannot write', async () => {
    await playingRoom();
    await assertFails(send('third', ['p12']));
  });

  test('the last move can end the game', async () => {
    await playingRoom();
    await assertSucceeds(send('host', ['p12'], { status: 'over' }));
    await assertFails(send('guest', ['p12', '0-2']));
  });

  test('anyone signed in can read a room', async () => {
    await playingRoom();
    await assertSucceeds(getDoc(room('third')));
  });
});

describe('leaving and rematches', () => {
  test('a player can resign', async () => {
    await playingRoom();
    await assertSucceeds(
      updateDoc(room('guest'), { status: 'abandoned', leftBy: 'guest', updatedAt: serverTimestamp() }),
    );
  });

  test('heartbeats are allowed while waiting and playing', async () => {
    await setDoc(room('host'), newRoom());
    const beat = (uid) =>
      updateDoc(room(uid), {
        [`lastSeen.${uid}`]: serverTimestamp(),
        updatedAt: serverTimestamp(),
        expireAt: new Date(Date.now() + 2 * 864e5),
      });
    await assertSucceeds(beat('host'));
    await assertFails(beat('guest'));
    await join();
    await assertSucceeds(beat('guest'));
  });

  test('a finished game can restart with sides swapped', async () => {
    await playingRoom();
    await send('host', ['p12'], { status: 'over' });
    await assertSucceeds(updateDoc(room('host'), { rematch: ['host'] }));
    await assertSucceeds(
      updateDoc(room('guest'), {
        moves: [],
        status: 'playing',
        round: 1,
        goatUid: 'guest',
        tigerUid: 'host',
        rematch: [],
        leftBy: null,
      }),
    );
  });

  test('a game in progress cannot be wiped', async () => {
    await playingRoom();
    await send('host', ['p12']);
    await assertFails(
      updateDoc(room('guest'), {
        moves: [],
        status: 'playing',
        round: 1,
        goatUid: 'guest',
        tigerUid: 'host',
      }),
    );
  });

  test('only the host can cancel a waiting room', async () => {
    await setDoc(room('host'), newRoom());
    await assertFails(deleteDoc(room('guest')));
    await assertSucceeds(deleteDoc(room('host')));
  });
});
