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
      // 背景层 - 店铺图片放大模糊效果
      Column() {
        if (this.storeImage) {
          Image(this.storeImage)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .blur(20)
            .opacity(0.6)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#DBD7D8')

      // 底部圆角遮罩
      Column()
        .width('100%')
        .height(16)
        .backgroundColor($r('app.color.page_background'))
        .borderRadius({ topLeft: 16, topRight: 16 })
        .position({ x: 0, y: '100%' })
        .translate({ y: -16 })

      // 内容层
      Row() {
        // 店铺图片
        if (this.storeImage) {
          Image(this.storeImage)
            .width(80)
            .height(80)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
            .shadow({
              radius: 4,
              color: 'rgba(0, 0, 0, 0.15)',
              offsetX: 0,
              offsetY: 2
            })
        } else {
          Image($r('app.media.startIcon'))
            .width(80)
            .height(80)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
        }

        // 店铺信息
        Column() {
          // 店铺名称
          Text(this.storeName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          // 状态标签行
          Row() {
            // 商家状态标签
            if (this.storeStatus) {
              Text(this.storeStatus)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor('rgba(255, 255, 255, 0.9)')
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            }

            // 今日状态标签
            if (this.todayStatus) {
              Text(this.todayStatus)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor('rgba(255, 255, 255, 0.9)')
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .margin({ left: 6 })
            }

            // 关于商户按钮
            Row() {
              Text('關於商戶')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              Text('\u24D8')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 2 })
            }
            .backgroundColor('rgba(255, 255, 255, 0.95)')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .border({ width: 1, color: '#E0E0E0' })
            .margin({ left: 6 })
            .onClick(() => {
              this.showStoreInfo();
            })
          }
          .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height(130)
  }

  // 登录卡片
  @Builder
  LoginCard() {
    Column() {
      // 登录引导区域
      Row() {
        Column() {
          Text('歡迎你來！')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Row() {
            Text('登入享更多優惠！')
              .fontSize(13)
              .fontColor($r('app.color.text_hint'))
            Text(' >')
              .fontSize(13)
              .fontColor($r('app.color.text_hint'))
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 登录按钮
        Button('即刻登入')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(this.themeColor)
          .borderRadius(20)
          .height(40)
          .width(100)
          .onClick(() => {
            this.loginWithHuaweiID();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })

      // 分隔线
      Divider()
        .color('#EEEEEE')
        .width('100%')

      // 功能入口
      Row() {
        // 我的订单
        Row() {
          this.OrderIcon()
          Text('我的訂單')
            .fontSize(15)
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
          .height(20)
          .color('#EEEEEE')

        // 我的优惠
        Row() {
          this.CouponIcon()
          Text('我的優惠')
            .fontSize(15)
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
      .height(50)
    }
    .width('92%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ top: 16 })
    .shadow({
      radius: 4,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 订单图标 - 文档样式
  @Builder
  OrderIcon() {
    Stack() {
      // 文档外框
      Column()
        .width(20)
        .height(24)
        .borderRadius(3)
        .border({ width: 2, color: this.themeColor })
      // 文档内横线
      Column() {
        Column()
          .width(10)
          .height(2)
          .backgroundColor(this.themeColor)
          .borderRadius(1)
        Column()
          .width(10)
          .height(2)
          .backgroundColor(this.themeColor)
          .borderRadius(1)
          .margin({ top: 3 })
        Column()
          .width(10)
          .height(2)
          .backgroundColor(this.themeColor)
          .borderRadius(1)
          .margin({ top: 3 })
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(24)
    .height(24)
  }

  // 优惠图标 - 票券样式
  @Builder
  CouponIcon() {
    Stack() {
      // 左半票券
      Column()
        .width(9)
        .height(18)
        .backgroundColor(this.themeColor)
        .borderRadius({ topLeft: 3, bottomLeft: 3 })
        .position({ x: 0, y: 3 })
      // 右半票券
      Column()
        .width(9)
        .height(18)
        .backgroundColor(this.themeColor)
        .borderRadius({ topRight: 3, bottomRight: 3 })
        .position({ x: 15, y: 3 })
      // 中间锯齿上
      Column()
        .width(6)
        .height(6)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(3)
        .position({ x: 9, y: 0 })
      // 中间锯齿下
      Column()
        .width(6)
        .height(6)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(3)
        .position({ x: 9, y: 18 })
    }
    .width(24)
    .height(24)
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
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 4,
          color: 'rgba(0, 0, 0, 0.08)',
          offsetX: 0,
          offsetY: 2
        })
        .opacity(this.isOpen ? 1 : 0.7)
        .onClick(() => {
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
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 4,
          color: 'rgba(0, 0, 0, 0.08)',
          offsetX: 0,
          offsetY: 2
        })
        .opacity(this.isOpen ? 1 : 0.7)
        .onClick(() => {
          this.selectOrderType(OrderType.DINE_IN);
        })
      }
    }
    .width('92%')
    .margin({ top: 16 })
  }

  // 自取图标 - 购物袋
  @Builder
  PickupIcon() {
    Stack() {
      // 袋子主体
      Column()
        .width(48)
        .height(45)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius(6)
        .position({ x: 6, y: 25 })
      // 袋子提手 - 弧形
      Column()
        .width(28)
        .height(18)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius({ topLeft: 14, topRight: 14 })
        .position({ x: 16, y: 10 })
      // 黄色条纹
      Column()
        .width(12)
        .height(38)
        .backgroundColor(this.themeColor)
        .borderRadius(2)
        .position({ x: 10, y: 29 })
    }
    .width(60)
    .height(75)
  }

  // 堂食图标 - 餐盖
  @Builder
  DineInIcon() {
    Stack() {
      // 盘子底座（黄色）
      Column()
        .width(58)
        .height(8)
        .backgroundColor(this.themeColor)
        .borderRadius(2)
        .position({ x: 1, y: 58 })
      // 餐盖主体（半圆形）
      Column()
        .width(58)
        .height(30)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius({ topLeft: 30, topRight: 30, bottomLeft: 2, bottomRight: 2 })
        .position({ x: 1, y: 28 })
      // 餐盖把手
      Column()
        .width(16)
        .height(8)
        .backgroundColor('transparent')
        .border({ width: 3, color: '#333333' })
        .borderRadius({ topLeft: 8, topRight: 8 })
        .position({ x: 22, y: 22 })
      // 蒸汽波浪线
      Column() {
        Text('~')
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
      }
      .position({ x: 10, y: 6 })
      .rotate({ angle: 90 })
      Column() {
        Text('~')
          .fontSize(20)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
      }
      .position({ x: 26, y: 3 })
      .rotate({ angle: 90 })
      Column() {
        Text('~')
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
      }
      .position({ x: 42, y: 6 })
      .rotate({ angle: 90 })
    }
    .width(60)
    .height(75)
  }

  // 页脚
  @Builder
  Footer() {
    Row() {
      Text('Powered by ')
        .fontSize(13)
        .fontColor($r('app.color.text_hint'))
      Text('PinMe')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFD700')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 30, bottom: 20 })
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
