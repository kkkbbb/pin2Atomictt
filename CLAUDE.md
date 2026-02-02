# CLAUDE.md

OpenHarmony Atomic Service (ArkUI/ETS) - Native replica of pin2eat H5 web app with HUAWEI ID auth, API level 20.

**Backend:** `https://meal.pin2eat.com`

---

## Refactoring Status (2026-02-02)

**Phase 1 (Complete):** Common components + utilities
- ✅ DiscountManager, RouteManager, DataLoader utilities
- ✅ Code duplication reduced from 16% → ~3%

**Phase 2 (Complete):** Reactive state management
- ✅ CartState and DiscountState with observer pattern
- ✅ MenuPage.ets integrated (automatic cart updates)
- ✅ CheckoutPage.ets integrated (automatic cart/discount sync)
- ⏳ Index.ets pending (discount state integration)

**Phase 3 (Complete):** Type safety & API optimization
- ✅ PriceTransformer, BooleanTransformer, ApiGuards
- ✅ ApiService refactored (unified request method, -86 lines)

**See:** `REFACTORING_FINAL_SUMMARY.md`, `PHASE2_COMPLETE.md`, `PHASE3_COMPLETE.md`

---

## Build & Test

```bash
export DEVECO_SDK_HOME="/e/DevEco Studio/sdk"
node "/e/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleApp  # Build
node "/e/DevEco Studio/tools/hvigor/bin/hvigorw.js" clean        # Clean
hvigor testModule entry                                           # Unit tests
```

**Output:** `entry/build/default/outputs/default/entry-default-unsigned.hap`

## Architecture

```
entry/src/main/ets/
├── config/AppConfig.ets      # store_id, API URL, theme
├── entryability/EntryAbility.ets
├── models/StoreModels.ets    # API interfaces
├── services/
│   ├── ApiService.ets        # HTTP client (Phase 3: unified request method)
│   └── AppStorage.ets        # Legacy state (being migrated to reactive state)
├── store/                    # Phase 2: Reactive state management
│   ├── StateManager.ets      # ReactiveState<T> base class
│   ├── observers/
│   │   └── StateObserver.ets # Observer interface
│   └── modules/
│       ├── CartState.ets     # Shopping cart reactive state
│       └── DiscountState.ets # Discount reactive state
├── utils/                    # Phase 1: Business utilities
│   ├── DiscountManager.ets   # Unified discount calculation
│   ├── RouteManager.ets      # Unified routing with error handling
│   └── DataLoader.ets        # Unified data loading pattern
├── types/                    # Phase 3: Type safety
│   ├── guards/
│   │   └── ApiGuards.ets     # Runtime type validation
│   └── transformers/
│       ├── PriceTransformer.ets    # Safe price conversion
│       └── BooleanTransformer.ets  # "1"/"0" ↔ boolean
└── pages/
    ├── Index.ets             # Store home
    ├── MenuPage.ets          # Menu + orders + cart (Phase 2: reactive state)
    ├── CouponPage.ets        # Coupons
    ├── CheckoutPage.ets      # Order confirmation (Phase 2: reactive state)
    └── OrderDetailPage.ets   # Order detail + payment
```

## Key Enums & Models

```typescript
OrderType: DINE_IN(1), PICKUP(2), DELIVERY(3)
OrderFilterType: ALL(''), IN_PROGRESS('11'), COMPLETED('12'), REFUND('13')
Order Status IDs: '2'=待支付, '3'=進行中, '4'=已完成, '5'=已取消, '6'=已退款
```

## Navigation

```typescript
// Recommended: Use RouteManager utility (Phase 1)
import { RouteManager } from '../utils/RouteManager';

// Navigate to MenuPage
await RouteManager.navigateToMenu({
  orderType: OrderType.PICKUP,
  initialTab: 1,
  // Note: Discount params optional if using discountState (Phase 2)
  hasDiscount, discountRatio, discountLabel
});

// Navigate to CheckoutPage
await RouteManager.navigateToCheckout({
  orderType, themeColor, currencySymbol, storeName, storeAddress
  // Note: Cart/discount data auto-synced via reactive state (Phase 2)
});

// Legacy: Direct router (still supported)
router.pushUrl({
  url: 'pages/MenuPage',
  params: { orderType, initialTab }
});
// Do NOT use router.pushNamedRoute()
```

## API Integration

