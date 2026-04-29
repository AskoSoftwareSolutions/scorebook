/**
 * ScoreBook — 14-day match retention cleanup.
 *
 * Scheduled function runs daily at 03:30 IST and deletes:
 *   /matches/{matchCode}            where updatedAt < (now - 14 days)
 *   /user_matches/{phone}/{code}    where updatedAt < (now - 14 days)
 *   /tournaments/{tournamentId}     where updatedAt < (now - 14 days)
 *
 * Fail-safe: any individual delete error is logged but does not abort
 * the rest of the sweep.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const rtdb = admin.database();

const TWO_WEEKS_MS = 14 * 24 * 60 * 60 * 1000;

exports.purgeOldMatches = onSchedule(
  {
    schedule: '30 3 * * *',           // every day at 03:30
    timeZone: 'Asia/Kolkata',
    region: 'us-central1',
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async (_event) => {
    const cutoff = Date.now() - TWO_WEEKS_MS;
    logger.info(`[purge] cutoff = ${new Date(cutoff).toISOString()}`);

    let purgedMatches = 0;
    let purgedTournaments = 0;
    let purgedUserIndex = 0;

    // ── 1. /matches/{code} ───────────────────────────────────────────────
    try {
      const snap = await rtdb.ref('matches').once('value');
      if (snap.exists()) {
        const all = snap.val() || {};
        const updates = {};
        for (const [code, data] of Object.entries(all)) {
          const updatedAt = (data && data.updatedAt) || 0;
          if (updatedAt && updatedAt < cutoff) {
            updates[`matches/${code}`] = null;
            purgedMatches++;
          }
        }
        if (purgedMatches > 0) {
          await rtdb.ref().update(updates);
        }
      }
    } catch (e) {
      logger.error('[purge] /matches sweep failed', e);
    }

    // ── 2. /user_matches/{phone}/{code} ──────────────────────────────────
    try {
      const snap = await rtdb.ref('user_matches').once('value');
      if (snap.exists()) {
        const byPhone = snap.val() || {};
        const updates = {};
        for (const [phone, codes] of Object.entries(byPhone)) {
          if (!codes) continue;
          for (const [code, entry] of Object.entries(codes)) {
            const updatedAt = (entry && entry.updatedAt) || 0;
            if (updatedAt && updatedAt < cutoff) {
              updates[`user_matches/${phone}/${code}`] = null;
              purgedUserIndex++;
            }
          }
        }
        if (purgedUserIndex > 0) {
          await rtdb.ref().update(updates);
        }
      }
    } catch (e) {
      logger.error('[purge] /user_matches sweep failed', e);
    }

    // ── 3. /tournaments/{tournamentId} ───────────────────────────────────
    try {
      const snap = await rtdb.ref('tournaments').once('value');
      if (snap.exists()) {
        const all = snap.val() || {};
        const updates = {};
        for (const [id, data] of Object.entries(all)) {
          const updatedAt =
            (data && (data.updatedAt || data.createdAt)) || 0;
          if (updatedAt && updatedAt < cutoff) {
            updates[`tournaments/${id}`] = null;
            purgedTournaments++;
          }
        }
        if (purgedTournaments > 0) {
          await rtdb.ref().update(updates);
        }
      }
    } catch (e) {
      logger.error('[purge] /tournaments sweep failed', e);
    }

    logger.info(
      `[purge] done. matches=${purgedMatches} tournaments=${purgedTournaments} userIndex=${purgedUserIndex}`,
    );
  },
);
