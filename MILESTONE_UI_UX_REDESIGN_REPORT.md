# SaloneMarket — Master UI/UX, Brand Identity & Interaction Redesign Report

**Project:** SaloneMarket  
**Date:** November 25, 2026  
**Status:** Design System, Brand Assets, Onboarding, Customer, Vendor & Admin Portals Updated & Verified  

---

## 1. Visual Identity & Design System (Phase 1)

### Colour System & Typography (`app/lib/core/theme/app_theme.dart`, `app/lib/core/theme/app_spacing.dart`)
- **Centralised Brand Tokens (`SaloneColors`):**
  - Primary forest green: `#123C35`
  - Secondary emerald green: `#0E8F6E`
  - Light cream: `#F5F2E9`
  - Warm gold accent: `#E7AD55`
  - Main text: `#202B28`
  - Secondary text: `#68756F`
  - White surface: `#FFFFFF`
  - Subtle background: `#F7F8F5`
  - Error: `#C94C4C`
  - Success: `#23845B`
- **Typography:**
  - `GoogleFonts.manrope` for headings, titles, and numerical KPIs.
  - `GoogleFonts.inter` for body copy, labels, and interface controls.
- **Themes:** Primary `SaloneMarketTheme.lightTheme` and `SaloneMarketTheme.darkTheme` wired in `app/lib/main.dart`.

### Scalable Logo & Android Launcher Assets
- **SVG Assets Created:**
  - `app/assets/icons/salone_logo_mark.svg`
  - `app/assets/icons/salone_logo_mark_mono.svg`
  - `app/assets/icons/salone_logo_mark_light.svg`
- **Flutter Vector Logo Widget:**
  - `app/lib/core/widgets/salone_logo.dart` (`SaloneLogo` supporting `full`, `compact`, `iconOnly`, `monochrome` variants and `lightBackground`/`darkBackground` tones).
- **Android Launcher & Splash Branding:**
  - Updated `app/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` with the Forest Green `#123C35` + Emerald `#0E8F6E` + Gold `#E7AD55` + Cream `#F5F2E9` SaloneMarket mark.
  - Updated `app/android/app/src/main/res/drawable/launch_background.xml` and `drawable-v21/launch_background.xml` to `#123C35` with centered launcher mark.

### Reusable Design System Components (`app/lib/core/widgets/`)
- `salone_buttons.dart`: `SalonePrimaryButton`, `SaloneSecondaryButton`, `SaloneGhostButton` (press-scale feedback, loading switcher, disabled states).
- `salone_text_field.dart`: `SaloneTextField`, `SaloneSearchBar` (focus states, password toggle, search trigger).
- `salone_cards.dart`: `SaloneCard`, `SaloneSectionHeader`, `SaloneMetricCard`, `SaloneStatusBadge`.
- `salone_states.dart`: `SaloneShimmerBox`, `SaloneProductGridSkeleton`, `SaloneListSkeleton`, `SaloneEmptyState`, `SaloneErrorState`, `SaloneToast`.
- `salone_motion.dart`: `SaloneMotion` (reduced-motion aware transitions, `SaloneFadeIn`, `SaloneMotion.buildPage`).

---

## 2. Splash, Onboarding & Authentication (Phases 2–3)

- **Splash Screen (`app/lib/features/auth/presentation/screens/splash_screen.dart`):**
  - Forest green `#123C35` animated logo reveal with `SharedPreferences` (`salone_onboarding_completed`) persistence check: routes authenticated users straight to `/home`, first-time users to `/onboarding`, and returning unauthenticated users to `/welcome`.
- **Onboarding (`app/lib/features/auth/presentation/screens/onboarding_screen.dart`):**
  - 3-slide horizontal `PageView` (**Discover**, **Shop with confidence**, **Grow with SaloneMarket**) with subtle `PageController` parallax, animated pagination dots, Skip/Next/Get Started controls, Sign In / Create Account actions, and reduced-motion support.
- **Welcome & Auth (`welcome_screen.dart`, `auth_button.dart`, `auth_header.dart`, `auth_text_field.dart`):**
  - Upgraded to `SaloneLogo`, `Manrope`/`Inter` typography, and `SalonePrimaryButton` / `SaloneSecondaryButton`.
- **Router (`app/lib/core/router/app_router.dart`):**
  - Added `/onboarding` and `/welcome` routes while preserving all existing auth, customer, vendor, and admin role guards.

---

## 3. Customer, Vendor & Admin Portals (Phases 3–6)

- **Customer Marketplace (`home_screen.dart`, `marketplace_app_bar.dart`, `product_card.dart`, `empty_state_view.dart`, `cart_screen.dart`, `profile_screen.dart`):**
  - Personalized greeting + delivery strip, `SaloneSearchBar`, `SaloneProductGridSkeleton` shimmer loading, `Hero` product image transitions, press-scale card feedback, animated cart badge, and Material 3 `NavigationBar`.
- **Vendor Portal (`vendor_dashboard_screen.dart`):**
  - Upgraded to `SaloneColors`, `Manrope`/`Inter` headings, `SaloneSectionHeader`, `kIsWeb`-safe `RefreshIndicator`, and fixed `Apply Now` / `Add Product` button contrast.
- **Admin Portal (`admin_dashboard_screen.dart`, `admin_vendors_screen.dart`, `admin_products_screen.dart`, `admin_orders_screen.dart`, `admin_transactions_screen.dart`, `admin_payouts_screen.dart`, `admin_users_screen.dart`, `admin_error_state.dart`):**
  - Upgraded dashboard metrics to `SaloneMetricCard` and `SaloneSectionHeader`, fixed `SaloneMarketTheme` infinite-width button layout crash across all `Row`s, wired `AdminUsersScreen`, added `AdminErrorState` with Retry buttons, and added 10s repository timeouts.

---

## 4. Verification & Build Results (Phase 7)

- **Static Analysis (`flutter analyze`):** 0 errors across the redesigned core theme, widgets, auth, marketplace, vendor, and admin files.
- **Unit & Widget Tests (`flutter test`):**
  - `admin_dashboard_render_test.dart`, `auth_notifier_test.dart`, `vendor_admin_portals_test.dart`, `customer_experience_and_cross_role_test.dart`: **All passed**.
  - `vendor_payouts_and_settlement_test.dart`: 10/11 passed (1 pre-existing financial calculation assertion failure unrelated to UI changes).
- **Android Debug APK:** Built via `flutter build apk --debug --dart-define-from-file=../supabase.dev.json` (`app/build/app/outputs/flutter-apk/app-debug.apk`).
