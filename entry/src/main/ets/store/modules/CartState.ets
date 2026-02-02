/**
 * CartState - 购物车响应式状态管理
 *
 * 核心改进：
 * - ✅ 返回只读副本，防止状态泄漏
 * - ✅ 观察者模式，UI 自动响应更新（无需手动 updateCartState()）
 * - ✅ 防抖持久化（500ms），避免并发冲突
 * - ✅ 类型安全的状态访问
 *
 * 使用示例：
 * ```typescript
 * // 订阅购物车状态
 * cartState.subscribe({
 *   onStateChange: (state) => {
 *     this.cartItems = state.items;  // UI 自动更新
 *     this.cartCount = state.count;
 *     this.cartTotal = state.total;
 *   }
 * });
 *
 * // 添加商品（自动触发观察者）
 * await cartState.addItem(cartItemInput);  // 无需手动 updateCartState()
 * ```
 */

import { ReactiveState } from '../StateManager';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type {
  CartItem,
  CartItemInput,
  CartPackageSelection,
  CartPolicySelection,
  CartBoxInfo
} from '../../services/AppStorage';

const DOMAIN = 0x0000;
const TAG = 'CartState';
const PREFERENCES_NAME = 'pin2eat_store';
const PERSIST_DEBOUNCE_MS = 500;  // 持久化防抖延迟

/**
 * 购物车状态数据结构
 */
export interface CartStateData {
  items: CartItem[];
  count: number;
  total: number;
}

/**
 * 购物车响应式状态管理
 */
export class CartState extends ReactiveState<CartStateData> {
  private static instance: CartState | null = null;
  private preferences: preferences.Preferences | null = null;
  private persistTimer: number = -1;

  constructor() {
    super({
      items: [],
      count: 0,
      total: 0
    });
  }

  /**
   * 获取单例
   */
  static getInstance(): CartState {
    if (!CartState.instance) {
      CartState.instance = new CartState();
    }
    return CartState.instance;
  }

