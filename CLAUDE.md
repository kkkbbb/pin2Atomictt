# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenHarmony (HarmonyOS) Atomic Service application using ArkUI framework with ETS (Extended TypeScript). The app is a native replica of the pin2eat H5 web app, integrating HUAWEI ID authentication and targeting API level 20 (SDK 6.0.0).

**Backend API:** `https://meal.pin2eat.com` (pin2eat ordering platform)

## Build Commands

```bash
# Set environment variable (required)
export DEVECO_SDK_HOME="/e/DevEco Studio/sdk"

# Build HAP/APP packages
node "/e/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleApp

# Clean build artifacts
node "/e/DevEco Studio/tools/hvigor/bin/hvigorw.js" clean

# List available tasks
node "/e/DevEco Studio/tools/hvigor/bin/hvigorw.js" tasks

# Stop hvigor daemon (if environment changed)
node "/e/DevEco Studio/tools/hvigor/bin/hvigorw.js" --stop-daemon
```

**Build Output:**
- HAP: `entry/build/default/outputs/default/entry-default-unsigned.hap`
- APP: `build/outputs/default/pin2Atomictt-default-unsigned.app`

**Note:** For signed builds, configure `signingConfigs` in `build-profile.json5`.

## Testing

```bash
# Run local unit tests (no device required)
hvigor testModule entry

# Run device/emulator tests
hvigor test --moduleName entry --testRunner
```

Test files:
- Local unit tests: `entry/src/test/`
- Device integration tests: `entry/src/ohosTest/`

Testing uses Hypium framework (`@ohos/hypium`) with standard `describe()`, `it()`, `expect()` patterns.

## Architecture

**Entry Point Flow:**
1. `EntryAbility.ets` - UIAbility managing app lifecycle, initializes global state
2. `pages/Index.ets` - Store home page with login and service selection
3. `pages/MenuPage.ets` - Product menu with categories and cart

**Key Directories:**
```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets       # App entry, init global state
├── models/
│   └── StoreModels.ets        # API data models (TypeScript interfaces)
├── services/
│   ├── ApiService.ets         # HTTP client for backend API
│   └── AppStorage.ets         # Global state (user, cart, preferences)
└── pages/
    ├── Index.ets              # Store home page
    └── MenuPage.ets           # Product menu page
```

**UI Pattern:** Declarative ArkUI components using decorators:
- `@Entry` - Page entry point
- `@Component` - UI component
- `@State` - Reactive state management
- `@Builder` - Reusable UI builders

**Key Kits:**
- `@kit.AccountKit` - HUAWEI ID authentication
- `@kit.NetworkKit` - HTTP requests
- `@kit.ArkData` - Local preferences storage
- `@kit.PerformanceAnalysisKit` - Logging via hilog
- `@kit.ArkUI` - Window management, router

## Backend API Integration

**Base URL:** `https://meal.pin2eat.com`

**Required Headers:**
```
Content-Type: application/json;charset=UTF-8
store-id: {store_id}
langcode: zh_HK | zh_CN
authorization: Bearer {token}  (after login)
```

**API Endpoints:**

| Endpoint | Method | Description | Implementation |
|----------|--------|-------------|----------------|
| `/api/v2/home` | POST | Store home data | `apiService.getHomeData()` |
| `/api/home/product-menus` | GET | Product menu | `apiService.getProductMenus()` |
| `/api/store/meal-member-plan` | GET | Member plans | `apiService.getMemberPlan()` |
| `/api/store/store-pops` | GET | Store popups | `apiService.getStorePops()` |
| `/api/order/list` | GET | User orders | `apiService.getOrders()` |
| `/api/coupon/list` | GET | User coupons | `apiService.getCoupons()` |

**Configuration:**
- Default store ID: `1551` (configurable in `ApiConfig.DEFAULT_STORE_ID`)
- Default language: `zh_HK`

## State Management

**AppStateManager** (`services/AppStorage.ets`) handles:
- User login state and token persistence
- Shopping cart (persisted to preferences)
- Store configuration

**Usage:**
```typescript
import { appState } from '../services/AppStorage';

// Check login
if (appState.isLoggedIn) { ... }

// Add to cart
await appState.addToCart(product, quantity);

// Get cart total
const total = appState.cartTotal;
```

## Permissions

Required permissions in `module.json5`:
- `ohos.permission.INTERNET` - Network access
- `ohos.permission.GET_NETWORK_INFO` - Network state

## Code Quality

Linting configured in `code-linter.json5` with security-focused rules for cryptographic operations. Release builds use code obfuscation (see `obfuscation-rules.txt`).

## Color Theme

Theme colors defined in `resources/base/element/color.json`:
- `primary_yellow`: #FFD700 (brand color, buttons)
- `page_background`: #F5F5F5
- `card_background`: #FFFFFF
- `text_primary`: #333333
- `text_secondary`: #666666
- `text_hint`: #999999
