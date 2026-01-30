import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { apiService } from '../services/ApiService';
import { ProductGroup, Product, OrderType } from '../models/StoreModels';

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

  private scroller: Scroller = new Scroller();

  build() {
    Column() {
      // 顶部导航栏
      this.NavBar()

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

  // 导航栏
  @Builder
  NavBar() {
    Row() {
      // 返回按钮
      Text('<')
        .width(24)
        .height(24)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .onClick(() => {
          router.back();
        })

      // 标题
      Text(this.orderType === OrderType.PICKUP ? '自取點餐' : '堂食點餐')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位
      Blank()
        .width(24)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
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
    List() {
      ForEach(this.productGroups, (group: ProductGroup, index: number) => {
        ListItem() {
          Column() {
            Text(group.local_name)
              .fontSize(14)
              .fontColor(this.selectedGroupIndex === index ?
                this.themeColor : $r('app.color.text_secondary'))
              .fontWeight(this.selectedGroupIndex === index ?
                FontWeight.Bold : FontWeight.Normal)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height(60)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 8, right: 8 })
          .backgroundColor(this.selectedGroupIndex === index ?
            $r('app.color.card_background') : 'transparent')
          .borderRadius({ topRight: 8, bottomRight: 8 })
          .onClick(() => {
            this.selectedGroupIndex = index;
            // 滚动到对应分组
            this.scroller.scrollToIndex(index);
          })
        }
      })
    }
    .width(90)
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
          Text(group.local_name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 12, top: 16, bottom: 8 })
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
    .padding({ right: 12 })
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
          .width(90)
          .height(90)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(90)
          .height(90)
          .borderRadius(8)
          .backgroundColor($r('app.color.tag_background'))
      }

      // 产品信息
      Column() {
        // 产品名称
        Text(product.local_name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 产品描述
        if (product.description?.local_description) {
          Text(product.description.local_description)
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }

        Blank()

        // 价格和添加按钮
        Row() {
          // 价格
          Text(`${this.currencySymbol}${this.getPrice(product)}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColor)

          Blank()

          // 添加按钮
          Button('+')
            .width(32)
            .height(32)
            .fontSize(20)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(this.themeColor)
            .borderRadius(16)
            .onClick(() => {
              this.addToCart(product);
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .height(90)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ top: 8, left: 12 })
  }

  aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.orderType = (params['orderType'] as OrderType) || OrderType.PICKUP;
      this.themeColor = (params['themeColor'] as string) || '#FFD700';
    }

    this.loadMenuData();
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
   * 添加到购物车
   */
  private addToCart(product: Product): void {
    hilog.info(DOMAIN, TAG, 'Add to cart: %{public}s', product.local_name);
    // TODO: 实现购物车逻辑
  }
}
