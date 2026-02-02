/**
 * API响应基础结构
 */
export interface ApiResponse<T> {
  code: number;
  msg: string;
  data: T;
}

/**
 * 登录方式配置
 */
export interface LoginConfig {
  telephone_login: number;      // 手机号登录
  telephone_register: number;   // 手机号注册
  google_register: number;      // Google登录
  facebook_register: number;    // Facebook登录
  email_register: number;       // 邮箱登录
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
  is_close: number;       // 0=营业, 1=休息
  is_service?: boolean;   // 是否在服务时间内
  is_operating?: number;  // 是否运营中
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
  login?: LoginConfig;  // 登录方式配置
  has_discount?: number;  // 是否有折扣: 1=有, 0=无
  discount?: number;      // 折扣百分比
  extend?: StoreExtend;   // 扩展配置
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
 * 折扣扩展信息
 */
export interface OrderAdjustExt {
  ratio?: number;       // 折扣率（type=1时，如0.9表示九折）
  number?: number;      // 固定金额（type=2时）
}

/**
 * 折扣调整项
 */
export interface OrderAdjustItem {
  id: number;
  name: string;
  type: number;           // 1=百分比折扣, 2=固定金额调整
  ext: OrderAdjustExt;
  object_type?: number;
}

/**
 * 订单折扣配置
 */
export interface OrderAdjustAmount {
  time: string;
  data: OrderAdjustItem[];
}

/**
 * 店铺扩展配置
 */
export interface StoreExtend {
  id: number;
  update_time: string;
  store_id: number;
  order_adjust_amount?: OrderAdjustAmount;  // 订单折扣配置
  product_adjust_amount?: OrderAdjustAmount;  // 商品折扣配置
}

/**
 * 热卖推荐商品
 */
export interface RankProduct {
  sale_num: string;
  product_id: string;
  product_local_name: string;
  total: string;
  dinner_in_sale_num: string;
  take_out_sale_num: string;
  product_detail: RankProductDetail;
}

/**
 * 热卖推荐商品详情
 */
export interface RankProductDetail {
  product_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  price: string;
  takeout_price: string;
  cover_image: string;
  description?: ProductDescription;
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
  rank_list?: RankProduct[];  // 热卖推荐列表
  scheme_stores?: SchemeStoresData;  // 连锁门店信息
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
  condiment_group: CondimentGroupDetail[];  // 配料选择（甜度、冰量等）
  box?: ProductBox;                         // 外卖盒（餐盒费）
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
  standard_code?: string;         // 规格码（用于提交订单）
  productStandardItem: ProductStandardItem;
}

export interface ProductStandardItem {
  item_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
}

/**
 * 调味料/配料组（菜单列表用）
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
 * 产品详情 - 套餐组（配料选择）
 */
export interface PackageGroup {
  id: string;
  product_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  select_count: string;      // 最少选择数量
  max_count: string;         // 最多选择数量，0=不限
  free_count: string;        // 免费数量
  select_type: string;       // 选择类型: "1"=多选, "2"=单选
  sort_num: string;
  status_id: string;
  item: PackageItem[];
}

/**
 * 产品详情 - 套餐项（配料项）
 */
export interface PackageItem {
  product_id: string;
  store_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  short_name: string;
  cover_image: string;
  status: string;
  takeout: string;
  has_stock: string;
  max_count: string | number;
  prices: PackageItemPrice[];
  description?: ProductDescription;
  condiment_group?: CondimentGroup[];
}

/**
 * 产品详情 - 套餐项价格
 */
export interface PackageItemPrice {
  standard_code: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  short_name: string;
  add_price: string;           // 堂食加价
  add_takeout_price: string;   // 外卖加价
  add_delivery_price: string;  // 配送加价
  num: number;                 // H5格式需要此字段
}

/**
 * 产品详情 - 政策信息
 */
export interface PolicyInfo {
  id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  local_description: string;
  status_id: string;
}

/**
 * 产品详情 - 政策说明
 */
export interface ProductPolicy {
  policy_id: string;
  product_id: string;
  sort_num: string;
  policy: PolicyInfo;
}

/**
 * 政策组数据 - 加送選擇
 * 来自 /api/product/policy 接口
 */
export interface PolicyGroupData {
  id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  local_description: string;
  status_id: string;
  store_id: string;
  groupData: PolicyGroup[];
}

/**
 * 政策组 - 加送選擇组
 */
export interface PolicyGroup {
  id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  sort_num: string;
  policy_id: string;
  status_id: string;
  free_count: string;       // 免费数量
  required: string;         // 是否必选: "1"=必选
  item: PolicyGroupItem[];
}

/**
 * 政策组项 - 可选饮品/加送项
 */
export interface PolicyGroupItem {
  product_id: string;
  store_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  short_name: string;
  status: string;
  takeout: string;
  cover_image: string;
  has_stock: string;
  prices: PackageItemPrice[];
  description?: ProductDescription;
  max_count: string | number;
  condiment_group: CondimentGroupDetail[];  // 饮品自己的配料组（甜度、冰量等）
}

/**
 * 配料组详情（用于饮品的甜度、冰量等选项）
 */
export interface CondimentGroupDetail {
  condiment_group_id: string;
  store_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  standard_local_name: string;
  multi_select: string;      // "0"=单选, "1"=多选
  max_select_num: string;
  display_order: string | number;
  item: CondimentItemDetail[];
}

/**
 * 配料项详情
 */
export interface CondimentItemDetail {
  condiment_item_id: string;
  group_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  display_order: string;
  price: string;
  takeout_price: string;
  delivery_price: string;
  status_id: string;
  is_default: string;       // "1"=默认选中
}

/**
 * 产品详情 - 盒子信息
 */
export interface BoxInfo {
  box_id: string;
  store_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  price: string;
}

/**
 * 产品详情 - 外卖盒
 */
export interface ProductBox {
  id: string;
  product_id: string;
  box_id: string;
  price: string;
  box: BoxInfo;
}

/**
 * 产品详情完整数据
 */
export interface ProductDetail {
  product_id: string;
  store_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  cover_image: string;
  price: string;
  takeout_price?: string;
  delivery_price?: string;
  sale_num: string;
  has_stock: string;
  takeout: string;
  dinner_in: string;
  delivery: string;
  status: string;
  description?: ProductDescription;
  prices: ProductPrice[];
  packageGroups: PackageGroup[];      // 配料选择组
  policy: ProductPolicy[];             // 套餐政策说明
  box?: ProductBox;                    // 外卖盒
  condiment_group?: CondimentGroupDetail[];  // 配料选择（甜度、冰量等）
  images?: string[];
}

/**
 * 顶级菜单分组（横向导航条）
 */
export interface MenuGroup {
  menu_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  store_id: string;
  display_order: string;
  status_id: string;
  takeout: string;
  dinein: string;
  delivery: string;
  start_time?: string;       // 供应开始时间
  end_time?: string;         // 供应结束时间
  groups: string[];          // 包含的二级分类 group_id 数组
  can_order: number;         // 当前时段是否可点餐 1=可以 0=不可以
  show_type: string;         // 展示类型: "1"=小图模式 "2"=大图模式
}

/**
 * 产品菜单数据
 */
export interface ProductMenuData {
  group: ProductGroup[];
  menu_group: MenuGroup[];   // 顶级菜单分组
}

/**
 * 会员计划数据
 */
export interface MemberPlanData {
  member_plan: MemberPlan | null;
  membership: Membership | null;
}

/**
 * 会员计划详情
 */
export interface MemberPlan {
  plan_id: string;
  store_id: string;
  scheme_id: string;
  title: string;
  name: string;                     // 店铺名称
  bg_image_url: string;             // 背景图片
  local_coupons_desc: string;       // 迎新优惠描述（繁体）
  cn_coupons_desc: string;
  en_coupons_desc: string;
  local_stamps_desc: string;        // 印花描述（繁体）"每1個印花換$5優惠券"
  cn_stamps_desc: string;
  en_stamps_desc: string;
  start_date: string;
  end_date: string;
  has_gift: string;
  has_birthday_gift: string;
  has_credit: string;
  status: string;
  open_registration: number;        // 是否开放注册 1=开放
  point_rules: MemberPointRule[];
}

/**
 * 会员积分规则
 */
export interface MemberPointRule {
  id: string;
  plan_id: string;
  type: string;
  amount: string;
  award_point: string;
  valid_period: string;
  start_date: string;
  end_date: string;
  status: string;
}

/**
 * 用户会员信息
 */
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
  DINE_IN = 1,   // 堂食
  PICKUP = 2,    // 外卖自取
  DELIVERY = 3   // 外送/配送
}

