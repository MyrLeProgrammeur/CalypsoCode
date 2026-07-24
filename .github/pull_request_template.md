<!--
This checklist is not ceremony. Every line is a rule already written in
CONTRIBUTING.md or docs/THREAT-MODEL.md — the template just puts them where
they get read. Delete what does not apply.
-->

## What changed, and why

<!-- What a reader needs to understand the diff. The reasoning matters more
     than the summary; the diff already says what moved. -->

## What was measured

<!-- The project's standard is evidence or nothing. If this PR makes a claim
     about behaviour — it is faster, it is isolated, the provider accepts it —
     say how that was observed. "Not measured" is a valid and useful answer. -->

## Checklist

- [ ] `./test/run.sh` passes
- [ ] `shellcheck bin/calypsocode` and `shellcheck -x test/*.sh` are clean
- [ ] No secret in the diff or in any new file (`gitleaks detect --source .`)
- [ ] New behaviour has a test, and I checked the test **fails** without the fix

### If this touches what the tool does or does not protect

- [ ] `docs/THREAT-MODEL.md` updated in this PR — it must stay honest, not promotional
- [ ] `docs/DESIGN.md` signal table still matches reality
- [ ] The receipt still states what was **not** removed

### If this adds anything to `docs/FINDINGS.md`

- [ ] Every claim was **measured**, with the evidence shown
- [ ] Anything untested is marked untested — inferences belong in `DESIGN.md`

### Scope

- [ ] No content rewriting of prompts, code, or tool calls
- [ ] No filesystem mounts or path remapping
- [ ] No new runtime dependency (or it was discussed first)

<!-- Out-of-scope items and the reasons they were rejected are recorded in
     docs/ROADMAP.md#decisions-taken. If this PR needs one of them, open an
     issue instead — that is not a decision to make inside a code review. -->
