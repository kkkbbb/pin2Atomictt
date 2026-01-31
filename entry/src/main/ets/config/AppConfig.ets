/**
 * 应用全局配置
 * 统一管理所有可配置项，方便修改
 */
export class AppConfig {
  // ==================== 店铺配置 ====================

  /**
   * 默认店铺ID
   * 修改此值可切换默认店铺
   */
  static readonly DEFAULT_STORE_ID: string = '5854';

  // ==================== API配置 ====================

  /**
   * API基础URL
   */
  static readonly API_BASE_URL: string = 'https://meal.pin2eat.com';

  /**
   * 默认语言代码
   */
  static readonly DEFAULT_LANG_CODE: string = 'zh_HK';

  // ==================== 超时配置 ====================

  /**
   * HTTP连接超时时间（毫秒）
   */
  static readonly HTTP_CONNECT_TIMEOUT: number = 30000;

  /**
   * HTTP读取超时时间（毫秒）
   */
  static readonly HTTP_READ_TIMEOUT: number = 30000;

  // ==================== UI配置 ====================

  /**
   * 默认主题色
   */
  static readonly DEFAULT_THEME_COLOR: string = '#FFD700';

  /**
   * 默认货币符号
   */
  static readonly DEFAULT_CURRENCY_SYMBOL: string = '$';
}
