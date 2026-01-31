import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../config/AppConfig';

const DOMAIN = 0x0000;
const TAG = 'AppStorage';
const PREFERENCES_NAME = 'pin2eat_store';

/**
 * 购物车项 - 配料选择
 */
export interface CartPackageSelection {
  groupId: string;
  groupName: string;
  items: CartPackageItem[];
}

export interface CartPackageItem {
  productId: string;
  name: string;
  addPrice: number;
}

/**
 * 购物车项 - 加送商品选择
 */
export interface CartPolicySelection {
  groupId: string;
  groupName: string;
  item: CartPolicyItem;
}

export interface CartPolicyItem {
  productId: string;
  name: string;
  priceIndex: number;         // 规格索引（熱/凍）
  priceName: string;          // 规格名称
  addPrice: number;           // 加价
  condiments: CartCondiment[];  // 配料选择（甜度、冰量等）
}

export interface CartCondiment {
  groupId: string;
  groupName: string;
  itemId: string;
  itemName: string;
  price: number;
}

/**
 * 购物车项输入（不含cartItemId，用于添加到购物车）
 */
export interface CartItemInput {
  // 商品基本信息
  productId: string;
  productName: string;
  coverImage: string;

  // 规格选择
  priceIndex: number;
  priceName: string;         // 规格名称（如果有多规格）
  basePrice: number;         // 基础价格

  // 配料选择
  packageSelections: CartPackageSelection[];

  // 加送商品选择
  policySelections: CartPolicySelection[];

  // 数量
  quantity: number;

  // 单价（包含所有加价）
  unitPrice: number;

  // 规格描述（用于显示 "奶茶·熱·標準·標準"）
  specDescription: string;
}

/**
 * 购物车项
 */
export interface CartItem {
  // 商品基本信息
  productId: string;
  productName: string;
  coverImage: string;

  // 规格选择
  priceIndex: number;
  priceName: string;         // 规格名称（如果有多规格）
  basePrice: number;         // 基础价格

  // 配料选择
  packageSelections: CartPackageSelection[];

  // 加送商品选择
  policySelections: CartPolicySelection[];

  // 数量
  quantity: number;

  // 单价（包含所有加价）
  unitPrice: number;

  // 规格描述（用于显示 "奶茶·熱·標準·標準"）
  specDescription: string;

  // 唯一标识（用于区分相同商品不同配料的项）
  cartItemId: string;
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
  private _storeId: string = AppConfig.DEFAULT_STORE_ID;
  private _themeColor: string = AppConfig.DEFAULT_THEME_COLOR;

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
      this._storeId = await this.preferences.get('store_id', AppConfig.DEFAULT_STORE_ID) as string;

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
      return sum + item.unitPrice * item.quantity;
    }, 0);
  }

  /**
   * 生成唯一购物车项ID
   */
  private generateCartItemId(cartItem: CartItemInput): string {
    // 基于商品ID、规格、配料选择生成唯一ID
    const parts: string[] = [];
    parts.push(cartItem.productId);
    parts.push(cartItem.priceIndex.toString());

    // 配料选择部分
    const pkgParts: string[] = [];
    for (const p of cartItem.packageSelections) {
      const itemIds: string[] = [];
      for (const item of p.items) {
        itemIds.push(item.productId);
      }
      pkgParts.push(`${p.groupId}:${itemIds.join(',')}`);
    }
    parts.push(pkgParts.join('|'));

    // 加送商品选择部分
    const policyParts: string[] = [];
    for (const p of cartItem.policySelections) {
      const condimentIds: string[] = [];
      for (const c of p.item.condiments) {
        condimentIds.push(c.itemId);
      }
      policyParts.push(`${p.groupId}:${p.item.productId}:${p.item.priceIndex}:${condimentIds.join(',')}`);
    }
    parts.push(policyParts.join('|'));

    return parts.join('_');
  }

  /**
   * 添加商品到购物车
   */
  async addToCart(cartItem: CartItemInput): Promise<void> {
    const cartItemId = this.generateCartItemId(cartItem);

    const existingIndex = this._cartItems.findIndex(
      item => item.cartItemId === cartItemId
    );

    if (existingIndex >= 0) {
      this._cartItems[existingIndex].quantity += cartItem.quantity;
    } else {
      // 创建完整的 CartItem
      const newItem: CartItem = {
        productId: cartItem.productId,
        productName: cartItem.productName,
        coverImage: cartItem.coverImage,
        priceIndex: cartItem.priceIndex,
        priceName: cartItem.priceName,
        basePrice: cartItem.basePrice,
        packageSelections: cartItem.packageSelections,
        policySelections: cartItem.policySelections,
        quantity: cartItem.quantity,
        unitPrice: cartItem.unitPrice,
        specDescription: cartItem.specDescription,
        cartItemId: cartItemId
      };
      this._cartItems.push(newItem);
    }

    await this.saveData('cart', JSON.stringify(this._cartItems));
    hilog.info(DOMAIN, TAG, 'Cart updated: %{public}d items, total: %{public}d',
      this.cartCount, this.cartTotal);
  }

  /**
   * 更新购物车商品数量
   */
  async updateCartItemQuantity(cartItemId: string, quantity: number): Promise<void> {
    const index = this._cartItems.findIndex(item => item.cartItemId === cartItemId);

    if (index >= 0) {
      if (quantity <= 0) {
        this._cartItems.splice(index, 1);
      } else {
        this._cartItems[index].quantity = quantity;
      }
      await this.saveData('cart', JSON.stringify(this._cartItems));
      hilog.info(DOMAIN, TAG, 'Cart item updated: %{public}s, qty: %{public}d',
        cartItemId, quantity);
    }
  }

  /**
   * 删除购物车项
   */
  async removeCartItem(cartItemId: string): Promise<void> {
    const index = this._cartItems.findIndex(item => item.cartItemId === cartItemId);
    if (index >= 0) {
      this._cartItems.splice(index, 1);
      await this.saveData('cart', JSON.stringify(this._cartItems));
      hilog.info(DOMAIN, TAG, 'Cart item removed: %{public}s', cartItemId);
    }
  }

  /**
   * 清空购物车
   */
  async clearCart(): Promise<void> {
    this._cartItems = [];
    await this.saveData('cart', '[]');
    hilog.info(DOMAIN, TAG, 'Cart cleared');
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
