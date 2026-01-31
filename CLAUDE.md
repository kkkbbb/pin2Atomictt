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
├── config/
│   └── AppConfig.ets          # Global configuration (store_id, API URL, theme)
├── entryability/
│   └── EntryAbility.ets       # App entry, init global state
├── models/
│   └── StoreModels.ets        # API data models (TypeScript interfaces)
├── services/
│   ├── ApiService.ets         # HTTP client for backend API
│   └── AppStorage.ets         # Global state (user, cart, preferences)
└── pages/
    ├── Index.ets              # Store home page
    ├── MenuPage.ets           # Product menu + order history page
    └── CouponPage.ets         # Coupon list page (優惠券/兌換券)
```

**Global Configuration (AppConfig.ets):**
```typescript
import { AppConfig } from '../config/AppConfig';

// All configurable values are centralized here
AppConfig.DEFAULT_STORE_ID    // Default store ID (e.g., '4874')
AppConfig.API_BASE_URL        // API base URL
AppConfig.DEFAULT_LANG_CODE   // Default language ('zh_HK')
AppConfig.DEFAULT_THEME_COLOR // Theme color ('#FFD700')
AppConfig.DEFAULT_CURRENCY_SYMBOL // Currency symbol ('$')
```

**Data Models (StoreModels.ets):**
- `OrderType` enum: PICKUP(1), DINE_IN(2), DELIVERY(3)
- `OrderStatus` enum: pending, confirmed, preparing, ready, completed, cancelled, refunded
- `OrderFilterType` enum: ALL(''), IN_PROGRESS, COMPLETED, REFUND
- `Order` interface: order_id, order_no, status, order_type, items[], pay_amount, created_at
- `OrderItem` interface: product_id, local_name, cover_image, price, quantity, specifications
- `OrderListData` interface: order_list[], total
- `MenuGroup` interface: menu_id, local_name, groups[], show_type, can_order, start_time, end_time
- `ProductMenuData` interface: group[], menu_group[]
- `CouponStatus` enum: available, used, expired
- `CouponType` enum: coupon, voucher
- `Coupon` interface: coupon_id, name, type, discount_type, discount_value, start_date, end_date, status
- `CouponListData` interface: coupon_list[], voucher_list[], total_coupons, total_vouchers

**Product Detail Models:**
- `Product` interface: product_id, local_name, prices[], condiment_group[] (CondimentGroupDetail[])
- `ProductDetail` interface: product_id, local_name, prices[], packageGroups[], policy[], box, condiment_group[]
  - `condiment_group`: CondimentGroupDetail[] - 主商品配料选择（甜度、冰量等），用于单点饮品
- `PackageGroup` interface: id, local_name, select_count, max_count, select_type, free_count, item[]
- `PackageItem` interface: product_id, local_name, prices[], condiment_group[]
- `PolicyGroupData` interface: id, local_name, groupData[] (from /api/product/policy)
- `PolicyGroup` interface: id, local_name, free_count, required, item[]
- `PolicyGroupItem` interface: product_id, local_name, prices[], condiment_group[]
- `CondimentGroupDetail` interface: condiment_group_id, local_name, multi_select, item[]
- `CondimentItemDetail` interface: condiment_item_id, local_name, price, takeout_price, is_default

## Page Routing

Pages are registered in `entry/src/main/resources/base/profile/main_pages.json`.

**Navigation Pattern:** Use `router.pushUrl()` for page navigation:
```typescript
import { router } from '@kit.ArkUI';

router.pushUrl({
  url: 'pages/MenuPage',
  params: { orderType: OrderType.PICKUP, ... }
});

