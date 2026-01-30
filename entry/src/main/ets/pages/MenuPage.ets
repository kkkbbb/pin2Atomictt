import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { apiService } from '../services/ApiService';
import { ProductGroup, Product, OrderType, HomeData } from '../models/StoreModels';

const DOMAIN = 0x0000;
const TAG = 'MenuPage';

@Entry
@Component
struct MenuPage {
  @State isLoading: boolean = true;
  @State productGroups: ProductGroup[] = [];
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

  private scroller: Scroller = new Scroller();
  private categoryScroller: Scroller = new Scroller();

  build() {
    Column() {
      // 顶部店铺信息区域
      this.StoreHeader()

      // 公告栏
      if (this.notices.length > 0) {
        this.NoticeBar()
      }

      // Tab 导航
      this.TabBar()

      // 服务类型头部 + 语言切换
      this.ServiceHeader()

      if (this.isLoading) {
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
    .backgroundColor($r('app.color.page_background'))
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
        // 返回按钮
        Text('‹')
          .width(32)
          .height(32)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .margin({ left: 8, top: 20 })
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
        .margin({ left: 8, top: 20 })

        // 店铺信息
        Column() {
          // 店铺名称
          Text(this.storeName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 状态标签行
          Flex({ wrap: FlexWrap.Wrap }) {
            // 商家状态标签
            if (this.storeStatus) {
              Text(this.storeStatus)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor($r('app.color.tag_background'))
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            }

            // 今日状态标签
            if (this.todayStatus) {
              Text(this.todayStatus)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .backgroundColor($r('app.color.tag_background'))
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .margin({ left: 6 })
            }

            // 关于商户按钮
            Row() {
              Text('關於商戶')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
              Text(' ⓘ')
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
            .backgroundColor($r('app.color.card_background'))
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
        .margin({ left: 12, top: 25 })
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height(120)
  }

  // 公告栏
  @Builder
  NoticeBar() {
    Row() {
      // 公告标签
      Text('公告:')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })

      // 公告内容
      Text(this.notices.join(' | '))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(this.showNoticeExpand ? 10 : 1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8, right: 8 })

      // 展开箭头
      Text(this.showNoticeExpand ? '▲' : '▼')
        .fontSize(12)
        .fontColor($r('app.color.text_hint'))
        .margin({ right: 12 })
        .onClick(() => {
          this.showNoticeExpand = !this.showNoticeExpand;
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .backgroundColor($r('app.color.notice_background'))
    .alignItems(VerticalAlign.Center)
  }

  // Tab 导航栏
  @Builder
  TabBar() {
    Row() {
      // 主頁 Tab
      Column() {
        Text('主頁')
          .fontSize(15)
          .fontColor(this.currentTab === 0 ? $r('app.color.text_primary') : $r('app.color.tab_inactive'))
          .fontWeight(this.currentTab === 0 ? FontWeight.Bold : FontWeight.Normal)
        if (this.currentTab === 0) {
          Column()
            .width(30)
            .height(3)
            .backgroundColor(this.themeColor)
            .borderRadius(2)
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        // 返回首页
        router.back();
      })

      // 點餐 Tab
      Column() {
        Text('點餐')
          .fontSize(15)
          .fontColor(this.currentTab === 1 ? $r('app.color.text_primary') : $r('app.color.tab_inactive'))
          .fontWeight(this.currentTab === 1 ? FontWeight.Bold : FontWeight.Normal)
        if (this.currentTab === 1) {
          Column()
            .width(30)
            .height(3)
            .backgroundColor(this.themeColor)
            .borderRadius(2)
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentTab = 1;
      })

      // 歷史訂單 Tab
      Column() {
        Text('歷史訂單')
          .fontSize(15)
          .fontColor(this.currentTab === 2 ? $r('app.color.text_primary') : $r('app.color.tab_inactive'))
          .fontWeight(this.currentTab === 2 ? FontWeight.Bold : FontWeight.Normal)
        if (this.currentTab === 2) {
          Column()
            .width(50)
            .height(3)
            .backgroundColor(this.themeColor)
            .borderRadius(2)
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.currentTab = 2;
        // TODO: 跳转到历史订单页
        hilog.info(DOMAIN, TAG, 'Navigate to order history');
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  // 服务类型头部
  @Builder
  ServiceHeader() {
    Row() {
      // 左侧：服务类型图标和文字
      Row() {
        // 外卖/自取图标
        Text('📦')
          .fontSize(16)
        Text(this.orderType === OrderType.PICKUP ? '外賣自取' : '堂食')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 6 })
      }
      .padding({ left: 12 })

      Blank()

      // 右侧：语言切换
      Row() {
        Text(this.currentLang)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Text(' Language')
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
      }
      .padding({ right: 12 })
      .onClick(() => {
        // 切换语言
        this.currentLang = this.currentLang === '繁' ? '简' : '繁';
        hilog.info(DOMAIN, TAG, 'Switch language to: %{public}s', this.currentLang);
      })
    }
    .width('100%')
    .height(44)
    .backgroundColor($r('app.color.card_background'))
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  // 加载中
  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(60)
        .height(60)
        .color(this.themeColor)
      Text('載入菜單中...')
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 16 })
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
          Column() {
            Text(group.local_name)
              .fontSize(13)
              .fontColor(this.selectedGroupIndex === index ?
                this.themeColor : $r('app.color.text_secondary'))
              .fontWeight(this.selectedGroupIndex === index ?
                FontWeight.Bold : FontWeight.Normal)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height(56)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 6, right: 6 })
          .backgroundColor(this.selectedGroupIndex === index ?
            $r('app.color.card_background') : 'transparent')
          .borderRadius({ topRight: 6, bottomRight: 6 })
          .onClick(() => {
            this.selectedGroupIndex = index;
            // 滚动到对应分组
            this.scroller.scrollToIndex(this.getProductListIndexForGroup(index));
          })
        }
      })
    }
    .width(85)
    .height('100%')
    .backgroundColor($r('app.color.service_card_background'))
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
              .fontColor($r('app.color.text_primary'))

            // 供应时间（如果有）
            if (group.time_range) {
              Text(`  供應時間 ${group.time_range}`)
                .fontSize(12)
                .fontColor($r('app.color.text_hint'))
            } else {
              Text('  供應時間-')
                .fontSize(12)
                .fontColor($r('app.color.text_hint'))
            }
          }
          .width('100%')
          .padding({ left: 12, top: 14, bottom: 8 })
        }