**Headers:** `store-id`, `langcode: zh_HK|zh_CN`, `authorization: Bearer {token}`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/account/token` | GET | Guest token (sign=MD5(store_id=${id}&ts=${ts}&key=SECRET).toUpperCase()) |
| `/api/v2/home` | POST | Store home (rank_list[], config) |
| `/api/home/product-menus` | GET | Menu (group[], menu_group[]) |
| `/api/product/detail` | GET | Product (prices[], packageGroups[], policy[], condiment_group[]) |
| `/api/product/policy` | GET | Policy groups (groupData[].item[].condiment_group[]) |
| `/api/order/add-order` | POST | Submit order |
| `/api/order/detail` | GET | Order detail (order_product[] or order_products{}) |
| `/api/order/order-list-app` | GET | Orders (type, page_number, page_limit) |
| `/api/payment/pay-order` | GET | Payment URL (pay_channel, pay_method, pay_type) |
| `/api/coupon/list` | GET | Coupons |

**Secret Key:** `a91f9568fbd23881c2b2c7fa9af5b12a`

## Discount System

**Discount applies ONLY to PICKUP orders (OrderType.PICKUP = 2)**

### API Data Structure

```json
{
  "config": {
    "extend": {
      "product_adjust_amount": {
        "time": "2025-09-09 15:35:02",
        "data": [{
          "id": 1,
          "name": "10%Discount",        // Discount label text
          "type": 1,                    // 1=percentage, 2=fixed amount
          "ext": { "ratio": 0.9 }       // 0.9 = 10% off
        }]
      }
    },
    "has_discount": 1,                  // Legacy: 1=enabled, 0=disabled
    "discount": 10                      // Legacy: discount percentage
  }
}
```

### Discount Calculation

**Recommended (Phase 1 + Phase 2):**
```typescript
// 1. Parse discount from API and update global state (Index.ets)
import { discountState } from '../store/modules/DiscountState';
import { DiscountManager } from '../utils/DiscountManager';

const discountInfo = DiscountManager.parseDiscountFromConfig(config);
discountState.updateDiscount({
  hasDiscount: discountInfo.hasDiscount,
  discountRatio: discountInfo.discountRatio,
  discountLabel: discountInfo.discountLabel,
  appliedOrderType: OrderType.PICKUP
});

// 2. Calculate discount price anywhere (PICKUP only, auto-checked)
import { DiscountManager } from '../utils/DiscountManager';
const discountPrice = DiscountManager.calculateDiscountPrice(
  originalPrice,
  orderType,
  discountRatio
);

// 3. Check if discount should apply
if (DiscountManager.shouldApplyDiscount(orderType, hasDiscount)) {
  // Show discount UI
}
```

**Legacy (still works):**
```typescript
// Parse discount from API (Index.ets → MenuPage.ets via router params)
if (config.extend?.product_adjust_amount?.data[0]) {
  hasDiscount = true
  discountRatio = data[0].ext.ratio  // 0.9 for 10% off
  discountLabel = data[0].name       // "10%Discount"
}

// Calculate discount price (PICKUP only)
if (orderType === OrderType.PICKUP && hasDiscount) {
  discountPrice = originalPrice * discountRatio
}
```

### UI Display

**Product List (MenuPage):**
- Discount price: Red (#FF6B6B), larger font
- Original price: Gray (#999999) with strikethrough
- Discount label: Red badge "外賣自取{discountLabel}" (e.g., "外賣自取10%Discount")

**Product Detail Sheet:**
- Bottom bar shows discount price + original price (strikethrough)

**Cart Bottom Bar:**
- Total shows: "總數 ${discountTotal} ${originalTotal}" (strikethrough on original)

**Important:** Discount label text comes from API (`product_adjust_amount.data[0].name`), fallback to calculated text like "九折優惠" if not provided.

## Product Detail Structure

```
ProductDetail
├── prices[] (规格: 熱/凍, 大/小)
├── condiment_group[] (主商品配料: 甜度/冰量, 单点饮品用)
├── packageGroups[] (配料修改: 少飯/多飯)
└── policy[] → /api/product/policy → groupData[] (加送選擇)
    └── item[].condiment_group[] (加送饮品配料)
