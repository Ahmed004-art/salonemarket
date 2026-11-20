## Summary
<!-- What does this PR do? Be specific. -->

## Type of Change
- [ ] Bug fix
- [ ] New feature / screen
- [ ] Database migration
- [ ] Edge Function change
- [ ] Documentation update
- [ ] FlutterFlow export integration
- [ ] Refactor / cleanup

## Related Issue
<!-- Link to GitHub issue: Closes #123 -->

## Testing Done
- [ ] Unit tests pass (`flutter test`)
- [ ] Widget tests pass
- [ ] Manual testing on device/emulator
- [ ] Tested with all three user roles (customer, vendor, admin)
- [ ] Integration tests (if applicable)

## FlutterFlow Export Checklist (if applicable)
- [ ] This PR includes a FlutterFlow export
- [ ] Export diff has been reviewed — custom code in `lib/custom_code/` and `lib/core/` is intact
- [ ] Design tokens match `docs/design_system.md`
- [ ] No service role key or credentials appear in generated code

## Security Checklist
- [ ] No credentials, API keys, or secrets in this diff
- [ ] `.env` is NOT committed
- [ ] RLS policies are correct for any new tables
- [ ] Service role key is NOT embedded in Dart code
- [ ] New Edge Functions authenticate the caller

## Database Migrations (if applicable)
- [ ] Migration file is versioned correctly (YYYYMMDDHHMMSS prefix)
- [ ] RLS enabled on new tables
- [ ] Down migration documented (or not applicable)
- [ ] Tested against local Supabase dev environment

## Screenshots
<!-- For UI changes: before/after screenshots. Required for screen-level changes. -->
