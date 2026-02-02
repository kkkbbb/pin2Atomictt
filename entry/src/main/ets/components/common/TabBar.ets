/**
 * TabBar 统一 Tab 栏组件
 *
 * 功能：
 * - 统一的 Tab 切换栏
 * - 支持徽章显示
 * - 支持自定义颜色
 *
 * 替换位置：
 * - MenuPage.ets L402-529
 * - CouponPage.ets L89-146
 */

export interface TabItem {
  id: string | number;
  label: string;
  badge?: string | number;
}

export interface TabBarConfig {
  tabs: TabItem[];
  selectedId: string | number;
  activeColor?: ResourceColor;
  inactiveColor?: ResourceColor;
  backgroundColor?: ResourceColor;
  onTabChange: (id: string | number) => void;
}

@Component
export struct TabBar {
  @Prop config: TabBarConfig = {
    tabs: [],
    selectedId: 0,
    activeColor: '#FFD700',
    inactiveColor: '#999999',
    backgroundColor: '#FFFFFF',
    onTabChange: () => {}
  };

  build() {
    Row() {
      ForEach(this.config.tabs, (tab: TabItem) => {
        Column({ space: 4 }) {
          // Tab 文本
          Row() {
            Text(tab.label)
              .fontSize(16)
              .fontWeight(this.config.selectedId === tab.id ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.config.selectedId === tab.id ? this.config.activeColor : this.config.inactiveColor)

            // 徽章
            if (tab.badge !== undefined && tab.badge !== null && tab.badge !== '' && tab.badge !== 0) {
              Row() {
                Text(typeof tab.badge === 'number' && tab.badge > 99 ? '99+' : tab.badge.toString())
                  .fontSize(10)
                  .fontColor('#FFFFFF')
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              }
              .height(16)
              .constraintSize({ minWidth: 16 })
              .backgroundColor('#FF0000')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .margin({ left: 4 })
            }
          }

          // 选中指示器
          Row()
            .width(40)
            .height(3)
            .backgroundColor(this.config.selectedId === tab.id ? this.config.activeColor : Color.Transparent)
            .borderRadius(1.5)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          if (this.config.selectedId !== tab.id) {
            this.config.onTabChange(tab.id);
          }
        })
      })
    }
    .width('100%')
    .backgroundColor(this.config.backgroundColor)
    .shadow({
      radius: 4,
      color: '#10000000',
      offsetY: 2
    })
  }
}
