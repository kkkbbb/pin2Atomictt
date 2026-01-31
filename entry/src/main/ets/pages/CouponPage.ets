import { router, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { apiService, ApiConfig } from '../services/ApiService';
import { Coupon, CouponListData } from '../models/StoreModels';

const DOMAIN = 0x0000;
const TAG = 'CouponPage';

/**
 * Tab类型枚举
 */
enum CouponTabType {
  COUPON = 0,    // 优惠券
  VOUCHER = 1    // 兑换券
}

@Entry
@Component
struct CouponPage {
  @State currentTab: CouponTabType = CouponTabType.COUPON;
  @State isLoggedIn: boolean = false;
  @State isLoading: boolean = true;
  @State couponList: Coupon[] = [];
  @State voucherList: Coupon[] = [];
  @State couponCount: number = 0;
  @State voucherCount: number = 0;
  @State topSafeHeight: number = 0;  // 顶部安全距离（避开胶囊）
  @State themeColor: string = '#FFD700';

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'CouponPage loading...');
    this.getTopSafeHeight();
    this.parseRouterParams();
    this.loadCoupons();
  }

  build() {
    Column() {
      // 顶部Header区域（包含安全距离和Tab栏）
      this.HeaderArea()

      // 内容区域
      if (this.isLoading) {
        this.LoadingView()
      } else if (!this.isLoggedIn) {
        this.LoginPromptView()
      } else {
        this.CouponListView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  // 顶部Header区域（避开胶囊）
  @Builder
  HeaderArea() {
    Column() {
      // 返回按钮行（在安全区域内）
      Row() {
        // 返回按钮
        Text('‹')
          .width(32)
          .height(32)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })

        Blank()
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      // Tab栏
      this.TabBar()
    }
    .width('100%')
    .backgroundColor(Color.White)
    .padding({ top: this.topSafeHeight + 8 })
  }

  // Tab栏
  @Builder
  TabBar() {
    Row() {
      // 优惠券Tab
      Column() {
        Text(`優惠券(${this.couponCount})`)
          .fontSize(15)
          .fontColor(this.currentTab === CouponTabType.COUPON ?
            $r('app.color.text_primary') : $r('app.color.text_hint'))
          .fontWeight(this.currentTab === CouponTabType.COUPON ?
            FontWeight.Medium : FontWeight.Normal)

        // 底部指示线
        Column()
          .width(50)
          .height(2)
          .backgroundColor(this.currentTab === CouponTabType.COUPON ?
            this.themeColor : Color.Transparent)
          .margin({ top: 10 })
          .borderRadius(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 14, bottom: 6 })
      .onClick(() => {
        this.currentTab = CouponTabType.COUPON;
      })

      // 兑换券Tab
      Column() {
        Text(`兌換券(${this.voucherCount})`)
          .fontSize(15)
          .fontColor(this.currentTab === CouponTabType.VOUCHER ?
            $r('app.color.text_primary') : $r('app.color.text_hint'))
          .fontWeight(this.currentTab === CouponTabType.VOUCHER ?
            FontWeight.Medium : FontWeight.Normal)

        // 底部指示线
        Column()
          .width(50)
          .height(2)
          .backgroundColor(this.currentTab === CouponTabType.VOUCHER ?
            this.themeColor : Color.Transparent)
          .margin({ top: 10 })
          .borderRadius(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 14, bottom: 6 })
      .onClick(() => {
        this.currentTab = CouponTabType.VOUCHER;
      })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .border({ width: { bottom: 1 }, color: '#F0F0F0' })
  }

  // 加载中视图
  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color(this.themeColor)
      Text('載入中...')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // 未登录提示视图
  @Builder
  LoginPromptView() {
    Column() {
      // 登录按钮
      Button('登入/註冊')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.themeColor)
        .borderRadius(24)
        .height(48)
        .width(140)
        .onClick(() => {
          this.loginWithHuaweiID();
        })

      // 提示文字
      Row() {
        Text('登入')
          .fontSize(14)
          .fontColor('#4A90E2')
        Text('｜')
          .fontSize(14)
          .fontColor($r('app.color.text_hint'))
        Text('註冊')
          .fontSize(14)
          .fontColor('#4A90E2')
        Text('，享更多優惠')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .margin({ top: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // 优惠券列表视图
  @Builder
  CouponListView() {
    Column() {
      if (this.currentTab === CouponTabType.COUPON) {
        if (this.couponList.length === 0) {
          this.EmptyView('暫無優惠券')
        } else {
          this.CouponCards(this.couponList)
        }
      } else {
        if (this.voucherList.length === 0) {
          this.EmptyView('暫無兌換券')
        } else {
          this.CouponCards(this.voucherList)
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  // 优惠券卡片列表
  @Builder
  CouponCards(coupons: Coupon[]) {
    Scroll() {
      Column() {
        ForEach(coupons, (coupon: Coupon) => {
          this.CouponCard(coupon)
        }, (coupon: Coupon) => coupon.coupon_id)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  // 单个优惠券卡片
  @Builder
  CouponCard(coupon: Coupon) {
    Row() {
      // 左侧金额/折扣区域
      Column() {
        if (coupon.discount_type === 'percentage') {
          Row() {
            Text(coupon.discount_value)
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text('%')
              .fontSize(16)
              .fontColor(Color.White)
              .margin({ left: 2, top: 8 })
          }
          Text('折扣')
            .fontSize(12)
            .fontColor(Color.White)
        } else if (coupon.discount_type === 'fixed') {
          Row() {
            Text('$')
              .fontSize(14)
              .fontColor(Color.White)
              .margin({ top: 4 })
            Text(coupon.discount_value)
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          Text('現金券')
            .fontSize(12)
            .fontColor(Color.White)
        } else {
          Text('免費')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('兌換')
            .fontSize(12)
            .fontColor(Color.White)
        }
      }
      .width(100)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.themeColor)
      .borderRadius({ topLeft: 8, bottomLeft: 8 })

      // 锯齿分隔
      Column() {
        ForEach([0, 1, 2, 3, 4], () => {
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor($r('app.color.page_background'))
            .margin({ top: 4, bottom: 4 })
        })
      }
      .position({ x: 95, y: 0 })
      .height('100%')
      .justifyContent(FlexAlign.Center)

      // 右侧详情区域
      Column() {
        Text(coupon.local_name || coupon.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (coupon.min_order_amount) {
          Text(`滿$${coupon.min_order_amount}可用`)
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
            .margin({ top: 4 })
        }

        Text(`有效期至 ${this.formatDate(coupon.end_date)}`)
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
          .margin({ top: 4 })

        // 使用按钮
        Button('立即使用')
          .fontSize(12)
          .fontColor(this.themeColor)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.themeColor })
          .borderRadius(12)
          .height(24)
          .margin({ top: 8 })
          .onClick(() => {
            this.useCoupon(coupon);
          })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 12, top: 12, bottom: 12 })
    }
    .width('100%')
    .height(120)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(8)
    .margin({ bottom: 12 })
    .shadow({
      radius: 4,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 空状态视图
  @Builder
  EmptyView(message: string) {
    Column() {
      // 空状态图标
      Column() {
        Text('🎫')
          .fontSize(48)
      }
      .width(80)
      .height(80)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F5F5F5')
      .borderRadius(40)

      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 获取顶部安全区域高度（避开胶囊）
   */
  private getTopSafeHeight(): void {
    try {
      const windowInstance = window.getLastWindow(getContext(this));
      windowInstance.then((win: window.Window) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.topSafeHeight = px2vp(avoidArea.topRect.height);
        hilog.info(DOMAIN, TAG, 'Top safe height: %{public}d', this.topSafeHeight);
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to get window: %{public}s', err.message);
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get top safe height error: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 解析路由参数
   */
  private parseRouterParams(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      if (params['themeColor']) {
        this.themeColor = params['themeColor'] as string;
      }
      if (params['isLoggedIn'] !== undefined) {
        this.isLoggedIn = params['isLoggedIn'] as boolean;
      }
    }
  }

  /**
   * 加载优惠券数据
   */
  private async loadCoupons(): Promise<void> {
    // 如果未登录，直接显示登录提示
    if (!this.isLoggedIn) {
      this.isLoading = false;
      return;
    }

    try {
      const response = await apiService.getCoupons();

      if (response.code === 200 && response.data) {
        const data = response.data as CouponListData;
        this.couponList = data.coupon_list || [];
        this.voucherList = data.voucher_list || [];
        this.couponCount = data.total_coupons || this.couponList.length;
        this.voucherCount = data.total_vouchers || this.voucherList.length;
        hilog.info(DOMAIN, TAG, 'Coupons loaded: %{public}d, Vouchers: %{public}d',
          this.couponCount, this.voucherCount);
      } else {
        hilog.error(DOMAIN, TAG, 'Failed to load coupons: %{public}s', response.msg);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error loading coupons: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 格式化日期
   */
  private formatDate(dateStr: string): string {
    if (!dateStr) {
      return '';
    }
    try {
      const date = new Date(dateStr);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    } catch {
      return dateStr;
    }
  }

  /**
   * 使用优惠券
   */
  private useCoupon(coupon: Coupon): void {
    hilog.info(DOMAIN, TAG, 'Use coupon: %{public}s', coupon.coupon_id);
    // 返回菜单页并携带优惠券信息
    router.back({
      url: 'pages/MenuPage',
      params: {
        selectedCoupon: coupon
      }
    });
  }

  /**
   * 华为ID登录
   */
  private loginWithHuaweiID(): void {
    const loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
    loginRequest.forceLogin = true;

    const controller = new authentication.AuthenticationController();
    controller.executeRequest(loginRequest).then(async (data) => {
      const loginResponse = data as authentication.LoginWithHuaweiIDResponse;
      const authCode = loginResponse.data?.authorizationCode;

      hilog.info(DOMAIN, TAG, 'HUAWEI ID auth success');

      if (authCode) {
        try {
          const apiResponse = await apiService.loginWithHuaweiId(authCode);
          if (apiResponse.code === 200 && apiResponse.data) {
            apiService.setToken(apiResponse.data.token);
            this.isLoggedIn = true;
            // 登录成功后重新加载优惠券
            this.isLoading = true;
            this.loadCoupons();
            hilog.info(DOMAIN, TAG, 'Login success, reloading coupons');
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Backend login error: %{public}s', JSON.stringify(error));
        }
      }
    }).catch((error: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'HUAWEI ID login error: %{public}s', JSON.stringify(error));
    });
  }
}
