import { hilog } from '@kit.PerformanceAnalysisKit';
import { router, window, promptAction } from '@kit.ArkUI';
import { appState, CartItem, CartBoxInfo } from '../services/AppStorage';
import { apiService } from '../services/ApiService';
import {
  OrderType,
  AddOrderRequest,
  OrderProduct,
  OrderCondiment,
  OrderPolicyProduct,
  OrderBoxInfo,
  PackageItemPrice
} from '../models/StoreModels';
import { AppConfig } from '../config/AppConfig';

const DOMAIN = 0x0000;
const TAG = 'CheckoutPage';

/**
 * 区号选项
 */
interface AreaCode {
  code: string;
  name: string;
}

@Entry
@Component
struct CheckoutPage {
  @State isLoading: boolean = true;
  @State orderType: OrderType = OrderType.PICKUP;
  @State themeColor: string = '#FFD700';
  @State currencySymbol: string = '$';
  @State topSafeHeight: number = 0;

  // 店铺信息
  @State storeName: string = '';
  @State storeAddress: string = '';

  // 购物车数据
  @State cartItems: CartItem[] = [];
  @State cartTotal: number = 0;
  @State cartCount: number = 0;

  // 费用明细
  @State boxFee: number = 0;         // 餐盒费（从购物车商品获取，0表示无餐盒费）
  @State boxInfo: CartBoxInfo | null = null;  // 餐盒费详情
  @State voucherDiscount: number = 0; // 兑换券折扣
  @State couponDiscount: number = 0;  // 优惠券折扣

  // 联系信息
  @State email: string = '';
  @State selectedAreaCode: AreaCode = { code: '+852', name: '中國香港' };
  @State phone: string = '';
  @State remark: string = '';

  // 区号列表
  private areaCodes: AreaCode[] = [
    { code: '+852', name: '中國香港' },
    { code: '+86', name: '中國大陸' },
    { code: '+853', name: '澳門' },
    { code: '+886', name: '台灣' },
    { code: '+65', name: '新加坡' },
    { code: '+60', name: '馬來西亞' }
  ];

  @State showAreaCodePicker: boolean = false;
  @State isSubmitting: boolean = false;

  aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      if (params['orderType']) {
        this.orderType = params['orderType'] as OrderType;
      }
      if (params['themeColor']) {
        this.themeColor = params['themeColor'] as string;
      }
      if (params['currencySymbol']) {
        this.currencySymbol = params['currencySymbol'] as string;
      }
      if (params['storeName']) {
        this.storeName = params['storeName'] as string;
      }
      if (params['storeAddress']) {
        this.storeAddress = params['storeAddress'] as string;
      }
    }

    this.loadData();
    this.getTopSafeHeight();
  }

  private async getTopSafeHeight(): Promise<void> {
    try {
      const win = await window.getLastWindow(getContext(this));
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeHeight = px2vp(avoidArea.topRect.height);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to get safe area: %{public}s', JSON.stringify(error));
      this.topSafeHeight = 44;
    }
  }

  private async loadData(): Promise<void> {
    // 加载购物车数据
    this.cartItems = appState.cartItems;
    this.cartTotal = appState.cartTotal;
    this.cartCount = appState.cartCount;

    // 计算餐盒费（外卖自取时收取，且需要商家配置了餐盒费）
    this.boxFee = 0;
    this.boxInfo = null;
    if (this.orderType === OrderType.PICKUP) {
      // 从购物车中找到第一个有餐盒费配置的商品
      for (const item of this.cartItems) {
        if (item.boxInfo && item.boxInfo.price > 0) {
          this.boxInfo = item.boxInfo;
          this.boxFee = item.boxInfo.price;
          break;
        }
      }
    }

    // 如果店铺信息为空，从API获取
    if (!this.storeName || !this.storeAddress) {
      await this.loadStoreInfo();
    }

    this.isLoading = false;
    hilog.info(DOMAIN, TAG, 'Cart loaded: %{public}d items, total: %{public}d',
      this.cartCount, this.cartTotal);
  }

  /**
   * 加载店铺信息
   */
  private async loadStoreInfo(): Promise<void> {
    try {
      const response = await apiService.getHomeData();
      if (response.code === 200 && response.data) {
        const config = response.data.config;
        if (!this.storeName) {
          this.storeName = config.name || '';
        }
        if (!this.storeAddress) {
          this.storeAddress = config.address || '';
        }
        hilog.info(DOMAIN, TAG, 'Store info loaded: %{public}s', this.storeName);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load store info: %{public}s', JSON.stringify(error));
    }
  }

  // 获取总计金额
  private getTotalAmount(): number {
    return this.cartTotal + this.boxFee - this.voucherDiscount - this.couponDiscount;
  }

  // 获取订单类型文本
  private getOrderTypeText(): string {
    switch (this.orderType) {
      case OrderType.PICKUP:
        return '外賣自取';
      case OrderType.DINE_IN:
        return '堂食';
      case OrderType.DELIVERY:
        return '外送';
      default:
        return '';
    }
  }

  // 返回上一页
  private goBack(): void {
    router.back();
  }

  // 修改菜品（返回菜单页）
  private modifyItems(): void {
    router.back();
  }

  // 提交订单
  private async submitOrder(): Promise<void> {
    // 验证手机号
    if (!this.phone) {
      promptAction.showToast({
        message: '請輸入手機號碼',
        duration: 2000
      });
      return;
    }

    // 验证购物车
    if (this.cartItems.length === 0) {
      promptAction.showToast({
        message: '購物車為空',
        duration: 2000
      });
      return;
    }

    if (this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;
    hilog.info(DOMAIN, TAG, 'Submitting order, total: %{public}d', this.getTotalAmount());

    try {
      // 构建订单商品数据
      const products: OrderProduct[] = this.buildOrderProducts();

      // 构建订单请求
      const orderRequest: AddOrderRequest = {
        store_id: AppConfig.DEFAULT_STORE_ID,
        table_id: 0,
        order_type: this.orderType,
        order_sub_type: 0,
        customer_num: 0,
        language: AppConfig.DEFAULT_LANG_CODE,
        comment: this.remark,
        products: products,
        total: this.getTotalAmount().toFixed(4),
        discount_total: 0,
        activity_discount_total: 0,
        seat_fee: 0,
        service_fee: '0.0000',
        email: this.email,
        telephone: this.phone,
        telephone_area_code: this.selectedAreaCode.code,
        coupon_total: this.couponDiscount > 0 ? this.couponDiscount : null,
        coupon_id: null,
        form_id: '',
        member_id: '',
        delivery_fee: 0,
        order_id: '',
        qr_code: null,
        table_group_name: null,
        cutlery_num: -1,
        cutlery_total: 0,
        need_cutlery_num: 0,
        member_discount_total: 0
      };

      hilog.info(DOMAIN, TAG, 'Order request: products=%{public}d', products.length);

      const response = await apiService.addOrder(orderRequest);

      if (response.code === 200 && response.data) {
        hilog.info(DOMAIN, TAG, 'Order submitted successfully: order_id=%{public}d',
          response.data.order_id);

        // 清空购物车
        await appState.clearCart();

        // 跳转到订单详情页进行支付
        router.pushUrl({
          url: 'pages/OrderDetailPage',
          params: {
            orderId: response.data.order_id,
            themeColor: this.themeColor
          }
        });
      } else {
        hilog.error(DOMAIN, TAG, 'Order submit failed: %{public}s', response.msg);
        promptAction.showToast({
          message: response.msg || '訂單提交失敗',
          duration: 2000
        });
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Order submit error: %{public}s', errorMsg);
      promptAction.showToast({
        message: '網絡錯誤，請重試',
        duration: 2000
      });
    } finally {
      this.isSubmitting = false;
    }
  }

  /**
   * 构建订单商品数据
   */
  private buildOrderProducts(): OrderProduct[] {
    const products: OrderProduct[] = [];
    let isFirstItem = true;  // 只为第一个商品添加盒费

    for (const cartItem of this.cartItems) {
      // 使用购物车中保存的规格码
      const standardCode = cartItem.standardCode || '';

      // 构建配料信息（匹配H5格式，添加防御性处理）
      const condiments: OrderCondiment[] = [];
      if (cartItem.packageSelections && cartItem.packageSelections.length > 0) {
        for (const pkgSelection of cartItem.packageSelections) {
          if (pkgSelection.items && pkgSelection.items.length > 0) {
            for (const item of pkgSelection.items) {
              const addPrice = item.addPrice ?? 0;
              const itemName = item.name || '';
              condiments.push({
                condiment_item_id: item.productId || '',
                group_id: pkgSelection.groupId || '',
                local_name: itemName,
                en_name: itemName,
                cn_name: '',
                display_order: '0',
                price: addPrice.toFixed(4),
                takeout_price: addPrice.toFixed(4),
                delivery_price: addPrice.toFixed(4),
                short_name: '',
                barcode: '',
                status_id: '1',
                default_type: '1',
                standard_code: '',
                is_default: '0',
                quantity: 1
              });
            }
          }
        }
      }

      // 构建加送商品信息
      const policyProducts: OrderPolicyProduct[][] = [];
      if (cartItem.policySelections && cartItem.policySelections.length > 0) {
        for (const policySelection of cartItem.policySelections) {
          const policyItem = policySelection.item;
          if (!policyItem) continue;

          // 构建配料信息（使用真实数据，匹配H5格式）
          const policyCondiments: OrderCondiment[] = [];
          if (policyItem.condiments && policyItem.condiments.length > 0) {
            for (const condiment of policyItem.condiments) {
              // 防御性处理：确保所有字段有默认值
              const price = condiment.price ?? 0;
              const takeoutPrice = condiment.takeoutPrice ?? price;
              const deliveryPrice = condiment.deliveryPrice ?? price;
              const itemName = condiment.itemName || '';
              const condStdCode = condiment.standardCode || policyItem.standardCode || '';
              policyCondiments.push({
                condiment_item_id: condiment.itemId || '',
                group_id: condiment.groupId || '',
                local_name: itemName,
                en_name: itemName,
                cn_name: '',
                display_order: '0',
                price: price.toFixed(4),
                takeout_price: takeoutPrice.toFixed(4),
                delivery_price: deliveryPrice.toFixed(4),
                short_name: '',
                barcode: '',
                status_id: '1',
                default_type: '1',
                standard_code: condStdCode,
                is_default: condiment.isDefault || '1',
                quantity: 1
              });
            }
          }

          // 构建 prices 数组（使用原始数据，添加防御性处理）
          const prices: PackageItemPrice[] = [];
          if (policyItem.originalPrices && policyItem.originalPrices.length > 0) {
            for (const p of policyItem.originalPrices) {
              prices.push({
                standard_code: p.standardCode || '',
                local_name: p.localName || '',
                en_name: p.enName || '',
                cn_name: '',
                short_name: p.localName || '',
                add_price: p.addPrice || '0.00',
                add_takeout_price: p.addTakeoutPrice || '0.00',
                add_delivery_price: p.addDeliveryPrice || '0.00',
                num: 0
              });
            }
          }

          // 获取选中的规格
          const selectedPrice = prices.length > policyItem.priceIndex
            ? prices[policyItem.priceIndex]
            : (prices.length > 0 ? prices[0] : null);

          // 构建加送商品（匹配H5格式，添加防御性处理）
          const productId = policyItem.productId || '';
          const productName = policyItem.name || '';
          const shortName = policyItem.shortName || productName;
          const priceName = policyItem.priceName || '';
          const stdCode = policyItem.standardCode || '';
          const addPriceNum = policyItem.addPrice ?? 0;

          const policyProduct: OrderPolicyProduct = {
            product_id: productId,
            store_id: AppConfig.DEFAULT_STORE_ID,
            scheme_id: '0',
            local_name: productName,
            cn_name: '',
            en_name: productName,
            short_name: shortName,
            status: '1',
            takeout: '1',
            cover_image: policyItem.coverImage || '',
            has_stock: '1',
            stock_number: '0',
            prices: prices,
            description: {
              product_id: productId,
              language_id: '1',
              name: productName,
              cn_description: '',
              local_description: '',
              en_description: '',
              barcode: ''
            },
            box: null,
            unit_id: 0,
            max_count: 0,
            condiment_group: [],
            condiments: policyCondiments,
            policy_id: policySelection.policyId || '',
            group_id: policySelection.groupId || '',
            select_price: selectedPrice || {
              standard_code: stdCode,
              local_name: priceName,
              en_name: priceName,
              cn_name: '',
              short_name: priceName,
              add_price: addPriceNum.toFixed(2),
              add_takeout_price: addPriceNum.toFixed(2),
              add_delivery_price: addPriceNum.toFixed(2),
              num: 0
            },
            quantity: 1,
            version: 'v1.9',
            add_price: addPriceNum,
            standard_code: stdCode,
            price: addPriceNum.toFixed(2),
            product_name: null
          };

          policyProducts.push([policyProduct]);
        }
      }

      // 构建订单商品
      // 只为第一个商品添加盒费，避免重复计费（需要商家配置了餐盒费）
      const boxInfo = (this.orderType === OrderType.PICKUP && isFirstItem && this.boxInfo)
        ? this.buildBoxInfo(cartItem)
        : null;

      const orderProduct: OrderProduct = {
        product_id: cartItem.productId,
        group_id: cartItem.groupId || '',
        standard_code: standardCode,
        condiments: condiments,
        quantity: cartItem.quantity,
        price: cartItem.basePrice,
        activity_id: null,
        box: boxInfo,
        store_id: AppConfig.DEFAULT_STORE_ID,
        dine_in_takeout: 0,
        member_discount_id: null,
        policy_products: policyProducts
      };

      products.push(orderProduct);
      isFirstItem = false;  // 后续商品不再添加盒费
    }

    return products;
  }

  /**
   * 构建外卖盒信息
   */
  private buildBoxInfo(cartItem: CartItem): OrderBoxInfo | null {
    // 外卖自取时添加餐盒费（需要有餐盒费配置）
    if (this.orderType === OrderType.PICKUP && this.boxInfo) {
      const priceStr = this.boxInfo.price.toFixed(4);
      const orderBoxInfo: OrderBoxInfo = {
        id: '',
        product_id: cartItem.productId,
        box_id: this.boxInfo.boxId,
        box: {
          box_id: this.boxInfo.boxId,
          store_id: AppConfig.DEFAULT_STORE_ID,
          local_name: this.boxInfo.localName,
          en_name: this.boxInfo.enName,
          cn_name: '',
          price: priceStr
        },
        store_id: AppConfig.DEFAULT_STORE_ID,
        local_name: this.boxInfo.localName,
        en_name: this.boxInfo.enName,
        cn_name: '',
        price: priceStr,
        display_order: '0'
      };
      return orderBoxInfo;
    }
    return null;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 顶部安全区域
        Column()
          .width('100%')
          .height(this.topSafeHeight)
          .backgroundColor('#F5F5F5')

        // 主内容区
        Scroll() {
          Column() {
            // 卡片1: 店铺地址
            this.StoreAddressCard()

            // 卡片2: 订单信息（订单类型+商品+费用+总计）
            this.OrderCard()

            // 卡片3: 联系信息+备注
            this.ContactCard()

            // 隐私条款
            this.PrivacySection()

            // 底部占位（给结算栏留空间）
            Column()
              .width('100%')
              .height(80)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .backgroundColor('#F5F5F5')
      }
      .width('100%')
      .height('100%')

      // 底部结算栏
      this.BottomBar()

      // 区号选择弹窗
      if (this.showAreaCodePicker) {
        Column() {
          // 遮罩层
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('rgba(0, 0, 0, 0.4)')
            .onClick(() => {
              this.showAreaCodePicker = false;
            })

          // 弹窗内容
          this.AreaCodePickerDialog()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // 卡片1: 店铺地址
  @Builder
  StoreAddressCard() {
    Row() {
      // 定位图标
      Image($r('app.media.icon_location'))
        .width(18)
        .height(18)
        .fillColor('#333333')
        .margin({ right: 8 })

      Column() {
        Text(this.storeName || '未知店铺')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text(this.storeAddress || '未知地址')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 6 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ top: 12 })
    .alignItems(VerticalAlign.Top)
  }

  // 卡片2: 订单信息（订单类型+商品+费用+总计）
  @Builder
  OrderCard() {
    Column() {
      // 订单类型头部
      Row() {
        Text(this.getOrderTypeText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()

        Text('修改菜品')
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.modifyItems();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      // 商品列表
      ForEach(this.cartItems, (item: CartItem, index: number) => {
        this.CartItemRow(item)
      })

      // 费用明细
      this.FeeDetailSection()

      // 总计
      this.TotalSection()
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ top: 10 })
  }

  // 购物车商品行
  @Builder
  CartItemRow(item: CartItem) {
    Row() {
      // 商品图片
      Image(item.coverImage || $r('app.media.startIcon'))
        .width(60)
        .height(60)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)

      // 商品信息
      Column() {
        Text(item.productName)
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.specDescription) {
          Text(item.specDescription)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      // 价格和数量
      Column() {
        Text(`${this.currencySymbol}${item.unitPrice.toFixed(0)}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)

        Text(`x${item.quantity}`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF')
  }

  // 费用明细
  @Builder
  FeeDetailSection() {
    Column() {
      // 餐盒费（只有当商家配置了餐盒费时才显示）
      if (this.boxFee > 0) {
        Row() {
          Text('餐盒費')
            .fontSize(14)
            .fontColor('#333333')
          Blank()
          Text(`${this.currencySymbol}${this.boxFee.toFixed(0)}`)
            .fontSize(14)
            .fontColor('#333333')
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })

        Divider().color('#F5F5F5').strokeWidth(1)
      }

      // 兑换券
      Row() {
        Text('兌換券')
          .fontSize(14)
          .fontColor('#333333')
        Blank()
        Text(this.voucherDiscount > 0 ? `-${this.currencySymbol}${this.voucherDiscount.toFixed(0)}` : '無可用兌換券')
          .fontSize(14)
          .fontColor(this.voucherDiscount > 0 ? '#333333' : '#999999')
          .fontWeight(this.voucherDiscount > 0 ? FontWeight.Medium : FontWeight.Normal)
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })

      Divider().color('#F5F5F5').strokeWidth(1)

      // 优惠券
      Row() {
        Text('優惠券')
          .fontSize(14)
          .fontColor('#333333')

        // 输入优惠码按钮
        Text('輸入優惠碼')
          .fontSize(12)
          .fontColor('#F5A623')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(4)
          .borderWidth(1)
          .borderColor('#F5A623')
          .margin({ left: 12 })

        Blank()

        Text(this.couponDiscount > 0 ? `-${this.currencySymbol}${this.couponDiscount.toFixed(0)}` : '無可用優惠券')
          .fontSize(14)
          .fontColor(this.couponDiscount > 0 ? '#333333' : '#999999')
          .fontWeight(this.couponDiscount > 0 ? FontWeight.Medium : FontWeight.Normal)
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
  }

  // 总计
  @Builder
  TotalSection() {
    Row() {
      Blank()
      Text(`共${this.cartCount}件菜品，應付`)
        .fontSize(14)
        .fontColor('#666666')

      Text(` ${this.currencySymbol}${this.getTotalAmount().toFixed(0)}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColor)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
  }

  // 卡片3: 联系信息
  @Builder
  ContactCard() {
    Column() {
      // 邮箱
      Row() {
        Text('郵箱')
          .fontSize(14)
          .fontColor('#333333')
          .width(70)

        TextInput({ placeholder: '建議填寫，用於接收訂單通知', text: this.email })
          .fontSize(14)
          .placeholderColor('#CCCCCC')
          .placeholderFont({ size: 14 })
          .backgroundColor('transparent')
          .layoutWeight(1)
          .padding({ left: 0 })
          .onChange((value: string) => {
            this.email = value;
          })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)

      Divider().color('#F5F5F5').strokeWidth(1)

      // 手机号码
      Row() {
        Text('手機號碼')
          .fontSize(14)
          .fontColor('#333333')
          .width(70)

        // 区号选择
        Row() {
          Text(`${this.selectedAreaCode.name} ${this.selectedAreaCode.code}`)
            .fontSize(14)
            .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          Text(' ▼')
            .fontSize(10)
            .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
        }
        .onClick(() => {
          this.showAreaCodePicker = true;
        })

        // 分隔线
        Divider()
          .vertical(true)
          .height(14)
          .color('#DDDDDD')
          .margin({ left: 10, right: 10 })

        TextInput({ placeholder: '請輸入手機號碼', text: this.phone })
          .fontSize(14)
          .placeholderColor('#CCCCCC')
          .placeholderFont({ size: 14 })
          .backgroundColor('transparent')
          .layoutWeight(1)
          .padding({ left: 0 })
          .type(InputType.PhoneNumber)
          .onChange((value: string) => {
            this.phone = value;
          })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)

      // 提示信息
      Row() {
        Text('💡')
          .fontSize(14)
          .margin({ right: 6 })
        Text('請輸入手機號碼，如訂單有任何修改或查詢，店員會致電通知閣下有關情況')
          .fontSize(12)
          .fontColor('#F5A623')
          .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FFFBEB')
      .borderRadius(6)
      .margin({ top: 8 })

      Divider().color('#F5F5F5').strokeWidth(1).margin({ top: 16 })

      // 备注
      Row() {
        Text('備註')
          .fontSize(14)
          .fontColor('#333333')
          .width(70)

        TextInput({ placeholder: '', text: this.remark })
          .fontSize(14)
          .placeholderColor('#CCCCCC')
          .backgroundColor('transparent')
          .layoutWeight(1)
          .padding({ left: 0 })
          .onChange((value: string) => {
            this.remark = value;
          })

        Text('>')
          .fontSize(18)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ top: 10 })
  }

  // 隐私条款
  @Builder
  PrivacySection() {
    Text() {
      Span('上方輸入手機號碼即表示你同意PinMe之 ')
        .fontSize(12)
        .fontColor('#999999')
      Span('私隱政策')
        .fontSize(12)
        .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
      Span('/')
        .fontSize(12)
        .fontColor('#999999')
      Span('使用條款')
        .fontSize(12)
        .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .textAlign(TextAlign.Center)
  }

  // 底部结算栏
  @Builder
  BottomBar() {
    Row() {
      // 总计
      Row() {
        Text('總計 ')
          .fontSize(14)
          .fontColor('#333333')
        Text(`${this.currencySymbol}${this.getTotalAmount().toFixed(0)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .layoutWeight(1)

      // 提交订单按钮
      Button(this.isSubmitting ? '提交中...' : '提交訂單')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .backgroundColor(this.isSubmitting ? '#CCCCCC' : this.themeColor)
        .borderRadius(6)
        .height(42)
        .padding({ left: 28, right: 28 })
        .enabled(!this.isSubmitting)
        .onClick(() => {
          this.submitOrder();
        })
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: -2
    })
  }

  // 区号选择弹窗
  @Builder
  AreaCodePickerDialog() {
    Column() {
      // 标题
      Text('選擇區號')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .padding({ top: 16, bottom: 16 })

      // 分隔线
      Divider().color('#F5F5F5').strokeWidth(1)

      // 区号列表
      List() {
        ForEach(this.areaCodes, (item: AreaCode) => {
          ListItem() {
            Row() {
              Text(`${item.name} ${item.code}`)
                .fontSize(15)
                .fontColor('#333333')

              Blank()

              if (this.selectedAreaCode.code === item.code) {
                Text('✓')
                  .fontSize(18)
                  .fontColor(this.themeColor)
              }
            }
            .width('100%')
            .height(50)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.selectedAreaCode = item;
              this.showAreaCodePicker = false;
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .divider({
        strokeWidth: 1,
        color: '#F5F5F5',
        startMargin: 16,
        endMargin: 16
      })

      // 取消按钮
      Button('取消')
        .fontSize(15)
        .fontColor('#666666')
        .backgroundColor('#F5F5F5')
        .borderRadius(6)
        .width('90%')
        .height(44)
        .margin({ top: 16, bottom: 16 })
        .onClick(() => {
          this.showAreaCodePicker = false;
        })
    }
    .width('100%')
    .height('50%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
