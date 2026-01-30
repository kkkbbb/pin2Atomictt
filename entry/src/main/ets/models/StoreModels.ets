/**
 * API响应基础结构
 */
export interface ApiResponse<T> {
  code: number;
  msg: string;
  data: T;
}

/**
 * 店铺配置信息
 */
export interface StoreConfig {
  config_id: number;
  store_id: number;
  store_image: string;
  store_logo: string | null;
  name: string;
  description: string;
  telephone: string;
  address: string;
  is_close: number;
  dinein: number;
  takeout: number;
  delivery_mode: number;
  theme_color: string;
  notice: StoreNotice[];
  currency: Currency;
  language: LanguageConfig;
  business_schedule: BusinessSchedule[];
  seat_fee: string;
  has_seat_fee: number;
}

/**
 * 店铺公告
 */
export interface StoreNotice {
  local_name: string;
  en_name: string;
  cn_name: string;
  type: string;
}

/**
 * 货币配置
 */
export interface Currency {
  currency_code: string;
  title: string;
  symbol_left: string;
  symbol_right: string;
  decimal_place?: string;
}

/**
 * 语言配置
 */
export interface LanguageConfig {
  local: LanguageItem;
  config_list: LanguageItem[];
}

export interface LanguageItem {
  language_code: string;
  native_name: string;
  field_name: string;
}

/**
 * 营业时间
 */
export interface BusinessSchedule {
  day: number;
  start_time: string;
  end_time: string;
}

/**
 * 首页数据
 */
export interface HomeData {
  config: StoreConfig;
  currency: Currency;
  language: LanguageConfig;
  notice: StoreNotice[];
  current_schedule: BusinessSchedule | null;
  table_count: string;
}

/**
 * 产品分组
 */
export interface ProductGroup {
  group_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  store_id: string;
  display_order: string;
  status_id: string;
  takeout: string;
  dinein: string;
  delivery: string;
  time_range?: string; // 供应时间范围
  products: Product[];
}

/**
 * 产品信息
 */
export interface Product {
  product_id: string;
  store_id: string;
  status: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  cover_image: string;
  price: string;
  takeout_price: string;
  delivery_price: string;
  sale_num: string;
  has_stock: string;
  takeout: string;
  dinner_in: string;
  delivery: string;
  description: ProductDescription;
  prices: ProductPrice[];
  condiment_group: CondimentGroup[];
}

/**
 * 产品描述
 */
export interface ProductDescription {
  product_id: string;
  name: string;
  local_description: string;
  cn_description: string;
  en_description: string;
}

/**
 * 产品价格规格
 */
export interface ProductPrice {
  price_plan_id: string;
  product_id: string;
  price: string;
  takeout_price: string;
  delivery_price: string;
  stock: string;
  status: string;
  productStandardItem: ProductStandardItem;
}

export interface ProductStandardItem {
  item_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
}

/**
 * 调味料/配料组
 */
export interface CondimentGroup {
  group_id: string;
  name: string;
  items: CondimentItem[];
}

export interface CondimentItem {
  item_id: string;
  name: string;
  price: string;
}

/**
 * 产品菜单数据
 */
export interface ProductMenuData {
  group: ProductGroup[];
}

/**
 * 会员计划数据
 */
export interface MemberPlanData {
  member_plan: MemberPlan[];
  membership: Membership | null;
}

export interface MemberPlan {
  plan_id: string;
  name: string;
  price: string;
  description: string;
}

export interface Membership {
  member_id: string;
  level: string;
  points: number;
  expire_date: string;
}

/**
 * 用户登录请求
 */
export interface LoginRequest {
  auth_code: string;
  login_type: string; // 'huawei' | 'phone' | 'email'
}

/**
 * 用户登录响应
 */
export interface LoginResponse {
  token: string;
  customer_id: number;
  nickname: string;
  avatar: string;
}

/**
 * 订单类型枚举
 */
export enum OrderType {
  PICKUP = 1,    // 自取
  DINE_IN = 2,   // 堂食
  DELIVERY = 3   // 外送
}
