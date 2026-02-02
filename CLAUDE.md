# CLAUDE.md

OpenHarmony Atomic Service (ArkUI/ETS) - Native replica of pin2eat H5 web app with HUAWEI ID auth, API level 20.

**Backend:** `https://meal.pin2eat.com`

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
│   ├── ApiService.ets        # HTTP client
│   └── AppStorage.ets        # State (user, cart)
└── pages/
    ├── Index.ets             # Store home
    ├── MenuPage.ets          # Menu + orders + cart
    ├── CouponPage.ets        # Coupons
    ├── CheckoutPage.ets      # Order confirmation
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
router.pushUrl({
  url: 'pages/MenuPage',
  params: {
    orderType, initialTab,
    hasDiscount, discountRatio, discountLabel  // Discount params from Index.ets
  }
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

```typescript
// Parse discount from API (Index.ets → MenuPage.ets via router params)
if (config.extend?.product_adjust_amount?.data[0]) {
  hasDiscount = true
  discountRatio = data[0].ext.ratio  // 0.9 for 10% off
  discountLabel = data[0].name       // "10%Discount"
}

// Calculate discount price (PICKUP only)
discountPrice = originalPrice * discountRatio
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

```typescript
import { appState } from '../services/AppStorage';
appState.isLoggedIn / addToCart() / cartTotal / cartCount / clearCart()
```

## Permissions

`ohos.permission.INTERNET`, `ohos.permission.GET_NETWORK_INFO`

## Colors

primary_yellow=#FFD700, page_background=#F5F5F5, text_primary=#333333, text_secondary=#666666, discount_red=#FF6B6B

## Key Kits

`@kit.AccountKit` (HUAWEI ID), `@kit.NetworkKit` (HTTP), `@kit.ArkData` (preferences), `@kit.ArkUI` (router)
