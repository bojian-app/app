-- Public-source review is mandatory before an enterprise benefit can be published.
-- Existing records are held for review; original private submissions stay owner-only.
ALTER TABLE company_benefits
 ADD COLUMN sources_jsonb jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(sources_jsonb)='object'),
 ADD COLUMN source_reviewed_at timestamptz,
 ADD COLUMN source_reviewed_by bigint REFERENCES admin_principals(id),
 ADD COLUMN source_review_note text NOT NULL DEFAULT '';

ALTER TABLE company_benefits DROP CONSTRAINT company_benefits_status_check;
ALTER TABLE company_benefits ALTER COLUMN status SET DEFAULT 'SOURCE_REVIEW';
ALTER TABLE company_benefits ADD CONSTRAINT company_benefits_status_check
 CHECK(status IN ('SOURCE_REVIEW','PUBLISHED','ARCHIVED'));

UPDATE company_benefits
 SET status='SOURCE_REVIEW',revision=revision+1,updated_at=now()
 WHERE status='PUBLISHED';

-- CHECK constraints cannot use subqueries; keep the coverage predicate immutable.
CREATE FUNCTION company_benefit_public_sources_complete(benefits jsonb, sources jsonb)
 RETURNS boolean LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
 SELECT jsonb_typeof(benefits)='object'
  AND jsonb_typeof(sources)='object'
  AND benefits <> '{}'::jsonb
  AND NOT EXISTS (
   SELECT 1 FROM jsonb_object_keys(benefits) AS benefit(key)
   WHERE NOT (sources ? benefit.key)
    OR jsonb_typeof(sources->benefit.key) <> 'object'
    OR jsonb_typeof(sources->benefit.key->'url') IS DISTINCT FROM 'string'
    OR jsonb_typeof(sources->benefit.key->'publisher') IS DISTINCT FROM 'string'
    OR btrim(sources->benefit.key->>'url')=''
    OR btrim(sources->benefit.key->>'publisher')=''
  )
  AND NOT EXISTS (
   SELECT 1 FROM jsonb_object_keys(sources) AS source(key)
   WHERE NOT (benefits ? source.key)
  );
$$;

ALTER TABLE company_benefits ADD CONSTRAINT company_benefits_public_source_review_check
 CHECK(status <> 'PUBLISHED' OR (
  source_reviewed_at IS NOT NULL
  AND source_reviewed_by IS NOT NULL
  AND btrim(source_review_note) <> ''
  AND official_note = ''
  AND company_benefit_public_sources_complete(benefits_jsonb,sources_jsonb)
 ));

ALTER TABLE company_benefit_submissions
 DROP CONSTRAINT company_benefit_submissions_employment_file_ids_check,
 DROP CONSTRAINT company_benefit_submissions_evidence_file_ids_check;
ALTER TABLE company_benefit_submissions
 ALTER COLUMN employment_file_ids SET DEFAULT '{}'::bigint[],
 ALTER COLUMN evidence_file_ids SET DEFAULT '{}'::bigint[],
 ADD CONSTRAINT company_benefit_submissions_employment_file_ids_check
  CHECK(cardinality(employment_file_ids) BETWEEN 0 AND 3),
 ADD CONSTRAINT company_benefit_submissions_evidence_file_ids_check
  CHECK(cardinality(evidence_file_ids) BETWEEN 0 AND 8);
