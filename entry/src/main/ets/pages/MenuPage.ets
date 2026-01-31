import { hilog } from '@kit.PerformanceAnalysisKit';
import { router, window } from '@kit.ArkUI';
import { apiService } from '../services/ApiService';
import {
  appState,
  CartItem,
  CartItemInput,
  CartPackageSelection,
  CartPackageItem,
  CartPolicySelection,
  CartPolicyItem,
  CartCondiment
} from '../services/AppStorage';
import {
  ProductGroup,
  Product,
  OrderType,
  HomeData,
  Order,
  OrderItem,
  OrderFilterType,
  MenuGroup,
  ProductDetail,
  PackageGroup,
  PackageItem,
  PolicyGroupData,
  PolicyGroup,
  PolicyGroupItem,
  CondimentGroupDetail,
  CondimentItemDetail
} from '../models/StoreModels';

const DOMAIN = 0x0000;
const TAG = 'MenuPage';

/**
 * 已确认的加送商品选择
 */
interface ConfirmedPolicySelection {
  item: PolicyGroupItem;
  priceIndex: number;
  priceName: string;
  condiments: Map<string, CondimentSelection>;  // condimentGroupId -> selection
}

interface CondimentSelection {
  groupName: string;
  itemId: string;
  itemName: string;
  price: number;
}

@Entry
@Component
struct MenuPage {
  @State isLoading: boolean = true;
  @State productGroups: ProductGroup[] = [];
  @State allProductGroups: ProductGroup[] = [];  // 所有分组（未过滤）
  @State menuGroups: MenuGroup[] = [];           // 顶级菜单分组
  @State selectedMenuGroupIndex: number = 0;     // 当前选中的顶级分组
  @State currentShowType: string = '2';          // 当前展示类型: "1"=小图 "2"=大图
  @State selectedGroupIndex: number = 0;
  @State orderType: OrderType = OrderType.PICKUP;
  @State themeColor: string = '#FFD700';
  @State currencySymbol: string = '$';

  // 店铺信息状态
  @State storeName: string = '';
  @State storeImage: string = '';
  @State storeStatus: string = '';
  @State todayStatus: string = '';
  @State isOpen: boolean = true;
  @State notices: string[] = [];
  @State currentTab: number = 1; // 0=主頁, 1=點餐, 2=歷史訂單
  @State currentLang: string = '繁';
  @State showNoticeExpand: boolean = false;
  @State topSafeHeight: number = 0; // 顶部安全距离（避开胶囊）

  // 订单相关状态
  @State orders: Order[] = [];
  @State orderTotal: number = 0;
  @State orderFilterType: OrderFilterType = OrderFilterType.ALL;
  @State isOrderLoading: boolean = false;
  @State orderPageNumber: number = 1;
  @State showFilterDropdown: boolean = false;
  @State hasMoreOrders: boolean = true;

  // 产品详情弹窗相关状态
  @State showProductDetail: boolean = false;
  @State selectedProduct: ProductDetail | null = null;
  @State isDetailLoading: boolean = false;
  @State selectedPriceIndex: number = 0;              // 选中的规格索引
  @State selectedPackageItems: Map<string, Set<string>> = new Map();  // 配料选择: groupId -> Set<productId>
  @State quantity: number = 1;                         // 购买数量
  @State policyGroups: PolicyGroup[] = [];            // 加送选择数据（来自policy API）
  // 加送商品配料选择弹窗状态
  @State showCondimentSheet: boolean = false;         // 是否显示配料选择弹窗
  @State selectedPolicyItem: PolicyGroupItem | null = null;  // 当前选中的加送商品
  @State selectedPolicyGroupId: string = '';          // 当前选中的加送组ID
  @State selectedCondimentItems: Map<string, string> = new Map();  // 配料选择: condimentGroupId -> condimentItemId
  @State selectedPolicyPriceIndex: number = 0;        // 加送商品的规格选择索引（prices数组）
  // 保存已确认的加送商品选择（包括规格和配料）: groupId -> { item, priceIndex, condiments }
  @State confirmedPolicySelections: Map<string, ConfirmedPolicySelection> = new Map();
  // 主商品配料选择（甜度、冰量等）: condimentGroupId -> condimentItemId
  @State selectedProductCondiments: Map<string, string> = new Map();

  // 购物车状态
  @State cartCount: number = 0;                       // 购物车商品数量
  @State cartTotal: number = 0;                       // 购物车总价
  @State showCartPopup: boolean = false;              // 购物车弹窗是否显示

  private detailScroller: Scroller = new Scroller();

  private scroller: Scroller = new Scroller();
  private categoryScroller: Scroller = new Scroller();
  private orderScroller: Scroller = new Scroller();