  /**
   * 初始化（从持久化存储加载数据）
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.preferences = await preferences.getPreferences(context, PREFERENCES_NAME);
      await this.loadFromStorage();
      hilog.info(DOMAIN, TAG, 'CartState initialized');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to init CartState: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 从持久化存储加载购物车数据
   */
  private async loadFromStorage(): Promise<void> {
    if (!this.preferences) return;

    try {
      const cartStr = await this.preferences.get('cart', '[]') as string;
      const items: CartItem[] = JSON.parse(cartStr);

      // 计算总数和总价
      const count = items.reduce((sum, item) => sum + item.quantity, 0);
      const total = items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);

      this.setValue({
        items: items,
        count: count,
        total: total
      });

      hilog.info(DOMAIN, TAG, 'Loaded cart from storage: %{public}d items', items.length);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load cart: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 持久化购物车数据（防抖）
   */
  private schedulePersist(): void {
    // 清除之前的计时器
    if (this.persistTimer !== -1) {
      clearTimeout(this.persistTimer);
    }

    // 延迟持久化
    this.persistTimer = setTimeout(() => {
      this.persistToStorage();
      this.persistTimer = -1;
    }, PERSIST_DEBOUNCE_MS);
  }

  /**
   * 立即持久化到存储
   */
  private async persistToStorage(): Promise<void> {
    if (!this.preferences) {
      hilog.warn(DOMAIN, TAG, 'Preferences not initialized, skipping persist');
      return;
    }

    try {
      const currentState = this.value;
      await this.preferences.put('cart', JSON.stringify(currentState.items));
      await this.preferences.flush();
      hilog.debug(DOMAIN, TAG, 'Cart persisted: %{public}d items', currentState.items.length);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to persist cart: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 创建只读副本（防止外部修改状态）
   */
  protected createReadonlyCopy(value: CartStateData): Readonly<CartStateData> {
    return {
      items: [...value.items],  // 浅拷贝数组
      count: value.count,
      total: value.total
    };
  }

  /**
   * 生成唯一购物车项ID
   */
  private generateCartItemId(cartItem: CartItemInput): string {
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
   * 添加商品到购物车（自动触发观察者）
   */
  async addItem(cartItem: CartItemInput): Promise<void> {
    const cartItemId = this.generateCartItemId(cartItem);
    const currentState = this.value;
    const items = [...currentState.items];  // 复制数组

    const existingIndex = items.findIndex(item => item.cartItemId === cartItemId);

    if (existingIndex >= 0) {
      // 更新已有商品数量（手动复制对象，避免 spread 操作符）
      const oldItem = items[existingIndex];
      items[existingIndex] = {
        productId: oldItem.productId,
        productName: oldItem.productName,
        coverImage: oldItem.coverImage,
        groupId: oldItem.groupId,
        priceIndex: oldItem.priceIndex,
        priceName: oldItem.priceName,
        standardCode: oldItem.standardCode,
        basePrice: oldItem.basePrice,
        packageSelections: oldItem.packageSelections,
        policySelections: oldItem.policySelections,
        quantity: oldItem.quantity + cartItem.quantity,
        unitPrice: oldItem.unitPrice,
        specDescription: oldItem.specDescription,
        cartItemId: oldItem.cartItemId,
        boxInfo: oldItem.boxInfo
      };
    } else {
      // 添加新商品
      const newItem: CartItem = {
        productId: cartItem.productId,
        productName: cartItem.productName,
        coverImage: cartItem.coverImage,
        groupId: cartItem.groupId,
        priceIndex: cartItem.priceIndex,
        priceName: cartItem.priceName,
        standardCode: cartItem.standardCode,
        basePrice: cartItem.basePrice,
        packageSelections: cartItem.packageSelections,
        policySelections: cartItem.policySelections,
        quantity: cartItem.quantity,
        unitPrice: cartItem.unitPrice,
        specDescription: cartItem.specDescription,
        cartItemId: cartItemId,
        boxInfo: cartItem.boxInfo
      };
      items.push(newItem);
    }

    // 重新计算总数和总价
    const count = items.reduce((sum, item) => sum + item.quantity, 0);
    const total = items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);

    // 更新状态（自动触发观察者）
    this.setValue({
      items: items,
      count: count,
      total: total
    });

    // 防抖持久化
    this.schedulePersist();

    hilog.info(DOMAIN, TAG, 'Item added: %{public}s, count: %{public}d', cartItemId, count);
  }

  /**
   * 更新购物车商品数量（自动触发观察者）
   */
  async updateItemQuantity(cartItemId: string, quantity: number): Promise<void> {
    const currentState = this.value;
    let items = [...currentState.items];  // 复制数组

    const index = items.findIndex(item => item.cartItemId === cartItemId);

    if (index >= 0) {
      if (quantity <= 0) {
        // 删除商品
        items.splice(index, 1);
      } else {
        // 更新数量（手动复制对象，避免 spread 操作符）
        const oldItem = items[index];
        items[index] = {
          productId: oldItem.productId,
          productName: oldItem.productName,
          coverImage: oldItem.coverImage,
          groupId: oldItem.groupId,
          priceIndex: oldItem.priceIndex,
          priceName: oldItem.priceName,
          standardCode: oldItem.standardCode,
          basePrice: oldItem.basePrice,
          packageSelections: oldItem.packageSelections,
          policySelections: oldItem.policySelections,
          quantity: quantity,
          unitPrice: oldItem.unitPrice,
          specDescription: oldItem.specDescription,
          cartItemId: oldItem.cartItemId,
          boxInfo: oldItem.boxInfo
        };
      }

      // 重新计算总数和总价
      const count = items.reduce((sum, item) => sum + item.quantity, 0);
      const total = items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);

      // 更新状态（自动触发观察者）
      this.setValue({
        items: items,
        count: count,
        total: total
      });

      // 防抖持久化
      this.schedulePersist();

      hilog.info(DOMAIN, TAG, 'Item quantity updated: %{public}s, qty: %{public}d', cartItemId, quantity);
    }
  }

  /**
   * 删除购物车项（自动触发观察者）
   */
  async removeItem(cartItemId: string): Promise<void> {
    await this.updateItemQuantity(cartItemId, 0);
  }

  /**
   * 清空购物车（自动触发观察者）
   */
  async clearCart(): Promise<void> {
    this.setValue({
      items: [],
      count: 0,
      total: 0
    });

    // 立即持久化清空操作
    await this.persistToStorage();

    hilog.info(DOMAIN, TAG, 'Cart cleared');
  }

  /**
   * 获取购物车商品数量
   */
  getCount(): number {
    return this.value.count;
  }

  /**
   * 获取购物车总价
   */
  getTotal(): number {
    return this.value.total;
  }

  /**
   * 获取购物车商品列表（只读副本）
   */
  getItems(): readonly CartItem[] {
    return this.value.items;
  }
}

// 导出单例
export const cartState = CartState.getInstance();
