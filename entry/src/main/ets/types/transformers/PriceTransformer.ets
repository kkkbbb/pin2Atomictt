/**
 * PriceTransformer - 价格类型转换器
 *
 * 功能：
 * - 安全转换价格字符串为数值（带 NaN 检查）
 * - 批量转换价格对象字段
 * - 格式化价格显示
 *
 * 解决问题：
 * - Product.price: string → number（消除重复 parseFloat）
 * - 统一 NaN 处理，默认值 0
 * - 类型安全的价格计算
 *
 * 使用示例：
 * ```typescript
 * // 单个价格转换
 * const price = PriceTransformer.toNumber(product.price);  // 安全转换，NaN → 0
 *
 * // 批量转换对象字段
 * const transformedProduct = PriceTransformer.transformPriceFields(product, ['price', 'takeout_price']);
 *
 * // 格式化显示
 * const display = PriceTransformer.formatDisplay(123.45, '$');  // "$123.5"
 * ```
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'PriceTransformer';

export class PriceTransformer {
  /**
   * 安全转换价格字符串为数值（带 NaN 检查）
   * @param priceStr 价格字符串或数值
   * @param defaultValue 默认值（当转换失败时）
   * @returns 转换后的数值
   */
  static toNumber(priceStr: string | number, defaultValue: number = 0): number {
    if (typeof priceStr === 'number') {
      return isNaN(priceStr) ? defaultValue : priceStr;
    }

    if (typeof priceStr === 'string') {
      const trimmed = priceStr.trim();
      if (trimmed === '' || trimmed === 'null' || trimmed === 'undefined') {
        return defaultValue;
      }

      const parsed = parseFloat(trimmed);
      if (isNaN(parsed)) {
        hilog.warn(DOMAIN, TAG, 'Failed to parse price: %{public}s, using default: %{public}d',
          priceStr, defaultValue);
        return defaultValue;
      }

      return parsed;
    }

    hilog.warn(DOMAIN, TAG, 'Invalid price type: %{public}s, using default: %{public}d',
      typeof priceStr, defaultValue);
    return defaultValue;
  }

  /**
   * 批量转换对象的价格字段
   * @param obj 待转换的对象
   * @param priceFields 价格字段名称数组
   * @returns 转换后的新对象（不修改原对象）
   */
  static transformPriceFields<T extends Record<string, string | number | object>>(
    obj: T,
    priceFields: string[]
  ): T {
    const result: Record<string, string | number | object> = {};

    // 复制所有字段 (使用 Object.keys 避免 hasOwnProperty)
    const keys = Object.keys(obj);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      result[key] = obj[key];
    }

    // 转换价格字段 (通过遍历 priceFields 而不是使用 in 操作符)
    for (let i = 0; i < priceFields.length; i++) {
      const field = priceFields[i];
      const keys = Object.keys(result);
      let found = false;
      for (let j = 0; j < keys.length; j++) {
        if (keys[j] === field) {
          found = true;
          break;
        }
      }
      if (found) {
        const value = result[field];
        if (typeof value === 'string' || typeof value === 'number') {
          result[field] = PriceTransformer.toNumber(value as string | number);
        }
      }
    }

    return result as T;
  }

  /**
   * 格式化价格显示（保留1位小数，去除尾部0）
   * @param price 价格数值
   * @param currencySymbol 货币符号（默认 '$'）
   * @returns 格式化后的字符串
   */
  static formatDisplay(price: number, currencySymbol: string = '$'): string {
    if (isNaN(price)) {
      return `${currencySymbol}0`;
    }

    // 保留1位小数
    const formatted = price.toFixed(1);

    // 去除尾部的 .0
    const withoutTrailingZero = formatted.replace(/\.0$/, '');

    return `${currencySymbol}${withoutTrailingZero}`;
  }

  /**
   * 格式化价格显示（保留指定小数位）
   * @param price 价格数值
   * @param decimals 小数位数（默认 2）
   * @param currencySymbol 货币符号（默认 '$'）
   * @returns 格式化后的字符串
   */
  static formatWithDecimals(price: number, decimals: number = 2, currencySymbol: string = '$'): string {
    if (isNaN(price)) {
      return `${currencySymbol}0`;
    }

    return `${currencySymbol}${price.toFixed(decimals)}`;
  }

  /**
   * 安全相加（避免浮点数精度问题）
   * @param a 加数1
   * @param b 加数2
   * @returns 和
   */
  static safeAdd(a: number, b: number): number {
    // 转换为整数计算，避免浮点数精度问题
    // 例如：0.1 + 0.2 = 0.30000000000000004
    const scale = 100;  // 精确到小数点后2位
    return Math.round((a * scale + b * scale)) / scale;
  }

  /**
   * 安全相乘（避免浮点数精度问题）
   * @param a 乘数1
   * @param b 乘数2
   * @returns 积
   */
  static safeMultiply(a: number, b: number): number {
    const scale = 100;  // 精确到小数点后2位
    return Math.round((a * scale) * (b * scale)) / (scale * scale);
  }

  /**
   * 计算百分比
   * @param value 值
   * @param percentage 百分比（如 10 表示 10%）
   * @returns 计算结果
   */
  static calculatePercentage(value: number, percentage: number): number {
    return PriceTransformer.safeMultiply(value, percentage / 100);
  }

  /**
   * 批量转换价格数组
   * @param prices 价格字符串数组
   * @param defaultValue 默认值
   * @returns 转换后的数值数组
   */
  static toNumberArray(prices: (string | number)[], defaultValue: number = 0): number[] {
    const result: number[] = [];
    for (const price of prices) {
      result.push(PriceTransformer.toNumber(price, defaultValue));
    }
    return result;
  }

  /**
   * 获取最小价格
   * @param prices 价格数组
   * @returns 最小价格（如果数组为空返回 0）
   */
  static getMinPrice(prices: number[]): number {
    if (prices.length === 0) {
      return 0;
    }
    return Math.min(...prices);
  }

  /**
   * 获取最大价格
   * @param prices 价格数组
   * @returns 最大价格（如果数组为空返回 0）
   */
  static getMaxPrice(prices: number[]): number {
    if (prices.length === 0) {
      return 0;
    }
    return Math.max(...prices);
  }
}