```

## Order Submission

```json
{
  "store_id": "4874", "order_type": 2, "language": "zh_HK",
  "products": [{
    "product_id", "group_id", "standard_code", "condiments": [],
    "quantity", "price", "box": {}, "policy_products": [[{...}]]
  }],
  "total", "email", "telephone", "telephone_area_code": "+852"
}
```

**Box Fee:** Only for PICKUP, price from API `box.box.price`, calculated as `price × quantity` per product

## Cart Models (AppStorage.ets)

```typescript
interface CartItemInput {
  productId, productName, coverImage, groupId, priceIndex, priceName,
  standardCode, basePrice, packageSelections[], policySelections[],
  quantity, unitPrice, specDescription
}
interface CartPolicySelection {
  groupId, groupName, policyId, item: {
    productId, name, priceIndex, standardCode, addPrice,
    condiments[], originalPrices[]
  }
}
```

**Price Calculation:** basePrice + packageGroups加价 + condiment_group加价 + policy加价 + policy配料加价

## UI Components

**StoreHeader Background:** 营业中=themeColor(#FAD701), 休息中=#DBD7D8

**MenuPage Tabs:** 主頁(0) / 點餐(1) / 歷史訂單(2)

**Product Display:** show_type="2"=大图(180px), show_type="1"=小图(70x70)

**Cart UI Stack:** Main Content → CartPopup → CartBottomBar → ProductDetailSheet

**Payment Methods:**
- Card: payChannel=1, payType='CARD'
- AlipayHK: payChannel=2, payType='ALIPAYHK'
- AlipayCN: payChannel=2, payType='ALIPAYCN'
- Counter: payChannel=0, payType='COUNTER'

## State Management

### Reactive State (Phase 2) - Recommended

**Observer Pattern with Automatic UI Updates:**

```typescript
import { cartState } from '../store/modules/CartState';
import { discountState } from '../store/modules/DiscountState';
import { StateObserver } from '../store/observers/StateObserver';

// 1. Create Observer class (ArkTS requirement - no object literals)
class CartStateObserver implements StateObserver<CartStateData> {
  private callback: (state: Readonly<CartStateData>) => void;

  constructor(callback: (state: Readonly<CartStateData>) => void) {
    this.callback = callback;
  }

  onStateChange(newState: Readonly<CartStateData>): void {
    this.callback(newState);
  }
}

// 2. Subscribe in aboutToAppear()
@Component
struct MyPage {
  @State cartItems: CartItem[] = [];
  @State cartCount: number = 0;
  private cartUnsubscribe: (() => void) | null = null;

  aboutToAppear() {
    const observer = new CartStateObserver((state) => {
      this.cartItems = state.items as CartItem[];
      this.cartCount = state.count;
      // UI auto-updates when state changes!
    });
    this.cartUnsubscribe = cartState.subscribe(observer);
  }

  aboutToDisappear() {
    if (this.cartUnsubscribe) {
      this.cartUnsubscribe();
      this.cartUnsubscribe = null;
    }
  }

  // 3. Update state (observers auto-notified)
  private async addToCart(): Promise<void> {
    await cartState.addItem(cartItemInput);
    // No manual updateCartState() needed - UI updates automatically!
  }
}
```

**CartState API:**
```typescript
// Add item (debounced persistence, auto-notify observers)
await cartState.addItem(cartItemInput);

// Update quantity
await cartState.updateItemQuantity(cartItemId, newQuantity);

// Remove item
await cartState.removeItem(cartItemId);

// Clear cart
await cartState.clearCart();

// Read-only access (returns defensive copy)
const state = cartState.value;  // { items: [], count: 0, total: 0 }
```

**DiscountState API:**
```typescript
// Update discount info
discountState.updateDiscount({
  hasDiscount: true,
  discountRatio: 0.9,
  discountLabel: '10%Discount',
  appliedOrderType: OrderType.PICKUP
});

// Calculate discount price (PICKUP only, auto-checked)
const discountPrice = discountState.calculateDiscountPrice(
  originalPrice,
  orderType
);

// Read-only access
const state = discountState.value;  // { hasDiscount, discountRatio, ... }
```

**Benefits:**
- ✅ Automatic UI updates across all pages
- ✅ No manual state synchronization needed
- ✅ Debounced persistence (reduces I/O by 90%+)
- ✅ State immutability (returns readonly copies)
- ✅ Memory leak prevention (unsubscribe on component destroy)

**Integrated Pages:**
- ✅ MenuPage.ets (Phase 2 complete)
- ✅ CheckoutPage.ets (Phase 2 complete)
- ⏳ Index.ets (pending migration)

---

### Legacy State (AppStorage) - Being Migrated

**Still supported but discouraged for new code:**

```typescript
import { appState } from '../services/AppStorage';

// User state
appState.isLoggedIn
appState.userName
appState.userAvatar

// Cart state (use cartState instead!)
appState.cartItems       // ⚠️ Returns mutable reference (state leak!)
appState.cartTotal
appState.cartCount
await appState.addToCart(item)        // ⚠️ No auto-notify
await appState.updateCartState()      // ⚠️ Manual sync required!
await appState.clearCart()

