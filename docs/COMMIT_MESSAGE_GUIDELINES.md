# Commit Message Guidelines

Use Conventional Commit-style messages:

```text
<type>: <subject>

<optional body>
```

## Types

- `feat`: user-visible feature or capability
- `fix`: bug or correctness fix
- `docs`: documentation only
- `refactor`: behavior-preserving code restructuring
- `perf`: performance improvement
- `test`: test-only change
- `style`: formatting with no behavior change
- `build`: build system or dependency change
- `ci`: continuous-integration change
- `chore`: repository maintenance not covered above

## Rules

- Write commit messages in English.
- Keep the subject concise and describe one logical change.
- Use a body only when the motivation or important trade-offs are not clear from the subject.
- Do not use emoji.
- Do not add generated-by notices, AI attribution, or AI `Co-Authored-By` trailers.
- Build and run the relevant tests before committing.
- Never commit credentials, signing material, local diagnostics, system-state backups, or personal filesystem paths.

Examples:

```text
feat: implement read-only accessibility inventory
fix: limit MenuBarAgent traversal to presentation roots
docs: record phase A observations
```
