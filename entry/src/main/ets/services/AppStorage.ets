import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Product } from '../models/StoreModels';

const DOMAIN = 0x0000;
const TAG = 'AppStorage';
const PREFERENCES_NAME = 'pin2eat_store';

/**
 * 购物车项
 */
export interface CartItem {
  product: Product;
  quantity: number;
  selectedPrice: string;
  selectedSpec: string;
}

/**
 * 用户信息
 */
export interface UserInfo {
  customerId: number;
  nickname: string;
  avatar: string;
  token: string;
}

/**
 * 应用全局状态管理
 */
export class AppStateManager {
  private static instance: AppStateManager;
  private preferences: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  // 用户状态
  private _isLoggedIn: boolean = false;
  private _userInfo: UserInfo | null = null;
  private _token: string = '';

  // 购物车状态
  private _cartItems: CartItem[] = [];

  // 店铺配置
  private _storeId: string = '1551';
  private _themeColor: string = '#FFD700';

  private constructor() {}

  static getInstance(): AppStateManager {
    if (!AppStateManager.instance) {
      AppStateManager.instance = new AppStateManager();
    }
    return AppStateManager.instance;
  }

  /**
   * 初始化（在Ability中调用）
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await this.loadPersistedData();
      hilog.info(DOMAIN, TAG, 'AppStateManager initialized');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to init preferences: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 加载持久化数据
   */
  private async loadPersistedData(): Promise<void> {
    if (!this.preferences) return;

    try {
      this._token = await this.preferences.get('token', '') as string;
      this._storeId = await this.preferences.get('store_id', '1551') as string;

      const userInfoStr = await this.preferences.get('user_info', '') as string;
      if (userInfoStr) {
        this._userInfo = JSON.parse(userInfoStr);
        this._isLoggedIn = true;
      }

      const cartStr = await this.preferences.get('cart', '[]') as string;
      this._cartItems = JSON.parse(cartStr);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load persisted data: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 保存数据到持久化存储
   */
  private async saveData(key: string, value: string): Promise<void> {
    if (!this.preferences) return;

    try {
      await this.preferences.put(key, value);
      await this.preferences.flush();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save data: %{public}s', JSON.stringify(error));
    }
  }

  // ==================== 用户相关 ====================

  get isLoggedIn(): boolean {
    return this._isLoggedIn;
  }

  get userInfo(): UserInfo | null {
    return this._userInfo;
  }

  get token(): string {
    return this._token;
  }

  /**
   * 设置登录状态
   */
  async setLoginState(userInfo: UserInfo): Promise<void> {
    this._userInfo = userInfo;
    this._token = userInfo.token;
    this._isLoggedIn = true;

    await this.saveData('token', userInfo.token);
    await this.saveData('user_info', JSON.stringify(userInfo));
  }

  /**
   * 登出
   */
  async logout(): Promise<void> {
    this._userInfo = null;
    this._token = '';
    this._isLoggedIn = false;
    this._cartItems = [];

    await this.saveData('token', '');
    await this.saveData('user_info', '');
    await this.saveData('cart', '[]');
  }

  // ==================== 购物车相关 ====================

  get cartItems(): CartItem[] {
    return this._cartItems;
  }

  get cartCount(): number {
    return this._cartItems.reduce((sum, item) => sum + item.quantity, 0);
  }

  get cartTotal(): number {
    return this._cartItems.reduce((sum, item) => {
      return sum + parseFloat(item.selectedPrice) * item.quantity;
    }, 0);
  }

  /**
   * 添加商品到购物车
   */
  async addToCart(product: Product, quantity: number = 1, spec?: string): Promise<void> {
    const existingIndex = this._cartItems.findIndex(
      item => item.product.product_id === product.product_id &&
        item.selectedSpec === (spec || '')
    );

    if (existingIndex >= 0) {
      this._cartItems[existingIndex].quantity += quantity;
    } else {
      this._cartItems.push({
        product: product,
        quantity: quantity,
        selectedPrice: product.price,
        selectedSpec: spec || ''
      });
    }

    await this.saveData('cart', JSON.stringify(this._cartItems));
    hilog.info(DOMAIN, TAG, 'Cart updated: %{public}d items', this.cartCount);
  }

  /**
   * 更新购物车商品数量
   */
  async updateCartItemQuantity(productId: string, spec: string, quantity: number): Promise<void> {
    const index = this._cartItems.findIndex(
      item => item.product.product_id === productId && item.selectedSpec === spec
    );

    if (index >= 0) {
      if (quantity <= 0) {
        this._cartItems.splice(index, 1);
      } else {
        this._cartItems[index].quantity = quantity;
      }
      await this.saveData('cart', JSON.stringify(this._cartItems));
    }
  }

  /**
   * 清空购物车
   */
  async clearCart(): Promise<void> {
    this._cartItems = [];
    await this.saveData('cart', '[]');
  }

  // ==================== 店铺配置 ====================

  get storeId(): string {
    return this._storeId;
  }

  get themeColor(): string {
    return this._themeColor;
  }

  async setStoreId(storeId: string): Promise<void> {
    this._storeId = storeId;
    await this.saveData('store_id', storeId);
  }

  setThemeColor(color: string): void {
    this._themeColor = color;
  }
}

// 导出单例
export const appState = AppStateManager.getInstance();
