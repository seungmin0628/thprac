---
name: thprac-personal-pr
description: Create or update pull requests for personal thprac changes, exclusively in seungmin0628/thprac. Use when drafting PR titles or bodies, creating a PR, or changing an existing PR; never use it to target an upstream thprac repository.
---

# thprac personal pull requests

The only allowed pull-request repository is exactly `seungmin0628/thprac` on GitHub. This identity is the safety boundary; remote names such as `origin` and `upstream` are not evidence of ownership.

## Hard boundary

- Never create, edit, reopen, close, comment on, label, merge, or otherwise mutate a pull request in any repository other than `seungmin0628/thprac`.
- Do not redirect a request to an upstream repository even when its remote is configured locally, GitHub suggests it as the base, or the branch originated there.
- If a requested or discovered PR resolves to any other `nameWithOwner`, stop before mutation and report that this repository-local skill prohibits upstream PR work. Do not reinterpret an upstream request as permission.
- Do not prepare submission text that conceals LLM use or is intended to bypass an upstream contribution policy.

The repository's `.githooks/pre-push` independently restricts pushes to the personal repository. Do not bypass it with `--no-verify`, replace its configured hook path, or create a fork to evade this boundary.

## Verify the target

Before every GitHub mutation, resolve the repository explicitly with `gh repo view seungmin0628/thprac --json nameWithOwner,url,defaultBranchRef` and require `nameWithOwner` to equal `seungmin0628/thprac` exactly.

For an existing PR, inspect it with an explicit repository selector, for example:

```powershell
gh pr view <number-or-url> --repo seungmin0628/thprac --json number,url,title,body,state,baseRefName,headRefName,headRepositoryOwner
```

Require the returned PR URL to belong to `https://github.com/seungmin0628/thprac/`. If the user supplies a URL for any other repository, refuse the mutation. Do not rely on the current directory or GitHub CLI defaults.

For creation and updates, pass `--repo seungmin0628/thprac` to every `gh pr` command. For a new PR, also pass an explicit base branch and an explicit head in the personal repository, such as `--head seungmin0628:<branch>`. Re-read the PR after mutation and verify its repository, title, body, base, and head.

## Draft from repository evidence

Inspect `AGENTS.md`, the current branch, status, diff, commits relative to the selected base, and relevant verification results before writing the title or body. Preserve unrelated user changes and do not commit, push, or publish merely because drafting was requested. Obtain whatever authorization is normally required immediately before an external mutation.

Use a concise Conventional Commit-style PR title when it fits the change, such as `feat(th18): ...` or `fix(launcher): ...`. The body should accurately cover:

- the behavior and motivation;
- affected games, versions, and code areas;
- whether the feature is intentionally personal-only;
- competitive-integrity and replay implications, including any visible marker or forced desynchronization when relevant;
- verification performed, with exact build/runtime scenarios and honest `PASS`, `FAIL`, or `NOT TESTED` results;
- screenshots for UI changes when available.

Do not claim tests, gameplay checks, or compatibility that were not demonstrated. Update only the requested PR fields and preserve unrelated body content when editing an existing PR unless the user asks for a rewrite.
