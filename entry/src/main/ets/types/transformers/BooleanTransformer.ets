/**
 * BooleanTransformer - 布尔值类型转换器
 *
 * 功能：
 * - "1"/"0" 字符串 ↔ true/false 转换
 * - 统一处理 API 返回的布尔值字符串
 * - 安全转换，带默认值处理
 *
 * 解决问题：
 * - has_stock: "1" → true
 * - is_default: "1" → true
 * - 消除重复的字符串比较代码
 *
 * 使用示例：
 * ```typescript
 * // API 响应 "1"/"0" → boolean
 * const hasStock = BooleanTransformer.toBoolean(product.has_stock);  // "1" → true
 *
 * // boolean → "1"/"0"（用于提交）
 * const stockStr = BooleanTransformer.toString(true);  // true → "1"
 *
 * // 批量转换对象字段
 * const transformed = BooleanTransformer.transformBooleanFields(product, ['has_stock', 'is_default']);
 * ```
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'BooleanTransformer';

export class BooleanTransformer {
  /**
   * 转换为布尔值（支持字符串、数值、布尔值）
   * @param value 待转换的值
   * @param defaultValue 默认值（当转换失败时）
   * @returns 转换后的布尔值
   */
  static toBoolean(value: string | number | boolean, defaultValue: boolean = false): boolean {
    if (typeof value === 'boolean') {
      return value;
    }

    if (typeof value === 'number') {
      return value !== 0;
    }

    if (typeof value === 'string') {
      const trimmed = value.trim().toLowerCase();

      // 真值：'1', 'true', 'yes', 'on'
      if (trimmed === '1' || trimmed === 'true' || trimmed === 'yes' || trimmed === 'on') {
        return true;
      }

      // 假值：'0', 'false', 'no', 'off', ''
      if (trimmed === '0' || trimmed === 'false' || trimmed === 'no' || trimmed === 'off' || trimmed === '') {
        return false;
      }

      // 未知值，使用默认值
      hilog.warn(DOMAIN, TAG, 'Unknown boolean string: %{public}s, using default: %{public}s',
        value, defaultValue.toString());
      return defaultValue;
    }

    hilog.warn(DOMAIN, TAG, 'Invalid boolean type: %{public}s, using default: %{public}s',
      typeof value, defaultValue.toString());
    return defaultValue;
  }

  /**
   * 转换为字符串 "1"/"0"
   * @param value 布尔值
   * @returns "1" 或 "0"
   */
  static toString(value: boolean): string {
    return value ? '1' : '0';
  }

  /**
   * 转换为数值 1/0
   * @param value 布尔值
   * @returns 1 或 0
   */
  static toNumber(value: boolean): number {
    return value ? 1 : 0;
  }

  /**
   * 批量转换对象的布尔字段
   * @param obj 待转换的对象
   * @param booleanFields 布尔字段名称数组
   * @returns 转换后的新对象（不修改原对象）
   */
  static transformBooleanFields<T extends Record<string, ESObject>>(
    obj: T,
    booleanFields: string[]
  ): T {
    const result: Record<string, ESObject> = {};

    // 复制所有字段
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        result[key] = obj[key];
      }
    }

    // 转换布尔字段
    for (const field of booleanFields) {
      if (result.hasOwnProperty(field)) {
        const value = result[field];
        if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
          result[field] = BooleanTransformer.toBoolean(value as string | number | boolean);
        }
      }
    }

    return result as T;
  }

  /**
   * 批量转换布尔数组为字符串数组
   * @param values 布尔值数组
   * @returns 字符串数组 ["1", "0", ...]
   */
  static toStringArray(values: boolean[]): string[] {
    const result: string[] = [];
    for (const value of values) {
      result.push(BooleanTransformer.toString(value));
    }
    return result;
  }

  /**
   * 批量转换字符串数组为布尔数组
   * @param values 字符串数组
   * @param defaultValue 默认值
   * @returns 布尔值数组
   */
  static toBooleanArray(values: (string | number | boolean)[], defaultValue: boolean = false): boolean[] {
    const result: boolean[] = [];
    for (const value of values) {
      result.push(BooleanTransformer.toBoolean(value, defaultValue));
    }
    return result;
  }

  /**
   * 切换布尔值
   * @param value 当前布尔值
   * @returns 切换后的布尔值
   */
  static toggle(value: boolean): boolean {
    return !value;
  }

  /**
   * 所有值都为真
   * @param values 布尔值数组
   * @returns 是否所有值都为真
   */
  static allTrue(values: boolean[]): boolean {
    if (values.length === 0) {
      return false;
    }
    for (const value of values) {
      if (!value) {
        return false;
      }
    }
    return true;
  }

  /**
   * 任意值为真
   * @param values 布尔值数组
   * @returns 是否有任意值为真
   */
  static anyTrue(values: boolean[]): boolean {
    for (const value of values) {
      if (value) {
        return true;
      }
    }
    return false;
  }

  /**
   * 计数真值数量
   * @param values 布尔值数组
   * @returns 真值数量
   */
  static countTrue(values: boolean[]): number {
    let count = 0;
    for (const value of values) {
      if (value) {
        count++;
      }
    }
    return count;
  }
}