/**
 * 订单状态枚举
 */
export enum OrderStatus {
  PENDING = 'pending',           // 待处理
  CONFIRMED = 'confirmed',       // 已确认
  PREPARING = 'preparing',       // 准备中
  READY = 'ready',               // 待取餐
  COMPLETED = 'completed',       // 已完成
  CANCELLED = 'cancelled',       // 已取消
  REFUNDED = 'refunded'          // 已退款
}

/**
 * 订单筛选类型
 * API接口期望的值: ''=全部, '11'=進行中, '12'=已完成, '13'=退款/取消
 */
export enum OrderFilterType {
  ALL = '',                      // 全部
  IN_PROGRESS = '11',            // 进行中
  COMPLETED = '12',              // 已完成
  REFUND = '13'                  // 退款/取消
}

/**
 * 订单商品项 (API原始格式)
 */
export interface OrderItem {
  product_id?: string;
  product_name?: string;
  product_local_name?: string;
  local_name?: string;
  en_name?: string;
  cn_name?: string;
  cover_image?: string;
  price: string;
  quantity: string | number;
  total_price?: string;
  specifications?: string;       // 规格描述
  condiments?: string;           // 配料描述
}

/**
 * 订单状态信息 (API原始格式)
 */
export interface OrderStatusDetail {
  name: string;
  order_status_id: string;
}

