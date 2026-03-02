# Supabase / Postgres Best Practices – Project Analysis

This document summarizes findings from reviewing the project against the **Supabase Postgres Best Practices** skill (query performance, connection management, security/RLS, schema design, data access patterns).

---

## Executive summary

- **Schema & indexes**: Several missing indexes (especially on FKs and RLS-filtered columns); UUID v4 used everywhere.
- **Security (RLS)**: RLS is enabled and used; no `FORCE ROW LEVEL SECURITY`; helper functions and `auth.uid()` are not wrapped in `(SELECT ...)` for single evaluation.
- **Data access**: No N+1 in the profiles/org_members flow (batched). List endpoints use OFFSET pagination; recycle_bin list applies `range` before `order` in the builder (verify generated SQL).
- **Connection**: Supabase client usage is standard; ensure server-side uses the pooler URL where applicable.

---

## 1. Query performance & indexes

### 1.1 Missing indexes on foreign keys / WHERE columns

**Rule:** [query-missing-indexes](.agents/skills/supabase-postgres-best-practices/references/query-missing-indexes.md), [schema-foreign-key-indexes](.agents/skills/supabase-postgres-best-practices/references/schema-foreign-key-indexes.md)

- **`org_members.user_id`**  
  Queried with `.in("user_id", userIds)` in `data.ts` (profiles getList). There is a `UNIQUE(org_id, user_id)` but no index on `user_id` alone. Add:
  ```sql
  CREATE INDEX idx_org_members_user_id ON public.org_members(user_id);
  ```

- **`product_role_definitions.product_id`**  
  FK from `product_role_definitions` to `products`; no index on `product_id`. JOINs and RLS may scan this table. Add:
  ```sql
  CREATE INDEX idx_product_role_definitions_product_id ON public.product_role_definitions(product_id);
  ```

- **`org_product_subscriptions.plan_id`**  
  Used in JOINs and possibly in filters; only `(org_id, product_id)` is unique. Consider:
  ```sql
  CREATE INDEX idx_org_product_subscriptions_plan_id ON public.org_product_subscriptions(plan_id);
  ```

- **`profiles.deleted_at`**  
  Filtered with `.is("deleted_at", null)` in getList. Consider a partial index if you often filter non-deleted:
  ```sql
  CREATE INDEX idx_profiles_deleted_at ON public.profiles(deleted_at) WHERE deleted_at IS NULL;
  ```
  (Only if you have a lot of soft-deleted rows and list non-deleted often.)

### 1.2 Indexes that are in good shape

- Payment tables: FKs and common filters are indexed (`org_id`, `provider_id`, `subscription_id`, etc.).
- Base tables: `product_plans`, `plan_entitlements`, `recycle_bin`, `org_invitations` have appropriate indexes.
- Partial indexes are used where it makes sense (e.g. `entitlements`, `plans`, `recycle_bin`).

---

## 2. Schema design

### 2.1 Primary keys: UUID v4 vs identity / UUIDv7

**Rule:** [schema-primary-keys](.agents/skills/supabase-postgres-best-practices/references/schema-primary-keys.md)

All main tables use `uuid primary key default gen_random_uuid()` (UUID v4). The skill recommends:

- **Single DB, numeric IDs:** `bigint generated always as identity primary key`.
- **Distributed / exposed IDs:** UUIDv7 (time-ordered) to avoid index fragmentation from random UUIDs.

**Recommendation:** For new tables or major migrations, consider:

- `bigint identity` for internal-only PKs.
- If you need UUIDs (e.g. external APIs), UUIDv7 via extension (e.g. `pg_uuidv7`) instead of `gen_random_uuid()`.

No change is strictly required for correctness; this is an optimization and long-term maintainability improvement.

### 2.2 Covering indexes

**Rule:** [query-covering-indexes](.agents/skills/supabase-postgres-best-practices/references/query-covering-indexes.md)

Many queries use `select("*")`. For hot paths (e.g. list by `org_id` or `user_id` with a fixed set of columns), consider `INCLUDE` columns so the index can serve the query without heap lookups. This can be done incrementally based on `EXPLAIN (ANALYZE, BUFFERS)` on the slowest endpoints.

---

## 3. Security & RLS

### 3.1 Force Row Level Security

**Rule:** [security-rls-basics](.agents/skills/supabase-postgres-best-practices/references/security-rls-basics.md)

RLS is enabled on all relevant tables, but **`FORCE ROW LEVEL SECURITY`** is not set. That means the table owner (e.g. `postgres`) can bypass RLS. For strict multi-tenant isolation, force RLS so that even owners are subject to policies:

```sql
-- Example for one table; repeat for all tables with RLS
ALTER TABLE public.organizations FORCE ROW LEVEL SECURITY;
-- ... same for profiles, org_members, products, etc.
```

Apply to every table that has RLS enabled.

### 3.2 RLS policy performance: wrap helpers and auth.uid()

**Rule:** [security-rls-performance](.agents/skills/supabase-postgres-best-practices/references/security-rls-performance.md)

Policies call `auth.uid()`, `public.get_my_org_id()`, and `public.is_super_admin()` directly. The skill recommends wrapping them in a scalar subquery so they are evaluated once per statement, not once per row:

**Current (evaluated per row):**

```sql
using (auth.uid() = id or public.is_super_admin())
using (public.is_super_admin() or id = public.get_my_org_id())
```

**Recommended:**

```sql
using ((select auth.uid()) = id or (select public.is_super_admin()))
using ((select public.is_super_admin()) or id = (select public.get_my_org_id()))
```

Apply this pattern everywhere these functions are used in RLS (core and payment RLS files), e.g.:

