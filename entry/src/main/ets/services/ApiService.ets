import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ApiResponse,
  HomeData,
  ProductMenuData,
  MemberPlanData,
  LoginResponse,
  OrderListData,
  CouponListData,
  ProductDetail,
  PolicyGroupData,
  AddOrderRequest,
  AddOrderResponse,
  OrderDetailData,
  PayOrderParams,
  PayOrderData,
  SchemeStoresData,
  PayMethodItem,
  StorePop
} from '../models/StoreModels';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { AppConfig } from '../config/AppConfig';

/**
 * 游客Token响应
 */
interface GuestTokenData {
  token: string;
  customer_id: number;
  telephone: string | null;
  customer_type: number;
}

const DOMAIN = 0x0000;
const TAG = 'ApiService';

/**
 * API服务配置（兼容旧代码，实际值来自 AppConfig）
 */
export class ApiConfig {
  static readonly BASE_URL: string = AppConfig.API_BASE_URL;
  static readonly DEFAULT_STORE_ID: string = AppConfig.DEFAULT_STORE_ID;
  static readonly DEFAULT_LANG: string = AppConfig.DEFAULT_LANG_CODE;
}

/**
 * API请求参数类型
 */
class RequestParams {
  store_id?: string;
  takeout?: string;
  order_sub_type?: string;
  t?: string;
  page?: string;
  page_size?: string;
  type?: string;           // 订单筛选类型
  page_number?: string;    // 页码
  page_limit?: string;     // 每页数量
  product_id?: string;     // 产品ID
  order_type?: string;     // 订单类型: 1=堂食, 2=外卖自取
  ts?: string;             // 时间戳
  sign?: string;           // 签名
}

/**
 * API请求Body类型
 */
class HomeRequestBody {
  store_id: string = '';
}

class LoginRequestBody {
  auth_code: string = '';
  login_type: string = '';
}

/**
 * API错误类
 */
class ApiError extends Error {
  code: number;
  constructor(message: string, code: number = 0) {
    super(message);
    this.code = code;
  }
}

/**
 * API服务类 - 对接pin2eat后端
 */
export class ApiService {
  private static instance: ApiService;
  private token: string = '';
  private storeId: string = ApiConfig.DEFAULT_STORE_ID;
  private langCode: string = ApiConfig.DEFAULT_LANG;

  private constructor() {}

