import { hilog } from '@kit.PerformanceAnalysisKit';
import { router, promptAction, window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { apiService } from '../services/ApiService';
import {
  OrderDetailData,
  OrderDetailProduct,
  OrderDetailStandard,
  OrderCondiment,
  PaymentMethod,
  PayOrderParams,
  PayMethodItem
} from '../models/StoreModels';
// 新增导入：工具类
import { RouteManager } from '../utils/RouteManager';

const DOMAIN = 0x0000;
const TAG = 'OrderDetailPage';

@Entry
@Component
struct OrderDetailPage {
  @State orderId: number = 0;
  @State orderDetail: OrderDetailData | null = null;
  @State isLoading: boolean = true;
  @State showPaymentSheet: boolean = false;
  @State selectedPaymentMethod: string = '';
  @State orderNumber: string = '';
  @State orderTotal: number = 0;
  @State isProcessingPayment: boolean = false;
  @State themeColor: string = '#FFD700';
  @State topSafeHeight: number = 0;
  @State currencySymbol: string = '$';
  @State showPaymentWebView: boolean = false;
  @State paymentUrl: string = '';
  @State paymentMethods: PayMethodItem[] = [];
  @State isLoadingPayMethods: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    // 使用 RouteManager 获取路由参数
    const params: ESObject | null = RouteManager.getParams<ESObject>();
    if (params) {
      if (params['orderId'] !== undefined) {
        // orderId 从 MenuPage 传递过来是字符串
        const orderIdParam: string | number = params['orderId'] as string | number;
        this.orderId = typeof orderIdParam === 'string' ?
          parseInt(orderIdParam) : orderIdParam;
      }
      if (params['themeColor']) {
        this.themeColor = params['themeColor'] as string;
      }
      if (params['currencySymbol']) {
        this.currencySymbol = params['currencySymbol'] as string;
      }
    }
    this.getTopSafeHeight();
    this.loadOrderDetail();
  }

  // 页面显示时刷新订单状态（用户从支付页面返回后）
  onPageShow(): void {
    if (this.orderId > 0 && !this.isLoading) {
      hilog.info(DOMAIN, TAG, 'Page shown, refreshing order status');
      this.refreshOrderStatus();
    }
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

  // 刷新订单状态（不显示全屏加载）
  async refreshOrderStatus(): Promise<void> {
    try {
      const response = await apiService.getOrderDetail(this.orderId.toString());
      if (response.code === 200 && response.data) {
        this.orderDetail = response.data;
        this.orderNumber = response.data.wt_order_id || response.data.order_id?.toString() || '';
        this.orderTotal = parseFloat(response.data.total || '0');
        hilog.info(DOMAIN, TAG, 'Order status refreshed, status_id: %{public}s', response.data.status_id);

        // 如果已支付，显示提示
        if (response.data.status_id !== '2') {
          this.showPaymentSheet = false;
          promptAction.showToast({
            message: '支付成功！',
            duration: 2000
          });
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Refresh order status error: %{public}s', JSON.stringify(error));
    }
  }

  async loadOrderDetail(): Promise<void> {
    this.isLoading = true;
    try {
      const response = await apiService.getOrderDetail(this.orderId.toString());
      if (response.code === 200 && response.data) {
        this.orderDetail = response.data;
        this.orderNumber = response.data.wt_order_id || response.data.order_id?.toString() || '';
        this.orderTotal = parseFloat(response.data.total || '0');
        hilog.info(DOMAIN, TAG, 'Order detail loaded successfully');

        // 如果是待支付状态，加载支付方式并自动显示支付方式选择
        if (response.data.status_id === '2') {
          await this.loadPaymentMethods();
          this.showPaymentSheet = true;
          hilog.info(DOMAIN, TAG, 'Order pending payment, showing payment sheet');
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Load order detail error: %{public}s', JSON.stringify(error));
    }
    this.isLoading = false;
  }

  // 加载支付方式
  async loadPaymentMethods(): Promise<void> {
    this.isLoadingPayMethods = true;
    try {
      const response = await apiService.getPaymentMethods();
      if (response.code === 200 && response.data) {
        this.paymentMethods = response.data;
        hilog.info(DOMAIN, TAG, 'Payment methods loaded: %{public}d', this.paymentMethods.length);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Load payment methods error: %{public}s', JSON.stringify(error));
    }
    this.isLoadingPayMethods = false;
  }

  // 获取订单状态文本
  getOrderStatusText(): string {
    if (!this.orderDetail) return '';
    return this.orderDetail.status?.customer_name || '處理中';
  }

  // 判断是否待支付
  isPendingPayment(): boolean {
    return this.orderDetail?.status_id === '2';
  }

  // 确认支付
  async confirmPayment(): Promise<void> {
    if (!this.selectedPaymentMethod) {
      promptAction.showToast({
        message: '請選擇支付方式',
        duration: 2000
      });
      return;
    }

    // 找到选中的支付方式
    const selectedMethod = this.paymentMethods.find(m => m.pay_type === this.selectedPaymentMethod);
    if (!selectedMethod) {
      return;
    }

    // 柜台支付特殊处理
    if (selectedMethod.pay_type === 'COUNTER') {
      promptAction.showToast({
        message: '請到櫃枱完成支付',
        duration: 2000
      });
      this.showPaymentSheet = false;
      return;
    }

    hilog.info(DOMAIN, TAG, 'Selected payment method: %{public}s', this.selectedPaymentMethod);
    this.isProcessingPayment = true;

    try {
      // 构建支付请求参数
      const payParams: PayOrderParams = {
        order_id: this.orderId,
        total: this.orderTotal.toFixed(2),
        pay_channel: parseInt(selectedMethod.pay_channel),
        pay_method: selectedMethod.pay_method,
        pay_type: selectedMethod.pay_type
      };

      hilog.info(DOMAIN, TAG, 'Pay order request: %{public}s', JSON.stringify(payParams));

      // 调用支付API
      const response = await apiService.payOrder(payParams);

      if (response.code === 200 && response.data && response.data.url) {
        hilog.info(DOMAIN, TAG, 'Payment URL obtained: %{public}s', response.data.url);

        // 关闭支付方式选择弹窗
        this.showPaymentSheet = false;

        // 使用内嵌WebView打开支付链接
        this.paymentUrl = response.data.url;
        this.showPaymentWebView = true;

        hilog.info(DOMAIN, TAG, 'Opening payment WebView');
      } else {
        promptAction.showToast({
          message: '獲取支付鏈接失敗，請重試',
          duration: 2000
        });
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Payment request error: %{public}s', JSON.stringify(error));
      promptAction.showToast({
        message: '支付請求失敗，請重試',
        duration: 2000
      });
    } finally {
      this.isProcessingPayment = false;
    }
  }

  // 返回菜单页
  goBack(): void {
    RouteManager.back();
  }

  // 重新落单 - 返回菜单页 - 使用 RouteManager
  reorder(): void {
    RouteManager.back();
  }

  // 获取所有商品列表（兼容两种 API 返回格式）
  getAllProducts(): OrderDetailProduct[] {
    if (!this.orderDetail) return [];

    const allProducts: OrderDetailProduct[] = [];

    // 格式1：order_product 数组
    if (this.orderDetail.order_product && Array.isArray(this.orderDetail.order_product)) {
      return this.orderDetail.order_product;
    }

    // 格式2：order_products 对象
    if (this.orderDetail.order_products) {
      const op = this.orderDetail.order_products;
      if (op.unconfirmed && op.unconfirmed.length > 0) {
        allProducts.push(...op.unconfirmed);
      }
      if (op.confirmed && op.confirmed.length > 0) {
        allProducts.push(...op.confirmed);
      }
      if (op.canceled && op.canceled.length > 0) {
        allProducts.push(...op.canceled);
      }
      if (op.refund && op.refund.length > 0) {
        allProducts.push(...op.refund);
      }
    }

    return allProducts;
  }

  // 获取商品规格描述
  getProductSpecs(product: OrderDetailProduct): string {
    const specs: string[] = [];

    // 规格信息
    if (product.standard && product.standard.length > 0) {
      product.standard.forEach((std: OrderDetailStandard) => {
        if (std.local_name) {
          specs.push(std.local_name);
        }
      });
    }

    // 配料信息
    if (product.condiments && product.condiments.length > 0) {
      product.condiments.forEach((cond: OrderCondiment) => {
        if (cond.local_name) {
          specs.push(cond.local_name);
        }
      });
    }

    return specs.join(' · ');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 顶部安全区域
        Column()
          .width('100%')
          .height(this.topSafeHeight)
          .backgroundColor('#FFFFFF')

        // 顶部导航栏
        Row() {
          Row() {
            Text('‹')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.goBack();
          })

          Text('訂單詳情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Row()
            .width(40)
        }
        .width('100%')
        .height(50)
        .padding({ left: 8, right: 8 })
        .backgroundColor('#FFFFFF')

        if (this.isLoading) {
          // 加载中
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(this.themeColor)
            Text('載入中...')
              .fontSize(14)
              .fontColor('#999999')
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F5F5F5')
        } else if (this.orderDetail) {
          // 订单详情内容
          Scroll() {
            Column({ space: 0 }) {
              // 1. 订单状态卡片区域
              Column() {
                // 状态卡片
                this.OrderStatusCard()

                // 操作按钮（在卡片外部右对齐）
                Row() {
                  Blank()
                  if (this.isPendingPayment()) {
                    Button('去付款')
                      .backgroundColor(this.themeColor)
                      .fontColor('#333333')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .height(32)
                      .padding({ left: 16, right: 16 })
                      .borderRadius(4)
                      .onClick(() => {
                        this.showPaymentSheet = true;
                      })
                  } else {
                    Button('重新落單')
                      .backgroundColor(this.themeColor)
                      .fontColor('#333333')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .height(32)
                      .padding({ left: 12, right: 12 })
                      .borderRadius(4)
                      .onClick(() => {
                        this.reorder();
                      })
                  }
                }
                .width('100%')
                .margin({ top: 12, bottom: 12 })
              }
              .padding({ left: 16, right: 16, top: 16 })

              // 2. 商品列表卡片
              this.ProductListCard()

              // 3. 订单信息卡片
              this.OrderInfoCard()

              // 底部留白
              Row()
                .height(30)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .backgroundColor('#F5F5F5')
        } else {
          // 加载失败
          Column() {
            Text('訂單加載失敗')
              .fontSize(14)
              .fontColor('#999999')
            Button('點擊重試')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(this.themeColor)
              .borderRadius(20)
              .margin({ top: 20 })
              .onClick(() => {
                this.loadOrderDetail();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F5F5F5')
        }
      }
      .width('100%')
      .height('100%')

      // 支付方式选择弹窗
      if (this.showPaymentSheet) {
        this.PaymentSheet()
      }

      // 支付WebView全屏弹层
      if (this.showPaymentWebView) {
        this.PaymentWebView()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 订单状态卡片
  @Builder
  OrderStatusCard() {
    Column() {
      // 状态文本
      Text(this.getOrderStatusText())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 20, bottom: this.isPendingPayment() ? 4 : 16 })

      // 待支付状态显示提示
      if (this.isPendingPayment()) {
        Text('付款成功後商家才開始製作')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ bottom: 20 })
      }

      // 非待支付状态显示取餐号码
      if (!this.isPendingPayment() && this.orderDetail?.redeem_code) {
        // 虚线分隔 + 取餐號碼标题
        Row() {
          Row()
            .height(1)
            .layoutWeight(1)
            .border({ width: { bottom: 1 }, color: '#DDDDDD', style: BorderStyle.Dashed })
          Text('取餐號碼')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ left: 12, right: 12 })
            .backgroundColor('#FFFFFF')
          Row()
            .height(1)
            .layoutWeight(1)
            .border({ width: { bottom: 1 }, color: '#DDDDDD', style: BorderStyle.Dashed })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16 })

        // 大字号取餐码
        Text(this.orderDetail.redeem_code)
          .fontSize(60)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ top: 10, bottom: 20 })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 5, color: '#05000000', offsetY: 2 })
  }

  // 商品列表卡片
  @Builder
  ProductListCard() {
    Column() {
      Text('訂單明細')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      // 商品列表（兼容两种 API 格式）
      ForEach(this.getAllProducts(), (product: OrderDetailProduct, index: number) => {
        this.ProductRow(product)
      }, (product: OrderDetailProduct, index: number) => `${product.order_product_id || product.product_id}_${index}`)

      // 分隔线
      Divider().color('#F5F5F5').height(1).margin({ left: 16, right: 16, top: 8, bottom: 8 })

      // 餐盒费
      if (this.orderDetail?.pack_total && parseFloat(this.orderDetail.pack_total) > 0) {
        Row() {
          Text('餐盒費')
            .fontSize(14)
            .fontColor('#333333')
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(this.currencySymbol + parseFloat(this.orderDetail.pack_total).toFixed(0))
            .fontSize(14)
            .fontColor('#333333')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      Divider().color('#F5F5F5').height(1).margin({ left: 16, right: 16, top: 8, bottom: 8 })

      // 折扣信息（如果有折扣）
      if (this.orderDetail?.discount_total && parseFloat(this.orderDetail.discount_total) > 0) {
        Row() {
          Column() {
            Text('外賣自取九折優惠')
              .fontSize(14)
              .fontColor('#FF6B00')
              .fontWeight(FontWeight.Medium)
            Text('10% OFF')
              .fontSize(11)
              .fontColor('#FF6B00')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('-' + this.currencySymbol + parseFloat(this.orderDetail.discount_total).toFixed(0))
            .fontSize(14)
            .fontColor('#FF6B00')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#FFF8F0')
        .borderRadius(4)
        .margin({ left: 16, right: 16, top: 8, bottom: 8 })

        Divider().color('#F5F5F5').height(1).margin({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      // 订单金额（折扣前）
      Row() {
        Text('訂單金額')
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.currencySymbol + parseFloat(this.orderDetail?.product_total || this.orderDetail?.total || '0').toFixed(0))
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })

      // 实付金额
      Row() {
        Text('實付金額')
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.currencySymbol + parseFloat(this.orderDetail?.total || '0').toFixed(0))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    }
    .width('92%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 16 })
    .shadow({ radius: 5, color: '#05000000', offsetY: 2 })
  }

  // 商品行
  @Builder
  ProductRow(product: OrderDetailProduct) {
    Row() {
      // 商品图片
      if (product.cover_image) {
        Image(product.cover_image)
          .width(60)
          .height(60)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#F5F5F5')
      } else {
        Column()
          .width(60)
          .height(60)
          .borderRadius(8)
          .backgroundColor('#F5F5F5')
      }

      // 商品信息
      Column() {
        // 名称和价格
        Row() {
          Text(product.local_name || '')
            .fontSize(15)
            .fontWeight(FontWeight.Regular)
            .fontColor('#333333')
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.currencySymbol + parseFloat(product.total_price || '0').toFixed(0))
            .fontSize(15)
            .fontColor('#333333')
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 规格描述和数量
        Row() {
          Column() {
            // 规格描述
            Text(this.getProductSpecs(product) || product.short_name || '')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 4 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            // 加送商品（如有）
            if (product.policy_products && product.policy_products.length > 0) {
              ForEach(product.policy_products, (policyGroup: OrderDetailProduct[]) => {
                ForEach(policyGroup, (policyProduct: OrderDetailProduct) => {
                  Text(`${policyProduct.local_name || ''} ${this.getProductSpecs(policyProduct)}`)
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 2 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                })
              })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('x' + product.quantity)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Top)
  }

  // 获取订单编号（取前8位）
  getDisplayOrderId(): string {
    const orderId = this.orderDetail?.wt_order_id || this.orderDetail?.order_id || '';
    return orderId.toString().substring(0, 8);
  }

  // 获取二维码URL
  getQrCodeUrl(): string {
    const orderId = this.orderDetail?.order_id || '';
    return `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${orderId}`;
  }

  // 订单信息卡片
  @Builder
  OrderInfoCard() {
    Column() {
      // 订单编号
      Text(`訂單編號: ${this.getDisplayOrderId()}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 16 })

      // 二维码
      Image(this.getQrCodeUrl())
        .width(180)
        .height(180)
        .alignSelf(ItemAlign.Center)
        .margin({ bottom: 20 })

      // 订单时间
      Row() {
        Text('訂單時間')
          .fontSize(13)
          .fontColor('#999999')
        Blank()
        Text(this.orderDetail?.date_added || '')
          .fontSize(13)
          .fontColor('#333333')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 取餐手机号
      if (this.orderDetail?.telephone) {
        Row() {
          Text('取餐手機號碼')
            .fontSize(13)
            .fontColor('#999999')
          Blank()
          Text(this.orderDetail.telephone)
            .fontSize(13)
            .fontColor('#333333')
        }
        .width('100%')
      }
    }
    .width('92%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(20)
    .margin({ bottom: 20 })
    .shadow({ radius: 5, color: '#05000000', offsetY: 2 })
  }

  // 支付方式弹窗
  @Builder
  PaymentSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => {
          this.showPaymentSheet = false;
        })

      // 弹窗内容
      Column() {
        // 返回按钮
        Row() {
          Text('返回')
            .fontSize(14)
            .fontColor('#666666')
            .onClick(() => {
              this.showPaymentSheet = false;
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16 })

        // 账单信息
        Column({ space: 8 }) {
          Text('您的賬單合計')
            .fontSize(16)
            .fontColor('#333333')

          Text(this.currencySymbol + this.orderTotal.toFixed(0))
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Text(this.orderNumber + ' (訂單編號)')
            .fontSize(13)
            .fontColor('#C8960D')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 16, bottom: 24 })

        // 分隔线
        Row()
          .width('100%')
          .height(0.5)
          .backgroundColor('#EEEEEE')

        // 支付方式标题
        Text('請在下方選擇一種支付方式')
          .fontSize(14)
          .fontColor('#333333')
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 16 })

        // 支付方式列表
        if (this.isLoadingPayMethods) {
          Row() {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(this.themeColor)
            Text('載入支付方式...')
              .fontSize(14)
              .fontColor('#999999')
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 20, bottom: 20 })
        } else {
          ForEach(this.paymentMethods, (method: PayMethodItem) => {
            Row() {
              // 图标
              if (method.pay_icon) {
                Image(method.pay_icon)
                  .width(44)
                  .height(44)
                  .borderRadius(8)
                  .objectFit(ImageFit.Contain)
                  .backgroundColor('#F5F5F5')
              } else {
                Text(this.getPaymentIcon(method.pay_type))
                  .fontSize(18)
                  .width(44)
                  .height(44)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
              }

              // 名称
              Text(method.pay_name)
                .fontSize(15)
                .fontColor('#333333')
                .margin({ left: 12 })
                .layoutWeight(1)

              // 选中状态
              if (this.selectedPaymentMethod === method.pay_type) {
                Text('●')
                  .fontSize(20)
                  .fontColor(this.themeColor)
              } else {
                Text('○')
                  .fontSize(20)
                  .fontColor('#CCCCCC')
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .onClick(() => {
              this.selectedPaymentMethod = method.pay_type;
            })
          })
        }

        // 确认按钮
        Row() {
          if (this.isProcessingPayment) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color('#333333')
              .margin({ right: 8 })
            Text('處理中...')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
          } else {
            Text('確認')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedPaymentMethod ? '#333333' : '#999999')
          }
        }
        .justifyContent(FlexAlign.Center)
        .width('90%')
        .padding({ top: 14, bottom: 14 })
        .margin({ top: 20, bottom: 30 })
        .backgroundColor(this.selectedPaymentMethod && !this.isProcessingPayment ? this.themeColor : '#F5F5F5')
        .borderRadius(8)
        .onClick(() => {
          if (!this.isProcessingPayment) {
            this.confirmPayment();
          }
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
  }

  // 获取支付图标（备用文字图标）
  getPaymentIcon(payType: string): string {
    switch (payType) {
      case 'CARD':
        return 'Card';
      case 'ALIPAYHK':
        return 'APHK';
      case 'ALIPAYCN':
        return 'AliP';
      case 'WXPAYCN':
      case 'WXPAYHK':
        return 'WX';
      case 'OCTOPUS':
        return '八達';
      case 'COUNTER':
        return 'Cash';
      default:
        return payType.substring(0, 4);
    }
  }

  // 关闭支付WebView
  closePaymentWebView(): void {
    this.showPaymentWebView = false;
    this.paymentUrl = '';
    // 刷新订单状态
    this.refreshOrderStatus();
  }

  // 支付WebView全屏组件
  @Builder
  PaymentWebView() {
    Column() {
      // 顶部安全区域
      Column()
        .width('100%')
        .height(this.topSafeHeight)
        .backgroundColor('#FFFFFF')

      // 顶部导航栏
      Row() {
        Row() {
          Text('✕')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.closePaymentWebView();
        })

        Text('支付')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row()
          .width(40)
      }
      .width('100%')
      .height(50)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })

      // WebView内容
      Web({ src: this.paymentUrl, controller: this.webController })
        .layoutWeight(1)
        .width('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .onPageBegin((event) => {
          hilog.info(DOMAIN, TAG, 'WebView page begin: %{public}s', event?.url || '');
        })
        .onPageEnd((event) => {
          hilog.info(DOMAIN, TAG, 'WebView page end: %{public}s', event?.url || '');
          // 检测支付成功回调URL
          const url = event?.url || '';
          if (url.includes('success') || url.includes('callback') || url.includes('return')) {
            hilog.info(DOMAIN, TAG, 'Payment may be completed, URL: %{public}s', url);
          }
        })
        .onErrorReceive((event) => {
          hilog.error(DOMAIN, TAG, 'WebView error: %{public}s', JSON.stringify(event?.error));
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