- `auth.uid()` in profiles and payment RLS (`20250101000009_rls_policies.sql`, `20250101000011_rls_policies_payment.sql`).
- `public.get_my_org_id()` and `public.get_my_role()`.
- `public.is_super_admin()`.

### 3.3 Indexes on RLS policy columns

Ensure columns used in `USING`/`WITH CHECK` are indexed so policy checks don’t cause full table scans. You already have indexes on things like `org_id`, `user_id` in many places; the new indexes suggested in section 1 (e.g. `org_members.user_id`, `product_role_definitions.product_id`) also help RLS.

---

## 4. Data access patterns

### 4.1 N+1 and batching

**Rule:** [data-n-plus-one](.agents/skills/supabase-postgres-best-practices/references/data-n-plus-one.md)

- **Profiles getList** (`data.ts`): Fetches profiles, then `org_members` with `.in("user_id", userIds)`, then `member_product_roles` with `.in("member_id", memberIds)`. This is batched correctly (no per-row queries).
- **org_members getList**: Fetches org_members then profiles with `.in("id", userIds)`. Also batched.

No N+1 issues identified in these flows.

### 4.2 Pagination: OFFSET vs cursor

**Rule:** [data-pagination](.agents/skills/supabase-postgres-best-practices/references/data-pagination.md)

All list endpoints use OFFSET/LIMIT (e.g. `range(offset, offset + pageSize - 1)`). For large tables and deep pages, OFFSET becomes expensive. For critical, high-volume lists (e.g. `recycle_bin`, `payment_webhook_events`, `payment_invoices`), consider cursor-based pagination (e.g. `WHERE (created_at, id) > ($last_created_at, $last_id) ORDER BY created_at, id LIMIT n`) so cost is stable across pages.

### 4.3 Recycle bin getList: order vs range

In `data.ts`, the recycle_bin getList builds:

```ts
let query = supabaseClient
  .from("recycle_bin")
  .select("*", { count: "exact" })
  .range(offset, offset + pageSize - 1);
// ...
query = query.order("deleted_at", { ascending: sorter.order === "asc" });
```

Semantically you want “order by deleted_at, then take a page”. The Supabase client usually sends both `order` and `range` to PostgREST, which applies ORDER BY then LIMIT/OFFSET. For clarity and to avoid any client quirks, prefer building the query with `order` before `range`:

```ts
let query = supabaseClient
  .from("recycle_bin")
  .select("*", { count: "exact" });
if (sorters && sorters.length > 0) {
  // apply sorters
} else {
  query = query.order("deleted_at", { ascending: false });
}
query = query.range(offset, offset + pageSize - 1);
```

---

## 5. Connection management

**Rule:** [conn-pooling](.agents/skills/supabase-postgres-best-practices/references/conn-pooling.md)

- **Client:** `apps/ait-sso-admin/src/providers/supabase-client.ts` uses `createClient(SUPABASE_URL, SUPABASE_KEY)`. That’s normal for a browser or server that talks to Supabase via HTTP.
- **Server-side Postgres:** If any server-side code (e.g. Edge Functions, custom API) opens direct Postgres connections, it should use the **connection pooler** (e.g. port 6543 / transaction mode) instead of the direct port (5432). Check that `SUPABASE_URL` (or any `DATABASE_URL`) used by server apps points to the pooler when opening SQL connections.

---

## 6. Implemented fixes (2025-03)

The following were applied:

- **Migration `20250101000041_supabase_best_practices_indexes_force_rls.sql`**
  - Added indexes: `idx_org_members_user_id`, `idx_product_role_definitions_product_id`, `idx_org_product_subscriptions_plan_id`, `idx_profiles_deleted_at` (partial).
  - Set `FORCE ROW LEVEL SECURITY` on all tables that have RLS (core, payment, product_plan_prices, billing_intervals, email_templates).
- **Migration `20250101000042_rls_policies_performance.sql`**
  - Recreated RLS policies so `auth.uid()`, `get_my_org_id()`, `get_my_role()`, and `is_super_admin()` are wrapped in `(SELECT ...)` for single evaluation per statement (core, payment, product_plan_prices, billing_intervals, email_templates).
- **`apps/ait-sso-admin/src/providers/data.ts`**
  - Recycle bin getList: applied `order` before `range` so pagination is consistent (order by `deleted_at`, then take page).

---

## 7. Summary of recommended actions

| Priority | Area              | Action | Status |
|----------|-------------------|--------|--------|
| High     | Indexes           | Add `idx_org_members_user_id`, `idx_product_role_definitions_product_id`, etc. | Done (migration 41) |
| High     | RLS               | Add `FORCE ROW LEVEL SECURITY` to all tables that have RLS. | Done (migration 41) |
| High     | RLS performance   | Use `(select auth.uid())`, `(select public.get_my_org_id())`, etc. in policies. | Done (migration 42) |
| Medium   | Pagination        | Recycle bin getList: apply `order` before `range`. | Done (data.ts) |
| Medium   | Schema            | For new tables or big migrations, consider `bigint identity` or UUIDv7 instead of UUID v4. | Optional |
| Low      | Pagination        | For very large tables, consider cursor-based pagination. | Optional |
| Low      | Connection        | Confirm any direct Postgres usage from server apps uses the pooler URL. | Verify |
| Low      | Covering indexes  | Add `INCLUDE` on hot paths after measuring with EXPLAIN. | Optional |

---

## References

- Skill: `.agents/skills/supabase-postgres-best-practices/SKILL.md`
- Refs: `.agents/skills/supabase-postgres-best-practices/references/*.md`
- [Supabase DB docs](https://supabase.com/docs/guides/database/overview)
- [Supabase RLS](https://supabase.com/docs/guides/auth/row-level-security)
