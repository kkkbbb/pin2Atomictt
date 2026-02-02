/**
 * ApiGuards - API 响应类型守卫与安全访问器
 *
 * 功能：
 * - 运行时类型验证（替代盲目的 as 断言）
 * - 安全获取字段（带默认值）
 * - 记录类型不匹配警告
 *
 * Note: ArkTS 不支持 TypeScript 的 type guard (`is` 语法)，
 * 所以这里使用布尔返回值 + 日志警告的方式进行验证
 *
 * 使用示例：
 * ```typescript
 * // 验证 API 响应
 * const response = await http.request(...);
 * if (isValidApiResponse(response)) {
 *   // 可以安全使用 response.data
 * }
 *
 * // 安全获取字段
 * const storeId = getStringField(config, 'store_id', 'default_id');
 * const price = getNumberField(product, 'price', 0);
 * ```
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'ApiGuards';

/**
 * 检查值是否为对象（非 null）
 */
function isObject(value: ESObject): boolean {
  return typeof value === 'object' && value !== null;
}

/**
 * 检查对象是否包含指定字段
 */
function hasFields(obj: ESObject, fields: string[]): boolean {
  for (const field of fields) {
    if (!obj.hasOwnProperty(field)) {
      return false;
    }
  }
  return true;
}

/**
 * 验证 API 响应基础结构
 * @param response 待验证的响应
 * @returns 是否为有效的 ApiResponse
 */
export function isValidApiResponse(response: ESObject): boolean {
  if (!isObject(response)) {
    hilog.warn(DOMAIN, TAG, 'Invalid API response: not an object');
    return false;
  }

  // 检查必需字段
  if (!hasFields(response, ['code', 'msg'])) {
    hilog.warn(DOMAIN, TAG, 'Invalid API response: missing code or msg field');
    return false;
  }

  // 检查 code 是否为数值
  const code: ESObject = response['code'];
  if (typeof code !== 'number') {
    hilog.warn(DOMAIN, TAG, 'Invalid API response: code is not a number');
    return false;
  }

  // 检查 msg 是否为字符串
  const msg: ESObject = response['msg'];
  if (typeof msg !== 'string') {
    hilog.warn(DOMAIN, TAG, 'Invalid API response: msg is not a string');
    return false;
  }

  return true;
}

/**
 * 验证 HomeData 结构
 * @param data 待验证的数据
 * @returns 是否为有效的 HomeData
 */
export function isValidHomeData(data: ESObject): boolean {
  if (!isObject(data)) {
    hilog.warn(DOMAIN, TAG, 'Invalid HomeData: not an object');
    return false;
  }

  // 检查必需字段
  const requiredFields = ['config', 'currency', 'language', 'notice'];
  if (!hasFields(data, requiredFields)) {
    hilog.warn(DOMAIN, TAG, 'Invalid HomeData: missing required fields');
    return false;
  }

  // 检查 config 是否为对象
  const configField: ESObject = data['config'];
  if (!isObject(configField)) {
    hilog.warn(DOMAIN, TAG, 'Invalid HomeData: config is not an object');
    return false;
  }

  // 检查 currency 是否为对象
  const currencyField: ESObject = data['currency'];
  if (!isObject(currencyField)) {
    hilog.warn(DOMAIN, TAG, 'Invalid HomeData: currency is not an object');
    return false;
  }

  // 检查 notice 是否为数组
  const noticeField: ESObject = data['notice'];
  if (!Array.isArray(noticeField)) {
    hilog.warn(DOMAIN, TAG, 'Invalid HomeData: notice is not an array');
    return false;
  }

  return true;
}

/**
 * 验证 ProductMenuData 结构
 * @param data 待验证的数据
 * @returns 是否为有效的 ProductMenuData
 */
export function isValidProductMenuData(data: ESObject): boolean {
  if (!isObject(data)) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductMenuData: not an object');
    return false;
  }

  // 检查必需字段
  if (!hasFields(data, ['group', 'menu_group'])) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductMenuData: missing required fields');
    return false;
  }

  // 检查 group 是否为数组
  const groupField: ESObject = data['group'];
  if (!Array.isArray(groupField)) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductMenuData: group is not an array');
    return false;
  }

  // 检查 menu_group 是否为数组
  const menuGroupField: ESObject = data['menu_group'];
  if (!Array.isArray(menuGroupField)) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductMenuData: menu_group is not an array');
    return false;
  }

  return true;
}

/**
 * 验证 StoreConfig 结构（HomeData.config）
 * @param config 待验证的配置
 * @returns 是否为有效的 StoreConfig
 */
export function isValidStoreConfig(config: ESObject): boolean {
  if (!isObject(config)) {
    hilog.warn(DOMAIN, TAG, 'Invalid StoreConfig: not an object');
    return false;
  }

  // 检查基础字段
  const basicFields = ['store_id', 'store_name'];
  if (!hasFields(config, basicFields)) {
    hilog.warn(DOMAIN, TAG, 'Invalid StoreConfig: missing basic fields');
    return false;
  }

  return true;
}

