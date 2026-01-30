import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { apiService, ApiConfig } from '../services/ApiService';
import { HomeData, OrderType } from '../models/StoreModels';
import { router } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'StoreHome';

@Entry
@Component
struct Index {
  @State isLoggedIn: boolean = false;
  @State isLoading: boolean = true;
  @State storeName: string = '';
  @State storeImage: string = '';
  @State storeStatus: string = '';
  @State todayStatus: string = '';
  @State isOpen: boolean = true;
  @State themeColor: string = '#FFD700';
  @State notices: string[] = [];
  @State hasDineIn: boolean = true;
  @State hasTakeout: boolean = true;

  // 店铺完整数据
  private homeData: HomeData | null = null;

  build() {
    Column() {
      if (this.isLoading) {
        // 加载状态
        this.LoadingView()
      } else {
        Scroll() {
          Column() {
            // 顶部店铺信息区域
            this.StoreHeader()

            // 登录卡片区域
            this.LoginCard()

            // 服务选择区域
            this.ServiceSection()

            // 底部留白
            Blank()
              .height(40)

            // 页脚
            this.Footer()
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  // 加载中视图
  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(60)
        .height(60)
        .color($r('app.color.primary_yellow'))
      Text('載入中...')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 店铺头部信息
  @Builder
  StoreHeader() {
    Stack() {
      // 背景层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#E0E0E0')

      // 内容层
      Row() {
        // 店铺图片
        Column() {
          if (this.storeImage) {
            Image(this.storeImage)
              .width(120)
              .height(120)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .shadow({
                radius: 8,
                color: 'rgba(0, 0, 0, 0.15)',
                offsetX: 0,
                offsetY: 4
              })
          } else {
            Image($r('app.media.startIcon'))
              .width(120)
              .height(120)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .shadow({
                radius: 8,
                color: 'rgba(0, 0, 0, 0.15)',
                offsetX: 0,
                offsetY: 4
              })
          }
        }
        .margin({ left: 20, top: 30 })

        // 店铺信息
        Column() {
          // 店铺名称
          Text(this.storeName)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          // 状态标签行
          Row() {
            // 商家状态标签
            if (this.storeStatus) {
              Text(this.storeStatus)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor($r('app.color.tag_background'))
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            }

            // 今日状态标签
            if (this.todayStatus) {
              Text(this.todayStatus)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor($r('app.color.tag_background'))
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .margin({ left: 8 })
            }

            // 关于商户按钮
            Row() {
              Text('關於商戶')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
              Text(' \u24D8')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .border({ width: 1, color: '#E0E0E0' })
            .margin({ left: 8 })
            .onClick(() => {
              this.showStoreInfo();
            })
          }
          .margin({ top: 12 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16, top: 40 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height(180)
  }

  // 登录卡片
  @Builder
  LoginCard() {
    Column() {
      // 登录引导区域
      Row() {
        Column() {
          Text('歡迎你來！')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Row() {
            Text('登入享更多優惠！')
              .fontSize(14)
              .fontColor($r('app.color.text_hint'))
            Text(' >')
              .fontSize(14)
              .fontColor($r('app.color.text_hint'))
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 登录按钮
        Button('即刻登入')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(this.themeColor)
          .borderRadius(25)
          .height(50)
          .width(120)
          .onClick(() => {
            this.loginWithHuaweiID();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 20 })

      // 分隔线
      Divider()
        .color($r('app.color.divider'))
        .width('90%')

      // 功能入口
      Row() {
        // 我的订单
        Row() {
          this.OrderIcon()
          Text('我的訂單')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.goToOrders();
        })

        // 分隔线
        Divider()
          .vertical(true)
          .height(24)
          .color($r('app.color.divider'))

        // 我的优惠
        Row() {
          this.CouponIcon()
          Text('我的優惠')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.goToCoupons();
        })
      }
      .width('100%')
      .height(60)
    }
    .width('92%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .margin({ top: 16 })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.05)',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 订单图标
  @Builder
  OrderIcon() {
    Stack() {
      Column()
        .width(24)
        .height(28)
        .borderRadius(4)
        .border({ width: 2, color: this.themeColor })
      Column() {
        Divider().color(this.themeColor).width(12)
        Divider().color(this.themeColor).width(12).margin({ top: 4 })
        Divider().color(this.themeColor).width(12).margin({ top: 4 })
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(28)
    .height(28)
  }

  // 优惠图标
  @Builder
  CouponIcon() {
    Stack() {
      Row() {
        Column()
          .width(10)
          .height(24)
          .backgroundColor(this.themeColor)
          .borderRadius({ topLeft: 4, bottomLeft: 4 })
        Column()
          .width(4)
          .height(8)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(4)
        Column()
          .width(10)
          .height(24)
          .backgroundColor(this.themeColor)
          .borderRadius({ topRight: 4, bottomRight: 4 })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width(28)
    .height(28)
  }

  // 服务选择区域
  @Builder
  ServiceSection() {
    Row() {
      // 自取卡片
      if (this.hasTakeout) {
        Column() {
          this.PickupIcon()
          Text('自取')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 16 })
        }
        .layoutWeight(1)
        .height(200)
        .backgroundColor($r('app.color.service_card_background'))
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .opacity(this.isOpen ? 1 : 0.7)
        .onClick(() => {
          // 即使店铺休息也允许浏览菜单
          this.selectOrderType(OrderType.PICKUP);
        })
      }

      // 间距
      if (this.hasTakeout && this.hasDineIn) {
        Blank()
          .width(12)
      }

      // 堂食卡片
      if (this.hasDineIn) {
        Column() {
          this.DineInIcon()
          Text('堂食')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 16 })
        }
        .layoutWeight(1)
        .height(200)
        .backgroundColor($r('app.color.service_card_background'))
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .opacity(this.isOpen ? 1 : 0.7)
        .onClick(() => {
          // 即使店铺休息也允许浏览菜单
          this.selectOrderType(OrderType.DINE_IN);
        })
      }
    }
    .width('92%')
    .margin({ top: 16 })
  }

  // 自取图标
  @Builder
  PickupIcon() {
    Stack() {
      Column()
        .width(50)
        .height(55)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius({ bottomLeft: 8, bottomRight: 8 })
        .margin({ top: 15 })
      Column()
        .width(56)
        .height(20)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius({ topLeft: 4, topRight: 4 })
      Column()
        .width(12)
        .height(40)
        .backgroundColor(this.themeColor)
        .borderRadius(2)
        .position({ x: 5, y: 20 })
    }
    .width(70)
    .height(80)
  }

  // 堂食图标
  @Builder
  DineInIcon() {
    Stack() {
      Column()
        .width(60)
        .height(12)
        .backgroundColor(this.themeColor)
        .borderRadius(2)
        .position({ x: 5, y: 58 })
      Column()
        .width(60)
        .height(35)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius({ topLeft: 30, topRight: 30, bottomLeft: 4, bottomRight: 4 })
        .position({ x: 5, y: 25 })
      Column()
        .width(16)
        .height(8)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius(4)
        .position({ x: 27, y: 20 })
      Column() {
        Text('~').fontSize(16).fontColor('#333333')
      }.position({ x: 20, y: 2 })
      Column() {
        Text('~').fontSize(16).fontColor('#333333')
      }.position({ x: 32, y: 5 })
      Column() {
        Text('~').fontSize(16).fontColor('#333333')
      }.position({ x: 44, y: 2 })
    }
    .width(70)
    .height(80)
  }

  // 页脚
  @Builder
  Footer() {
    Row() {
      Text('Powered by ')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
      Text('PinMe')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 20 })
  }

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Store home page loading...');
    this.loadStoreData();
  }

  /**
   * 加载店铺数据
   */
  private async loadStoreData(): Promise<void> {
    try {
      // 设置店铺ID（可从路由参数获取）
      apiService.setStoreId(ApiConfig.DEFAULT_STORE_ID);

      // 获取首页数据
      const response = await apiService.getHomeData();

      if (response.code === 200 && response.data) {
        this.homeData = response.data;
        this.updateUIFromData(response.data);
        hilog.info(DOMAIN, TAG, 'Store data loaded successfully');
      } else {
        hilog.error(DOMAIN, TAG, 'Failed to load store data: %{public}s', response.msg);
        this.setDefaultData();
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error loading store data: %{public}s', JSON.stringify(error));
      this.setDefaultData();
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 从API数据更新UI
   */
  private updateUIFromData(data: HomeData): void {
    const config = data.config;

    // 店铺基本信息
    this.storeName = config.name || '店铺名称';
    this.storeImage = config.store_image || '';
    this.themeColor = config.theme_color || '#FFD700';

    // 营业状态
    this.isOpen = config.is_close !== 1;
    if (!this.isOpen) {
      this.storeStatus = '商家休息中';
      this.todayStatus = '今日休業';
    } else {
      this.storeStatus = '';
      this.todayStatus = '';
    }

    // 服务类型
    this.hasDineIn = config.dinein === 1;
    this.hasTakeout = config.takeout === 1;

    // 公告
    if (data.notice && data.notice.length > 0) {
      this.notices = data.notice.map(n => n.local_name);
    }
  }

  /**
   * 设置默认数据（API失败时使用）
   */
  private setDefaultData(): void {
    this.storeName = '老馮茶居';
    this.storeStatus = '商家休息中';
    this.todayStatus = '今日休業';
    this.isOpen = false;
    this.hasDineIn = true;
    this.hasTakeout = true;
  }

  /**
   * 显示店铺详情
   */
  private showStoreInfo(): void {
    hilog.info(DOMAIN, TAG, 'Show store info');
    // TODO: 跳转到店铺详情页
  }

  /**
   * 跳转到订单列表
   */
  private goToOrders(): void {
    hilog.info(DOMAIN, TAG, 'Go to orders');
    // TODO: 跳转到订单列表页
  }

  /**
   * 跳转到优惠券列表
   */
  private goToCoupons(): void {
    hilog.info(DOMAIN, TAG, 'Go to coupons');
    // TODO: 跳转到优惠券列表页
  }

  /**
   * 选择订单类型，跳转到菜单页
   */
  private selectOrderType(orderType: OrderType): void {
    hilog.info(DOMAIN, TAG, 'Select order type: %{public}d', orderType);
    router.pushUrl({
      url: 'pages/MenuPage',
      params: {
        orderType: orderType,
        themeColor: this.themeColor,
        storeId: ApiConfig.DEFAULT_STORE_ID,
        storeName: this.storeName,
        storeImage: this.storeImage,
        storeStatus: this.storeStatus,
        todayStatus: this.todayStatus,
        isOpen: this.isOpen,
        notices: this.notices
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Router error: %{public}s', err.message);
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
        // 使用authCode调用后端登录接口
        try {
          const apiResponse = await apiService.loginWithHuaweiId(authCode);
          if (apiResponse.code === 200 && apiResponse.data) {
            // 保存token
            apiService.setToken(apiResponse.data.token);
            this.isLoggedIn = true;
            hilog.info(DOMAIN, TAG, 'Backend login success');
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Backend login error: %{public}s', JSON.stringify(error));
        }
      }
    }).catch((error: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'HUAWEI ID login error: %{public}s', JSON.stringify(error));
      if (error.code === authentication.AuthenticationErrorCode.ACCOUNT_NOT_LOGGED_IN) {
        hilog.info(DOMAIN, TAG, 'HUAWEI ID not logged in');
      }
    });
  }
}