  build() {
    Stack() {
      // 主内容层
      Column() {
        // 顶部店铺信息区域（包含安全距离）
        this.StoreHeader()

        // 公告栏
        if (this.notices.length > 0) {
          this.NoticeBar()
        }

        // Tab 导航 + 服务类型 + 语言切换
        this.TabBar()

        // 顶级菜单分组导航条（仅在点餐Tab且有多个分类时显示）
        if (this.currentTab === 1 && this.shouldShowMenuGroupBar()) {
          this.MenuGroupBar()
        }

        // 根据当前Tab显示不同内容
        if (this.currentTab === 2) {
          // 历史订单
          this.OrderHistoryView()
        } else if (this.isLoading) {
          this.LoadingView()
        } else {
          Row() {
            // 左侧分类列表
            this.CategoryList()

            // 右侧产品列表
            this.ProductList()
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 购物车弹窗（在悬浮栏下层）
      if (this.showCartPopup && this.currentTab === 1) {
        this.CartPopup()
      }

      // 购物车悬浮栏（仅在点餐Tab且有商品时显示，始终在最上层）
      if (this.currentTab === 1 && this.cartCount > 0) {
        this.CartBottomBar()
      }

      // 产品详情弹窗层
      if (this.showProductDetail) {
        this.ProductDetailSheet()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 店铺头部信息（包含顶部安全距离）
  @Builder
  StoreHeader() {
    Stack() {
      // 背景层 - 店铺图片毛玻璃效果
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

      // 内容层
      Column() {
        Row() {
          // 返回按钮
          Text('‹')
            .width(32)
            .height(32)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .margin({ left: 8, top: 12 })
            .onClick(() => {
              router.back();
            })

          // 店铺图片
          Column() {
            if (this.storeImage) {
              Image(this.storeImage)
                .width(80)
                .height(80)
                .borderRadius(10)
                .objectFit(ImageFit.Cover)
                .shadow({
                  radius: 6,
                  color: 'rgba(0, 0, 0, 0.15)',
                  offsetX: 0,
                  offsetY: 3
                })
            } else {
              Image($r('app.media.startIcon'))
                .width(80)
                .height(80)
                .borderRadius(10)
                .objectFit(ImageFit.Cover)
                .shadow({
                  radius: 6,
                  color: 'rgba(0, 0, 0, 0.15)',
                  offsetX: 0,
                  offsetY: 3
                })
            }
          }
          .margin({ left: 8, top: 12 })

          // 店铺信息
          Column() {
            // 店铺名称
            Text(this.storeName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            // 状态标签行
            Row() {
              // 商家状态标签
              if (this.storeStatus) {
                Text(this.storeStatus)
                  .fontSize(11)
                  .fontColor('#666666')
                  .backgroundColor('#EEEEEE')
                  .borderRadius(3)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              }

              // 今日状态标签
              if (this.todayStatus) {
                Text(this.todayStatus)
                  .fontSize(11)
                  .fontColor('#666666')
                  .backgroundColor('#EEEEEE')
                  .borderRadius(3)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .margin({ left: 6 })
              }

              // 关于商户按钮
              Row() {
                Text('關於商戶')
                  .fontSize(11)
                  .fontColor('#666666')
                Text(' ⓘ')
                  .fontSize(10)
                  .fontColor('#999999')
              }
              .backgroundColor('#FFFFFF')
              .borderRadius(3)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .border({ width: 0.5, color: '#DDDDDD' })
              .margin({ left: 6 })
              .onClick(() => {
                this.showStoreInfo();
              })
            }
            .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12, top: 16 })
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .padding({ top: this.topSafeHeight + 8, bottom: 12 })
    }
    .width('100%')
    .height(this.topSafeHeight + 120)
  }

  // 公告栏
  @Builder
  NoticeBar() {
    Row() {
      // 公告标签
      Text('公告:')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ left: 12 })

      // 公告内容
      Text(this.notices.join(' | '))
        .fontSize(13)
        .fontColor('#666666')
        .maxLines(this.showNoticeExpand ? 10 : 1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 6, right: 8 })

      // 展开箭头
      Text(this.showNoticeExpand ? '▲' : '▼')
        .fontSize(10)
        .fontColor('#999999')
        .margin({ right: 12 })
        .onClick(() => {
          this.showNoticeExpand = !this.showNoticeExpand;
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .backgroundColor('#FFFACD')
    .alignItems(VerticalAlign.Center)
  }

  // 顶级菜单分组横向导航条
  @Builder
  MenuGroupBar() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.menuGroups, (menuGroup: MenuGroup, index: number) => {
          Text(menuGroup.local_name)
            .fontSize(14)
            .fontWeight(this.selectedMenuGroupIndex === index ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.selectedMenuGroupIndex === index ? '#333333' : '#666666')
            .backgroundColor(this.selectedMenuGroupIndex === index ? this.themeColor : '#FFFFFF')
            .borderRadius(16)
            .border({
              width: 1,
              color: this.themeColor
            })
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .opacity(menuGroup.can_order === 1 ? 1 : 0.6)
            .onClick(() => {
              this.onMenuGroupSelect(index);
            })
        })
      }
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Start)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .width('100%')
    .height(48)
    .backgroundColor('#FFFFFF')
  }

  /**
   * 判断是否显示顶级分类导航条
   */
  private shouldShowMenuGroupBar(): boolean {
    // 没有分类或只有一个分类时不显示
    return this.menuGroups.length > 1;
  }

  // Tab 导航栏 + 服务类型 + 语言切换（合并为一行）
  @Builder
  TabBar() {
    Row() {
      // 左侧：Tab 导航（左对齐）
      Row() {
        // 主頁 Tab
        Column() {
          Text('主頁')
            .fontSize(15)
            .fontColor(this.currentTab === 0 ? '#333333' : '#999999')
            .fontWeight(this.currentTab === 0 ? FontWeight.Medium : FontWeight.Normal)
          if (this.currentTab === 0) {
            Column()
              .width(24)
              .height(2)
              .backgroundColor(this.themeColor)
              .borderRadius(1)
              .margin({ top: 4 })
          }
        }
        .height(44)
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        // 點餐 Tab
        Column() {
          Text('點餐')
            .fontSize(15)
            .fontColor(this.currentTab === 1 ? '#333333' : '#999999')
            .fontWeight(this.currentTab === 1 ? FontWeight.Medium : FontWeight.Normal)
          if (this.currentTab === 1) {
            Column()
              .width(24)
              .height(2)
              .backgroundColor(this.themeColor)
              .borderRadius(1)
              .margin({ top: 4 })
          }
        }
        .height(44)
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.currentTab = 1;
          // 如果菜单还未加载，则加载
          if (this.productGroups.length === 0 && !this.isLoading) {
            this.loadMenuData();
          }
        })

        // 歷史訂單 Tab
        Column() {
          Text('歷史訂單')
            .fontSize(15)
            .fontColor(this.currentTab === 2 ? '#333333' : '#999999')
            .fontWeight(this.currentTab === 2 ? FontWeight.Medium : FontWeight.Normal)
          if (this.currentTab === 2) {
            Column()
              .width(42)
              .height(2)
              .backgroundColor(this.themeColor)
              .borderRadius(1)
              .margin({ top: 4 })
          }
        }
        .height(44)
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.currentTab = 2;
          hilog.info(DOMAIN, TAG, 'Navigate to order history');
          this.loadOrders();
        })
      }

      Blank()

      // 右侧：外卖自取 + 语言切换（匹配H5样式）
      Row() {
        // 外卖自取按钮（图标+文字垂直布局）
        Column() {
          // 使用文字图标（盒子符号）
          Text('📦')
            .fontSize(16)
          Text(this.orderType === OrderType.PICKUP ? '外賣自取' : '堂食')
            .fontSize(9)
            .fontColor('#666666')
            .margin({ top: 2 })
        }
        .width(50)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          hilog.info(DOMAIN, TAG, 'Order type: %{public}s',
            this.orderType === OrderType.PICKUP ? '外賣自取' : '堂食');
        })

        // 语言切换按钮（文字+Language垂直布局）
        Column() {
          Text(this.currentLang)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Text('Language')
            .fontSize(8)
            .fontColor('#999999')
            .margin({ top: 1 })
        }
        .width(50)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.currentLang = this.currentLang === '繁' ? '简' : '繁';
          hilog.info(DOMAIN, TAG, 'Switch language to: %{public}s', this.currentLang);
        })
      }
      .padding({ right: 4 })
    }
    .width('100%')
    .height(46)
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
  }

  // 加载中
  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color(this.themeColor)
      Text('載入菜單中...')
        .fontSize(13)
        .fontColor('#999999')
        .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // 左侧分类列表
  @Builder
  CategoryList() {
    List({ scroller: this.categoryScroller }) {
      ForEach(this.productGroups, (group: ProductGroup, index: number) => {
        ListItem() {
          Row() {
            // 选中指示条
            if (this.selectedGroupIndex === index) {
              Column()
                .width(3)
                .height(18)
                .backgroundColor(this.themeColor)
                .borderRadius(1.5)
            }
            Text(group.local_name)
              .fontSize(13)
              .fontColor(this.selectedGroupIndex === index ? '#333333' : '#666666')
              .fontWeight(this.selectedGroupIndex === index ? FontWeight.Medium : FontWeight.Normal)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Start)
              .layoutWeight(1)
              .margin({ left: this.selectedGroupIndex === index ? 6 : 9 })
          }
          .width('100%')
          .height(48)
          .alignItems(VerticalAlign.Center)
          .padding({ right: 6 })
          .backgroundColor(this.selectedGroupIndex === index ? '#FFFFFF' : 'transparent')
          .onClick(() => {
            this.selectedGroupIndex = index;
            // 滚动到对应分组
            this.scroller.scrollToIndex(this.getProductListIndexForGroup(index));
          })
        }
      })

      // 底部占位，为购物车悬浮卡片留出空间
      if (this.cartCount > 0) {
        ListItem() {
          Column()
            .width('100%')
            .height(66)
        }
      }
    }
    .width(85)
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // 右侧产品列表
  @Builder
  ProductList() {
    List({ scroller: this.scroller }) {
      ForEach(this.productGroups, (group: ProductGroup, groupIndex: number) => {
        // 分组标题
        ListItem() {
          Row() {
            Text(group.local_name)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')

            Blank()

            // 供应时间（右对齐，灰色小字）
            Text(group.time_range ? `供應時間${group.time_range}` : '供應時間-')
              .fontSize(11)
              .fontColor('#999999')
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 14, bottom: 6 })
        }

        // 产品列表
        ForEach(group.products, (product: Product) => {
          ListItem() {
            if (this.currentShowType === '2') {
              this.ProductItemLarge(product)
            } else {
              this.ProductItemSmall(product)
            }
          }
        })
      })

      // 底部占位，为购物车悬浮卡片留出空间
      if (this.cartCount > 0) {
        ListItem() {
          Column()
            .width('100%')
            .height(66)
        }
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor('#F5F5F5')
    .onScrollIndex((firstIndex: number) => {
      // 更新选中的分类
      let currentGroup = 0;
      let itemCount = 0;
      for (let i = 0; i < this.productGroups.length; i++) {
        if (firstIndex <= itemCount) {
          currentGroup = i;
          break;
        }
        itemCount += this.productGroups[i].products.length + 1;
        currentGroup = i;
      }
      if (this.selectedGroupIndex !== currentGroup) {
        this.selectedGroupIndex = currentGroup;
        // 同步滚动左侧分类列表
        this.categoryScroller.scrollToIndex(currentGroup);
      }
    })
  }

  // 产品项 - 大图模式 (show_type = "2")
  @Builder
  ProductItemLarge(product: Product) {
    Column() {
      // 产品图片（大图，宽度填满）
      if (product.cover_image) {
        Image(product.cover_image)
          .width('100%')
          .height(180)
          .borderRadius({ topLeft: 8, topRight: 8 })
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width('100%')
          .height(180)
          .borderRadius({ topLeft: 8, topRight: 8 })
          .backgroundColor('#EEEEEE')
      }

      // 产品信息区域
      Column() {
        // 产品名称 + 點選按钮
        Row() {
          Text(product.local_name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          // 點選按钮
          Text('點選')
            .fontSize(13)
            .fontColor('#666666')
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .border({ width: 1, color: '#E5E5E5' })
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .onClick(() => {
              this.openProductDetail(product);
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 产品描述/标签
        if (product.description?.local_description) {
          Text(product.description.local_description)
            .fontSize(12)
            .fontColor('#999999')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
        }

        // 价格
        Row() {
          Text(this.currencySymbol)
            .fontSize(14)
            .fontColor('#C4A000')
          Text(this.getPrice(product))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#C4A000')
          if (this.hasMultipleSpecs(product)) {
            Text('起')
              .fontSize(12)
              .fontColor('#C4A000')
              .margin({ left: 2 })
          }
        }
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .padding(12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ top: 8, left: 8, right: 8 })
    .onClick(() => {
      this.openProductDetail(product);
    })
  }

  // 产品项 - 小图模式 (show_type = "1")
  @Builder
  ProductItemSmall(product: Product) {
    Row() {
      // 产品图片（小图）
      if (product.cover_image) {
        Image(product.cover_image)
          .width(70)
          .height(70)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(70)
          .height(70)
          .borderRadius(6)
          .backgroundColor('#EEEEEE')
      }

      // 产品信息
      Column() {
        // 产品名称
        Text(product.local_name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        // 价格行
        Row() {
          Text(this.currencySymbol)
            .fontSize(13)
            .fontColor('#C4A000')
          Text(this.getPrice(product))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#C4A000')
          if (this.hasMultipleSpecs(product)) {
            Text(' 起')
              .fontSize(11)
              .fontColor('#C4A000')
          }
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .layoutWeight(1)
      .height(70)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ left: 12 })

      // 點選按钮
      Text('點選')
        .fontSize(13)
        .fontColor('#666666')
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: '#E5E5E5' })
        .padding({ left: 12, right: 12, top: 5, bottom: 5 })
        .onClick(() => {
          this.openProductDetail(product);
        })
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ top: 6, left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openProductDetail(product);
    })
  }

  // ==================== 历史订单相关组件 ====================

  // 历史订单主视图
  @Builder
  OrderHistoryView() {
    Column() {
      // 筛选栏
      this.OrderFilterBar()

      if (this.isOrderLoading && this.orders.length === 0) {
        // 初次加载中
        this.OrderLoadingView()
      } else if (this.orders.length === 0) {
        // 空状态
        this.OrderEmptyView()
      } else {
        // 订单列表
        this.OrderListView()
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#F5F5F5')
  }

  // 订单筛选栏
  @Builder
  OrderFilterBar() {
    Row() {
      Blank()

      // 筛选下拉框
      Row() {
        Text(this.getFilterLabel())
          .fontSize(14)
          .fontColor('#333333')
        Text(' ▼')
          .fontSize(10)
          .fontColor('#666666')
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')
      .borderRadius(4)
      .border({ width: 0.5, color: '#E5E5E5' })
      .onClick(() => {
        this.showFilterDropdown = !this.showFilterDropdown;
      })
      .bindMenu(this.showFilterDropdown, [
        {
          value: '全部訂單',
          action: () => {
            this.onFilterChange(OrderFilterType.ALL);
          }
        },
        {
          value: '進行中',
          action: () => {
            this.onFilterChange(OrderFilterType.IN_PROGRESS);
          }
        },
        {
          value: '已完成',
          action: () => {
            this.onFilterChange(OrderFilterType.COMPLETED);
          }
        },
        {
          value: '退款/取消',
          action: () => {
            this.onFilterChange(OrderFilterType.REFUND);
          }
        }
      ])
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
  }

  // 订单加载中
  @Builder
  OrderLoadingView() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color(this.themeColor)
      Text('載入訂單中...')
        .fontSize(13)
        .fontColor('#999999')
        .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // 订单空状态
  @Builder
  OrderEmptyView() {
    Column() {
      Text('📋')
        .fontSize(60)
        .margin({ bottom: 16 })

      Text('暫無訂單')
        .fontSize(16)
        .fontColor('#999999')
        .margin({ bottom: 24 })

      // 登录/注册按钮（未登录时显示）
      Button('登入/註冊')
        .width(140)
        .height(44)
        .fontSize(15)
        .fontColor('#333333')
        .backgroundColor(this.themeColor)
        .borderRadius(22)
        .onClick(() => {
          hilog.info(DOMAIN, TAG, 'Navigate to login');
          // TODO: 跳转到登录页面
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // 订单列表
  @Builder
  OrderListView() {
    List({ scroller: this.orderScroller }) {
      ForEach(this.orders, (order: Order) => {
        ListItem() {
          this.OrderCard(order)
        }
      })

      // 加载更多
      if (this.hasMoreOrders) {
        ListItem() {
          Row() {
            if (this.isOrderLoading) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color(this.themeColor)
              Text('載入更多...')
                .fontSize(13)
                .fontColor('#999999')
                .margin({ left: 8 })
            } else {
              Text('上拉加載更多')
                .fontSize(13)
                .fontColor('#999999')
            }
          }
          .width('100%')
          .height(50)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .onReachEnd(() => {
      if (this.hasMoreOrders && !this.isOrderLoading) {
        this.loadMoreOrders();
      }
    })
  }

  // 订单卡片
  @Builder
  OrderCard(order: Order) {
    Column() {
      // 顶部：订单号 + 状态
      Row() {
        Text(`訂單號: ${order.order_no}`)
          .fontSize(13)
          .fontColor('#666666')

        Blank()

        // 状态标签
        Text(this.getStatusText(order.status))
          .fontSize(12)
          .fontColor(this.getStatusColor(order.status))
          .backgroundColor(this.getStatusBgColor(order.status))
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 订单类型 + 时间
      Row() {
        Text(order.order_type === 1 ? '外賣自取' : '堂食')
          .fontSize(12)
          .fontColor('#999999')

        Text(' | ')
          .fontSize(12)
          .fontColor('#E5E5E5')

        Text(order.created_at)
          .fontSize(12)
          .fontColor('#999999')
      }
      .margin({ bottom: 12 })

      // 商品列表（最多显示3个）
      ForEach(order.items.slice(0, 3), (item: OrderItem) => {
        Row() {
          // 商品图片
          if (item.cover_image) {
            Image(item.cover_image)
              .width(50)
              .height(50)
              .borderRadius(4)
              .objectFit(ImageFit.Cover)
          } else {
            Column()
              .width(50)
              .height(50)
              .borderRadius(4)
              .backgroundColor('#EEEEEE')
          }

          // 商品信息
          Column() {
            Text(item.local_name)
              .fontSize(14)
              .fontColor('#333333')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (item.specifications) {
              Text(item.specifications)
                .fontSize(12)
                .fontColor('#999999')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10 })

          // 数量
          Text(`x${item.quantity}`)
            .fontSize(13)
            .fontColor('#666666')
        }
        .width('100%')
        .margin({ bottom: 8 })
      })

      // 如果商品超过3个，显示更多提示
      if (order.items.length > 3) {
        Text(`...共${order.items.length}件商品`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ bottom: 8 })
      }

      // 分隔线
      Divider()
        .strokeWidth(0.5)
        .color('#E5E5E5')
        .margin({ top: 8, bottom: 12 })

      // 底部：金额 + 操作按钮
      Row() {
        // 金额
        Row() {
          Text('合計: ')
            .fontSize(14)
            .fontColor('#666666')
          Text(this.currencySymbol)
            .fontSize(12)
            .fontColor('#333333')
          Text(order.pay_amount)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
        }

        Blank()

        // 再来一单按钮
        Button('再來一單')
          .height(32)
          .fontSize(13)
          .fontColor('#333333')
          .backgroundColor(this.themeColor)
          .borderRadius(16)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.reorder(order);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ left: 12, right: 12, bottom: 10 })
  }

  // ==================== 产品详情弹窗组件 ====================

  // 产品详情弹窗
  @Builder
  ProductDetailSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.closeProductDetail();
        })

      // 弹窗内容（从底部弹出，高度自适应）
      Column() {
        // 顶部标题栏
        Row() {
          Text('‹')
            .width(40)
            .height(44)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.closeProductDetail();
            })

          Text('選擇餐品')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Column()
            .width(40)
            .height(44)
        }
        .width('100%')
        .height(44)
        .padding({ left: 4, right: 4 })
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })

        if (this.isDetailLoading) {
          // 加载中
          Column() {
            LoadingProgress()
              .width(50)
              .height(50)
              .color(this.themeColor)
            Text('載入中...')
              .fontSize(13)
              .fontColor('#999999')
              .margin({ top: 12 })
          }
          .width('100%')
          .height(150)
          .justifyContent(FlexAlign.Center)
        } else if (this.selectedProduct) {
          // 产品详情内容 - 直接内联
          Scroll(this.detailScroller) {
            Column() {
              // 产品图片
              if (this.selectedProduct.cover_image) {
                Image(this.selectedProduct.cover_image)
                  .width('100%')
                  .height(220)
                  .objectFit(ImageFit.Cover)
              }

              // 产品名称
              Text(this.selectedProduct.local_name)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .width('100%')
                .padding({ left: 16, right: 16, top: 16, bottom: 8 })

              // 产品描述
              if (this.selectedProduct.description?.local_description) {
                Text(this.selectedProduct.description.local_description)
                  .fontSize(13)
                  .fontColor('#666666')
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })
              }

              // 规格选择（多个价格规格时显示）
              if (this.selectedProduct.prices && this.selectedProduct.prices.length > 1) {
                this.PriceSpecSection(this.selectedProduct)
              }

              // 主商品配料选择（甜度、冰量等）
              if (this.selectedProduct.condiment_group && this.selectedProduct.condiment_group.length > 0) {
                ForEach(this.selectedProduct.condiment_group as CondimentGroupDetail[], (group: CondimentGroupDetail) => {
                  this.ProductCondimentGroupSection(group)
                })
              }

              // 配料选择组（packageGroups）
              if (this.selectedProduct.packageGroups && this.selectedProduct.packageGroups.length > 0) {
                ForEach(this.selectedProduct.packageGroups, (group: PackageGroup) => {
                  this.PackageGroupSection(group)
                })
              }

              // 加送选择组（policyGroups）
              if (this.policyGroups && this.policyGroups.length > 0) {
                ForEach(this.policyGroups, (group: PolicyGroup) => {
                  this.PolicyGroupSection(group)
                })
              }

            }
            .width('100%')
          }
          .constraintSize({ maxHeight: '60%' })
          .scrollBar(BarState.Off)

          // 底部购物栏
          Row() {
            // 价格信息
            Column() {
              Row() {
                Text(this.currencySymbol)
                  .fontSize(14)
                  .fontColor('#C4A000')
                Text(this.calculateTotalPrice())
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#C4A000')
              }
              .alignItems(VerticalAlign.Bottom)

              Text(this.selectedProduct.local_name)
                .fontSize(12)
                .fontColor('#666666')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // 数量选择器
            Row() {
              Text('－')
                .width(32)
                .height(32)
                .fontSize(18)
                .fontColor(this.quantity > 1 ? '#333333' : '#CCCCCC')
                .textAlign(TextAlign.Center)
                .backgroundColor('#F5F5F5')
                .borderRadius(16)
                .onClick(() => {
                  if (this.quantity > 1) {
                    this.quantity--;
                  }
                })

              Text(this.quantity.toString())
                .width(40)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .textAlign(TextAlign.Center)

              Text('＋')
                .width(32)
                .height(32)
                .fontSize(18)
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
                .backgroundColor('#F5F5F5')
                .borderRadius(16)
                .onClick(() => {
                  this.quantity++;
                })
            }
            .margin({ right: 12 })

            // 加入购物篮按钮
            Button('加入購物籃')
              .height(44)
              .fontSize(15)
              .fontColor('#333333')
              .backgroundColor(this.themeColor)
              .borderRadius(22)
              .padding({ left: 20, right: 20 })
              .onClick(() => {
                this.addToCart();
              })
          }
          .width('100%')
          .height(70)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#FFFFFF')
          .border({ width: { top: 0.5 }, color: '#E5E5E5' })
          .alignItems(VerticalAlign.Center)
        } else {
          // 加载失败
          Column() {
            Text('載入失敗')
              .fontSize(15)
              .fontColor('#999999')
          }
          .width('100%')
          .height(150)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 16, topRight: 16 })

      // 配料选择弹窗层（覆盖在产品详情之上）
      if (this.showCondimentSheet) {
        // 遮罩层
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.3)')
          .onClick(() => {
            this.closeCondimentSheet();
          })

        // 配料选择弹窗内容
        this.CondimentSelectionSheet()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 规格选择区
  @Builder
  PriceSpecSection(product: ProductDetail) {
    Column() {
      // 标题
      Text('規格')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 规格选项
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(product.prices, (price: Object, index: number) => {
          Text(this.getPriceSpecName(price, index))
            .fontSize(14)
            .fontColor(this.selectedPriceIndex === index ? '#333333' : '#666666')
            .backgroundColor(this.selectedPriceIndex === index ? this.themeColor : '#F5F5F5')
            .borderRadius(16)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .margin({ right: 10, bottom: 10 })
            .onClick(() => {
              this.selectedPriceIndex = index;
            })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  /**
   * 获取规格名称
   */
  private getPriceSpecName(price: Object, index: number): string {
    const priceObj = price as Record<string, Object>;
    if (priceObj['productStandardItem']) {
      const standardItem = priceObj['productStandardItem'] as Record<string, string>;
      return standardItem['local_name'] || `規格${index + 1}`;
    }
    return (priceObj as Record<string, string>)['local_name'] || `規格${index + 1}`;
  }

  // 主商品配料选择组（甜度、冰量等）
  @Builder
  ProductCondimentGroupSection(group: CondimentGroupDetail) {
    Column() {
      // 组标题
      Row() {
        Text(group.local_name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        // 必选提示
        Text('請選擇1項')
          .fontSize(12)
          .fontColor('#FF6600')
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      // 配料项列表
      ForEach(group.item, (item: CondimentItemDetail) => {
        this.ProductCondimentItemRow(group, item)
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  // 主商品配料项行
  @Builder
  ProductCondimentItemRow(group: CondimentGroupDetail, item: CondimentItemDetail) {
    Row() {
      // 配料名称
      Text(item.local_name)
        .fontSize(15)
        .fontColor('#333333')
        .layoutWeight(1)

      // 加价显示
      if (parseFloat(item.price || '0') > 0) {
        Text(`+${this.currencySymbol}${parseFloat(item.price).toFixed(0)}`)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ right: 12 })
      }

      // 选中状态圆形
      Column() {
        if (this.isProductCondimentSelected(group.condiment_group_id, item.condiment_item_id)) {
          Column()
            .width(12)
            .height(12)
            .borderRadius(6)
            .backgroundColor(this.themeColor)
        }
      }
      .width(22)
      .height(22)
      .borderRadius(11)
      .border({
        width: 2,
        color: this.isProductCondimentSelected(group.condiment_group_id, item.condiment_item_id) ? this.themeColor : '#DDDDDD'
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => {
      this.selectProductCondiment(group.condiment_group_id, item.condiment_item_id);
    })
  }

  // 配料选择组
  @Builder
  PackageGroupSection(group: PackageGroup) {
    Column() {
      // 组标题
      Row() {
        Text(group.local_name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        // 必选提示
        if (parseInt(group.select_count) > 0) {
          Text(`請選擇${group.select_count}項`)
            .fontSize(12)
            .fontColor('#FF6600')
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      // 配料项列表
      ForEach(group.item, (item: PackageItem) => {
        this.PackageItemRow(group, item)
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  // 配料项行
  @Builder
  PackageItemRow(group: PackageGroup, item: PackageItem) {
    Row() {
      // 配料名称
      Column() {
        Text(item.local_name)
          .fontSize(14)
          .fontColor('#333333')

        // 描述（如果有）
        if (item.description?.local_description) {
          Text(item.description.local_description)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 加价显示
      if (this.getItemAddPrice(item) > 0) {
        Text(`+${this.currencySymbol}${this.getItemAddPrice(item).toFixed(0)}`)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ right: 12 })
      }

      // 选择按钮
      if (group.select_type === '2') {
        // 单选 - 圆形
        Radio({ value: item.product_id, group: group.id })
          .checked(this.isPackageItemSelected(group.id, item.product_id))
          .width(22)
          .height(22)
          .onChange((isChecked: boolean) => {
            if (isChecked) {
              this.togglePackageItem(group.id, item.product_id, group.select_type, parseInt(group.max_count) || 0);
            }
          })
      } else {
        // 多选 - 加号/勾选按钮
        Column() {
          if (this.isPackageItemSelected(group.id, item.product_id)) {
            Text('✓')
              .fontSize(14)
              .fontColor('#FFFFFF')
          } else {
            Text('+')
              .fontSize(18)
              .fontColor('#999999')
          }
        }
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(this.isPackageItemSelected(group.id, item.product_id) ? this.themeColor : '#F5F5F5')
        .border({ width: 1, color: this.isPackageItemSelected(group.id, item.product_id) ? this.themeColor : '#E5E5E5' })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.togglePackageItem(group.id, item.product_id, group.select_type, parseInt(group.max_count) || 0);
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }

  // 加送选择组（来自 policy API）
  @Builder
  PolicyGroupSection(group: PolicyGroup) {
    Column() {
      // 组标题
      Row() {
        Text(`加選·${group.local_name}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)

        // 必选提示
        if (group.required === '1') {
          Text(`請選擇${group.free_count || '1'}項`)
            .fontSize(12)
            .fontColor('#FF6600')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      // 加送项列表
      ForEach(group.item, (item: PolicyGroupItem) => {
        this.PolicyItemRow(group, item)
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .margin({ top: 8 })
  }

  // 加送项行
  @Builder
  PolicyItemRow(group: PolicyGroup, item: PolicyGroupItem) {
    Row() {
      // 项目名称和描述
      Column() {
        Text(item.local_name)
          .fontSize(14)
          .fontColor('#333333')

        // 显示配料组提示（如：可选甜度、冰量等）
        if (item.condiment_group && item.condiment_group.length > 0) {
          Text(`${item.short_name || item.local_name}·可選加料`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 加价显示
      if (this.getPolicyItemAddPrice(item) > 0) {
        Text(`+${this.currencySymbol}${this.getPolicyItemAddPrice(item).toFixed(0)}`)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ right: 12 })
      }

      // 选择按钮（单选圆形）
      Radio({ value: item.product_id, group: `policy_${group.id}` })
        .checked(this.isPolicyItemSelected(group.id, item.product_id))
        .width(22)
        .height(22)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            // 如果商品有配料组（甜度、冰量等），打开配料选择弹窗
            if (item.condiment_group && item.condiment_group.length > 0) {
              this.openCondimentSheet(group.id, item);
            } else {
              // 没有配料组，直接选中
              this.selectPolicyItem(group.id, item.product_id);
            }
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => {
      // 点击整行也可以打开配料选择（如果有配料组）
      if (item.condiment_group && item.condiment_group.length > 0) {
        this.openCondimentSheet(group.id, item);
      } else {
        this.selectPolicyItem(group.id, item.product_id);
      }
    })
  }

  // 获取加送项加价
  private getPolicyItemAddPrice(item: PolicyGroupItem): number {
    if (item.prices && item.prices.length > 0) {
      return parseFloat(item.prices[0].add_price || '0');
    }
    return 0;
  }

  // 加送商品配料选择弹窗
  @Builder
  CondimentSelectionSheet() {
    Column() {
      // 顶部标题栏
      Row() {
        // 返回箭头
        Text('‹')
          .width(40)
          .height(44)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.closeCondimentSheet();
          })

        // 商品名称
        Text(this.selectedPolicyItem?.local_name || '')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 确认按钮
        Text('確認')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.themeColor)
          .borderRadius(4)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ right: 12 })
          .onClick(() => {
            this.confirmCondimentSelection();
          })
      }
      .width('100%')
      .height(48)
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })

      // 规格选择 + 配料组列表
      if (this.selectedPolicyItem) {
        Scroll() {
          Column() {
            // 规格选择（如果有多个prices，显示热/冻等选择）
            if (this.selectedPolicyItem.prices && this.selectedPolicyItem.prices.length > 1) {
              this.PriceSpecSelectionSection()
            }

            // 配料组列表
            if (this.selectedPolicyItem.condiment_group) {
              ForEach(this.selectedPolicyItem.condiment_group, (group: CondimentGroupDetail) => {
                this.CondimentGroupSection(group)
              })
            }

            // 底部间距
            Column()
              .width('100%')
              .height(20)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('70%')
    .backgroundColor('#F5F5F5')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '30%' })
  }

  // 规格选择区域（prices数组，如熱/凍）
  @Builder
  PriceSpecSelectionSection() {
    Column() {
      // 组标题
      Row() {
        Text('規格')
          .fontSize(14)
          .fontColor('#999999')

        Blank()

        // 必选提示
        Text('請選擇1項')
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 规格选项列表
      Column() {
        if (this.selectedPolicyItem && this.selectedPolicyItem.prices) {
          ForEach(this.selectedPolicyItem.prices, (price: Object, index: number) => {
            this.PriceSpecItemRow(price, index)
          })
        }
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
  }

  // 规格选项行
  @Builder
  PriceSpecItemRow(price: Object, index: number) {
    Row() {
      // 规格名称
      Text(this.getPolicyPriceSpecName(price))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .layoutWeight(1)

      // 加价显示（如果有）
      if (this.getPolicyPriceAddPrice(price) > 0) {
        Text(`+${this.currencySymbol}${this.getPolicyPriceAddPrice(price).toFixed(0)}`)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ right: 12 })
      }

      // 选择状态圆形（单选）
      Column() {
        if (this.selectedPolicyPriceIndex === index) {
          // 选中状态 - 黄色实心圆
          Column()
            .width(12)
            .height(12)
            .borderRadius(6)
            .backgroundColor(this.themeColor)
        }
      }
      .width(22)
      .height(22)
      .borderRadius(11)
      .border({
        width: 2,
        color: this.selectedPolicyPriceIndex === index ? this.themeColor : '#DDDDDD'
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => {
      this.selectedPolicyPriceIndex = index;
    })
  }

  /**
   * 获取加送商品规格名称
   */
  private getPolicyPriceSpecName(price: Object): string {
    const priceObj = price as Record<string, string>;
    return priceObj['local_name'] || priceObj['en_name'] || '規格';
  }

  /**
   * 获取加送商品规格加价
   */
  private getPolicyPriceAddPrice(price: Object): number {
    const priceObj = price as Record<string, string>;
    if (this.orderType === OrderType.PICKUP) {
      return parseFloat(priceObj['add_takeout_price'] || priceObj['add_price'] || '0');
    }
    return parseFloat(priceObj['add_price'] || '0');
  }

  // 配料组区域
  @Builder
  CondimentGroupSection(group: CondimentGroupDetail) {
    Column() {
      // 组标题
      Row() {
        Text(group.local_name)
          .fontSize(14)
          .fontColor('#999999')

        Blank()

        // 必选提示
        Text('請選擇1項')
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 配料项列表
      Column() {
        ForEach(group.item, (item: CondimentItemDetail) => {
          this.CondimentItemRow(group, item)
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
  }

  // 配料项行
  @Builder
  CondimentItemRow(group: CondimentGroupDetail, item: CondimentItemDetail) {
    Row() {
      // 配料名称
      Text(item.local_name)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .layoutWeight(1)

      // 加价显示（如果有）
      if (parseFloat(item.price || '0') > 0) {
        Text(`+${this.currencySymbol}${parseFloat(item.price).toFixed(0)}`)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ right: 12 })
      }

      // 选择状态圆形（单选）
      Column() {
        if (this.isCondimentItemSelected(group.condiment_group_id, item.condiment_item_id)) {
          // 选中状态 - 黄色实心圆
          Column()
            .width(12)
            .height(12)
            .borderRadius(6)
            .backgroundColor(this.themeColor)
        }
      }
      .width(22)
      .height(22)
      .borderRadius(11)
      .border({
        width: 2,
        color: this.isCondimentItemSelected(group.condiment_group_id, item.condiment_item_id) ? this.themeColor : '#DDDDDD'
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => {
      this.selectCondimentItem(group.condiment_group_id, item.condiment_item_id);
    })
  }

  // 购物车悬浮卡片
  @Builder
  CartBottomBar() {
    Row() {
      // 购物车图标区域（点击展开弹窗）
      Stack() {
        // 购物车图标背景圆形
        Column() {
          Text('🛒')
            .fontSize(22)
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor('rgba(255, 255, 255, 0.4)')
        .justifyContent(FlexAlign.Center)

        // 数量徽章
        if (this.cartCount > 0) {
          Text(this.cartCount > 99 ? '99+' : this.cartCount.toString())
            .fontSize(11)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#FF6B00')
            .borderRadius(9)
            .constraintSize({ minWidth: 18 })
            .height(18)
            .textAlign(TextAlign.Center)
            .padding({ left: 4, right: 4 })
            .position({ x: 26, y: -2 })
        }
      }
      .width(46)
      .height(42)
      .onClick(() => {
        this.showCartPopup = !this.showCartPopup;
      })

      // 总数金额
      Row() {
        Text('總數')
          .fontSize(14)
          .fontColor('#333333')
        Text(` ${this.currencySymbol}${this.cartTotal.toFixed(0)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .margin({ left: 8 })

      // 下一步按钮
      Button('下一步')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor('#333333')
        .borderRadius(20)
        .height(40)
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          this.goToCheckout();
        })
    }
    .height(50)
    .padding({ left: 10, right: 10 })
    .margin({ left: 10, right: 10, bottom: 0 })
    .backgroundColor(this.themeColor)
    .borderRadius(25)
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.2)',
      offsetX: 0,
      offsetY: 4
    })
    .position({ x: 0, y: '100%' })
    .translate({ y: -66 })
  }

  // 购物车商品列表弹窗（从底部弹出，在悬浮卡片下层）
  @Builder
  CartPopup() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 半透明遮罩（点击关闭）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.4)')
        .onClick(() => {
          this.showCartPopup = false;
        })

      // 购物车商品列表区域（从底部弹出，在悬浮卡片下方）
      Column() {
        // 标题栏
        Row() {
          Text('購物車')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Blank()

          // 清空购物车按钮
          Row() {
            Text('🗑')
              .fontSize(14)
              .margin({ right: 4 })
            Text('清空購物車')
              .fontSize(13)
              .fontColor('#999999')
          }
          .onClick(() => {
            this.clearCart();
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 12 })

        // 购物车商品列表
        List() {
          ForEach(appState.cartItems, (item: CartItem) => {
            ListItem() {
              this.CartItemRow(item)
            }
          })
        }
        .width('100%')
        .constraintSize({ maxHeight: 300 })
        .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 16, endMargin: 16 })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 16, topRight: 16 })
      .padding({ bottom: 76 })  // 为悬浮购物车卡片留出空间
    }
    .width('100%')
    .height('100%')
  }

  // 购物车商品项
  @Builder
  CartItemRow(item: CartItem) {
    Row() {
      // 商品信息
      Column() {
        // 商品名称
        Text(item.productName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 规格描述
        if (item.specDescription) {
          Text(item.specDescription)
            .fontSize(12)
            .fontColor('#999999')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 价格
      Text(`${this.currencySymbol}${item.unitPrice.toFixed(0)}`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColor)
        .margin({ left: 12, right: 12 })

      // 数量控制器
      Row() {
        // 减少按钮
        Text('−')
          .width(28)
          .height(28)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.quantity > 1 ? '#333333' : '#CCCCCC')
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .border({ width: 1, color: item.quantity > 1 ? '#DDDDDD' : '#EEEEEE' })
          .onClick(() => {
            if (item.quantity > 1) {
              this.updateCartItemQuantity(item.cartItemId, item.quantity - 1);
            } else {
              this.removeCartItem(item.cartItemId);
            }
          })

        // 数量
        Text(item.quantity.toString())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .width(36)
          .textAlign(TextAlign.Center)

        // 增加按钮
        Text('+')
          .width(28)
          .height(28)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .border({ width: 1, color: '#DDDDDD' })
          .onClick(() => {
            this.updateCartItemQuantity(item.cartItemId, item.quantity + 1);
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  /**
   * 更新购物车商品数量
   */
  private async updateCartItemQuantity(cartItemId: string, quantity: number): Promise<void> {
    await appState.updateCartItemQuantity(cartItemId, quantity);
    this.updateCartState();
  }

  /**
   * 删除购物车商品
   */
  private async removeCartItem(cartItemId: string): Promise<void> {
    await appState.removeCartItem(cartItemId);
    this.updateCartState();
    // 如果购物车为空，关闭弹窗
    if (this.cartCount === 0) {
      this.showCartPopup = false;
    }
  }

  /**
   * 清空购物车
   */
  private async clearCart(): Promise<void> {
    await appState.clearCart();
    this.updateCartState();
    this.showCartPopup = false;
  }

  /**
   * 前往结算页面
   */
  private goToCheckout(): void {
    hilog.info(DOMAIN, TAG, 'Go to checkout, total: %{public}d', this.cartTotal);
    // TODO: 跳转到结算页面
  }

  // 检查加送项是否被选中
  private isPolicyItemSelected(groupId: string, itemProductId: string): boolean {
    const selectedSet = this.selectedPackageItems.get(`policy_${groupId}`);
    return selectedSet ? selectedSet.has(itemProductId) : false;
  }

  // 选择加送项（单选）
  private selectPolicyItem(groupId: string, itemProductId: string): void {
    const key = `policy_${groupId}`;
    const selectedSet = new Set<string>();
    selectedSet.add(itemProductId);
    this.selectedPackageItems.set(key, selectedSet);
    // 触发 UI 更新
    this.selectedPackageItems = new Map(this.selectedPackageItems);
  }

  /**
   * 打开加送商品配料选择弹窗
   */
  private openCondimentSheet(groupId: string, item: PolicyGroupItem): void {
    hilog.info(DOMAIN, TAG, 'Open condiment sheet for: %{public}s, prices: %{public}d',
      item.local_name, item.prices?.length || 0);
    this.selectedPolicyGroupId = groupId;
    this.selectedPolicyItem = item;
    // 初始化规格选择（默认选第一个）
    this.selectedPolicyPriceIndex = 0;
    // 初始化配料选择（选中默认项）
    this.selectedCondimentItems = new Map();
    if (item.condiment_group) {
      for (const condimentGroup of item.condiment_group) {
        // 找到默认选中的项
        const defaultItem = condimentGroup.item.find(i => i.is_default === '1');
        if (defaultItem) {
          this.selectedCondimentItems.set(condimentGroup.condiment_group_id, defaultItem.condiment_item_id);
        } else if (condimentGroup.item.length > 0) {
          // 如果没有默认项，选中第一个
          this.selectedCondimentItems.set(condimentGroup.condiment_group_id, condimentGroup.item[0].condiment_item_id);
        }
      }
    }
    this.showCondimentSheet = true;
  }

  /**
   * 关闭配料选择弹窗
   */
  private closeCondimentSheet(): void {
    this.showCondimentSheet = false;
    this.selectedPolicyItem = null;
    this.selectedPolicyGroupId = '';
  }

  /**
   * 确认配料选择
   */
  private confirmCondimentSelection(): void {
    if (this.selectedPolicyItem && this.selectedPolicyGroupId) {
      // 先选中该加送商品
      this.selectPolicyItem(this.selectedPolicyGroupId, this.selectedPolicyItem.product_id);

      // 获取规格名称
      let priceName = '';
      if (this.selectedPolicyItem.prices && this.selectedPolicyItem.prices.length > this.selectedPolicyPriceIndex) {
        priceName = this.selectedPolicyItem.prices[this.selectedPolicyPriceIndex].local_name || '';
      }

      // 构建配料选择
      const condiments = new Map<string, CondimentSelection>();
      if (this.selectedPolicyItem.condiment_group) {
        for (const group of this.selectedPolicyItem.condiment_group) {
          const selectedItemId = this.selectedCondimentItems.get(group.condiment_group_id);
          if (selectedItemId) {
            const selectedItem = group.item.find(i => i.condiment_item_id === selectedItemId);
            if (selectedItem) {
              condiments.set(group.condiment_group_id, {
                groupName: group.local_name,
                itemId: selectedItem.condiment_item_id,
                itemName: selectedItem.local_name,
                price: parseFloat(selectedItem.price || '0')
              });
            }
          }
        }
      }

      // 保存到已确认选择
      const selection: ConfirmedPolicySelection = {
        item: this.selectedPolicyItem,
        priceIndex: this.selectedPolicyPriceIndex,
        priceName: priceName,
        condiments: condiments
      };

      const newMap = new Map(this.confirmedPolicySelections);
      newMap.set(this.selectedPolicyGroupId, selection);
      this.confirmedPolicySelections = newMap;

      hilog.info(DOMAIN, TAG, 'Condiment selection confirmed for: %{public}s, spec: %{public}s',
        this.selectedPolicyItem.local_name, priceName);
    }
    this.closeCondimentSheet();
  }

  /**
   * 选择配料项
   */
  private selectCondimentItem(condimentGroupId: string, condimentItemId: string): void {
    this.selectedCondimentItems.set(condimentGroupId, condimentItemId);
    // 触发UI更新
    this.selectedCondimentItems = new Map(this.selectedCondimentItems);
  }

  /**
   * 检查配料项是否被选中
   */
  private isCondimentItemSelected(condimentGroupId: string, condimentItemId: string): boolean {
    return this.selectedCondimentItems.get(condimentGroupId) === condimentItemId;
  }

  aboutToAppear() {
    // 初始化购物车状态
    this.updateCartState();

    // 获取顶部安全区域高度（避开胶囊）
    this.getTopSafeHeight();

    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.orderType = (params['orderType'] as OrderType) || OrderType.PICKUP;
      this.themeColor = (params['themeColor'] as string) || '#FFD700';

      // 从路由参数获取店铺信息
      if (params['storeName']) {
        this.storeName = params['storeName'] as string;
      }
      if (params['storeImage']) {
        this.storeImage = params['storeImage'] as string;
      }
      if (params['notices']) {
        this.notices = params['notices'] as string[];
      }
      if (params['isOpen'] !== undefined) {
        this.isOpen = params['isOpen'] as boolean;
      }
      if (params['storeStatus']) {
        this.storeStatus = params['storeStatus'] as string;
      }
      if (params['todayStatus']) {
        this.todayStatus = params['todayStatus'] as string;
      }
      // 初始Tab（用于从首页"我的订单"跳转）
      if (params['initialTab'] !== undefined) {
        this.currentTab = params['initialTab'] as number;
      }
    }

    // 如果没有从路由获取到店铺信息，则加载
    if (!this.storeName) {
      this.loadStoreData();
    }

    // 根据初始Tab加载对应数据
    if (this.currentTab === 2) {
      // 历史订单Tab
      this.loadOrders();
    } else {
      // 点餐Tab
      this.loadMenuData();
    }
  }

  /**
   * 加载店铺数据
   */
  private async loadStoreData(): Promise<void> {
    try {
      // 确保有游客token
      if (!apiService.hasToken()) {
        hilog.info(DOMAIN, TAG, 'No token for store data, getting guest token first');
        await apiService.getGuestToken();
      }

      const response = await apiService.getHomeData();

      if (response.code === 200 && response.data) {
        this.updateStoreInfo(response.data);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load store data: %{public}s', JSON.stringify(error));
      // 使用默认数据
      this.storeName = '老馮茶居';
    }
  }

  /**
   * 更新店铺信息
   */
  private updateStoreInfo(data: HomeData): void {
    const config = data.config;

    this.storeName = config.name || '店铺名称';
    this.storeImage = config.store_image || '';

    this.isOpen = config.is_close !== 1;
    if (!this.isOpen) {
      this.storeStatus = '商家休息中';
      this.todayStatus = '今日休業';
    }

    if (data.notice && data.notice.length > 0) {
      this.notices = data.notice.map(n => n.local_name);
    }
  }

  /**
   * 加载菜单数据
   */
  private async loadMenuData(): Promise<void> {
    try {
      // 确保有游客token
      if (!apiService.hasToken()) {
        hilog.info(DOMAIN, TAG, 'No token for menu, getting guest token first');
        const tokenSuccess = await apiService.getGuestToken();
        if (!tokenSuccess) {
          hilog.error(DOMAIN, TAG, 'Failed to get guest token for menu');
        }
      }

      const takeout = this.orderType === OrderType.PICKUP ? 1 : 0;
      const response = await apiService.getProductMenus(takeout);

      if (response.code === 200 && response.data) {
        // 保存所有分组
        this.allProductGroups = response.data.group || [];
        // 保存顶级菜单分组
        this.menuGroups = response.data.menu_group || [];
        hilog.info(DOMAIN, TAG, 'Menu loaded: %{public}d groups, %{public}d menu_groups',
          this.allProductGroups.length, this.menuGroups.length);

        // 根据当前选中的顶级分组过滤显示的二级分组
        this.filterProductGroups();
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load menu: %{public}s', JSON.stringify(error));
      // 如果没有 menu_group，直接显示所有分组
      this.productGroups = this.allProductGroups;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 顶级菜单分组选择
   */
  private onMenuGroupSelect(index: number): void {
    if (this.selectedMenuGroupIndex === index) {
      return;
    }
    this.selectedMenuGroupIndex = index;
    this.selectedGroupIndex = 0;
    this.filterProductGroups();
    // 滚动到顶部
    this.scroller.scrollToIndex(0);
    this.categoryScroller.scrollToIndex(0);
    hilog.info(DOMAIN, TAG, 'Selected menu group: %{public}s', this.menuGroups[index]?.local_name);
  }

  /**
   * 根据选中的顶级分组过滤二级分组
   */
  private filterProductGroups(): void {
    if (this.menuGroups.length === 0) {
      // 没有顶级分组，显示所有
      this.productGroups = this.allProductGroups;
      this.currentShowType = '2'; // 默认大图模式
      return;
    }

    const selectedMenuGroup = this.menuGroups[this.selectedMenuGroupIndex];
    if (!selectedMenuGroup || !selectedMenuGroup.groups || selectedMenuGroup.groups.length === 0) {
      this.productGroups = this.allProductGroups;
      this.currentShowType = '2';
      return;
    }

    // 更新展示类型
    this.currentShowType = selectedMenuGroup.show_type || '2';

    // 根据 groups 数组过滤
    const groupIds = new Set(selectedMenuGroup.groups);
    this.productGroups = this.allProductGroups.filter(g => groupIds.has(g.group_id));
    hilog.info(DOMAIN, TAG, 'Filtered groups: %{public}d, show_type: %{public}s',
      this.productGroups.length, this.currentShowType);
  }

  /**
   * 获取产品价格
   */
  private getPrice(product: Product): string {
    if (this.orderType === OrderType.PICKUP) {
      return product.takeout_price || product.price;
    }
    return product.price;
  }

  /**
   * 计算分组在产品列表中的起始索引
   */
  private getProductListIndexForGroup(groupIndex: number): number {
    let index = 0;
    for (let i = 0; i < groupIndex; i++) {
      index += this.productGroups[i].products.length + 1; // +1 for group header
    }
    return index;
  }

  /**
   * 检查产品是否有多规格
   */
  private hasMultipleSpecs(product: Product): boolean {
    return (product.prices && product.prices.length > 1) || (product.condiment_group && product.condiment_group.length > 0);
  }

  /**
   * 显示产品详情（点击产品卡片）
   * 调用产品详情API获取完整数据（包含配料选择）
   */
  private openProductDetail(product: Product): void {
    hilog.info(DOMAIN, TAG, 'Open product detail: %{public}s (id=%{public}s)', product.local_name, product.product_id);

    // 重置选择状态
    this.selectedPriceIndex = 0;
    this.selectedPackageItems = new Map();
    this.selectedProductCondiments = new Map();
    this.quantity = 1;

    // 先显示加载状态
    this.isDetailLoading = true;
    this.showProductDetail = true;
    this.selectedProduct = this.convertToProductDetail(product);

    // 调用API获取完整详情（包含packageGroups配料数据）
    const orderType = this.orderType === OrderType.PICKUP ? 1 : 2;
    this.fetchProductDetail(product.product_id, orderType);
  }

  /**
   * 获取产品详情（带token检查）
   */
  private async fetchProductDetail(productId: string, orderType: number): Promise<void> {
    try {
      // 确保有游客token
      if (!apiService.hasToken()) {
        hilog.info(DOMAIN, TAG, 'No token for product detail, getting guest token first');
        const tokenSuccess = await apiService.getGuestToken();
        if (!tokenSuccess) {
          hilog.error(DOMAIN, TAG, 'Failed to get guest token for product detail');
          this.isDetailLoading = false;
          return;
        }
      }

      // 重置政策组数据
      this.policyGroups = [];

      const response = await apiService.getProductDetail(productId, orderType);
      if (response.code === 200 && response.data) {
        this.selectedProduct = response.data;
        hilog.info(DOMAIN, TAG, 'Product detail from API: %{public}s, prices: %{public}d, packageGroups: %{public}d, policies: %{public}d, condiment_groups: %{public}d',
          response.data.local_name,
          response.data.prices?.length || 0,
          response.data.packageGroups?.length || 0,
          response.data.policy?.length || 0,
          response.data.condiment_group?.length || 0);

        // 初始化主商品配料的默认选择
        this.initProductCondimentDefaults(response.data);

        // 如果有政策，获取政策详情（加送选择数据）
        if (response.data.policy && response.data.policy.length > 0) {
          const policyIds = response.data.policy.map(p => p.policy_id);
          this.fetchPolicyData(policyIds);
        }
      } else {
        hilog.warn(DOMAIN, TAG, 'API returned no data, using menu data. Code: %{public}d, msg: %{public}s',
          response.code, response.msg);
      }
      this.isDetailLoading = false;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Failed to get product detail: %{public}s', errorMsg);
      this.isDetailLoading = false;
    }
  }

  /**
   * 获取产品政策数据（加送选择）
   */
  private async fetchPolicyData(policyIds: string[]): Promise<void> {
    try {
      const response = await apiService.getProductPolicy(policyIds);
      if (response.code === 200 && response.data) {
        // 提取所有 groupData
        const allGroups: PolicyGroup[] = [];
        for (const policyData of response.data) {
          if (policyData.groupData && policyData.groupData.length > 0) {
            allGroups.push(...policyData.groupData);
          }
        }
        this.policyGroups = allGroups;
        hilog.info(DOMAIN, TAG, 'Policy groups loaded: %{public}d groups', allGroups.length);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Failed to get policy data: %{public}s', errorMsg);
    }
  }

  /**
   * 将菜单产品转换为详情格式
   */
  private convertToProductDetail(product: Product): ProductDetail {
    return {
      product_id: product.product_id,
      store_id: product.store_id,
      local_name: product.local_name,
      cn_name: product.cn_name,
      en_name: product.en_name,
      cover_image: product.cover_image,
      price: product.price,
      takeout_price: product.takeout_price,
      delivery_price: product.delivery_price,
      sale_num: product.sale_num,
      has_stock: product.has_stock,
      takeout: product.takeout,
      dinner_in: product.dinner_in,
      delivery: product.delivery,
      status: product.status,
      description: product.description,
      prices: product.prices || [],
      packageGroups: [],  // 菜单数据没有packageGroups，使用空数组
      policy: [],
      condiment_group: product.condiment_group
    };
  }

  /**
   * 初始化主商品配料的默认选择
   */
  private initProductCondimentDefaults(product: ProductDetail): void {
    this.selectedProductCondiments = new Map();
    if (product.condiment_group) {
      for (const group of product.condiment_group as CondimentGroupDetail[]) {
        // 查找默认选中项
        const defaultItem = group.item?.find(item => item.is_default === '1');
        if (defaultItem) {
          this.selectedProductCondiments.set(group.condiment_group_id, defaultItem.condiment_item_id);
        } else if (group.item && group.item.length > 0) {
          // 没有默认项则选第一个
          this.selectedProductCondiments.set(group.condiment_group_id, group.item[0].condiment_item_id);
        }
      }
    }
    hilog.info(DOMAIN, TAG, 'Initialized product condiment defaults: %{public}d groups',
      this.selectedProductCondiments.size);
  }

  /**
   * 选择主商品配料项
   */
  private selectProductCondiment(groupId: string, itemId: string): void {
    this.selectedProductCondiments.set(groupId, itemId);
    // 触发UI更新
    this.selectedProductCondiments = new Map(this.selectedProductCondiments);
  }

  /**
   * 检查主商品配料项是否选中
   */
  private isProductCondimentSelected(groupId: string, itemId: string): boolean {
    return this.selectedProductCondiments.get(groupId) === itemId;
  }

  /**
   * 关闭产品详情弹窗
   */
  private closeProductDetail(): void {
    this.showProductDetail = false;
    this.selectedProduct = null;
  }

  /**
   * 切换配料选择
   */
  private togglePackageItem(groupId: string, itemProductId: string, selectType: string, maxCount: number): void {
    let selectedSet = this.selectedPackageItems.get(groupId);
    if (!selectedSet) {
      selectedSet = new Set<string>();
    }

    if (selectType === '2') {
      // 单选模式
      selectedSet.clear();
      selectedSet.add(itemProductId);
    } else {
      // 多选模式
      if (selectedSet.has(itemProductId)) {
        selectedSet.delete(itemProductId);
      } else {
        // 检查是否达到最大数量
        if (maxCount === 0 || selectedSet.size < maxCount) {
          selectedSet.add(itemProductId);
        }
      }
    }

    // 创建新Map触发状态更新
    const newMap = new Map(this.selectedPackageItems);
    newMap.set(groupId, selectedSet);
    this.selectedPackageItems = newMap;
  }

  /**
   * 检查配料项是否被选中
   */
  private isPackageItemSelected(groupId: string, itemProductId: string): boolean {
    const selectedSet = this.selectedPackageItems.get(groupId);
    return selectedSet ? selectedSet.has(itemProductId) : false;
  }

  /**
   * 获取配料项加价
   */
  private getItemAddPrice(item: PackageItem): number {
    if (!item.prices || item.prices.length === 0) {
      return 0;
    }
    if (this.orderType === OrderType.PICKUP) {
      return parseFloat(item.prices[0].add_takeout_price || item.prices[0].add_price || '0');
    }
    return parseFloat(item.prices[0].add_price || '0');
  }

  /**
   * 计算总价
   */
  private calculateTotalPrice(): string {
    if (!this.selectedProduct) {
      return '0';
    }

    // 基础价格
    let basePrice = 0;
    if (this.selectedProduct.prices && this.selectedProduct.prices.length > 0) {
      const selectedPrice = this.selectedProduct.prices[this.selectedPriceIndex];
      if (this.orderType === OrderType.PICKUP) {
        basePrice = parseFloat(selectedPrice.takeout_price || selectedPrice.price);
      } else {
        basePrice = parseFloat(selectedPrice.price);
      }
    } else {
      basePrice = parseFloat(this.selectedProduct.price);
    }

    // 配料加价（packageGroups）
    let addPrice = 0;
    if (this.selectedProduct.packageGroups) {
      for (const group of this.selectedProduct.packageGroups) {
        const selectedSet = this.selectedPackageItems.get(group.id);
        if (selectedSet) {
          for (const item of group.item) {
            if (selectedSet.has(item.product_id) && item.prices && item.prices.length > 0) {
              const itemPrice = item.prices[0];
              if (this.orderType === OrderType.PICKUP) {
                addPrice += parseFloat(itemPrice.add_takeout_price || itemPrice.add_price || '0');
              } else {
                addPrice += parseFloat(itemPrice.add_price || '0');
              }
            }
          }
        }
      }
    }

    // 主商品配料加价（condiment_group：甜度、冰量等）
    if (this.selectedProduct.condiment_group) {
      for (const group of this.selectedProduct.condiment_group as CondimentGroupDetail[]) {
        const selectedItemId = this.selectedProductCondiments.get(group.condiment_group_id);
        if (selectedItemId && group.item) {
          const selectedItem = group.item.find(item => item.condiment_item_id === selectedItemId);
          if (selectedItem) {
            if (this.orderType === OrderType.PICKUP) {
              addPrice += parseFloat(selectedItem.takeout_price || selectedItem.price || '0');
            } else {
              addPrice += parseFloat(selectedItem.price || '0');
            }
          }
        }
      }
    }

    const total = (basePrice + addPrice) * this.quantity;
    return total.toFixed(0);
  }

  /**
   * 检查是否满足必选条件
   */
  private checkRequiredSelections(): boolean {
    if (!this.selectedProduct || !this.selectedProduct.packageGroups) {
      return true;
    }

    for (const group of this.selectedProduct.packageGroups) {
      const minCount = parseInt(group.select_count) || 0;
      if (minCount > 0) {
        const selectedSet = this.selectedPackageItems.get(group.id);
        const selectedCount = selectedSet ? selectedSet.size : 0;
        if (selectedCount < minCount) {
          return false;
        }
      }
    }
    return true;
  }

  /**
   * 添加到购物车
   */
  private async addToCart(): Promise<void> {
    if (!this.selectedProduct) {
      return;
    }

    // 检查必选项
    if (!this.checkRequiredSelections()) {
      hilog.warn(DOMAIN, TAG, 'Required selections not met');
      // TODO: 显示提示
      return;
    }

    // 构建购物车项
    const cartItem = this.buildCartItem();
    if (!cartItem) {
      hilog.error(DOMAIN, TAG, 'Failed to build cart item');
      return;
    }

    // 添加到购物车
    await appState.addToCart(cartItem);

    // 更新购物车状态
    this.updateCartState();

    hilog.info(DOMAIN, TAG, 'Add to cart: %{public}s x%{public}d, total: %{public}s',
      this.selectedProduct.local_name, this.quantity, this.calculateTotalPrice());

    this.closeProductDetail();
  }

  /**
   * 构建购物车项
   */
  private buildCartItem(): CartItemInput | null {
    if (!this.selectedProduct) {
      return null;
    }

    // 基础信息
    const productId = this.selectedProduct.product_id;
    const productName = this.selectedProduct.local_name;
    const coverImage = this.selectedProduct.cover_image;

    // 规格选择
    let priceName = '';
    let basePrice = 0;
    if (this.selectedProduct.prices && this.selectedProduct.prices.length > 0) {
      const selectedPrice = this.selectedProduct.prices[this.selectedPriceIndex];
      if (selectedPrice.productStandardItem) {
        priceName = selectedPrice.productStandardItem.local_name;
      }
      if (this.orderType === OrderType.PICKUP) {
        basePrice = parseFloat(selectedPrice.takeout_price || selectedPrice.price);
      } else {
        basePrice = parseFloat(selectedPrice.price);
      }
    } else {
      basePrice = parseFloat(this.selectedProduct.price);
    }

    // 配料选择（packageGroups）
    const packageSelections: CartPackageSelection[] = [];
    if (this.selectedProduct.packageGroups) {
      for (const group of this.selectedProduct.packageGroups) {
        const selectedSet = this.selectedPackageItems.get(group.id);
        if (selectedSet && selectedSet.size > 0) {
          const items: CartPackageItem[] = [];
          for (const item of group.item) {
            if (selectedSet.has(item.product_id)) {
              let addPrice = 0;
              if (item.prices && item.prices.length > 0) {
                if (this.orderType === OrderType.PICKUP) {
                  addPrice = parseFloat(item.prices[0].add_takeout_price || item.prices[0].add_price || '0');
                } else {
                  addPrice = parseFloat(item.prices[0].add_price || '0');
                }
              }
              const pkgItem: CartPackageItem = {
                productId: item.product_id,
                name: item.local_name,
                addPrice: addPrice
              };
              items.push(pkgItem);
            }
          }
          if (items.length > 0) {
            const pkgSelection: CartPackageSelection = {
              groupId: group.id,
              groupName: group.local_name,
              items: items
            };
            packageSelections.push(pkgSelection);
          }
        }
      }
    }

    // 主商品配料选择（condiment_group：甜度、冰量等）
    if (this.selectedProduct.condiment_group) {
      for (const group of this.selectedProduct.condiment_group as CondimentGroupDetail[]) {
        const selectedItemId = this.selectedProductCondiments.get(group.condiment_group_id);
        if (selectedItemId && group.item) {
          const selectedItem = group.item.find(item => item.condiment_item_id === selectedItemId);
          if (selectedItem) {
            let addPrice = 0;
            if (this.orderType === OrderType.PICKUP) {
              addPrice = parseFloat(selectedItem.takeout_price || selectedItem.price || '0');
            } else {
              addPrice = parseFloat(selectedItem.price || '0');
            }
            const pkgItem: CartPackageItem = {
              productId: selectedItem.condiment_item_id,
              name: selectedItem.local_name,
              addPrice: addPrice
            };
            const pkgSelection: CartPackageSelection = {
              groupId: group.condiment_group_id,
              groupName: group.local_name,
              items: [pkgItem]
            };
            packageSelections.push(pkgSelection);
          }
        }
      }
    }

    // 加送商品选择
    const policySelections: CartPolicySelection[] = [];
    for (const group of this.policyGroups) {
      const confirmed = this.confirmedPolicySelections.get(group.id);
      if (confirmed) {
        // 计算加送商品加价
        let addPrice = 0;
        if (confirmed.item.prices && confirmed.item.prices.length > confirmed.priceIndex) {
          const price = confirmed.item.prices[confirmed.priceIndex];
          if (this.orderType === OrderType.PICKUP) {
            addPrice = parseFloat(price.add_takeout_price || price.add_price || '0');
          } else {
            addPrice = parseFloat(price.add_price || '0');
          }
        }

        // 配料选择
        const condiments: CartCondiment[] = [];
        confirmed.condiments.forEach((value, key) => {
          const condiment: CartCondiment = {
            groupId: key,
            groupName: value.groupName,
            itemId: value.itemId,
            itemName: value.itemName,
            price: value.price
          };
          condiments.push(condiment);
        });

        const policyItem: CartPolicyItem = {
          productId: confirmed.item.product_id,
          name: confirmed.item.local_name,
          priceIndex: confirmed.priceIndex,
          priceName: confirmed.priceName,
          addPrice: addPrice,
          condiments: condiments
        };
        const policySelection: CartPolicySelection = {
          groupId: group.id,
          groupName: group.local_name,
          item: policyItem
        };
        policySelections.push(policySelection);
      } else {
        // 检查是否有通过 selectPolicyItem 选中但没有配料的项
        const key = `policy_${group.id}`;
        const selectedSet = this.selectedPackageItems.get(key);
        if (selectedSet && selectedSet.size > 0) {
          const selectedProductId = Array.from(selectedSet)[0];
          const selectedItem = group.item.find(i => i.product_id === selectedProductId);
          if (selectedItem) {
            let addPrice = 0;
            let policyPriceName = '';
            if (selectedItem.prices && selectedItem.prices.length > 0) {
              policyPriceName = selectedItem.prices[0].local_name || '';
              if (this.orderType === OrderType.PICKUP) {
                addPrice = parseFloat(selectedItem.prices[0].add_takeout_price || selectedItem.prices[0].add_price || '0');
              } else {
                addPrice = parseFloat(selectedItem.prices[0].add_price || '0');
              }
            }
            const policyItem: CartPolicyItem = {
              productId: selectedItem.product_id,
              name: selectedItem.local_name,
              priceIndex: 0,
              priceName: policyPriceName,
              addPrice: addPrice,
              condiments: []
            };
            const policySelection: CartPolicySelection = {
              groupId: group.id,
              groupName: group.local_name,
              item: policyItem
            };
            policySelections.push(policySelection);
          }
        }
      }
    }

    // 计算单价
    const unitPrice = parseFloat(this.calculateTotalPrice()) / this.quantity;

    // 生成规格描述
    const specDescription = this.buildSpecDescription(packageSelections, policySelections);

    const cartItem: CartItemInput = {
      productId: productId,
      productName: productName,
      coverImage: coverImage,
      priceIndex: this.selectedPriceIndex,
      priceName: priceName,
      basePrice: basePrice,
      packageSelections: packageSelections,
      policySelections: policySelections,
      quantity: this.quantity,
      unitPrice: unitPrice,
      specDescription: specDescription
    };
    return cartItem;
  }

  /**
   * 构建规格描述字符串
   */
  private buildSpecDescription(
    packageSelections: CartPackageSelection[],
    policySelections: CartPolicySelection[]
  ): string {
    const parts: string[] = [];

    // 配料选择
    for (const pkg of packageSelections) {
      for (const item of pkg.items) {
        parts.push(item.name);
      }
    }

    // 加送商品选择
    for (const policy of policySelections) {
      const policyParts = [policy.item.name];
      if (policy.item.priceName) {
        policyParts.push(policy.item.priceName);
      }
      for (const condiment of policy.item.condiments) {
        policyParts.push(condiment.itemName);
      }
      parts.push(policyParts.join('·'));
    }

    return parts.join(' | ');
  }

  /**
   * 更新购物车状态
   */
  private updateCartState(): void {
    this.cartCount = appState.cartCount;
    this.cartTotal = appState.cartTotal;
  }

  /**
   * 显示店铺详情
   */
  private showStoreInfo(): void {
    hilog.info(DOMAIN, TAG, 'Show store info');
    // TODO: 跳转到店铺详情页
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
      hilog.error(DOMAIN, TAG, 'Failed to get top safe height: %{public}s', JSON.stringify(error));
    }
  }

  // ==================== 订单相关方法 ====================

  /**
   * 加载订单列表
   */
  private async loadOrders(): Promise<void> {
    this.isOrderLoading = true;
    this.orderPageNumber = 1;
    this.orders = [];
    this.hasMoreOrders = true;

    try {
      // 确保有游客token
      if (!apiService.hasToken()) {
        hilog.info(DOMAIN, TAG, 'No token for orders, getting guest token first');
        await apiService.getGuestToken();
      }

      const response = await apiService.getOrders(this.orderFilterType, this.orderPageNumber, 10);

      if (response.code === 200 && response.data) {
        this.orders = response.data.order_list || [];
        this.orderTotal = parseInt(response.data.total) || 0;
        this.hasMoreOrders = this.orders.length < this.orderTotal;
        hilog.info(DOMAIN, TAG, 'Orders loaded: %{public}d / %{public}d', this.orders.length, this.orderTotal);
      } else {
        hilog.warn(DOMAIN, TAG, 'Failed to load orders: %{public}s', response.msg);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load orders: %{public}s', JSON.stringify(error));
    } finally {
      this.isOrderLoading = false;
    }
  }

  /**
   * 加载更多订单（分页）
   */
  private async loadMoreOrders(): Promise<void> {
    if (this.isOrderLoading || !this.hasMoreOrders) {
      return;
    }

    this.isOrderLoading = true;
    this.orderPageNumber++;

    try {
      const response = await apiService.getOrders(this.orderFilterType, this.orderPageNumber, 10);

      if (response.code === 200 && response.data) {
        const newOrders = response.data.order_list || [];
        this.orders = this.orders.concat(newOrders);
        this.hasMoreOrders = this.orders.length < this.orderTotal;
        hilog.info(DOMAIN, TAG, 'More orders loaded: %{public}d / %{public}d', this.orders.length, this.orderTotal);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load more orders: %{public}s', JSON.stringify(error));
      this.orderPageNumber--; // 回退页码
    } finally {
      this.isOrderLoading = false;
    }
  }

  /**
   * 筛选器切换
   */
  private onFilterChange(filterType: OrderFilterType): void {
    this.showFilterDropdown = false;
    if (this.orderFilterType !== filterType) {
      this.orderFilterType = filterType;
      this.loadOrders();
    }
  }

  /**
   * 获取筛选器标签
   */
  private getFilterLabel(): string {
    switch (this.orderFilterType) {
      case OrderFilterType.IN_PROGRESS:
        return '進行中';
      case OrderFilterType.COMPLETED:
        return '已完成';
      case OrderFilterType.REFUND:
        return '退款/取消';
      default:
        return '全部訂單';
    }
  }

  /**
   * 获取状态显示文本
   */
  private getStatusText(status: string): string {
    switch (status) {
      case 'pending':
        return '待處理';
      case 'confirmed':
        return '已確認';
      case 'preparing':
        return '準備中';
      case 'ready':
        return '待取餐';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'refunded':
        return '已退款';
      default:
        return status;
    }
  }

  /**
   * 获取状态文字颜色
   */
  private getStatusColor(status: string): string {
    switch (status) {
      case 'pending':
      case 'confirmed':
      case 'preparing':
      case 'ready':
        return '#FF8C00'; // 进行中 - 橙色
      case 'completed':
        return '#4CAF50'; // 已完成 - 绿色
      case 'cancelled':
      case 'refunded':
        return '#999999'; // 取消/退款 - 灰色
      default:
        return '#666666';
    }
  }

  /**
   * 获取状态背景颜色
   */
  private getStatusBgColor(status: string): string {
    switch (status) {
      case 'pending':
      case 'confirmed':
      case 'preparing':
      case 'ready':
        return '#FFF3E0'; // 进行中 - 浅橙色
      case 'completed':
        return '#E8F5E9'; // 已完成 - 浅绿色
      case 'cancelled':
      case 'refunded':
        return '#F5F5F5'; // 取消/退款 - 浅灰色
      default:
        return '#F5F5F5';
    }
  }

  /**
   * 再来一单
   */
  private reorder(order: Order): void {
    hilog.info(DOMAIN, TAG, 'Reorder: %{public}s', order.order_no);
    // TODO: 实现再来一单逻辑，将订单商品添加到购物车
  }
}
