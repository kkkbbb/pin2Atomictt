/**
 * DiscountState - 折扣响应式状态管理
 *
 * 核心改进：
 * - ✅ 统一管理折扣状态（消除 3 个页面的重复定义）
 * - ✅ 观察者模式，折扣变化时 UI 自动响应
 * - ✅ 集成 DiscountManager 计算逻辑
 * - ✅ 类型安全的状态访问
 *
 * 使用示例：
 * ```typescript
 * // 订阅折扣状态
 * discountState.subscribe({
 *   onStateChange: (state) => {
 *     this.hasDiscount = state.hasDiscount;
 *     this.discountRatio = state.discountRatio;
 *     this.discountLabel = state.discountLabel;
 *   }
 * });
 *
 * // 更新折扣信息（从 API 获取后）
 * discountState.updateDiscount({
 *   hasDiscount: true,
 *   discountRatio: 0.9,
 *   discountLabel: '10%Discount',
 *   appliedOrderType: OrderType.PICKUP
 * });
 * ```
 */

import { ReactiveState } from '../StateManager';
import {
  DiscountManager,
  CartItemForDiscount,
  CartDiscountResult
} from '../../utils/DiscountManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OrderType } from '../../models/StoreModels';

const DOMAIN = 0x0000;
const TAG = 'DiscountState';

/**
 * 折扣状态数据结构
 */
export interface DiscountStateData {
  hasDiscount: boolean;
  discountRatio: number;      // 0.9 表示 10% 折扣
  discountLabel: string;       // "10%Discount"
  appliedOrderType: OrderType; // 折扣适用的订单类型（通常是 PICKUP）
}

/**
 * 折扣响应式状态管理
 */
export class DiscountState extends ReactiveState<DiscountStateData> {
  private static instance: DiscountState | null = null;

  constructor() {
    super({
      hasDiscount: false,
      discountRatio: 1.0,
      discountLabel: '',
      appliedOrderType: OrderType.PICKUP
    });
  }

  /**
   * 获取单例
   */
  static getInstance(): DiscountState {
    if (!DiscountState.instance) {
      DiscountState.instance = new DiscountState();
    }
    return DiscountState.instance;
  }

  /**
   * 创建只读副本（防止外部修改状态）
   */
  protected createReadonlyCopy(value: DiscountStateData): Readonly<DiscountStateData> {
    return {
      hasDiscount: value.hasDiscount,
      discountRatio: value.discountRatio,
      discountLabel: value.discountLabel,
      appliedOrderType: value.appliedOrderType
    };
  }

  /**
   * 更新折扣信息（自动触发观察者）
   */
  updateDiscount(discount: Partial<DiscountStateData>): void {
    const currentState = this.value;

    const newState: DiscountStateData = {
      hasDiscount: discount.hasDiscount ?? currentState.hasDiscount,
      discountRatio: discount.discountRatio ?? currentState.discountRatio,
      discountLabel: discount.discountLabel ?? currentState.discountLabel,
      appliedOrderType: discount.appliedOrderType ?? currentState.appliedOrderType
    };

    this.setValue(newState);

    hilog.info(DOMAIN, TAG, 'Discount updated: hasDiscount=%{public}s, ratio=%{public}f, label=%{public}s',
      newState.hasDiscount, newState.discountRatio, newState.discountLabel);
  }

  /**
   * 重置折扣状态（自动触发观察者）
   */
  resetDiscount(): void {
    this.setValue({
      hasDiscount: false,
      discountRatio: 1.0,
      discountLabel: '',
      appliedOrderType: OrderType.PICKUP
    });

    hilog.info(DOMAIN, TAG, 'Discount reset');
  }

  /**
   * 计算折扣价格（集成 DiscountManager）
   */
  calculateDiscountPrice(originalPrice: number, orderType: OrderType): number {
    const state = this.value;
    return DiscountManager.calculateDiscountPrice(originalPrice, orderType, state.discountRatio);
  }

  /**
   * 判断是否应用折扣（集成 DiscountManager）
   */
  shouldApplyDiscount(orderType: OrderType): boolean {
    const state = this.value;
    return DiscountManager.shouldApplyDiscount(orderType, state.hasDiscount);
  }

  /**
   * 获取折扣标签文本（集成 DiscountManager）
   */
  getDiscountBadgeText(): string {
    const state = this.value;
    if (!state.hasDiscount) {
      return '';
    }
    return DiscountManager.getDiscountBadgeText(
      state.discountLabel || DiscountManager.formatDiscountLabel(state.discountRatio)
    );
  }

  /**
   * 批量计算购物车折扣（集成 DiscountManager）
   */
  calculateCartDiscount(
    items: CartItemForDiscount[],
    orderType: OrderType
  ): CartDiscountResult {
    const state = this.value;
    return DiscountManager.calculateCartDiscountTotal(items, orderType, state.discountRatio);
  }

  /**
   * 获取当前折扣信息（只读）
   */
  getDiscountInfo(): Readonly<DiscountStateData> {
    return this.value;
  }

  /**
   * 是否有折扣
   */
  hasDiscountEnabled(): boolean {
    return this.value.hasDiscount;
  }

  /**
   * 获取折扣比例
   */
  getDiscountRatio(): number {
    return this.value.discountRatio;
  }

  /**
   * 获取折扣标签
   */
  getDiscountLabel(): string {
    return this.value.discountLabel;
  }
}

// 导出单例
export const discountState = DiscountState.getInstance();
