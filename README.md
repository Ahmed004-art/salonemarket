# SaloneMarket

> Open-source mobile commerce platform connecting customers with local vendors in Sierra Leone.

[![Flutter CI](https://github.com/Ahmed004-art/salonemarket/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/Ahmed004-art/salonemarket/actions/workflows/flutter_ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## About

SaloneMarket is a multi-vendor mobile commerce application built for Sierra Leone's growing digital economy. It connects customers with local vendors, supports product discovery and purchase, and provides vendors with tools to manage their shop, products and orders.

**University project — FlutterFlow + Supabase mandated stack.**

---

## Features

### For Customers
- Browse products by category, search, and filter
- Multi-vendor cart (buy from multiple shops in one order)
- Simulated checkout and payment flow [*]
- Order tracking and digital receipts
- Product reviews and ratings
- Wishlist

### For Vendors
- Shop management and profile
- Product catalogue with inventory tracking
- Order management and fulfilment status
- Basic sales analytics

### For Administrators
- User and vendor management
- Vendor approval workflow
- Product moderation
- Platform configuration

[*] _Payment is simulated. No real money is transferred. This is an academic project._

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile UI | FlutterFlow (export) + Flutter/Dart |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime) |
| Server Logic | Supabase Edge Functions (Deno/TypeScript) |
| State Management | Provider + Supabase streams |
| Navigation | go_router |
| Version Control | GitHub |
| CI/CD | GitHub Actions |

---

## Project Structure

```
salonemarket/
├── .github/
│   ├── workflows/
│   │   ├── flutter_ci.yml          # Lint, test, coverage on every push/PR
│   │   └── supabase_validate.yml   # SQL migration validation on PR
│   └── PULL_REQUEST_TEMPLATE.md
├── app/                            # Flutter application (FlutterFlow export target)
│   ├── lib/
│   │   ├── core/                   # Custom code preserved across FF exports
│   │   ├── custom_code/            # FlutterFlow custom actions & widgets
│   │   └── main.dart
│   ├── test/                       # Unit & widget tests
│   ├── pubspec.yaml
│   └── .gitignore
├── supabase/
│   ├── migrations/                 # Versioned SQL migrations (YYYYMMDDHHMMSS_name.sql)
│   ├── functions/                  # Edge Functions (Deno/TypeScript)
│   └── config.toml
├── docs/
│   ├── architecture.md
│   ├── database_schema.md
│   ├── design_system.md
│   ├── animation_spec.md
│   ├── flutterflow_workflow.md
│   └── security.md
├── .env.example                    # Environment variable template (safe to commit)
├── .gitignore
└── README.md
```

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.19.0 ([install](https://docs.flutter.dev/get-started/install))
- Supabase CLI ([install](https://supabase.com/docs/guides/cli))
- Git
- FlutterFlow account (for UI development)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ahmed004-art/salonemarket.git
   cd salonemarket
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env and fill in your Supabase project URL and anon key
   ```

3. **Create a Supabase project**
   - Go to [supabase.com](https://supabase.com) and create a new project
   - Copy your Project URL and anon key into `.env`

4. **Run database migrations**
   ```bash
   supabase db push
   ```

5. **Install Flutter dependencies**
   ```bash
   cd app
   flutter pub get
   ```

6. **Run the app**
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=<your-url> \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
   ```

### Running Tests
```bash
cd app
flutter test
```

---

## CI/CD

| Workflow | Trigger | What it does |
|---|---|---|
| `flutter_ci.yml` | Push / PR to `main` | `flutter analyze`, `flutter test --coverage`, upload to Codecov |
| `supabase_validate.yml` | PR touching `supabase/migrations/**` or `supabase/functions/**` | Runs `supabase db lint` to validate SQL syntax |

### Required GitHub Secrets

Configure these in **GitHub repo → Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | Personal access token from [app.supabase.com/account/tokens](https://app.supabase.com/account/tokens) |
| `SUPABASE_DB_PASSWORD` | Your Supabase project's database password |

---

## Documentation
- [Architecture](docs/architecture.md)
- [Database Schema](docs/database_schema.md)
- [Design System](docs/design_system.md)
- [Animation Spec](docs/animation_spec.md)
- [FlutterFlow Workflow](docs/flutterflow_workflow.md)
- [Security](docs/security.md)

---

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md). All PRs require review. See [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md).

---

## License
MIT — see [LICENSE](LICENSE).

---

## Disclaimer
SaloneMarket is an academic project. Payment processing is simulated. No real financial transactions occur.