// Receive params in target page
const params = router.getParams() as Record<string, Object>;
```

**Note:** Do NOT use `router.pushNamedRoute()` unless `routerMap` is configured in `module.json5`.

## Page Structure

### Index.ets (Store Home)
- StoreHeader: Store image, name, status tags
- LoginCard: Login prompt, order/coupon shortcuts
- ServiceSection: Pickup/Dine-in selection cards

### MenuPage.ets (Product Menu & Order History)
UI components (H5 replica):
- **StoreHeader**: Back button, store image (80x80), name, status tags, "關於商戶" button
- **NoticeBar**: Yellow background (#FFFACD), expandable announcements
- **TabBar**: 主頁/點餐/歷史訂單 tabs with active indicator (currentTab: 0/1/2)
- **MenuGroupBar**: Top-level category navigation (午餐/套餐/單點/啤酒飲料), yellow pills, left-aligned
  - Only displayed when `menu_group.length > 1`
  - Filters left sidebar categories based on selected menu group
- **ServiceHeader**: Service type icon + language toggle (繁/简)
- **CategoryList**: Left sidebar (85px), synchronized scrolling
- **ProductList**: Product cards with "供應時間" in category headers

**Product Display Modes (based on `menu_group.show_type`):**
- `show_type = "2"` (Large): Image on top (180px), product info below (午餐 category)
- `show_type = "1"` (Small): Image on left (70x70), product info on right (啤酒/飲料 category)

**Order History (Tab 2):**
- **OrderFilterBar**: Dropdown filter (全部訂單/進行中/已完成/退款取消)
- **OrderListView**: Paginated order list with infinite scroll
- **OrderCard**: Order number, status badge, items preview, total amount, "再來一單" button
- **OrderEmptyView**: Empty state with "暫無訂單" message

**Product Detail Popup:**
- **ProductDetailSheet**: Bottom sheet modal for product customization
  - Dynamic height based on content (see below)
- **ProductImage**: Cover image (220px height)
- **ProductInfo**: Name, price, description
- **PriceSpecSection**: Spec selection (熱/凍, 大/小) - shown when `prices.length > 1`
- **ProductCondimentGroupSection**: 主商品配料選擇 (甜度/冰量/奶) - shown when `condiment_group` exists
  - Used for single-item drinks (單點奶茶, 啤酒飲料)
  - State: `selectedProductCondiments: Map<string, string>` (condimentGroupId → condimentItemId)
- **PackageGroupSection**: 配料修改 sections (from `packageGroups`)
  - Group header with required indicator ("請選擇n項")
  - PackageItemRow: Item name, add price, checkbox/radio
  - Used for meal modifications (少飯/多飯/走青)
- **PolicyGroupSection**: 加送選擇 sections (from policy API `groupData`)
  - Group header "加選·{group_name}" with required indicator
  - PolicyItemRow: Drink name, description, add price, radio button
  - Click to open **CondimentSelectionSheet** (if drink has condiment_group)
- **BottomBar**: Price display, quantity selector, "加入購物籃" button

**Product Detail Adaptive Height:**
- Uses `Stack({ alignContent: Alignment.Bottom })` for bottom-aligned popup
- Scroll content uses `constraintSize({ maxHeight: '60%' })` for auto height
- Simple products show compact view (image + name + bottom bar only)
- Complex products with many options will scroll within the max height

**Condiment Selection Popup (二级弹窗):**
- **CondimentSelectionSheet**: Secondary popup for drink customization (甜度、冰量、奶等)
- Triggered when clicking a policy item (drink) with `condiment_group`
- **Header**: Back arrow, drink name, "確認" button (yellow)
- **PriceSpecSelectionSection**: Spec selection (熱/凍) from `prices[]` array
  - Only shown when `prices.length > 1`
  - Each option shows name and add price (+$3)
- **CondimentGroupSection**: Condiment groups (轉大杯/甜度/冰量/奶)
  - Group header with "請選擇1項" indicator
  - CondimentItemRow: Option name, add price, radio button
- Default selections initialized from `is_default: "1"` items

**Product Detail Data Flow:**
```
openProductDetail(product)
  → Reset states: selectedPriceIndex, selectedPackageItems, selectedProductCondiments
  → fetchProductDetail(productId, orderType)
    → GET /api/product/detail → selectedProduct, packageGroups, condiment_group
    → initProductCondimentDefaults() → Initialize default condiment selections
    → if policy[] exists:
        → fetchPolicyData(policyIds)
          → GET /api/product/policy → policyGroups
  → UI renders based on available data:
    → PriceSpecSection (if prices.length > 1)
    → ProductCondimentGroupSection (if condiment_group exists)
    → PackageGroupSection (if packageGroups exists)
    → PolicyGroupSection (if policyGroups exists)