/**
 * 验证 Currency 结构（HomeData.currency）
 * @param currency 待验证的货币信息
 * @returns 是否为有效的 Currency
 */
export function isValidCurrency(currency: ESObject): boolean {
  if (!isObject(currency)) {
    hilog.warn(DOMAIN, TAG, 'Invalid Currency: not an object');
    return false;
  }

  // 检查必需字段
  const requiredFields = ['currency_code', 'currency_symbol'];
  if (!hasFields(currency, requiredFields)) {
    hilog.warn(DOMAIN, TAG, 'Invalid Currency: missing required fields');
    return false;
  }

  return true;
}

/**
 * 验证 Product 结构
 * @param product 待验证的产品
 * @returns 是否为有效的 Product
 */
export function isValidProduct(product: ESObject): boolean {
  if (!isObject(product)) {
    hilog.warn(DOMAIN, TAG, 'Invalid Product: not an object');
    return false;
  }

  // 检查必需字段
  const requiredFields = ['product_id', 'local_name', 'price'];
  if (!hasFields(product, requiredFields)) {
    hilog.warn(DOMAIN, TAG, 'Invalid Product: missing required fields');
    return false;
  }

  return true;
}

/**
 * 验证 ProductGroup 结构
 * @param group 待验证的产品分组
 * @returns 是否为有效的 ProductGroup
 */
export function isValidProductGroup(group: ESObject): boolean {
  if (!isObject(group)) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductGroup: not an object');
    return false;
  }

  // 检查必需字段
  const requiredFields = ['id', 'local_name', 'product'];
  if (!hasFields(group, requiredFields)) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductGroup: missing required fields');
    return false;
  }

  // 检查 product 是否为数组
  const productField: ESObject = group['product'];
  if (!Array.isArray(productField)) {
    hilog.warn(DOMAIN, TAG, 'Invalid ProductGroup: product is not an array');
    return false;
  }

  return true;
}

/**
 * 验证 Order 结构
 * @param order 待验证的订单
 * @returns 是否为有效的 Order
 */
export function isValidOrder(order: ESObject): boolean {
  if (!isObject(order)) {
    hilog.warn(DOMAIN, TAG, 'Invalid Order: not an object');
    return false;
  }

  // 检查必需字段
  const requiredFields = ['order_id', 'order_no', 'create_time', 'total'];
  if (!hasFields(order, requiredFields)) {
    hilog.warn(DOMAIN, TAG, 'Invalid Order: missing required fields');
    return false;
  }

  return true;
}

/**
 * 安全获取字符串字段（带默认值）
 * @param obj 对象
 * @param field 字段名
 * @param defaultValue 默认值
 * @returns 字符串值
 */
export function getStringField(obj: ESObject, field: string, defaultValue: string = ''): string {
  if (!obj.hasOwnProperty(field)) {
    return defaultValue;
  }

  const fieldValue: ESObject = obj[field];
  if (typeof fieldValue === 'string') {
    return fieldValue;
  }

  // 尝试转换为字符串
  if (fieldValue === null || fieldValue === undefined) {
    return defaultValue;
  }

  return String(fieldValue);
}

/**
 * 安全获取数值字段（带默认值）
 * @param obj 对象
 * @param field 字段名
 * @param defaultValue 默认值
 * @returns 数值
 */
export function getNumberField(obj: ESObject, field: string, defaultValue: number = 0): number {
  if (!obj.hasOwnProperty(field)) {
    return defaultValue;
  }

  const fieldValue: ESObject = obj[field];
  if (typeof fieldValue === 'number') {
    return fieldValue;
  }

  // 尝试转换为数值
  if (typeof fieldValue === 'string') {
    const parsed = parseFloat(fieldValue);
    return isNaN(parsed) ? defaultValue : parsed;
  }

  return defaultValue;
}

/**
 * 安全获取布尔字段（带默认值）
 * @param obj 对象
 * @param field 字段名
 * @param defaultValue 默认值
 * @returns 布尔值
 */
export function getBooleanField(obj: ESObject, field: string, defaultValue: boolean = false): boolean {
  if (!obj.hasOwnProperty(field)) {
    return defaultValue;
  }

  const fieldValue: ESObject = obj[field];
  if (typeof fieldValue === 'boolean') {
    return fieldValue;
  }

  // 尝试转换为布尔值
  if (typeof fieldValue === 'string') {
    const trimmed = fieldValue.trim().toLowerCase();
    return trimmed === '1' || trimmed === 'true' || trimmed === 'yes';
  }

  if (typeof fieldValue === 'number') {
    return fieldValue !== 0;
  }

  return defaultValue;
}
