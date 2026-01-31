import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { apiService, ApiConfig } from '../services/ApiService';
import { HomeData, OrderType, LoginConfig, RankProduct, MemberPlan, SchemeStore } from '../models/StoreModels';
import { router, window } from '@kit.ArkUI';

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
  @State topAvoidHeight: number = 56; // 默认安全区域高度
  @State headerContentHeight: number = 100; // header 内容区域高度（可收缩部分）
  @State scrollOffset: number = 0; // 滚动偏移量
  @State showLoginPanel: boolean = false; // 控制登录面板显示
  @State loginPanelTab: number = 0; // 登录面板标签页：0=登录，1=更多優惠
  // 登录方式配置（从API获取）
  @State loginConfig: LoginConfig = {
    telephone_login: 1,
    telephone_register: 0,
    google_register: 1,
    facebook_register: 1,
    email_register: 1
  };
  // 门店地址
  @State storeAddress: string = '';
  // 热卖推荐列表
  @State rankList: RankProduct[] = [];
  // 会员计划
  @State memberPlan: MemberPlan | null = null;
  // 货币符号
  @State currencySymbol: string = '$';
  // 是否有多门店（显示门店选择卡片）
  @State hasMultipleStores: boolean = false;
  // 是否有登录方式（显示登录卡片）
  @State hasLoginMethods: boolean = false;
  // 骨架屏动画透明度
  @State skeletonOpacity: number = 0.3;
  // 门店选择弹窗
  @State showStoreSelectPanel: boolean = false;
  // 门店列表
  @State storeList: SchemeStore[] = [];
  // 当前选中的门店ID
  @State selectedStoreId: number = 0;
  // scheme_id（连锁品牌ID）
  private schemeId: string = '';

  // 店铺完整数据
  private homeData: HomeData | null = null;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 顶部店铺信息区域（固定）
        this.StoreHeader()

        if (this.isLoading) {
          // 加载状态
          this.LoadingView()
        } else {
          // 下方内容区域 - 使用Scroll支持滚动
          Scroll() {
            Column() {
              // 登录卡片区域 - 仅当商家配置了登录方式时显示
              if (this.hasLoginMethods) {
                this.LoginCard()
              }

              // 服务选择区域
              this.ServiceSection()

              // 会员印花卡片 - 仅当会员计划激活且开放注册时显示
              if (this.memberPlan && this.memberPlan.status === '1' && this.memberPlan.open_registration === 1) {
                this.MemberStampCard()
              }

              // 门店选择卡片 - 仅当有多门店时显示
              if (this.hasMultipleStores) {
                this.StoreSelectCard()
              }

              // 热卖推荐 - 仅当有推荐商品时显示
              if (this.rankList.length > 0) {
                this.HotProductsSection()
              }

              // 页脚
              this.Footer()
            }
          }
          .width('100%')
          .layoutWeight(1)
          .clip(true)
          .gesture(
            PanGesture({ direction: PanDirection.Vertical })
              .onActionStart(() => {
                // 手势开始
              })
              .onActionUpdate((event: GestureEvent) => {
                // 只响应下拉（正值表示向下拖动）
                if (event.offsetY > 0) {
                  // 限制最大下拉 50vp，添加阻尼效果
                  this.scrollOffset = -Math.min(event.offsetY * 0.5, 50);
                }
              })
              .onActionEnd(() => {
                // 释放时回弹
                animateTo({
                  duration: 200,
                  curve: Curve.EaseOut
                }, () => {
                  this.scrollOffset = 0;
                });
              })
          )
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      // 登录面板遮罩层
      if (this.showLoginPanel) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            this.closeLoginPanel();
          })
      }

      // 登录面板
      if (this.showLoginPanel) {
        this.LoginPanel()
      }

      // 门店选择弹窗遮罩层
      if (this.showStoreSelectPanel) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            this.closeStoreSelectPanel();
          })
      }

      // 门店选择弹窗
      if (this.showStoreSelectPanel) {
        this.StoreSelectPanel()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 加载中视图 - 骨架屏
  @Builder
  LoadingView() {
    Scroll() {
      Column() {
        // 登录卡片骨架
        Column() {
          Row() {
            Column() {
              Column()
                .width(120)
                .height(20)
                .backgroundColor('#E0E0E0')
                .borderRadius(4)
                .opacity(this.skeletonOpacity)
              Column()
                .width(100)
                .height(14)
                .backgroundColor('#E0E0E0')
                .borderRadius(4)
                .opacity(this.skeletonOpacity)
                .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column()
              .width(100)
              .height(40)
              .backgroundColor('#E0E0E0')
              .borderRadius(20)
              .opacity(this.skeletonOpacity)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })

          Divider().color('#EEEEEE').width('100%')

          Row() {
            Column()
              .width(80)
              .height(20)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
            Divider().vertical(true).height(20).color('#EEEEEE')
            Column()
              .width(80)
              .height(20)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
          }
          .width('100%')
          .height(50)
          .justifyContent(FlexAlign.SpaceAround)
        }
        .width('92%')
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .margin({ top: 16 })
        .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.08)', offsetX: 0, offsetY: 2 })

        // 服务选择区域骨架（自取/堂食）
        Row() {
          Column() {
            Column()
              .width(62)
              .height(62)
              .backgroundColor('#E0E0E0')
              .borderRadius(8)
              .opacity(this.skeletonOpacity)
            Column()
              .width(40)
              .height(16)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.08)', offsetX: 0, offsetY: 2 })

          Blank().width(12)

          Column() {
            Column()
              .width(62)
              .height(62)
              .backgroundColor('#E0E0E0')
              .borderRadius(8)
              .opacity(this.skeletonOpacity)
            Column()
              .width(40)
              .height(16)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.08)', offsetX: 0, offsetY: 2 })
        }
        .width('92%')
        .margin({ top: 16 })

        // 门店卡片骨架
        Column() {
          Row() {
            Column()
              .width(24)
              .height(24)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
            Column()
              .width(60)
              .height(18)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ bottom: 12 })

          Row() {
            Column()
              .width(20)
              .height(20)
              .backgroundColor('#E0E0E0')
              .borderRadius(10)
              .opacity(this.skeletonOpacity)
            Column() {
              Column()
                .width('80%')
                .height(16)
                .backgroundColor('#E0E0E0')
                .borderRadius(4)
                .opacity(this.skeletonOpacity)
              Column()
                .width('60%')
                .height(14)
                .backgroundColor('#E0E0E0')
                .borderRadius(4)
                .opacity(this.skeletonOpacity)
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')
        }
        .width('92%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .margin({ top: 16 })
        .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.08)', offsetX: 0, offsetY: 2 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .onAppear(() => {
      this.startSkeletonAnimation();
    })
  }

  // 骨架屏闪烁动画
  private startSkeletonAnimation(): void {
    const animate = () => {
      animateTo({
        duration: 800,
        curve: Curve.EaseInOut,
        onFinish: () => {
          if (this.isLoading) {
            animateTo({
              duration: 800,
              curve: Curve.EaseInOut,
              onFinish: () => {
                if (this.isLoading) {
                  animate();
                }
              }
            }, () => {
              this.skeletonOpacity = 0.3;
            });
          }
        }
      }, () => {
        this.skeletonOpacity = 0.6;
      });
    };
    animate();
  }

  // 店铺头部信息
  @Builder
  StoreHeader() {
    // 背景层 + 内容层
    Stack() {
      // 背景层 - 加载中使用浅灰色，加载完成后根据营业状态显示
      Column() {
        if (!this.isLoading && this.storeImage) {
          Image(this.storeImage)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .blur(20)
            .opacity(0.19)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isLoading ? '#F0F0F0' : (this.isOpen ? this.themeColor : '#DBD7D8'))

      // 内容层 - 通过固定 margin-top 避开状态栏和胶囊
      Row() {
        // 店铺图片 - 加载中显示骨架屏
        if (this.isLoading) {
          Column()
            .width(80)
            .height(80)
            .borderRadius(6)
            .backgroundColor('#E0E0E0')
            .opacity(this.skeletonOpacity)
        } else if (this.storeImage) {
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
          // 无店铺图片时显示占位图
          Image('https://spics.wantu.cn/7de3bb719f90f1b80a0b4995d69df0ca.png')
            .width(80)
            .height(80)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
        }

        // 店铺信息 - 加载中显示骨架屏
        if (this.isLoading) {
          Column() {
            Column()
              .width(140)
              .height(22)
              .backgroundColor('#E0E0E0')
              .borderRadius(4)
              .opacity(this.skeletonOpacity)
            Row() {
              Column()
                .width(50)
                .height(18)
                .backgroundColor('#E0E0E0')
                .borderRadius(4)
                .opacity(this.skeletonOpacity)
              Column()
                .width(60)
                .height(18)
                .backgroundColor('#E0E0E0')
                .borderRadius(4)
                .opacity(this.skeletonOpacity)
                .margin({ left: 8 })
            }
            .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
        } else {
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
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 16, right: 16, bottom: 10 })
      .margin({ top: this.topAvoidHeight })
    }
    .width('100%')
    .height(this.topAvoidHeight + this.headerContentHeight - this.scrollOffset)
    .borderRadius({ bottomLeft: 16, bottomRight: 16 })
    .clip(true)
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
          .onClick(() => {
            this.openLoginPanel();
          })
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
            this.openLoginPanel();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })

      // 功能入口 - 只有自取时移到服务卡片中，这里不显示
      if (this.hasDineIn || !this.hasTakeout) {
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
    if (this.hasTakeout && !this.hasDineIn && this.hasLoginMethods) {
      // 组合卡片布局：我的订单/我的优惠（上下） + 自取
      Row() {
        // 左侧功能入口（上下排列，每项图标在上文字在下）
        Column() {
          // 我的订单
          Column() {
            this.OrderIcon()
            Text('我的訂單')
              .fontSize(12)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 4 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.goToOrders();
          })

          // 分隔线
          Divider()
            .color('#EEEEEE')
            .width('80%')

          // 我的优惠
          Column() {
            this.CouponIcon()
            Text('我的優惠')
              .fontSize(12)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 4 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.goToCoupons();
          })
        }
        .layoutWeight(1)
        .height('100%')

        // 分隔线
        Divider()
          .vertical(true)
          .height('70%')
          .color('#EEEEEE')

        // 右侧自取按钮
        Column() {
          this.PickupIcon()
          Text('自取')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .opacity(this.isOpen ? 1 : 0.7)
        .onClick(() => {
          this.selectOrderType(OrderType.PICKUP);
        })
      }
      .width('92%')
      .height(140)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(12)
      .margin({ top: 16 })
      .shadow({
        radius: 4,
        color: 'rgba(0, 0, 0, 0.08)',
        offsetX: 0,
        offsetY: 2
      })
    } else {
      // 常规布局：自取和堂食并排
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
  }

  // 自取图标 - 使用图片
  @Builder
  PickupIcon() {
    Image($r('app.media.icon_pickup'))
      .width(62)
      .height(62)
      .objectFit(ImageFit.Contain)
  }

  // 堂食图标 - 使用图片
  @Builder
  DineInIcon() {
    Image($r('app.media.icon_dinein'))
      .width(62)
      .height(62)
      .objectFit(ImageFit.Contain)
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

  // 会员印花卡片 - 黄色边框样式
  @Builder
  MemberStampCard() {
    Row() {
      // 左侧星星图标 - 使用H5相同的图片
      Image($r('app.media.icon_member_star'))
        .width(44)
        .height(44)
        .objectFit(ImageFit.Contain)

      // 中间文字
      Column() {
        Text('註冊會員，消費集印花')
          .fontSize(14)
          .fontWeight(600)
          .fontColor('#000000')
        Text(this.memberPlan?.local_stamps_desc || '每1個印花換$5優惠券')
          .fontSize(10)
          .fontWeight(400)
          .fontColor('#666666')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      // 右侧 Go 按钮
      Row() {
        Text('Go')
          .fontSize(12)
          .fontWeight(500)
          .fontColor('#232323')
        Text(' >')
          .fontSize(12)
          .fontWeight(500)
          .fontColor('#232323')
      }
      .backgroundColor(this.themeColor)
      .borderRadius(16)
      .padding({ left: 14, right: 10, top: 6, bottom: 6 })
      .onClick(() => {
        this.openLoginPanel();
      })
    }
    .width('92%')
    .height(70)
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .borderRadius(12)
    .backgroundImage($r('app.media.bg_member_stamp'))
    .backgroundImageSize(ImageSize.Cover)
    .margin({ top: 12 })
  }


  // 门店选择卡片
  @Builder
  StoreSelectCard() {
    Column() {
      // 标题行 - 带门店图标
      Row() {
        // 门店图标 - 使用H5相同的图片
        Image($r('app.media.icon_store_select'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
        Text('已選門店')
          .fontSize(16)
          .fontWeight(700)
          .fontColor('#22272F')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 门店信息行
      Row() {
        // 左侧门店信息
        Column() {
          Text(this.storeName)
            .fontSize(16)
            .fontWeight(500)
            .fontColor('#232323')
          Text(this.storeAddress)
            .fontSize(11)
            .fontWeight(400)
            .fontColor('#666666')
            .margin({ top: 6 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 右侧选择按钮
        Button('選擇其他門店')
          .fontSize(11)
          .fontWeight(500)
          .fontColor('#232323')
          .backgroundColor(this.themeColor)
          .borderRadius(16)
          .height(32)
          .onClick(() => {
            this.openStoreSelectPanel();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('92%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ top: 12 })
    .shadow({
      radius: 4,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }


  // 热卖推荐区域 - 两列瀑布流布局
  @Builder
  HotProductsSection() {
    Column() {
      // 标题
      Row() {
        Text('熱賣推薦')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ top: 20, bottom: 12 })

      // 两列瀑布流布局
      Row() {
        // 左列
        Column({ space: 10 }) {
          ForEach(this.getLeftColumnItems(), (item: RankProduct) => {
            this.HotProductCard(item)
          }, (item: RankProduct) => item.product_id)
        }
        .layoutWeight(1)

        Blank().width(10)

        // 右列
        Column({ space: 10 }) {
          ForEach(this.getRightColumnItems(), (item: RankProduct) => {
            this.HotProductCard(item)
          }, (item: RankProduct) => item.product_id)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Top)
    }
  }

  // 获取左列商品（奇数索引）
  private getLeftColumnItems(): RankProduct[] {
    const items: RankProduct[] = [];
    const list = this.rankList.slice(0, 10);
    for (let i = 0; i < list.length; i += 2) {
      items.push(list[i]);
    }
    return items;
  }

  // 获取右列商品（偶数索引）
  private getRightColumnItems(): RankProduct[] {
    const items: RankProduct[] = [];
    const list = this.rankList.slice(0, 10);
    for (let i = 1; i < list.length; i += 2) {
      items.push(list[i]);
    }
    return items;
  }

  // 热卖商品卡片 - 大图样式，价格在右下角
  @Builder
  HotProductCard(item: RankProduct) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 商品图片
        if (item.product_detail?.cover_image) {
          Image(item.product_detail.cover_image)
            .width('100%')
            .height(140)
            .objectFit(ImageFit.Cover)
            .borderRadius({ topLeft: 8, topRight: 8 })
        } else {
          Column()
            .width('100%')
            .height(140)
            .backgroundColor('#F5F5F5')
            .borderRadius({ topLeft: 8, topRight: 8 })
        }

        // 商品名称
        Text(item.product_detail?.local_name || item.product_local_name)
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 8, right: 8, top: 8, bottom: 10 })
          .width('100%')
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(8)

      // 价格标签 - 右下角黄色背景
      Row() {
        Text(this.currencySymbol)
          .fontSize(10)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 2 })
        Text(parseFloat(item.product_detail?.takeout_price || item.product_detail?.price || '0').toFixed(0))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .backgroundColor(this.themeColor)
      .borderRadius({ topLeft: 12, bottomRight: 8 })
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .position({ x: '100%', y: 140 })
      .translate({ x: '-100%', y: -24 })
    }
    .width('100%')
    .onClick(() => {
      this.selectOrderType(OrderType.PICKUP);
    })
  }

  // 登录面板（底部弹出）
  @Builder
  LoginPanel() {
    Column() {
      // 顶部拖拽指示条
      Column()
        .width(40)
        .height(4)
        .backgroundColor('#E0E0E0')
        .borderRadius(2)
        .margin({ top: 12, bottom: 16 })

      // 标签栏
      Row() {
        // 建立帳號或登入
        Column() {
          Text('建立帳號或登入')
            .fontSize(16)
            .fontWeight(this.loginPanelTab === 0 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.loginPanelTab === 0 ? $r('app.color.text_primary') : $r('app.color.text_hint'))
          // 下划线指示器
          Column()
            .width(80)
            .height(2)
            .backgroundColor(this.loginPanelTab === 0 ? this.themeColor : 'transparent')
            .borderRadius(1)
            .margin({ top: 8 })
        }
        .onClick(() => {
          this.loginPanelTab = 0;
        })

        Blank().width(40)

        // 更多優惠
        Row() {
          // 礼物图标
          this.GiftIcon()
          Text('更多優惠')
            .fontSize(16)
            .fontWeight(this.loginPanelTab === 1 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.loginPanelTab === 1 ? $r('app.color.text_primary') : $r('app.color.text_hint'))
            .margin({ left: 6 })
        }
        .onClick(() => {
          this.loginPanelTab = 1;
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 20 })

      // 分隔线
      Divider()
        .color('#F0F0F0')
        .width('100%')
        .margin({ top: 12 })

      if (this.loginPanelTab === 0) {
        // 登录选项内容
        this.LoginOptions()
      } else {
        // 更多優惠内容 - 未登录时显示登录提示，已登录时显示优惠活动
        if (!this.isLoggedIn) {
          this.LoginOptions()
        } else {
          // 已登录时显示优惠活动列表
          Column() {
            Text('暫無優惠活動')
              .fontSize(15)
              .fontColor($r('app.color.text_hint'))
              .margin({ top: 60, bottom: 60 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .transition(
      TransitionEffect.translate({ y: 500 })
        .animation({ duration: 300, curve: Curve.EaseOut })
    )
  }

  // 礼物图标（更多优惠）
  @Builder
  GiftIcon() {
    Stack() {
      // 礼物盒主体
      Column()
        .width(14)
        .height(10)
        .backgroundColor(this.loginPanelTab === 1 ? this.themeColor : '#999999')
        .borderRadius({ bottomLeft: 2, bottomRight: 2 })
        .position({ x: 3, y: 10 })
      // 礼物盒盖子
      Column()
        .width(18)
        .height(5)
        .backgroundColor(this.loginPanelTab === 1 ? this.themeColor : '#999999')
        .borderRadius(2)
        .position({ x: 1, y: 5 })
      // 中间竖条装饰
      Column()
        .width(3)
        .height(15)
        .backgroundColor(this.loginPanelTab === 1 ? '#FFFFFF' : '#CCCCCC')
        .position({ x: 8.5, y: 5 })
      // 蝴蝶结左
      Column()
        .width(5)
        .height(4)
        .backgroundColor(this.loginPanelTab === 1 ? this.themeColor : '#999999')
        .borderRadius({ topLeft: 4, bottomLeft: 4 })
        .position({ x: 3, y: 1 })
      // 蝴蝶结右
      Column()
        .width(5)
        .height(4)
        .backgroundColor(this.loginPanelTab === 1 ? this.themeColor : '#999999')
        .borderRadius({ topRight: 4, bottomRight: 4 })
        .position({ x: 12, y: 1 })
    }
    .width(20)
    .height(20)
  }

  // 邮件图标 - 蓝色信封
  @Builder
  EmailIcon() {
    Stack({ alignContent: Alignment.Center }) {
      // 信封主体
      Column()
        .width(22)
        .height(16)
        .backgroundColor('transparent')
        .border({ width: 2, color: '#4A90D9' })
        .borderRadius(3)
      // 信封V形折线
      Column()
        .width(12)
        .height(2)
        .backgroundColor('#4A90D9')
        .position({ x: 5, y: 5 })
        .rotate({ angle: 20, centerX: '0%', centerY: '50%' })
      Column()
        .width(12)
        .height(2)
        .backgroundColor('#4A90D9')
        .position({ x: 5, y: 5 })
        .rotate({ angle: -20, centerX: '100%', centerY: '50%' })
    }
    .width(24)
    .height(24)
  }

  // Google图标 - 彩色G
  @Builder
  GoogleIcon() {
    Stack({ alignContent: Alignment.Center }) {
      // 白色圆形背景
      Column()
        .width(24)
        .height(24)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
      // Google G字母 - 使用多色渐变效果的简化版
      Text('G')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#EA4335') // Google红色
    }
    .width(24)
    .height(24)
  }

  // Facebook图标 - 圆形蓝底白色f
  @Builder
  FacebookIcon() {
    Stack({ alignContent: Alignment.Center }) {
      // 蓝色圆形背景
      Column()
        .width(24)
        .height(24)
        .backgroundColor('#1877F2')
        .borderRadius(12)
      // Facebook f字母
      Text('f')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .width(24)
    .height(24)
  }

  // 登录选项（根据API配置动态显示）
  @Builder
  LoginOptions() {
    Column() {
      // 电邮登录按钮
      if (this.loginConfig.email_register === 1) {
        Button() {
          Row() {
            this.EmailIcon()
            Text('使用電郵地址繼續')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E0E0E0' })
        .borderRadius(24)
        .margin({ top: 20 })
        .onClick(() => {
          this.loginWithEmail();
        })
      }

      // Google登录按钮
      if (this.loginConfig.google_register === 1) {
        Button() {
          Row() {
            this.GoogleIcon()
            Text('使用谷歌帳戶繼續')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.themeColor)
        .borderRadius(24)
        .margin({ top: 12 })
        .onClick(() => {
          this.loginWithGoogle();
        })
      }

      // Facebook登录按钮
      if (this.loginConfig.facebook_register === 1) {
        Button() {
          Row() {
            this.FacebookIcon()
            Text('使用Facebook繼續')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#1877F2')
        .borderRadius(24)
        .margin({ top: 12 })
        .onClick(() => {
          this.loginWithFacebook();
        })
      }

      // 提示文字
      Text('登入享更多優惠')
        .fontSize(13)
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 16 })

      // 手机号登录（如果启用）
      if (this.loginConfig.telephone_login === 1) {
        // 分隔线 "或"
        Row() {
          Divider()
            .color('#E0E0E0')
            .layoutWeight(1)
          Text('或')
            .fontSize(13)
            .fontColor($r('app.color.text_hint'))
            .margin({ left: 16, right: 16 })
          Divider()
            .color('#E0E0E0')
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 16 })

        // 手机号登录按钮
        Button() {
          Text('手機號登入')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(48)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E0E0E0' })
        .borderRadius(24)
        .margin({ top: 16 })
        .onClick(() => {
          this.loginWithPhone();
        })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 40 })
  }

  // 门店选择弹窗
  @Builder
  StoreSelectPanel() {
    Column() {
      // 顶部拖拽指示条
      Column()
        .width(40)
        .height(4)
        .backgroundColor('#E0E0E0')
        .borderRadius(2)
        .margin({ top: 12, bottom: 16 })

      // 标题栏
      Row() {
        // 关闭按钮
        Text('✕')
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.closeStoreSelectPanel();
          })

        Text('選擇門店')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位，保持标题居中
        Column()
          .width(24)
          .height(24)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 分隔线
      Divider()
        .color('#F0F0F0')
        .width('100%')
        .margin({ top: 16 })

      // 门店列表
      Scroll() {
        Column() {
          ForEach(this.storeList, (store: SchemeStore) => {
            this.StoreListItem(store)
          }, (store: SchemeStore) => store.store_id.toString())
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('50%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .transition(
      TransitionEffect.translate({ y: 500 })
        .animation({ duration: 300, curve: Curve.EaseOut })
    )
  }

  // 门店列表项
  @Builder
  StoreListItem(store: SchemeStore) {
    Row() {
      // 门店图标
      Image($r('app.media.icon_store_select'))
        .width(32)
        .height(32)
        .objectFit(ImageFit.Contain)

      // 门店信息
      Column() {
        Text(store.local_name || store.name)
          .fontSize(16)
          .fontWeight(500)
          .fontColor($r('app.color.text_primary'))

        Text(store.address)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      // 选中指示器
      if (store.store_id === this.selectedStoreId) {
        Column()
          .width(20)
          .height(20)
          .backgroundColor(this.themeColor)
          .borderRadius(10)
      } else {
        Column()
          .width(20)
          .height(20)
          .border({ width: 2, color: '#E0E0E0' })
          .borderRadius(10)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(store.store_id === this.selectedStoreId ? '#FFF9E6' : '#FFFFFF')
    .onClick(() => {
      this.selectStore(store);
    })
  }

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Store home page loading...');
    this.getTopAvoidHeight();
    this.loadStoreData();
  }

  /**
   * 获取顶部安全区域高度（状态栏+元服务胶囊）
   */
  private getTopAvoidHeight(): void {
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const height = px2vp(avoidArea.topRect.height);
        // 确保高度在合理范围内（元服务胶囊通常 40-80vp）
        this.topAvoidHeight = Math.max(height, 100);
        hilog.info(DOMAIN, TAG, 'Top avoid height: %{public}f', this.topAvoidHeight);
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get avoid height error: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 加载店铺数据
   */
  private async loadStoreData(): Promise<void> {
    try {
      // 设置店铺ID（可从路由参数获取）
      apiService.setStoreId(ApiConfig.DEFAULT_STORE_ID);

      // 获取首页数据
      const homeResponse = await apiService.getHomeData();

      // 处理首页数据
      if (homeResponse.code === 200 && homeResponse.data) {
        this.homeData = homeResponse.data;
        this.updateUIFromData(homeResponse.data);
        hilog.info(DOMAIN, TAG, 'Store data loaded successfully');
      } else {
        hilog.error(DOMAIN, TAG, 'Failed to load store data: %{public}s', homeResponse.msg);
        this.setDefaultData();
      }

      // 获取会员计划
      this.loadMemberPlan();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error loading store data: %{public}s', JSON.stringify(error));
      this.setDefaultData();
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载会员计划数据
   */
  private async loadMemberPlan(): Promise<void> {
    try {
      const memberResponse = await apiService.getMemberPlan();
      if (memberResponse.code === 200 && memberResponse.data?.member_plan) {
        this.memberPlan = memberResponse.data.member_plan;
        // 判断是否有多门店：如果 member_plan.store_id === "0"，说明是连锁店（计划适用于所有门店）
        // scheme_id 存在且 store_id 为 "0" 表示这是连锁品牌的会员计划
        if (this.memberPlan.scheme_id && this.memberPlan.store_id === '0') {
          this.hasMultipleStores = true;
          this.schemeId = this.memberPlan.scheme_id;
          hilog.info(DOMAIN, TAG, 'Multiple stores detected: scheme_id=%{public}s', this.memberPlan.scheme_id);
        }
        hilog.info(DOMAIN, TAG, 'Member plan loaded: %{public}s, open_registration=%{public}d',
          this.memberPlan.title, this.memberPlan.open_registration);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error loading member plan: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 加载连锁门店列表
   */
  private async loadSchemeStores(): Promise<void> {
    if (!this.schemeId) {
      hilog.warn(DOMAIN, TAG, 'No scheme_id available');
      return;
    }

    try {
      const response = await apiService.getSchemeStores(this.schemeId);
      if (response.code === 200 && response.data?.stores) {
        this.storeList = response.data.stores;
        // 设置当前选中的门店
        this.selectedStoreId = parseInt(ApiConfig.DEFAULT_STORE_ID);
        hilog.info(DOMAIN, TAG, 'Scheme stores loaded: %{public}d stores', this.storeList.length);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error loading scheme stores: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 打开门店选择弹窗
   */
  private openStoreSelectPanel(): void {
    // 加载门店列表
    this.loadSchemeStores();

    animateTo({
      duration: 300,
      curve: Curve.EaseOut
    }, () => {
      this.showStoreSelectPanel = true;
    });
  }

  /**
   * 关闭门店选择弹窗
   */
  private closeStoreSelectPanel(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseIn
    }, () => {
      this.showStoreSelectPanel = false;
    });
  }

  /**
   * 选择门店
   */
  private selectStore(store: SchemeStore): void {
    if (store.store_id === this.selectedStoreId) {
      // 已选中，直接关闭
      this.closeStoreSelectPanel();
      return;
    }

    hilog.info(DOMAIN, TAG, 'Switching to store: %{public}d - %{public}s',
      store.store_id, store.local_name || store.name);

    // 更新选中状态
    this.selectedStoreId = store.store_id;

    // 关闭弹窗
    this.closeStoreSelectPanel();

    // 切换门店：重新设置 store_id 并刷新数据
    this.isLoading = true;
    apiService.setStoreId(store.store_id.toString());

    // 重新加载首页数据
    this.loadStoreData();
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

    // 营业状态 - 根据 is_close 和 is_service 判断
    // is_close: 0=营业, 1=休息
    // is_service: true=服务中, false=非服务中
    const isService = config.is_service !== false;
    this.isOpen = config.is_close !== 1 && isService;

    if (this.isOpen) {
      this.storeStatus = '營業中';
      this.todayStatus = '';
    } else {
      this.storeStatus = '商家休息中';
      this.todayStatus = '今日休業';
    }

    // 服务类型
    this.hasDineIn = config.dinein === 1;
    this.hasTakeout = config.takeout === 1;

    // 公告
    if (data.notice && data.notice.length > 0) {
      this.notices = data.notice.map(n => n.local_name);
    }

    // 登录方式配置
    if (config.login) {
      this.loginConfig = {
        telephone_login: config.login.telephone_login || 0,
        telephone_register: config.login.telephone_register || 0,
        google_register: config.login.google_register || 0,
        facebook_register: config.login.facebook_register || 0,
        email_register: config.login.email_register || 0
      };
      // 判断是否有任意登录方式启用
      this.hasLoginMethods = (
        this.loginConfig.telephone_login === 1 ||
        this.loginConfig.google_register === 1 ||
        this.loginConfig.facebook_register === 1 ||
        this.loginConfig.email_register === 1
      );
      hilog.info(DOMAIN, TAG, 'Login config loaded: email=%{public}d, google=%{public}d, facebook=%{public}d, phone=%{public}d, hasLoginMethods=%{public}s',
        this.loginConfig.email_register, this.loginConfig.google_register,
        this.loginConfig.facebook_register, this.loginConfig.telephone_login, this.hasLoginMethods ? 'true' : 'false');
    }

    // 门店地址
    this.storeAddress = config.address || '';

    // 热卖推荐
    if (data.rank_list && data.rank_list.length > 0) {
      this.rankList = data.rank_list;
      hilog.info(DOMAIN, TAG, 'Rank list loaded: %{public}d items', this.rankList.length);
    }

    // 货币符号
    if (data.currency?.symbol_left) {
      this.currencySymbol = data.currency.symbol_left;
    }

    // 连锁门店信息
    if (data.scheme_stores && data.scheme_stores.scheme_id) {
      this.hasMultipleStores = true;
      this.schemeId = data.scheme_stores.scheme_id;
      this.storeList = data.scheme_stores.stores || [];
      this.selectedStoreId = parseInt(ApiConfig.DEFAULT_STORE_ID);
      hilog.info(DOMAIN, TAG, 'Scheme stores loaded from home: scheme_id=%{public}s, stores=%{public}d',
        this.schemeId, this.storeList.length);
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
   * 跳转到订单列表（历史订单）
   */
  private goToOrders(): void {
    hilog.info(DOMAIN, TAG, 'Go to orders');
    router.pushUrl({
      url: 'pages/MenuPage',
      params: {
        orderType: OrderType.PICKUP,
        themeColor: this.themeColor,
        storeId: ApiConfig.DEFAULT_STORE_ID,
        storeName: this.storeName,
        storeImage: this.storeImage,
        storeStatus: this.storeStatus,
        todayStatus: this.todayStatus,
        isOpen: this.isOpen,
        notices: this.notices,
        initialTab: 2  // 历史订单Tab
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Router error: %{public}s', err.message);
    });
  }

  /**
   * 跳转到优惠券列表
   */
  private goToCoupons(): void {
    hilog.info(DOMAIN, TAG, 'Go to coupons');
    router.pushUrl({
      url: 'pages/CouponPage',
      params: {
        themeColor: this.themeColor,
        isLoggedIn: this.isLoggedIn
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Router error: %{public}s', err.message);
    });
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
   * 打开登录面板
   */
  private openLoginPanel(): void {
    animateTo({
      duration: 300,
      curve: Curve.EaseOut
    }, () => {
      this.showLoginPanel = true;
      this.loginPanelTab = 0;
    });
  }

  /**
   * 关闭登录面板
   */
  private closeLoginPanel(): void {
    animateTo({
      duration: 200,
      curve: Curve.EaseIn
    }, () => {
      this.showLoginPanel = false;
    });
  }

  /**
   * 电邮登录
   */
  private loginWithEmail(): void {
    hilog.info(DOMAIN, TAG, 'Login with email');
    // TODO: 跳转到电邮登录页面
    this.closeLoginPanel();
  }

  /**
   * Google登录
   */
  private loginWithGoogle(): void {
    hilog.info(DOMAIN, TAG, 'Login with Google');
    // TODO: 实现Google登录
    this.closeLoginPanel();
  }

  /**
   * Facebook登录
   */
  private loginWithFacebook(): void {
    hilog.info(DOMAIN, TAG, 'Login with Facebook');
    // TODO: 实现Facebook登录
    this.closeLoginPanel();
  }

  /**
   * 手机号登录
   */
  private loginWithPhone(): void {
    hilog.info(DOMAIN, TAG, 'Login with phone');
    // TODO: 跳转到手机号登录页面
    this.closeLoginPanel();
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
