/**
 * DiscountManager 折扣管理工具类
 *
 * 功能：
 * - 统一折扣信息解析（新老 API 格式兼容）
 * - 统一折扣价格计算（仅 PICKUP 订单）
 * - 统一折扣标签格式化
 *
 * 替换位置：
 * - Index.ets L1808-1825
 * - MenuPage.ets L730-763
 * - CheckoutPage.ets L171-190
 */

import { OrderType } from '../models/StoreModels';

export interface DiscountInfo {
  hasDiscount: boolean;
  discountRatio: number;
  discountLabel: string;
}

export class DiscountManager {
  /**
   * 从 API 配置解析折扣信息
   * 兼容新老两种格式：
   * 1. 新格式：config.extend.product_adjust_amount.data[0]
   * 2. 老格式：config.has_discount, config.discount
   */
  static parseDiscountFromConfig(config: ESObject): DiscountInfo {
    const defaultDiscount: DiscountInfo = {
      hasDiscount: false,
      discountRatio: 1.0,
      discountLabel: ''
    };

    if (!config) {
      return defaultDiscount;
    }

    try {
      // 尝试解析新格式
      if (config['extend']) {
        const extend: ESObject = config['extend'] as ESObject;
        if (extend['product_adjust_amount']) {
          const productAdjustAmount: ESObject = extend['product_adjust_amount'] as ESObject;
          if (productAdjustAmount['data']) {
            const dataArray: ESObject[] = productAdjustAmount['data'] as ESObject[];
            if (Array.isArray(dataArray) && dataArray.length > 0) {
              const discountData: ESObject = dataArray[0];
              if (discountData['ext']) {
                const ext: ESObject = discountData['ext'] as ESObject;
                if (ext['ratio']) {
                  const ratio: number = ext['ratio'] as number;
                  if (typeof ratio === 'number' && ratio > 0 && ratio < 1) {
                    const name: string = (discountData['name'] as string) || '';
                    return {
                      hasDiscount: true,
                      discountRatio: ratio,
                      discountLabel: name || DiscountManager.formatDiscountLabel(ratio)
                    };
                  }
                }
              }
            }
          }
        }
      }

      // 回退到老格式
      if (config['has_discount']) {
        const hasDiscount: number = config['has_discount'] as number;
        if (hasDiscount === 1 && config['discount']) {
          const discount: number = config['discount'] as number;
          if (typeof discount === 'number' && discount > 0) {
            const ratio = (100 - discount) / 100;
            return {
              hasDiscount: true,
              discountRatio: ratio,
              discountLabel: DiscountManager.formatDiscountLabel(ratio)
            };
          }
        }
      }

      return defaultDiscount;
    } catch (error) {
      console.error('[DiscountManager] 解析折扣配置失败:', error);
      return defaultDiscount;
    }
  }

  /**
   * 计算折扣价格
   * 注意：折扣仅适用于 PICKUP 订单 (OrderType.PICKUP = 2)
   */
  static calculateDiscountPrice(originalPrice: number, orderType: OrderType, discountRatio: number): number {
    if (orderType !== OrderType.PICKUP) {
      return originalPrice;
    }

    if (discountRatio <= 0 || discountRatio > 1) {
      return originalPrice;
    }

    return parseFloat((originalPrice * discountRatio).toFixed(2));
  }

  /**
   * 格式化折扣标签
   * 示例：0.9 → "九折優惠" 或 "10%Discount"
   */
  static formatDiscountLabel(discountRatio: number): string {
    if (discountRatio <= 0 || discountRatio >= 1) {
      return '';
    }

    const discountPercent = Math.round((1 - discountRatio) * 100);
    return `${discountPercent}%折扣`;
  }

  /**
   * 生成折扣标签文本（用于 UI 显示）
   * 示例：外賣自取10%Discount
   */
  static getDiscountBadgeText(discountLabel: string): string {
    if (!discountLabel) {
      return '';
    }
    return `外賣自取${discountLabel}`;
  }

  /**
   * 判断是否应用折扣
   */
  static shouldApplyDiscount(orderType: OrderType, hasDiscount: boolean): boolean {
    return orderType === OrderType.PICKUP && hasDiscount;
  }

  /**
   * 计算购物车总折扣价格
   */
  static calculateCartDiscountTotal(
    items: CartItemForDiscount[],
    orderType: OrderType,
    discountRatio: number
  ): CartDiscountResult {
    const originalTotal = items.reduce((sum: number, item: CartItemForDiscount) =>
      sum + item.unitPrice * item.quantity, 0);
    const discountTotal = DiscountManager.calculateDiscountPrice(originalTotal, orderType, discountRatio);

    return {
      originalTotal: parseFloat(originalTotal.toFixed(2)),
      discountTotal: parseFloat(discountTotal.toFixed(2))
    };
  }
}

// 辅助接口定义
export interface CartItemForDiscount {
  unitPrice: number;
  quantity: number;
}

export interface CartDiscountResult {
  originalTotal: number;
  discountTotal: number;
}
