/**
 * LoadingView 统一加载状态组件
 *
 * 功能：
 * - 统一的 Loading 状态显示
 * - 支持自定义加载文本
 * - 支持骨架屏模式
 *
 * 替换位置：
 * - Index.ets L197-374
 * - MenuPage.ets L531-547
 * - OrderDetailPage.ets L330-345
 * - CouponPage.ets L148-164
 */

export enum SkeletonType {
  LIST = 'list',
  CARD = 'card',
  DETAIL = 'detail'
}

export interface LoadingViewConfig {
  message?: string;
  showSpinner?: boolean;
  skeletonType?: SkeletonType;
}

@Component
export struct LoadingView {
  @Prop config: LoadingViewConfig = {
    message: '加載中...',
    showSpinner: true
  };

  build() {
    Column() {
      if (this.config.skeletonType) {
        this.buildSkeleton()
      } else {
        this.buildSpinner()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  buildSpinner() {
    Column({ space: 16 }) {
      if (this.config.showSpinner) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#FFD700')
      }

      if (this.config.message) {
        Text(this.config.message)
          .fontSize(14)
          .fontColor('#999999')
      }
    }
  }

  @Builder
  buildSkeleton() {
    Column({ space: 12 }) {
      if (this.config.skeletonType === SkeletonType.LIST) {
        ForEach([1, 2, 3, 4, 5], (item: number) => {
          this.buildListItemSkeleton()
        })
      } else if (this.config.skeletonType === SkeletonType.CARD) {
        this.buildCardSkeleton()
      } else if (this.config.skeletonType === SkeletonType.DETAIL) {
        this.buildDetailSkeleton()
      }
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  buildListItemSkeleton() {
    Row({ space: 12 }) {
      // 图片占位
      Row()
        .width(70)
        .height(70)
        .borderRadius(8)
        .backgroundColor('#E0E0E0')
        .sharedTransition('skeleton_shimmer', {
          duration: 1000,
          curve: Curve.Linear
        })

      // 文本占位
      Column({ space: 8 }) {
        Row()
          .width('80%')
          .height(16)
          .borderRadius(4)
          .backgroundColor('#E0E0E0')

        Row()
          .width('60%')
          .height(14)
          .borderRadius(4)
          .backgroundColor('#E0E0E0')

        Row()
          .width('40%')
          .height(14)
          .borderRadius(4)
          .backgroundColor('#E0E0E0')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  buildCardSkeleton() {
    Column({ space: 12 }) {
      // 大图占位
      Row()
        .width('100%')
        .height(180)
        .borderRadius(8)
        .backgroundColor('#E0E0E0')

      // 标题占位
      Row()
        .width('70%')
        .height(20)
        .borderRadius(4)
        .backgroundColor('#E0E0E0')

      // 描述占位
      Row()
        .width('90%')
        .height(14)
        .borderRadius(4)
        .backgroundColor('#E0E0E0')

      Row()
        .width('60%')
        .height(14)
        .borderRadius(4)
        .backgroundColor('#E0E0E0')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  buildDetailSkeleton() {
    Column({ space: 16 }) {
      // 头部占位
      Row()
        .width('100%')
        .height(200)
        .borderRadius(8)
        .backgroundColor('#E0E0E0')

      // 信息占位
      Column({ space: 8 }) {
        ForEach([1, 2, 3, 4], (item: number) => {
          Row()
            .width('100%')
            .height(16)
            .borderRadius(4)
            .backgroundColor('#E0E0E0')
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
  }
}
