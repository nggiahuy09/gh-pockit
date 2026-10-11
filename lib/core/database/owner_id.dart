/// Placeholder owner until auth (W10), when sign-in claims these rows (ADR-0001, open question 1). Not a UUID on purpose: it can never collide with a
/// real uid, and a stray one on the server is a visible bug.
const String localOwnerId = 'local';
