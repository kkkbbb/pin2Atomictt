/**
 * BottomBar 统一底部操作栏组件
 *
 * 功能：
 * - 统一的底部操作栏样式
 * - 支持自定义左侧内容
 * - 支持主操作按钮
 *
 * 替换位置：
 * - CheckoutPage.ets L1045-1085
 */

export interface BottomBarConfig {
  leftContent?: () => void;
  primaryButton?: {
    text: string;
    disabled?: boolean;
    loading?: boolean;
    onClick: () => void;
  };
  backgroundColor?: ResourceColor;
  showShadow?: boolean;
}

@Component
export struct BottomBar {
  @Prop config: BottomBarConfig = {
    backgroundColor: '#FFFFFF',
    showShadow: true
  };
  @BuilderParam leftContent?: () => void;

  build() {
    Column() {
      Row() {
        // 左侧内容
        if (this.leftContent) {
          Row() {
            this.leftContent();
          }
          .layoutWeight(1)
        }

        // 主按钮
        if (this.config.primaryButton) {
          Button(this.config.primaryButton.text)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.config.primaryButton.disabled ? '#CCCCCC' : '#333333')
            .backgroundColor(this.config.primaryButton.disabled ? '#F0F0F0' : '#FFD700')
            .borderRadius(8)
            .padding({ left: 32, right: 32, top: 12, bottom: 12 })
            .enabled(!this.config.primaryButton.disabled && !this.config.primaryButton.loading)
            .onClick(() => {
              if (this.config.primaryButton && !this.config.primaryButton.disabled) {
                this.config.primaryButton.onClick();
              }
            })

          if (this.config.primaryButton.loading) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color('#FFD700')
              .position({ x: '50%', y: '50%' })
              .markAnchor({ x: '50%', y: '50%' })
          }
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.config.backgroundColor)

      // 底部安全区域
      Row()
        .width('100%')
        .height(px2vp(AppStorage.get<number>('bottomSafeHeight') ?? 0))
        .backgroundColor(this.config.backgroundColor)
    }
    .width('100%')
    .shadow(this.config.showShadow ? {
      radius: 8,
      color: '#20000000',
      offsetY: -2
    } : undefined)
  }
}
