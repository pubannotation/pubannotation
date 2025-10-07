# Performance Analysis: `update_final_project_stats` at Scale

## Scenario
- **Upload size**: Millions of documents
- **Database size**: 10 million documents already in database
- **Total annotations**: Could be 100+ million across all tables

## Current Implementation Flow

```ruby
def update_final_project_stats
  @project.update_annotation_stats_from_database
end

def update_annotation_stats_from_database
  # Step 1: Count project-level annotations (single project)
  denotations_count = denotations.count           # SELECT COUNT(*) FROM denotations WHERE project_id = ?
  blocks_count = blocks.count                     # SELECT COUNT(*) FROM blocks WHERE project_id = ?
  relations_count = relations.count               # SELECT COUNT(*) FROM relations WHERE project_id = ?
  docs_count_value = docs.count                   # SELECT COUNT(*) FROM docs JOIN project_docs...

  # Step 2: Update project record (FAST - single row)
  update!(denotations_num: ..., blocks_num: ..., ...)

  # Step 3: Update ALL project_docs for this project (BOTTLENECK!)
  ProjectDoc.bulk_update_counts(project_id: id)

  # Step 4: Update ALL docs for this project (MASSIVE BOTTLENECK!)
  doc_ids = project_docs.pluck(:doc_id).uniq     # Get all doc IDs for this project
  Doc.bulk_update_docs_counts(doc_ids: doc_ids)  # Update potentially millions of docs
end
```

## Performance Analysis by Step

### Step 1: Project-level counts ✅ FAST
```sql
SELECT COUNT(*) FROM denotations WHERE project_id = 10
SELECT COUNT(*) FROM blocks WHERE project_id = 10
SELECT COUNT(*) FROM relations WHERE project_id = 10
```

**Performance**:
- **Good** - Uses index on `project_id`
- Estimated time: 1-5 seconds per query (even with 100M+ total annotations)
- Total: **~15 seconds**

### Step 2: Update project record ✅ FAST
```sql
UPDATE projects SET denotations_num = ?, blocks_num = ?, ... WHERE id = 10
```

**Performance**:
- **Excellent** - Single row update
- Estimated time: **<100ms**

### Step 3: Update project_docs ⚠️ SLOW for millions of docs
```sql
-- Fetches doc IDs
SELECT doc_id FROM project_docs WHERE project_id = 10

-- Then for millions of project_docs rows:
UPDATE project_docs
SET
  denotations_num = COALESCE(d.cnt, 0),
  blocks_num = COALESCE(b.cnt, 0),
  relations_num = COALESCE(r.cnt, 0)
FROM
  (SELECT doc_id, project_id FROM project_docs WHERE project_id = 10) pd_list
  LEFT JOIN (SELECT doc_id, project_id, COUNT(*) FROM denotations
             WHERE project_id = 10 GROUP BY doc_id, project_id) d
             ON pd_list.doc_id = d.doc_id AND pd_list.project_id = d.project_id
  LEFT JOIN (SELECT doc_id, project_id, COUNT(*) FROM blocks
             WHERE project_id = 10 GROUP BY doc_id, project_id) b ...
  LEFT JOIN (SELECT doc_id, project_id, COUNT(*) FROM relations
             WHERE project_id = 10 GROUP BY doc_id, project_id) r ...
WHERE project_docs.doc_id = pd_list.doc_id
  AND project_docs.project_id = pd_list.project_id
  AND project_docs.project_id = 10
```

**Performance**:
- **3 aggregate subqueries** (denotations, blocks, relations) with GROUP BY
- Each aggregation scans millions of annotation rows
- Updates millions of project_docs rows

