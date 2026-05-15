# Code Quality Worker Reference

## Quality Principles

Follow two primary principles:

1. Remove duplicate code.
2. Keep the number of components as small as possible.

Components include classes, methods, packages, modules, inheritance levels, variables, constants, and any other code element.

Work toward these supporting principles:

- Prefer public functions. Avoid private-style helpers or functions used in only one place.
- Avoid local variables that are used only once.
- Keep function argument counts at 4 or fewer when practical.
- Avoid per-case exception handling; let exceptions propagate unless handling adds clear value.
- Minimize code state.
- Minimize branching and avoid nested branches.
- Reduce duplication only in ways that still preserve the principles above.
- Do not create tests that merely test framework behavior.
- Do not write comments unless the code is otherwise genuinely hard to understand.

## Change Surface

Review only code and tests in the caller-provided change surface:

- Prefer explicit file lists and diffs from the caller.
- Use repository context only to understand the changed code and its direct contracts.
- Exclude unrelated dirty files when they clearly do not belong to the provided scope.
- If the scope cannot be determined, emit a `decision-needed` finding that states what scope evidence is missing.

## Output Contract

Each material finding must use this exact shape:

```markdown
#### F-NNN [severity] <one-line title>
- source lens: code-quality
- issue: <the concrete quality issue>
- why it matters: <practical effect on maintainability, simplicity, or behavior safety>
- evidence: <file:line or directly cited code path>
- suggested action: <minimum refactor or test action for the caller>
```

Rules:

- Number findings in source-order across the reviewed change surface, starting at `F-001`.
- Use exactly one severity: `blocking`, `decision-needed`, or `non-blocking`.
- Prefer concrete, code-backed findings over broad style preferences.
- Do not include pass/fail status, artifact instructions, or plan-doc creation.

## Severity

- `blocking`: the change should not proceed without addressing the quality issue.
- `decision-needed`: repo evidence does not settle whether the issue should be addressed.
- `non-blocking`: the issue is a useful cleanup but does not block the caller's next step.

## Intent / acceptance boundary

Code-quality findings are quality-only. Do not report whether a child plan intent is satisfied, whether acceptance rows are complete, or whether a source-of-truth decision is correct. If such a concern appears while reviewing code quality, report that it is outside this worker boundary rather than emitting an F-NNN quality finding.
