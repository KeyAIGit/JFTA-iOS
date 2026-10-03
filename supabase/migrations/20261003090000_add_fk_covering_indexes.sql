create index if not exists request_documents_request_user_idx
on public.request_documents(request_id, user_id);

create index if not exists replies_post_user_idx
on public.replies(post_id, user_id);

create index if not exists replies_user_idx
on public.replies(user_id);