        // 产品列表
        ForEach(group.products, (product: Product) => {
          ListItem() {
            this.ProductItem(product)
          }
        })
      })
    }
    .layoutWeight(1)
    .height('100%')
    .padding({ right: 8 })
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

  // 产品项
  @Builder
  ProductItem(product: Product) {
    Row() {
      // 产品图片
      if (product.cover_image) {
        Image(product.cover_image)
          .width(85)
          .height(85)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(85)
          .height(85)
          .borderRadius(8)
          .backgroundColor($r('app.color.tag_background'))
      }

      // 产品信息
      Column() {
        // 产品名称
        Text(product.local_name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 产品描述
        if (product.description?.local_description) {
          Text(product.description.local_description)
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }

        Blank()

        // 价格和添加按钮
        Row() {
          // 价格
          Text(`${this.currencySymbol}${this.getPrice(product)}`)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColor)

          Blank()

          // 添加按钮
          Button('+')
            .width(30)
            .height(30)
            .fontSize(18)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(this.themeColor)
            .borderRadius(15)
            .onClick(() => {
              this.addToCart(product);
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .height(85)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(10)
    .margin({ top: 6, left: 8 })
  }

  aboutToAppear() {
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
    }

    // 如果没有从路由获取到店铺信息，则加载
    if (!this.storeName) {
      this.loadStoreData();
    }

    this.loadMenuData();
  }

  /**
   * 加载店铺数据
   */
  private async loadStoreData(): Promise<void> {
    try {
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
      const takeout = this.orderType === OrderType.PICKUP ? 1 : 0;
      const response = await apiService.getProductMenus(takeout);

      if (response.code === 200 && response.data) {
        this.productGroups = response.data.group || [];
        hilog.info(DOMAIN, TAG, 'Menu loaded: %{public}d groups', this.productGroups.length);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load menu: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
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
   * 添加到购物车
   */
  private addToCart(product: Product): void {
    hilog.info(DOMAIN, TAG, 'Add to cart: %{public}s', product.local_name);
    // TODO: 实现购物车逻辑
  }

  /**
   * 显示店铺详情
   */
  private showStoreInfo(): void {
    hilog.info(DOMAIN, TAG, 'Show store info');
    // TODO: 跳转到店铺详情页
  }
}