/**
 * 订单店铺信息 (API原始格式)
 */
export interface OrderStoreInfo {
  name: string;
  store_image?: string;
}

/**
 * 订单信息 (API原始格式)
 * 匹配 /api/order/order-list-app 返回的数据结构
 */
export interface Order {
  order_id: string;
  wt_order_id?: string;          // 订单显示号
  store_id?: string;
  status_id?: string;            // 状态ID
  order_status?: string;         // 订单状态
  order_type?: string | number;  // 1=堂食, 2=外卖自取
  dine_in_takeout?: string;      // 堂食/外卖标识
  total: string;                 // 订单总额
  date_added: string;            // 创建时间
  redeem_code?: string;          // 取餐码
  pack_total?: string;           // 餐盒费
  order_product?: OrderItem[];   // 商品列表
  status?: OrderStatusDetail;    // 状态详情
  store?: OrderStoreInfo;        // 店铺信息
  telephone?: string;
  // 兼容旧字段
  order_no?: string;
  status_text?: string;
  pay_amount?: string;
  items?: OrderItem[];
  created_at?: string;
}

/**
 * 订单列表响应
 */
export interface OrderListData {
  order_list: Order[];
  total: string;
}

/**
 * 优惠券状态枚举
 */
export enum CouponStatus {
  AVAILABLE = 'available',     // 可使用
  USED = 'used',               // 已使用
  EXPIRED = 'expired'          // 已过期
}

/**
 * 优惠券类型枚举
 */
export enum CouponType {
  COUPON = 'coupon',           // 优惠券
  VOUCHER = 'voucher'          // 兑换券
}

/**
 * 优惠券信息
 */
export interface Coupon {
  coupon_id: string;
  coupon_code: string;
  name: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  type: string;                // coupon | voucher
  discount_type: string;       // percentage | fixed | free_item
  discount_value: string;      // 折扣值
  min_order_amount?: string;   // 最低消费
  max_discount?: string;       // 最大折扣金额
  start_date: string;
  end_date: string;
  status: string;
  description?: string;
  usage_limit?: number;
  used_count?: number;
  applicable_products?: string[];  // 适用商品
  applicable_categories?: string[]; // 适用分类
}

/**
 * 优惠券列表响应
 */
export interface CouponListData {
  coupon_list: Coupon[];
  voucher_list: Coupon[];
  total_coupons: number;
  total_vouchers: number;
}

// ==================== 提交订单相关模型 ====================

/**
 * 订单商品 - 配料信息
 */
