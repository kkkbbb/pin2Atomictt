/**
 * EmptyState 统一空状态组件
 *
 * 功能：
 * - 统一的空状态显示
 * - 支持自定义图标、标题、描述
 * - 支持操作按钮
 *
 * 替换位置：
 * - MenuPage.ets L979-1008
 * - CouponPage.ets L360-383
 */

export interface EmptyStateConfig {
  icon?: string | ResourceStr;
  title: string;
  message?: string;
  actionText?: string;
  onAction?: () => void;
}

@Component
export struct EmptyState {
  @Prop config: EmptyStateConfig;

  build() {
    Column({ space: 16 }) {
      // 图标
      if (this.config.icon) {
        if (typeof this.config.icon === 'string') {
          Image(this.config.icon)
            .width(120)
            .height(120)
            .objectFit(ImageFit.Contain)
        } else {
          Image(this.config.icon)
            .width(120)
            .height(120)
            .objectFit(ImageFit.Contain)
        }
      } else {
        // 默认空状态图标（使用文本表情符号）
        Text('📭')
          .fontSize(80)
          .width(120)
          .height(120)
          .textAlign(TextAlign.Center)
      }

      // 标题
      Text(this.config.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)

      // 描述
      if (this.config.message) {
        Text(this.config.message)
          .fontSize(14)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('80%')
      }

      // 操作按钮
      if (this.config.actionText && this.config.onAction) {
        Button(this.config.actionText)
          .fontSize(14)
          .fontColor('#FFD700')
          .backgroundColor('#FFFFFF')
          .border({
            width: 1,
            color: '#FFD700'
          })
          .borderRadius(20)
          .padding({ left: 24, right: 24, top: 8, bottom: 8 })
          .margin({ top: 8 })
          .onClick(() => {
            if (this.config.onAction) {
              this.config.onAction();
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(32)
  }
}