```

**Condiment Selection Flow (加送商品配料选择):**
```
PolicyItemRow.onClick(item)
  → if item.condiment_group exists:
      → openCondimentSheet(groupId, item)
        → selectedPolicyItem = item
        → selectedPolicyPriceIndex = 0 (default first spec)
        → selectedCondimentItems = Map (init with is_default items)
        → showCondimentSheet = true
      → UI shows CondimentSelectionSheet overlay
      → User selects specs (熱/凍) and condiments (甜度/奶...)
      → confirmCondimentSelection()
        → selectPolicyItem(groupId, item.product_id)
        → closeCondimentSheet()
  → else:
      → selectPolicyItem(groupId, item.product_id) directly
```

**State Variables for Product Detail:**
- `selectedPriceIndex: number` - Selected price spec index (0-based)
- `selectedProductCondiments: Map<string, string>` - Main product condiments (甜度/冰量)
- `selectedPackageItems: Map<string, Set<string>>` - Package selections (少飯/多飯)

**State Variables for Policy Condiment Selection (二级弹窗):**
- `showCondimentSheet: boolean` - Controls popup visibility
- `selectedPolicyItem: PolicyGroupItem | null` - Current drink being customized
- `selectedPolicyGroupId: string` - Parent policy group ID
- `selectedPolicyPriceIndex: number` - Selected spec index (熱=0, 凍=1)
- `selectedCondimentItems: Map<string, string>` - condimentGroupId → condimentItemId

**Navigation from Index.ets:**
```typescript
// Jump to order history from home page "我的訂單"
router.pushUrl({
  url: 'pages/MenuPage',
  params: { initialTab: 2, ... }
});

