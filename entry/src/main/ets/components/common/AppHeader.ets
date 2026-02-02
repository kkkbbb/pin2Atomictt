/**
 * AppHeader 统一顶部导航栏组件
 *
 * 功能：
 * - 统一的顶部导航栏样式
 * - 状态栏安全区域处理
 * - 可选返回按钮
 * - 自定义背景色
 *
 * 替换位置：
 * - Index.ets L405-548
 * - MenuPage.ets L192-323
 */

export interface AppHeaderConfig {
  title?: string;
  showBackButton?: boolean;
  showStatusBar?: boolean;
  backgroundColor?: string | ResourceColor;
  statusText?: string;
  statusColor?: string | ResourceColor;
  onBackClick?: () => void;
}

@Component
export struct AppHeader {
  @Prop config: AppHeaderConfig = {
    showBackButton: false,
    showStatusBar: false,
    backgroundColor: '#FFFFFF'
  };

  build() {
    Column() {
      // 状态栏占位
      Row()
        .width('100%')
        .height(px2vp(AppStorage.get<number>('statusBarHeight') ?? 0))
        .backgroundColor(this.config.backgroundColor)

      // 导航栏
      Row() {
        // 返回按钮
        if (this.config.showBackButton) {
          Row() {
            Image($r('sys.symbol.chevron_left'))
              .width(24)
              .height(24)
              .fillColor('#333333')
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.config.onBackClick) {
              this.config.onBackClick();
            } else {
              router.back();
            }
          })
        }

        // 标题
        if (this.config.title) {
          Text(this.config.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .layoutWeight(1)
            .textAlign(this.config.showBackButton ? TextAlign.Center : TextAlign.Start)
            .margin({ left: this.config.showBackButton ? 0 : 16 })
        }

        // 状态指示器
        if (this.config.showStatusBar && this.config.statusText) {
          Row() {
            Text(this.config.statusText)
              .fontSize(14)
              .fontColor(this.config.statusColor || '#FAD701')
              .padding({ horizontal: 12, vertical: 4 })
              .borderRadius(12)
              .backgroundColor(this.config.statusColor ?
                Color.Transparent :
                '#FAD701')
              .fontColor(this.config.statusColor ?
                (this.config.statusColor as string) :
                '#333333')
          }
          .padding({ right: 16 })
        }

        // 占位（保持居中）
        if (this.config.showBackButton && !this.config.showStatusBar) {
          Row()
            .width(44)
            .height(44)
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor(this.config.backgroundColor)
    }
    .width('100%')
  }
}

import router from '@ohos.router';