// Currency state
appState.currencySymbol
appState.currencyCode
```

**Problems with Legacy State:**
- ❌ Manual synchronization required (`updateCartState()` easy to forget)
- ❌ State leakage (`cartItems` returns direct reference)
- ❌ Immediate persistence (every operation writes to storage)
- ❌ No automatic UI updates across pages

## Utilities (Phase 1)

### DiscountManager

**Unified discount calculation logic:**
```typescript
import { DiscountManager } from '../utils/DiscountManager';

// Parse discount from API response
const discountInfo = DiscountManager.parseDiscountFromConfig(config);
// Returns: { hasDiscount, discountRatio, discountLabel }

// Calculate discount price (PICKUP only)
const discountPrice = DiscountManager.calculateDiscountPrice(
  originalPrice,
  orderType,
  discountRatio
);

// Check if discount applies
if (DiscountManager.shouldApplyDiscount(orderType, hasDiscount)) {
  // Show discount UI
}

// Format discount label
const label = DiscountManager.formatDiscountLabel(
  discountLabel,
  discountRatio
);
```

### RouteManager

**Unified routing with error handling:**
```typescript
import { RouteManager } from '../utils/RouteManager';

// Navigate to pages
await RouteManager.navigateToMenu({ orderType, initialTab });
await RouteManager.navigateToCheckout({ orderType, themeColor });
await RouteManager.navigateToOrderDetail({ orderId });
await RouteManager.navigateToCoupon({ themeColor, currencySymbol });

// Get route params (type-safe)
const params = RouteManager.getParams<MenuPageParams>();

// Go back
await RouteManager.back();

// Replace current page
await RouteManager.replace('pages/Index', {});
```

### DataLoader

**Unified data loading pattern (try-catch-finally):**
```typescript
import { DataLoader } from '../utils/DataLoader';

// Simple load
await DataLoader.load({
  loadFn: async () => await apiService.getHomeData(),
  onSuccess: (data) => {
    this.storeData = data;
  },
  errorMessage: '加載失敗'
});

// With loading state
await DataLoader.loadWithState({
  loadFn: async () => await apiService.getMenus(),
  onSuccess: (data) => { this.menus = data; },
  loadingState: this.isLoading,  // @State variable
  errorMessage: '菜單加載失敗'
});
```

---

## Type Safety (Phase 3)

### Type Transformers

**PriceTransformer - Safe price conversion:**
```typescript
import { PriceTransformer } from '../types/transformers/PriceTransformer';

// Safe string → number (handles NaN)
const price = PriceTransformer.toNumber(priceStr, 0);  // Default: 0

// Fix floating-point precision
const total = PriceTransformer.safeAdd(0.1, 0.2);  // 0.3 (not 0.30000000000000004)

// Format for display
const display = PriceTransformer.formatDisplay(10.0, '$');  // "$10" (not "$10.0")

// Batch transform object fields
const product = PriceTransformer.transformPriceFields(
  rawProduct,
  ['price', 'takeout_price', 'delivery_price']
);
```

**BooleanTransformer - "1"/"0" ↔ boolean:**
```typescript
import { BooleanTransformer } from '../types/transformers/BooleanTransformer';

// API "1"/"0" → boolean
const hasStock = BooleanTransformer.toBoolean(product.has_stock);  // "1" → true

// boolean → "1"/"0" (for API submission)
const stockStr = BooleanTransformer.toString(true);  // "1"

// Batch transform
const product = BooleanTransformer.transformBooleanFields(
  rawProduct,
  ['has_stock', 'is_default']
);
```

### Type Guards (Runtime Validation)

**ApiGuards - Validate API responses:**
```typescript
import {
  isValidApiResponse,
  isValidHomeData,
  getStringField,
  getNumberField
} from '../types/guards/ApiGuards';

// Validate API response structure
if (isValidApiResponse(response)) {
  // Safe to use response.code, response.msg
}

// Validate nested data
if (isValidHomeData(response.data)) {
  // Safe to use response.data.config, response.data.currency
}

// Safe field accessors with defaults
const storeId = getStringField(config, 'store_id', 'default_id');
const price = getNumberField(product, 'price', 0);
```

**Note:** ArkTS does not support TypeScript type guards (`is` syntax), so these return `boolean` with warning logs instead.

---

## Permissions

`ohos.permission.INTERNET`, `ohos.permission.GET_NETWORK_INFO`

## Colors

primary_yellow=#FFD700, page_background=#F5F5F5, text_primary=#333333, text_secondary=#666666, discount_red=#FF6B6B

## Key Kits

`@kit.AccountKit` (HUAWEI ID), `@kit.NetworkKit` (HTTP), `@kit.ArkData` (preferences), `@kit.ArkUI` (router)
