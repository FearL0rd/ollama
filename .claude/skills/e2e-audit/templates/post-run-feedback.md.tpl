# Post-run feedback — {{SESSION_ID}}

Duration: **{{DURATION_S}}s** · Tests: **{{TESTS_PASSED}}/{{TESTS_TOTAL}}** passed · **{{TESTS_FLAKY}}** flaky · **{{TESTS_FAILED}}** failed

## Verdict

{{VERDICT}}

## Top problems

{{#each problems}}
- **[{{severity}}] {{kind}}** — {{where}} (count: {{count}})
{{#if sample_trace}}
  - Trace: `{{sample_trace}}`
{{/if}}
{{#if sample_log_tail}}
  - Log tail:
    ```
    {{sample_log_tail}}
    ```
{{/if}}
{{#if sample}}
  - Sample: `{{sample}}`
{{/if}}
{{/each}}

## Coverage still uncovered after this run

- Routes: **{{UNCOVERED.routes}}**
- HTTP handlers: **{{UNCOVERED.http}}**
- tRPC procedures: **{{UNCOVERED.trpc}}**
- Server actions: **{{UNCOVERED.actions}}**

## Suggested next actions

{{NEXT_ACTIONS}}