// Jump to coupon list from home page "我的優惠"
router.pushUrl({
  url: 'pages/CouponPage',
  params: { themeColor, isLoggedIn }
});
```

### CouponPage.ets (Coupon List)
UI components (H5 replica):
- **PageHeader**: Back button, "我的優惠" title
- **TabBar**: 優惠券(n)/兌換券(n) tabs with count and active indicator
- **LoginPromptView**: "登入/註冊" button for unauthenticated users
- **CouponCards**: Coupon card list with ticket-style design (left color block, serrated edge)
- **EmptyView**: Empty state with "暫無優惠券/兌換券" message

**Coupon Card Design:**
- Left: Discount value (percentage/fixed amount) with yellow background
- Right: Coupon name, min order amount, expiry date, "立即使用" button
- Serrated edge separating left and right sections

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
| `/api/account/token` | GET | Guest token (requires sign) | `apiService.getGuestToken()` |
| `/api/v2/home` | POST | Store home data | `apiService.getHomeData()` |
| `/api/home/product-menus` | GET | Product menu | `apiService.getProductMenus()` |
| `/api/product/detail` | GET | Product detail with packageGroups | `apiService.getProductDetail(productId, orderType)` |
| `/api/product/policy` | GET | Policy groups (加送選擇) | `apiService.getProductPolicy(policyIds)` |
| `/api/store/meal-member-plan` | GET | Member plans | `apiService.getMemberPlan()` |
| `/api/store/store-pops` | GET | Store popups | `apiService.getStorePops()` |
| `/api/order/order-list-app` | GET | User orders (paginated) | `apiService.getOrders(filterType, pageNumber, pageLimit)` |
| `/api/coupon/list` | GET | User coupons | `apiService.getCoupons()` |

**Guest Token API (Sign Generation):**
```typescript
// Sign algorithm: MD5(store_id=${storeId}&ts=${ts}&key=SECRET_KEY).toUpperCase()
const secretKey = 'a91f9568fbd23881c2b2c7fa9af5b12a';
const ts = Date.now().toString();
const signStr = `store_id=${storeId}&ts=${ts}&key=${secretKey}`;
const sign = MD5(signStr).toUpperCase();
// Request: GET /api/account/token?store_id=4874&ts=1234567890&sign=XXXX
```

**Order List Parameters:**
- `store_id`: Store ID
- `type`: Filter type (`''`=全部, `'in_progress'`=進行中, `'completed'`=已完成, `'refund'`=退款取消)
- `page_number`: Page number (starts from 1)
- `page_limit`: Items per page (default: 10)

**Product Menu Response Structure:**
```json
{
  "group": [...],           // Product groups (二级分类)
  "menu_group": [           // Top-level menu groups (顶级分类导航条)
    {
      "menu_id": "1084",
      "local_name": "午餐",
      "groups": ["35579", "6507"],  // 包含的二级分类 group_id
      "show_type": "2",             // 展示模式: "1"=小图 "2"=大图
      "can_order": 1,               // 当前时段是否可点餐
      "start_time": "11:30",
      "end_time": "15:00"
    }
  ]
}
```

**Product Detail Response Structure (`/api/product/detail`):**
```json
{
  "product_id": "322172",
  "local_name": "梅菜煎肉餅飯",
  "prices": [...],              // 规格价格列表
  "packageGroups": [            // 配料選擇 (condiment modifications)
    {
      "id": "1932688",
      "local_name": "配料更改",
      "select_count": "0",      // 最少选择数量
      "max_count": "0",         // 最多选择数量 (0=不限)
      "select_type": "1",       // "1"=多选 "2"=单选
      "free_count": "0",
      "item": [
        { "product_id": "68135", "local_name": "少飯", "prices": [...] },
        { "product_id": "68134", "local_name": "多飯", "prices": [...] }
      ]
    }
  ],
  "policy": [                   // 政策引用 (用于获取加送数据)
    { "policy_id": "821", "product_id": "322172" }
  ]
}
```

**Product Policy Response Structure (`/api/product/policy`):**
```json
{
  "data": [{
    "id": "821",
    "local_name": "咖啡/茶凍飲+$3,汽水+$5,特飲+$6",
    "groupData": [              // 加送選擇组
      {
        "id": "79074",
        "local_name": "奉送咖啡/茶, 凍飲+$3,汽水+$4 +$6可選特飲",
        "free_count": "1",      // 免费数量
        "required": "1",        // "1"=必选
        "item": [               // 可选饮品列表
          {
            "product_id": "434067",
            "local_name": "泰國奶茶",
            "prices": [{ "add_price": "6.00" }],
            "condiment_group": [  // 饮品自己的配料 (甜度、冰量等)
              { "local_name": "甜度", "item": [...] },
              { "local_name": "冰量", "item": [...] }
            ]
          }
        ]
      }
    ]
  }]
}
```

**Policy Item with Multiple Specs (prices) Example:**
```json
{
  "product_id": "434841",
  "local_name": "奶茶",
  "prices": [                    // 多规格：熱/凍
    { "local_name": "熱", "add_price": "0.00" },
    { "local_name": "涷", "add_price": "3.00" }
  ],
  "condiment_group": [           // 配料选择
    {
      "condiment_group_id": "4096",
      "local_name": "轉大杯",
      "item": [
        { "local_name": "標準", "price": "0", "is_default": "1" },
        { "local_name": "6元轉大杯", "price": "6" }
      ]
    },
    {
      "condiment_group_id": "3859",
      "local_name": "甜度",
      "item": [
        { "local_name": "標準", "is_default": "1" },
        { "local_name": "不要糖" }
      ]
    },
    {
      "condiment_group_id": "3861",
      "local_name": "奶",
      "item": [
        { "local_name": "標準", "is_default": "1" },
        { "local_name": "走奶" },
        { "local_name": "轉煉奶" },
        { "local_name": "多奶" },
        { "local_name": "少奶" }
      ]
    }
  ]
}
```

**Configuration:**
- Default store ID: Configured in `config/AppConfig.ets` → `AppConfig.DEFAULT_STORE_ID`
- Default language: `zh_HK`

## State Management

**AppStateManager** (`services/AppStorage.ets`) handles:
- User login state and token persistence
- Shopping cart (persisted to preferences)
- Store configuration

**Usage:**
```typescript
import { appState, CartItemInput } from '../services/AppStorage';

// Check login
if (appState.isLoggedIn) { ... }

// Add to cart
const cartItem: CartItemInput = { ... };
await appState.addToCart(cartItem);

// Get cart total
const total = appState.cartTotal;
const count = appState.cartCount;

// Update quantity
await appState.updateCartItemQuantity(cartItemId, newQuantity);

