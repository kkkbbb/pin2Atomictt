import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ApiResponse,
  HomeData,
  ProductMenuData,
  MemberPlanData,
  LoginResponse
} from '../models/StoreModels';

const DOMAIN = 0x0000;
const TAG = 'ApiService';

/**
 * API服务配置
 */
export class ApiConfig {
  static readonly BASE_URL: string = 'https://meal.pin2eat.com';
  static readonly DEFAULT_STORE_ID: string = '1551';
  static readonly DEFAULT_LANG: string = 'zh_HK';
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

    hilog.info(DOMAIN, TAG, 'GET request: %{public}s', url);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<T>;
        hilog.info(DOMAIN, TAG, 'GET success: code=%{public}d', result.code);
        return result;
      } else {
        throw new ApiError(`HTTP Error: ${response.responseCode}`, response.responseCode);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'GET error: %{public}s', JSON.stringify(error));
      throw new ApiError(JSON.stringify(error));
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
  async getStorePops(): Promise<ApiResponse<object[]>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    return this.get<object[]>('/api/store/store-pops', params);
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
   */
  async getOrders(page: number = 1, pageSize: number = 20): Promise<ApiResponse<object>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    params.page = page.toString();
    params.page_size = pageSize.toString();
    return this.get<object>('/api/order/list', params);
  }

  /**
   * 获取用户优惠券列表
   */
  async getCoupons(): Promise<ApiResponse<object[]>> {
    const params = new RequestParams();
    params.store_id = this.storeId;
    return this.get<object[]>('/api/coupon/list', params);
  }
}

// 导出单例
export const apiService = ApiService.getInstance();