export interface OrderCondiment {
  condiment_item_id: string;
  group_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  display_order: string;
  price: string;
  takeout_price: string;
  delivery_price: string;
  short_name: string;
  barcode: string;
  status_id: string;
  default_type: string;
  standard_code: string;
  is_default: string;
  quantity: number;
}

/**
 * 订单商品 - 加送商品描述
 */
export interface OrderPolicyProductDescription {
  product_id: string;
  language_id: string;
  name: string;
  cn_description: string;
  local_description: string;
  en_description: string;
  barcode: string;
}

/**
 * 订单商品 - 加送商品
 */
export interface OrderPolicyProduct {
  product_id: string;
  store_id: string;
  scheme_id: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  short_name: string;
  status: string;
  takeout: string;
  cover_image: string;
  has_stock: string;
  stock_number: string;
  prices: PackageItemPrice[];
  description: OrderPolicyProductDescription | null;
  box: BoxInfo | null;
  unit_id: number;
  max_count: number;
  condiment_group: CondimentGroupDetail[];
  condiments: OrderCondiment[];
  policy_id: string;
  group_id: string;
  select_price: PackageItemPrice;
  quantity: number;
  version: string;
  add_price: number;
  standard_code: string;
  price: string;
  product_name: string | null;
}

/**
 * 订单商品 - 外卖盒信息
 */
export interface OrderBoxInfo {
  id: string;
  product_id: string;
  box_id: string;
  box: BoxInfo;
  store_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  price: string;
  display_order: string;
}

/**
 * 订单商品
 */
export interface OrderProduct {
  product_id: string;
  group_id: string;
  standard_code: string;
  condiments: OrderCondiment[];
  quantity: number;
  price: number;
  activity_id: string | null;
  box: OrderBoxInfo | null;
  store_id: string;
  dine_in_takeout: number;
  member_discount_id: string | null;
  policy_products: OrderPolicyProduct[][];
}

/**
 * 提交订单请求
 */
export interface AddOrderRequest {
  store_id: string;
  table_id: number;
  order_type: number;          // 1=堂食, 2=外卖自取, 3=外送
  order_sub_type: number;
  customer_num: number;
  language: string;
  comment: string;
  products: OrderProduct[];
  total: string;
  discount_total: number;
  activity_discount_total: number;
  seat_fee: number;
  service_fee: string;
  email: string;
  telephone: string;
  telephone_area_code: string;
  coupon_total: number | null;
  coupon_id: string | null;
  form_id: string;
  member_id: string;
  delivery_fee: number;
  order_id: string;
  qr_code: string | null;
  table_group_name: string | null;
  cutlery_num: number;
  cutlery_total: number;
  need_cutlery_num: number;
  member_discount_total: number;
}

/**
 * 提交订单响应
 */
export interface AddOrderResponse {
  order_id: number;
  latest_batch_no: number;
  customer_id: number;
}

/**
 * 订单详情 - 状态信息
 */
export interface OrderStatusInfo {
  order_status_id: string;
  name: string;
  customer_name: string;
  merchant_name: string;
  tag_name: string;
}

/**
 * 订单详情 - 商品信息
 */
export interface OrderDetailProduct {
  order_id: string;
  order_product_id: string;
  product_id: string;
  local_name: string;
  en_name: string;
  cn_name: string;
  short_name: string;
  price: string;
  condiment_price: string;
  total_price: string;
  original_price: string;
  quantity: string;
  total: string;
  standard_code: string;
  cover_image: string;
  status_id: string;
  box_price: string;
  standard: OrderDetailStandard[];
  condiments: OrderCondiment[];
  policy_products?: OrderDetailProduct[][];
}

/**
 * 订单详情 - 规格信息
 */
export interface OrderDetailStandard {
  local_name: string;
  en_name: string;
  cn_name: string;
  standard_code: string;
  price: string;
  quantity: string;
}

/**
 * 订单商品集合
 */
export interface OrderProductsCollection {
  confirmed: OrderDetailProduct[];
  unconfirmed: OrderDetailProduct[];
  canceled: OrderDetailProduct[];
  refund: OrderDetailProduct[];
}

/**
 * 订单详情 - 店铺配置简要
 */