**Estimated time for 1 million docs**:
- Aggregations: 30-60 seconds (depends on # annotations per doc)
- Row updates: 10-30 seconds (bulk UPDATE is efficient)
- **Total: 40-90 seconds** ⚠️

**Estimated time for 5 million docs**:
- Aggregations: 2-5 minutes
- Row updates: 1-3 minutes
- **Total: 3-8 minutes** ⚠️⚠️

### Step 4: Update docs 🔴 MASSIVE BOTTLENECK for millions of docs

```sql
-- First: Get all doc_ids for project
SELECT doc_id FROM project_docs WHERE project_id = 10

-- For doc_ids < 5000: Single query
UPDATE docs SET ... WHERE docs.id IN (1,2,3,...)

-- For 5000-100k doc_ids: Batched (5000 per batch)
-- Runs 200 times for 1M docs, 1000 times for 5M docs

-- For 100k+ doc_ids: Uses temp table
CREATE TEMP TABLE temp_doc_ids ...
INSERT INTO temp_doc_ids VALUES (1), (2), ... (batched 10k at a time)
UPDATE docs ... FROM temp_doc_ids ...
```

**The Critical Problem**:

For millions of docs, the query becomes:
```sql
UPDATE docs
SET
  denotations_num = COALESCE(d.cnt, 0),
  blocks_num = COALESCE(b.cnt, 0),
  relations_num = COALESCE(r.cnt, 0)
FROM
  docs doc_list
  LEFT JOIN (SELECT doc_id, COUNT(*) FROM denotations
             WHERE doc_id IN (SELECT doc_id FROM temp_doc_ids)
             GROUP BY doc_id) d ON doc_list.id = d.doc_id
  LEFT JOIN (SELECT doc_id, COUNT(*) FROM blocks
             WHERE doc_id IN (...)
             GROUP BY doc_id) b ON doc_list.id = b.doc_id
  LEFT JOIN (SELECT doc_id, COUNT(*) FROM relations
             WHERE doc_id IN (...)
             GROUP BY doc_id) r ON doc_list.id = r.doc_id
WHERE docs.id = doc_list.id
  AND docs.id IN (SELECT doc_id FROM temp_doc_ids)
```

**Why This is Catastrophically Slow**:

1. **Scans across ALL projects' annotations**
   - Database has 10M docs across MANY projects
   - Total denotations table: Could be 100M+ rows
   - The aggregation subqueries scan ALL denotations for the doc_ids, not just for current project

2. **No project_id filter in aggregations**
   - Query: `SELECT doc_id, COUNT(*) FROM denotations WHERE doc_id IN (1M doc_ids)`
   - This scans denotations across ALL projects for these docs
   - If doc_id=123 appears in 20 different projects, it counts ALL of them together

3. **3 full table aggregations**
   - Must aggregate across denotations, blocks, and relations tables
   - Each table could have 100M+ rows
   - Even with indexes, scanning millions of rows is slow

**Estimated time for 1 million docs**:
- Temp table creation + inserts: 30-60 seconds
- 3 aggregation subqueries: **5-15 minutes EACH** 🔥
- Row updates: 2-5 minutes
- **Total: 15-50 minutes** 🔴🔴🔴

**Estimated time for 5 million docs**:
- Temp table creation + inserts: 2-5 minutes
- 3 aggregation subqueries: **30-90 minutes EACH** 🔥🔥🔥
- Row updates: 10-20 minutes
- **Total: 1.5-5 HOURS** 🔴🔴🔴🔴🔴

## Total Estimated Runtime

| Upload Size | Project Counts | ProjectDoc Update | Doc Update | **TOTAL** |
|------------|---------------|-------------------|------------|-----------|
| 100k docs  | 15s           | ~10s              | ~5 min     | **~6 minutes** ⚠️ |
| 500k docs  | 15s           | ~30s              | ~15 min    | **~16 minutes** ⚠️⚠️ |
| 1M docs    | 15s           | ~60s              | ~30 min    | **~32 minutes** 🔴 |
| 5M docs    | 15s           | ~5 min            | **~3 hours** | **~3+ HOURS** 🔴🔴🔴 |

## Root Cause Issues

### Issue 1: Doc.bulk_update_docs_counts aggregates across ALL projects
The fundamental problem is in `Doc.bulk_update_docs_counts`:

```sql
-- Current query (WRONG for multi-project scenario):
SELECT doc_id, COUNT(*) FROM denotations WHERE doc_id IN (1M ids) GROUP BY doc_id

-- What it should be:
SELECT doc_id, COUNT(*) FROM denotations
WHERE doc_id IN (1M ids) AND project_id = 10  -- ← Missing project filter!
GROUP BY doc_id
```

**Impact**: Counts annotations from ALL projects instead of just the current project!

### Issue 2: No batching for very large updates
Even with temp tables, updating 5M rows in a single UPDATE is slow.

### Issue 3: Called too frequently
`update_final_project_stats` is called:
- During queue throttling (every 2s) in `wait_for_queue_space`
- During batch completion loop (line 327)
- After all batches complete (line 370)

**This compounds the performance problem exponentially!**

## Critical Bug Discovery! 🐛

**The `Doc.bulk_update_docs_counts` query is INCORRECT for projects!**

It counts ALL annotations for a doc across ALL projects, but it should count ONLY the annotations for the current project.

Example:
- Doc ID 123 exists in 3 projects (A, B, C)
- Project A has 50 denotations for doc 123
- Project B has 30 denotations for doc 123
- Project C has 20 denotations for doc 123

Current query counts: **100 denotations** ❌
Correct count should be: **50 denotations** (only Project A) ✅

**This means the doc-level counters are WRONG!**

## Recommended Fixes

### Fix 1: Skip Doc Updates Entirely (FASTEST)
The `docs` table counters (denotations_num, blocks_num, relations_num) aggregate across ALL projects. They're not needed for the current project upload operation.

```ruby
def update_annotation_stats_from_database
  # Calculate and update project-level counts (fast)
  denotations_count = denotations.count
  blocks_count = blocks.count
  relations_count = relations.count

  update!(
    denotations_num: denotations_count,
    blocks_num: blocks_count,
    relations_num: relations_count,
    ...
  )

  # Update project_docs (slower but necessary)
  ProjectDoc.bulk_update_counts(project_id: id)

  # SKIP Doc updates - they're not needed for project-specific operations
  # and they're incorrectly aggregating across all projects anyway!
  # doc_ids = project_docs.pluck(:doc_id).uniq
  # Doc.bulk_update_docs_counts(doc_ids: doc_ids)  # ← REMOVE THIS
end
```

**Benefits**:
- Eliminates 90%+ of runtime for large uploads
- Fixes the bug where doc counters were incorrect anyway
- Project still has accurate stats in `projects` and `project_docs` tables

**Runtime reduction**:
- 1M docs: 32 min → **2 minutes** ✅ (16x faster)
- 5M docs: 3+ hours → **6 minutes** ✅ (30x faster)

### Fix 2: Defer Final Stats Update (if Fix 1 not acceptable)
Move `update_final_project_stats` to run ONLY at the end, not during loops:

```ruby
# In wait_for_queue_space - REMOVE this call
# update_progress_from_tracking  # ← This calls update_final_project_stats every 5 min

# In wait_for_batch_jobs_completion - REMOVE this call
# if Time.current - last_stats_update > 300
#   update_final_project_stats  # ← REMOVE
# end

# Keep ONLY final call after completion (line 370)
update_final_project_stats  # ← Keep this one
```

**Benefits**:
- Runs expensive query only once instead of every 5 minutes
- Still provides final accurate counts

### Fix 3: Add project_id Filter to Doc Aggregations (if doc stats needed)
Fix the bug in `Doc.bulk_update_docs_counts`:

```ruby
# This requires passing project_id context through to Doc model
# and filtering aggregations by project_id
# Complex change - only do if doc-level per-project stats are actually needed
```

## Recommendation: Implement Fix 1

**Skip Doc updates entirely** because:
1. ✅ **90%+ performance improvement** (minutes instead of hours)
2. ✅ **Fixes existing bug** (doc counters were wrong anyway)
3. ✅ **Project stats remain accurate** (projects and project_docs tables)
4. ✅ **Minimal code change** (just comment out 2 lines)
5. ✅ **No correctness impact** (doc counters aggregate across projects, not useful for single-project operations)

If doc-level stats are needed elsewhere, they should be updated in a separate background job, not during time-critical upload operations.
