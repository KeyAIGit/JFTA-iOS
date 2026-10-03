# JFTA Supabase backend

This directory defines the first hosted backend for the JFTA iOS local beta.

## Security model

- Every application table has Row Level Security enabled.
- The anonymous role receives no table privileges.
- Authenticated users can access only rows whose owner UUID equals their Supabase Auth UUID.
- Community posts are private drafts in this first migration; no cross-user community read policy exists.
- The request-documents bucket is private and limited to 25 MiB per object.
- Storage paths must begin with the authenticated user's UUID.
- The service-role key must never be embedded in the iOS app or committed to Git.
- Real medical/PHI documents are out of scope until a compliant deployment and BAA are in place.

The client may contain the project URL and publishable/anon client key; authorization still depends on the user's JWT plus RLS.
## Data model

profiles stores the signed-in user's app profile and preferences.
requests stores local-style request drafts only; status is constrained to draft.
request_documents maps private Storage objects to a user's own request.
user_saves stores saved offer/article/listing identifiers.
posts and replies store private discussion drafts only.
activity_notices stores the owner's synchronized activity records.

No membership entitlement, payment, professional assignment, appointment, or submitted-case state is represented by this schema.

## Deployment sequence

1. Connect/create the hosted Supabase project.
2. Apply migrations with the Supabase integration or CLI.
3. Run database lint and the security verification checks.
4. Create two non-production test users.
5. Verify that user A cannot select/update/delete user B's rows or Storage objects.
6. Only then add the hosted URL and publishable key to the iOS configuration and enable remote sync behind a feature flag.
7. Keep the existing local store as offline/failure-safe storage during the beta.

Do not add database passwords, service-role keys, JWT signing keys, SMTP secrets, or Apple OAuth secrets to this repository.