// Clear cart
await appState.clearCart();
```

## Shopping Cart

### Cart Data Models (`AppStorage.ets`)

**CartItemInput** - Input for adding to cart (without cartItemId):
```typescript
interface CartItemInput {
  productId: string;
  productName: string;
  coverImage: string;
  priceIndex: number;
  priceName: string;
  basePrice: number;
  packageSelections: CartPackageSelection[];
  policySelections: CartPolicySelection[];
  quantity: number;
  unitPrice: number;
  specDescription: string;  // e.g., "奶茶·熱·標準·標準"
}
```

**CartItem** - Full cart item (extends CartItemInput with cartItemId):
```typescript
interface CartItem extends CartItemInput {
  cartItemId: string;  // Auto-generated unique ID
}
```

**CartPackageSelection** - 配料選擇:
```typescript
interface CartPackageSelection {
  groupId: string;
  groupName: string;
  items: CartPackageItem[];
}

interface CartPackageItem {
  productId: string;
  name: string;
  addPrice: number;
}
```

**CartPolicySelection** - 加送商品選擇:
```typescript
interface CartPolicySelection {
  groupId: string;
  groupName: string;
  item: CartPolicyItem;
}

interface CartPolicyItem {
  productId: string;
  name: string;
  priceIndex: number;
  priceName: string;
  addPrice: number;
  condiments: CartCondiment[];
}

interface CartCondiment {
  groupId: string;
  groupName: string;
  itemId: string;
  itemName: string;
  price: number;
}
```

### Cart UI Components (`MenuPage.ets`)

**UI Layer Structure (bottom to top):**
```
Stack {
  1. Main Content (CategoryList + ProductList)  // 底层：菜单滑动页
  2. CartPopup                                   // 中间层：购物车弹窗
  3. CartBottomBar                               // 顶层：悬浮购物车卡片
  4. ProductDetailSheet                          // 最顶层：商品详情弹窗
}
```

**CartBottomBar** - 悬浮购物车卡片 (始终在最上层):
- Yellow background with rounded corners (borderRadius: 25)
- Shadow effect for floating appearance
- Left: Cart icon (🛒) with quantity badge
- Center: "總數" + total amount
- Right: "下一步" button (black)
- Position: `position({ x: 0, y: '100%' }).translate({ y: -66 })`
- Only visible when `currentTab === 1 && cartCount > 0`

**CartPopup** - 购物车商品列表弹窗 (在悬浮卡片下层):
- Stack layout with `alignContent: Alignment.Bottom`
- Semi-transparent overlay (rgba(0,0,0,0.4), click to close)
- White background with top rounded corners (borderRadius: 16)
- Header: "購物車" title + "清空購物車" button
- List of CartItemRow components (maxHeight: 300)
- Bottom padding (76px) for floating cart bar space

**CartItemRow** - 购物车商品项:
- Product name (bold)
- Spec description (gray, smaller)
- Unit price (theme color)
- Quantity controls (- / count / +)

**List Bottom Padding:**
- CategoryList and ProductList add transparent ListItem (height: 66) at end
- Ensures last items are not obscured by floating cart bar

### Cart State Variables (`MenuPage.ets`)

```typescript
@State cartCount: number = 0;           // Total item count
@State cartTotal: number = 0;           // Total price
@State showCartPopup: boolean = false;  // Popup visibility
@State confirmedPolicySelections: Map<string, ConfirmedPolicySelection> = new Map();
```

### Add to Cart Flow

```
User clicks "加入購物籃" in ProductDetailSheet
  → addToCart()
    → checkRequiredSelections() // Validate required options
    → buildCartItem() // Construct CartItemInput
      → Collect product info, price, specs
      → Collect packageSelections from selectedPackageItems
      → Collect policySelections from confirmedPolicySelections
      → Calculate unitPrice
      → Build specDescription
    → appState.addToCart(cartItem)
    → updateCartState() // Refresh cartCount, cartTotal
    → closeProductDetail()
```

### Cart Persistence

Cart data is automatically persisted to preferences:
- Key: `'cart'`
- Format: JSON array of CartItem objects
- Loaded on app init via `loadPersistedData()`
- Saved on every cart modification

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
- `notice_background`: #FFFACD (announcement bar)
- `tab_active`: #FFD700 (active tab indicator)
- `tab_inactive`: #999999 (inactive tab text)