export interface OrderConfigInfo {
  name: string;
  address: string;
  telephone: string;
  store_image: string;
}

/**
 * 订单详情响应
 */
export interface OrderDetailData {
  order_id: string;
  customer_id: string;
  wt_order_id: string;
  status_id: string;
  order_type: string;
  order_sub_type: string;
  store_id: string;
  date_added: string;
  redeem_code: string;
  total: string;
  pay_total: string;
  discount_total: string;
  product_total: string;
  pack_total: string;
  now_total: string;
  status: OrderStatusInfo;
  order_products?: OrderProductsCollection;  // 对象格式：{ confirmed: [], unconfirmed: [] }
  order_product?: OrderDetailProduct[];       // 数组格式：直接是商品数组
  telephone: string;
  paid_time_limit: string;
  config: OrderConfigInfo;
}

// ==================== 支付相关模型 ====================

/**
 * 支付方式配置（本地使用）
 */
export interface PaymentMethod {
  id: string;
  name: string;
  icon: string;
  payChannel: number;
  payMethod: string;
  payType: string;
}

/**
 * 支付方式（API返回）
 * GET /api/payment/pay-method?store_id=xxx
 */
export interface PayMethodItem {
  pay_channel: string;      // 支付渠道ID: "1"=微信, "2"=支付宝, "13"=八达通
  pay_method: string;       // 支付方法: "WechatPay", "AliPay", "OctopusPay"
  pay_name: string;         // 显示名称: "微信支付", "Alipay HK"
  pay_type: string;         // 支付类型: "WXPAYCN", "ALIPAYHK", "OCTOPUS"
  pay_icon: string;         // 图标URL
  discount: object[];       // 折扣信息
}

/**
 * 支付订单请求参数
 */
export interface PayOrderParams {
  order_id: number;
  total: string;
  pay_channel: number;
  pay_method: string;
  pay_type: string;
}

/**
 * 支付订单响应数据
 */
export interface PayOrderData {
  url: string;       // 支付跳转URL
  form?: string;     // 表单脚本
  params?: string;   // 支付参数
}

// ==================== 门店选择相关模型 ====================

/**
 * 连锁门店信息
 */
export interface SchemeStore {
  store_id: number;
  name: string;
  local_name: string;
  cn_name: string;
  en_name: string;
  address: string;
  cn_address: string;
  en_address: string;
  coordinate: string;
}

/**
 * 连锁门店列表响应
 */
export interface SchemeStoresData {
  scheme_id: string;
  scheme_name: string;
  is_scheme_menu: string;
  flagship: string;
  stores: SchemeStore[];
}

// ==================== 弹窗相关模型 ====================

/**
 * 弹窗显示页面配置
 */
export interface PopShowPage {
  home_page: number;              // 首页
  dinein_home_page: number;       // 堂食首页
  takeout_home_page: number;      // 自取首页
  delivery_home_page: number;     // 配送首页
  courier_home_page: number;      // 快递首页
}

/**
 * 弹窗显示平台配置
 */
export interface PopShowPlat {
  h5: number;                     // H5平台
  mini_app: number;               // 小程序
}

/**
 * 弹窗显示频率配置
 */
export interface PopShowFrequency {
  days: number;                   // 每隔多少天显示一次（0=每次都显示）
  nums: number;                   // 每次访问显示次数（0=不限制）
}

/**
 * 店铺弹窗信息
 */
export interface StorePop {
  pop_id: string;
  store_id: string;
  type: string;                   // 弹窗类型
  status: string;                 // 状态: "1"=启用
  name: string;                   // 弹窗名称
  brief?: string;
  brief_cn?: string;
  brief_en?: string;
  brief_local?: string;
  image_url: string;              // 弹窗图片URL
  link_url: string;               // 点击跳转链接
  store_noticy?: string | null;
  store_noticy_cn?: string;
  store_noticy_en?: string | null;
  store_noticy_local?: string | null;
  show_page: PopShowPage;         // 显示页面配置
  show_plat: PopShowPlat;         // 显示平台配置
  show_frequency: PopShowFrequency; // 显示频率配置
  start_date: string;             // 开始日期
  end_date: string;               // 结束日期
  sort: string;                   // 排序
}
