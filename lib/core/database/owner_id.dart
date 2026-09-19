/// The `owner_id` every synced row carries until auth lands in W10 — ADR-0001, open question 1, answered at W2 T3.
///
/// §6 requires `owner_id` on every synced entity, and the blueprint declares it `NOT NULL`; auth is seven weeks away. The two candidates were a nullable
/// column backfilled at W10 and this sentinel. The sentinel wins on one argument: a nullable `owner_id` would make every DAO, every query and every sync
/// path written between W2 and W9 tolerate a null owner, and then tightening the column to `NOT NULL` in SQLite is a full table rebuild rather than an
/// `ALTER`. The local schema would also disagree with the Postgres mirror of W10 T3 for eight weeks, which is exactly the period sync is being designed in.
///
/// What it costs: `NOT NULL` is enforced from the first insert, but *a real uid flowing through* is not proven until W10. That is the risk ADR-0001 named,
/// and it is accepted rather than dissolved.
///
/// **W10 is not a schema migration.** Claiming these rows needs the uid, which only exists at runtime after a sign-in, so it cannot live in an `onUpgrade`
/// step. It belongs in the sign-in flow: `UPDATE <table> SET owner_id = :uid, updated_at = :now, version = version + 1 WHERE owner_id = 'local'`, then the
/// rows enqueue as ordinary create mutations. That step has to exist regardless — a user who tracks expenses offline for a week and only then registers
/// must keep the week — so the sentinel is not buying a migration on credit; it is naming work that was always required.
///
/// Deliberately not a UUID. `auth.uid()` is always one, so no real owner can ever collide with this value, and a stray `'local'` reaching the server is a
/// visible bug rather than a plausible-looking id.
const String localOwnerId = 'local';
