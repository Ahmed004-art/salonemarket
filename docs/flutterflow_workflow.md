# SaloneMarket ↔ GitHub Integration Guide

## 1. Overview

This guide explains how the **FlutterFlow** visual development environment syncs with the project's **GitHub** repository. The workflow guarantees that:
- FlutterFlow‑generated UI code lives on the `flutterflow/export` branch.
- The reviewed, production‑ready source lives on `main`.
- Custom Dart code (`lib/custom_code/**` and `lib/core/**`) is never overwritten by FlutterFlow.
- Every sync creates a Pull Request (PR) that must be reviewed before merging into `main`.

---

## 2. Branch Strategy

| Branch | Owner | Purpose |
|---|---|---|
| `main` | Developers | Production‑ready source of truth. Contains reviewed code, custom logic, and the final app ready for CI/CD. |
| `flutterflow/export` | FlutterFlow | Raw output from FlutterFlow exports. **Never edit manually**; it is regenerated on each sync. |
| `feature/*` | Developers | Feature work branched from `main`. |

> **Why never merge `flutterflow/export` directly into `main`?**
> FlutterFlow regenerates all files under `lib/` on each export, which would overwrite any custom code placed there. All merges must go through a PR where the diff is inspected.

---

## 3. Setting Up FlutterFlow ↔ GitHub Sync

1. **Create the GitHub repo** if it does not exist and push an initial commit of the project (including `main` branch).
2. In FlutterFlow open **Project Settings → GitHub**.
3. Connect your GitHub account and select the repository.
4. Set the **Target branch** to `flutterflow/export`.
5. **Add a Deploy key** (read/write) on GitHub – FlutterFlow will provide the public key. Store the private key **only** on the FlutterFlow side; never commit it.
6. Click **Enable Sync**.
7. After the first sync, FlutterFlow will push all generated files to `flutterflow/export`.

---

## 4. Custom Code Contract

| Directory | Contents | Preservation Rule |
|---|---|---|
| `lib/custom_code/actions/` | Custom Dart actions callable from FlutterFlow flow (e.g., API calls, payment logic). | **Never overwritten** – FlutterFlow only adds stubs if a new action is declared. |
| `lib/custom_code/widgets/` | Custom widgets used inside FlutterFlow screens. | **Never overwritten** – same rule as actions. |
| `lib/core/` | Shared utilities, theme definitions (`app_theme.dart`), service classes (`auth_service.dart`, `supabase_client.dart`). | **Never overwritten** – FlutterFlow does not touch this folder. |
| `lib/` (other) | Generated UI code (`screens/`, `widgets/`). | Regenerated on each export; changes must be made via FlutterFlow UI.

> **Do not place business logic or design tokens inside generated files.**

---

## 5. Design System in FlutterFlow

1. Open **FlutterFlow → Theme**.
2. Define colour tokens matching `docs/design_system.md` (e.g., `primary = #1A1A2E`).
3. Set the **Font families**:
   - Heading / Display → **Plus Jakarta Sans**
   - Body → **DM Sans**
   - Price hero → **Lora** (must be approved – see sign‑off list).
4. Configure **Spacing** and **Border radii** to match the 8‑pt grid and radii tokens.
5. Save the theme; FlutterFlow will embed the values into generated Dart theme files located in `lib/`.

When the theme diverges from the source‐of‑truth (`app_theme.dart` in `lib/core/`), **run a manual diff review** before merging the PR.

---

## 6. Reviewing an FF Export PR

When FlutterFlow pushes a new commit to `flutterflow/export`, GitHub automatically opens a PR.

**Checklist** for reviewers:
- ✅ All generated files are under `lib/` and follow the expected naming convention.
- ✅ No changes to files inside `lib/custom_code/` or `lib/core/`.
- ✅ Colour tokens and font families match the design system.
- ✅ No accidental removal of custom code imports.
- ✅ Build passes locally: `flutter pub get && flutter build apk` (CI will run this).

If any **suspicious diffs** appear (e.g., modified `lib/core/app_theme.dart`), **reject the PR** and ask the developer to fix the source of truth.

---

## 7. Conflict Resolution Procedure

1. **Identify the conflict** – GitHub will show merge conflicts when the PR is opened.
2. **Pull the `flutterflow/export` branch locally**:
   ```bash
   git checkout flutterflow/export
   git pull origin flutterflow/export
   ```
3. **Create a temporary branch** to resolve:
   ```bash
   git checkout -b resolve-ff-conflict
   ```
4. Resolve the conflict **only in generated files**. Do **not** edit files under `lib/custom_code/` or `lib/core/`.
5. Commit the resolution and push:
   ```bash
   git add .
   git commit -m "Resolve FlutterFlow export conflict – generated files only"
   git push origin resolve-ff-conflict
   ```
6. Update the PR to point at the `resolve-ff-conflict` branch and request a review.

---

## 8. CI/CD Integration (GitHub Actions)

The repo includes a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs on every PR:
- **Step 1:** Flutter SDK install (version ≥ 3.19).
- **Step 2:** `flutter pub get`.
- **Step 3:** `flutter test` (unit & widget tests).
- **Step 4:** `flutter build apk --debug` (quick build to ensure no compile errors).
- **Step 5:** Lint with `flutter analyze`.

Only when **all checks pass** may the PR be merged into `main`.

---

## 9. Summary

- FlutterFlow ↔ GitHub sync is a **one‑way push** from FlutterFlow to `flutterflow/export`.
- All custom code lives outside generated directories and is protected by RLS and PR review.
- The design system defined in `docs/design_system.md` must be mirrored in FlutterFlow Theme.
- Follow the conflict‑resolution steps to keep the `main` branch clean.

For any questions, open an issue in the repository or contact the project lead.
