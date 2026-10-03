# Hosted RLS acceptance

Use two disposable confirmed Auth users: A and B.

1. A can insert/select/update/delete only A's profile.
2. A can CRUD A's draft request; B cannot read or mutate it.
3. A cannot create request_documents metadata for B's request or a path outside A's UUID folder.
4. A can upload/read/update/delete only objects in `request-documents/<A UUID>/...`.
5. B cannot list or fetch A's private Storage objects.
6. A's saved catalog IDs are invisible to B.
7. Posts remain owner-private; B cannot read A's post or reply.
8. A cannot create a reply for a post owned by B.
9. Anonymous requests receive no application-table rows and cannot upload Storage objects.
10. A service-role credential is used only in controlled server/admin tests, never in iOS.

Do not use real medical, legal, identity, payment, or customer documents for these tests.
