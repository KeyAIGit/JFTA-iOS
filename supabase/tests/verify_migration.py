from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
migration = next((root / "supabase" / "migrations").glob("*_jfta_backend.sql"))
sql = migration.read_text()
lower = sql.lower()

tables = [
    "profiles", "requests", "request_documents", "user_saves",
    "posts", "replies", "activity_notices",
]

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("FAIL: " + message)
    print("PASS:", message)

require(lower.startswith("begin;"), "migration is transactional")
require(lower.rstrip().endswith("commit;"), "migration commits explicitly")
require("service_role" not in lower, "migration does not grant app tables to service_role")
for table in tables:
    require(
        f"alter table public.{table} enable row level security;" in lower,
        f"RLS enabled on {table}",
    )

require(" from anon;" in lower, "anonymous table privileges are revoked")
require("public = excluded.public" in lower, "bucket privacy remains managed by migration")
require("'request-documents'" in lower, "private request-documents bucket exists")
require("26214400" in lower, "document size is capped at 25 MiB")
require("owner_id = (select auth.uid())::text" in lower, "Storage reads/deletes enforce owner")
require("(storage.foldername(name))[1] = (select auth.uid())::text" in lower,
        "Storage writes require user-id folder")
require("status = 'draft'" in lower, "requests cannot claim server submission")
require("visibility = 'private'" in lower, "discussion records are private in MVP")
require("using (true)" not in lower and "with check (true)" not in lower,
        "no allow-all RLS policy exists")

policy_count = len(re.findall(r"\bcreate\s+policy\b", lower))
require(policy_count >= 20, f"expected security policies present ({policy_count})")
swift_text = "\n".join(
    p.read_text(errors="ignore")
    for p in (root / "JFTA").glob("*.swift")
)
require("service_role" not in swift_text.lower(), "iOS source contains no service-role key marker")

config = (root / "supabase" / "config.toml").read_text()
require("enable_anonymous_sign_ins = false" in config, "anonymous Auth is disabled locally")
require("file_size_limit = \"25MiB\"" in config, "local Storage limit matches hosted migration")

print("Backend migration static security checks passed.")