  static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService();
    }
    return ApiService.instance;
  }

  /**
   * 设置授权Token
   */
  setToken(token: string): void {
    this.token = token;
  }

  /**
   * 设置店铺ID
   */
  setStoreId(storeId: string): void {
    this.storeId = storeId;
  }

  /**
   * 设置语言代码
   */
  setLangCode(langCode: string): void {
    this.langCode = langCode;
  }

  /**
   * 创建HTTP请求客户端
   */
  private createHttpRequest(): http.HttpRequest {
    return http.createHttp();
  }

  /**
   * 获取通用请求头
   */
  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json;charset=UTF-8',
      'store-id': this.storeId,
      'langcode': this.langCode,
      'Accept': '*/*'
    };
    if (this.token) {
      headers['authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }

  /**
   * 构建查询字符串
   */
  private buildQueryString(params: RequestParams): string {
    const parts: string[] = [];
    if (params.store_id) {
      parts.push(`store_id=${encodeURIComponent(params.store_id)}`);
    }
    if (params.takeout) {
      parts.push(`takeout=${encodeURIComponent(params.takeout)}`);
    }
    if (params.order_sub_type) {
      parts.push(`order_sub_type=${encodeURIComponent(params.order_sub_type)}`);
    }
    if (params.t) {
      parts.push(`t=${encodeURIComponent(params.t)}`);
    }
    if (params.page) {
      parts.push(`page=${encodeURIComponent(params.page)}`);
    }
    if (params.page_size) {
      parts.push(`page_size=${encodeURIComponent(params.page_size)}`);
    }
    if (params.type !== undefined) {
      parts.push(`type=${encodeURIComponent(params.type)}`);
    }
    if (params.page_number) {
      parts.push(`page_number=${encodeURIComponent(params.page_number)}`);
    }
    if (params.page_limit) {
      parts.push(`page_limit=${encodeURIComponent(params.page_limit)}`);
    }
    if (params.product_id) {
      parts.push(`product_id=${encodeURIComponent(params.product_id)}`);
    }
    if (params.order_type) {
      parts.push(`order_type=${encodeURIComponent(params.order_type)}`);
    }
    if (params.ts) {
      parts.push(`ts=${encodeURIComponent(params.ts)}`);
    }
    if (params.sign) {
      parts.push(`sign=${encodeURIComponent(params.sign)}`);
    }
    return parts.join('&');
  }

  /**
   * GET请求
   */
  private async get<T>(path: string, params?: RequestParams): Promise<ApiResponse<T>> {
    const httpRequest = this.createHttpRequest();
    let url = `${ApiConfig.BASE_URL}${path}`;

    if (params) {
      const queryString = this.buildQueryString(params);
      if (queryString) {
        url = `${url}?${queryString}`;
      }
    }

    const headers = this.getHeaders();
    hilog.info(DOMAIN, TAG, 'GET request: %{public}s', url);
    hilog.info(DOMAIN, TAG, 'Headers: store-id=%{public}s, langcode=%{public}s',
      headers['store-id'], headers['langcode']);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 30000,
        readTimeout: 30000
      });

      hilog.info(DOMAIN, TAG, 'HTTP responseCode: %{public}d', response.responseCode);
      httpRequest.destroy();

      if (response.responseCode === 200) {
        const resultStr = response.result as string;
        hilog.info(DOMAIN, TAG, 'Response length: %{public}d', resultStr.length);
        const result = JSON.parse(resultStr) as ApiResponse<T>;
        hilog.info(DOMAIN, TAG, 'GET success: code=%{public}d, msg=%{public}s', result.code, result.msg);
        return result;
      } else {
        hilog.error(DOMAIN, TAG, 'HTTP Error: %{public}d', response.responseCode);
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'GET error: %{public}s', errorMsg);
      throw new ApiError(errorMsg);
    }
  }

  /**
   * POST请求
   */
  private async post<T>(path: string, body: object): Promise<ApiResponse<T>> {
    const httpRequest = this.createHttpRequest();
    const url = `${ApiConfig.BASE_URL}${path}`;

    hilog.info(DOMAIN, TAG, 'POST request: %{public}s', url);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<T>;
        hilog.info(DOMAIN, TAG, 'POST success: code=%{public}d', result.code);
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'POST error: %{public}s', JSON.stringify(error));
      throw new ApiError(JSON.stringify(error));
    }
  }

  // ==================== 业务接口 ====================

  /**
   * 生成签名
   * 签名算法: MD5(store_id=${store_id}&ts=${ts}&key=SECRET_KEY)
   * 参数按字母顺序排序后拼接，最后追加密钥
   */
  private async generateSign(storeId: string, ts: string): Promise<string> {
    try {
      // 按字母顺序排列参数: store_id 在 ts 之前
      // 拼接格式: store_id=xxx&ts=xxx&key=SECRET_KEY
      const secretKey = 'a91f9568fbd23881c2b2c7fa9af5b12a';
      const signStr = `store_id=${storeId}&ts=${ts}&key=${secretKey}`;
      hilog.info(DOMAIN, TAG, 'Sign input: %{public}s', signStr);

      // 使用 MD5 生成签名
      const md5 = cryptoFramework.createMd('MD5');
      await md5.update({ data: new Uint8Array(buffer.from(signStr, 'utf-8').buffer) });
      const result = await md5.digest();

      // 转换为十六进制字符串（大写）
      const hexArr = Array.from(result.data);
      const hexStr = hexArr.map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase();
      return hexStr;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Generate sign error: %{public}s', JSON.stringify(error));
      return '';
    }
  }

  /**
   * 获取游客Token
   * GET /api/account/token
   * 在应用启动时调用，获取游客身份token用于后续API请求
   */
  async getGuestToken(): Promise<boolean> {
    try {
      const ts = Date.now().toString();
      const sign = await this.generateSign(this.storeId, ts);

      const params = new RequestParams();
      params.store_id = this.storeId;
      params.ts = ts;
      params.sign = sign;

      hilog.info(DOMAIN, TAG, 'Getting guest token with sign: %{public}s', sign);

      const response = await this.get<GuestTokenData>('/api/account/token', params);

      if (response.code === 200 && response.data?.token) {
        this.token = response.data.token;
        hilog.info(DOMAIN, TAG, 'Guest token obtained, customer_id: %{public}d, type: %{public}d',
          response.data.customer_id, response.data.customer_type);
        return true;
      } else {
        hilog.error(DOMAIN, TAG, 'Failed to get guest token: %{public}s', response.msg);
        return false;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get guest token error: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 检查是否有有效token
   */
  hasToken(): boolean {
    return this.token.length > 0;
  }

  /**
   * 获取店铺首页数据
   * POST /api/v2/home
   */
  async getHomeData(storeId?: string): Promise<ApiResponse<HomeData>> {
    const body = new HomeRequestBody();
    body.store_id = storeId || this.storeId;
    return this.post<HomeData>('/api/v2/home', body);
  }

  /**
   * 获取产品菜单
   * GET /api/home/product-menus
   * @param takeout 1=自取, 0=堂食
   * @param orderSubType 订单子类型
   */
  async getProductMenus(takeout: number = 1, orderSubType: number = 0): Promise<ApiResponse<ProductMenuData>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    params.takeout = takeout.toString();
    params.order_sub_type = orderSubType.toString();
    return this.get<ProductMenuData>('/api/home/product-menus', params);
  }

  /**
   * 获取会员计划
   * GET /api/store/meal-member-plan
   */
  async getMemberPlan(): Promise<ApiResponse<MemberPlanData>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    params.t = Date.now().toString();
    return this.get<MemberPlanData>('/api/store/meal-member-plan', params);
  }

  /**
   * 获取店铺弹窗
   * GET /api/store/store-pops
   */
  async getStorePops(): Promise<ApiResponse<StorePop[]>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    return this.get<StorePop[]>('/api/store/store-pops', params);
  }

  /**
   * 用户登录（使用华为ID授权码）
   * 注意：这是假设的接口路径，需根据实际后端接口调整
   */
  async loginWithHuaweiId(authCode: string): Promise<ApiResponse<LoginResponse>> {
    const body = new LoginRequestBody();
    body.auth_code = authCode;
    body.login_type = 'huawei';
    return this.post<LoginResponse>('/api/auth/huawei-login', body);
  }

  /**
   * 获取用户订单列表
   * GET /api/order/order-list-app
   * @param filterType 筛选类型: '' (全部) | '11' (進行中) | '12' (已完成) | '13' (退款/取消)
   * @param pageNumber 页码（从1开始）
   * @param pageLimit 每页数量
   */
  async getOrders(
    filterType: string = '',
    pageNumber: number = 1,
    pageLimit: number = 10
  ): Promise<ApiResponse<OrderListData>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    params.type = filterType;
    params.page_number = pageNumber.toString();
    params.page_limit = pageLimit.toString();
    return this.get<OrderListData>('/api/order/order-list-app', params);
  }

  /**
   * 获取用户优惠券列表
   */
  async getCoupons(): Promise<ApiResponse<CouponListData>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    return this.get<CouponListData>('/api/coupon/list', params);
  }

  /**
   * 获取产品详情
   * GET /api/product/detail
   * @param productId 产品ID
   * @param orderType 订单类型: 1=堂食, 2=外卖自取
   */
  async getProductDetail(productId: string, orderType: number = 2): Promise<ApiResponse<ProductDetail>> {
    const params = new RequestParams();
    params.product_id = productId;
    params.order_type = orderType.toString();
    return this.get<ProductDetail>('/api/product/detail', params);
  }

  /**
   * 获取产品政策（加送選擇）
   * GET /api/product/policy
   * @param policyIds 政策ID数组
   */
  async getProductPolicy(policyIds: string[]): Promise<ApiResponse<PolicyGroupData[]>> {
    if (policyIds.length === 0) {
      return { code: 200, msg: '成功', data: [] };
    }

    const httpRequest = this.createHttpRequest();
    // 构建URL: /api/product/policy?store_id=xxx&policies[]=id1&policies[]=id2
    let url = `${ApiConfig.BASE_URL}/api/product/policy?store_id=${this.storeId}`;
    for (const policyId of policyIds) {
      url += `&policies[]=${encodeURIComponent(policyId)}`;
    }

    hilog.info(DOMAIN, TAG, 'GET policy request: %{public}s', url);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<PolicyGroupData[]>;
        hilog.info(DOMAIN, TAG, 'Policy success: code=%{public}d, count=%{public}d',
          result.code, result.data?.length || 0);
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Policy error: %{public}s', errorMsg);
      throw new ApiError(errorMsg);
    }
  }

  /**
   * 提交订单
   * POST /api/order/add-order
   */
  async addOrder(orderData: AddOrderRequest): Promise<ApiResponse<AddOrderResponse>> {
    hilog.info(DOMAIN, TAG, 'Submitting order: products=%{public}d, total=%{public}s',
      orderData.products.length, orderData.total);
    return this.post<AddOrderResponse>('/api/order/add-order', orderData);
  }

  /**
   * 获取订单详情
   * GET /api/order/detail
   * @param orderId 订单ID
   */
  async getOrderDetail(orderId: string): Promise<ApiResponse<OrderDetailData>> {
    const httpRequest = this.createHttpRequest();
    const url = `${ApiConfig.BASE_URL}/api/order/detail?order_id=${orderId}`;

    hilog.info(DOMAIN, TAG, 'GET order detail: %{public}s', url);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<OrderDetailData>;
        hilog.info(DOMAIN, TAG, 'Order detail success: order_id=%{public}s, status=%{public}s',
          result.data?.order_id, result.data?.status?.customer_name);
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Order detail error: %{public}s', errorMsg);
      throw new ApiError(errorMsg);
    }
  }

  /**
   * 支付订单
   * GET /api/payment/pay-order
   * @param params 支付参数
   */
  async payOrder(params: PayOrderParams): Promise<ApiResponse<PayOrderData>> {
    const httpRequest = this.createHttpRequest();
    const url = `${ApiConfig.BASE_URL}/api/payment/pay-order?order_id=${params.order_id}&total=${params.total}&pay_channel=${params.pay_channel}&pay_method=${params.pay_method}&pay_type=${params.pay_type}`;

    hilog.info(DOMAIN, TAG, 'Pay order request: order_id=%{public}d, total=%{public}s, pay_type=%{public}s',
      params.order_id, params.total, params.pay_type);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<PayOrderData>;
        hilog.info(DOMAIN, TAG, 'Pay order success: url=%{public}s', result.data?.url || 'null');
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Pay order error: %{public}s', errorMsg);
      throw new ApiError(errorMsg);
    }
  }

  /**
   * 获取连锁门店列表
   * GET /api/store/scheme-stores
   * @param schemeId 连锁品牌ID（从 member_plan.scheme_id 获取）
   */
  async getSchemeStores(schemeId: string): Promise<ApiResponse<SchemeStoresData>> {
    const httpRequest = this.createHttpRequest();
    const url = `${ApiConfig.BASE_URL}/api/store/scheme-stores?scheme_id=${schemeId}&store_id=${this.storeId}`;

    hilog.info(DOMAIN, TAG, 'Get scheme stores: scheme_id=%{public}s', schemeId);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<SchemeStoresData>;
        hilog.info(DOMAIN, TAG, 'Scheme stores success: count=%{public}d',
          result.data?.stores?.length || 0);
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Scheme stores error: %{public}s', errorMsg);
      throw new ApiError(errorMsg);
    }
  }

  /**
   * 获取支付方式列表
   * GET /api/payment/pay-method?store_id=xxx
   */
  async getPaymentMethods(): Promise<ApiResponse<PayMethodItem[]>> {
    const httpRequest = this.createHttpRequest();
    const url = `${ApiConfig.BASE_URL}/api/payment/pay-method?store_id=${this.storeId}`;

    hilog.info(DOMAIN, TAG, 'Get payment methods: store_id=%{public}s', this.storeId);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<PayMethodItem[]>;
        hilog.info(DOMAIN, TAG, 'Payment methods success: count=%{public}d',
          result.data?.length || 0);
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN, TAG, 'Payment methods error: %{public}s', errorMsg);
      throw new ApiError(errorMsg);
    }
  }
}

// 导出单例
export const apiService = ApiService.getInstance();
