/**
 * RouteManager 路由管理工具类
 *
 * 功能：
 * - 统一路由跳转逻辑
 * - 统一错误处理
 * - 类型安全的路由参数
 *
 * 替换位置：
 * - Index.ets L1895-1913
 * - MenuPage.ets L1186-1223
 * - CheckoutPage.ets L306-312
 */

import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { OrderType } from '../models/StoreModels';

// 路由参数类型定义
export interface MenuPageParams {
  orderType: OrderType;
  initialTab?: number;
  hasDiscount?: boolean;
  discountRatio?: number;
  discountLabel?: string;
}

export interface CheckoutPageParams {
  orderType: OrderType;
  hasDiscount?: boolean;
  discountRatio?: number;
  discountLabel?: string;
}

export interface OrderDetailPageParams {
  orderId: string;
}

export interface CouponPageParams {
  // 优惠券页面参数
}

export class RouteManager {
  /**
   * 跳转到菜单页面
   */
  static async navigateToMenu(params: MenuPageParams): Promise<void> {
    try {
      await router.pushUrl({
        url: 'pages/MenuPage',
        params: {
          orderType: params.orderType,
          initialTab: params.initialTab ?? 1,
          hasDiscount: params.hasDiscount ?? false,
          discountRatio: params.discountRatio ?? 1.0,
          discountLabel: params.discountLabel ?? ''
        }
      });
    } catch (error) {
      console.error('[RouteManager] 跳转到菜单页面失败:', error);
      promptAction.showToast({
        message: '頁面跳轉失敗，請重試',
        duration: 2000
      });
    }
  }

  /**
   * 跳转到结账页面
   */
  static async navigateToCheckout(params: CheckoutPageParams): Promise<void> {
    try {
      await router.pushUrl({
        url: 'pages/CheckoutPage',
        params: {
          orderType: params.orderType,
          hasDiscount: params.hasDiscount ?? false,
          discountRatio: params.discountRatio ?? 1.0,
          discountLabel: params.discountLabel ?? ''
        }
      });
    } catch (error) {
      console.error('[RouteManager] 跳转到结账页面失败:', error);
      promptAction.showToast({
        message: '頁面跳轉失敗，請重試',
        duration: 2000
      });
    }
  }

  /**
   * 跳转到订单详情页面
   */
  static async navigateToOrderDetail(params: OrderDetailPageParams): Promise<void> {
    try {
      await router.pushUrl({
        url: 'pages/OrderDetailPage',
        params: {
          orderId: params.orderId
        }
      });
    } catch (error) {
      console.error('[RouteManager] 跳转到订单详情页面失败:', error);
      promptAction.showToast({
        message: '頁面跳轉失敗，請重試',
        duration: 2000
      });
    }
  }

  /**
   * 跳转到优惠券页面
   */
  static async navigateToCoupon(params?: CouponPageParams): Promise<void> {
    try {
      const routeParams: CouponPageParams = params ? params : {} as CouponPageParams;
      await router.pushUrl({
        url: 'pages/CouponPage',
        params: routeParams
      });
    } catch (error) {
      console.error('[RouteManager] 跳转到优惠券页面失败:', error);
      promptAction.showToast({
        message: '頁面跳轉失敗，請重試',
        duration: 2000
      });
    }
  }

  /**
   * 安全获取路由参数（带类型检查）
   */
  static getParams<T extends ESObject>(): T | null {
    try {
      const params = router.getParams() as T;
      if (!params || Object.keys(params).length === 0) {
        console.warn('[RouteManager] 未获取到路由参数');
        return null;
      }
      return params;
    } catch (error) {
      console.error('[RouteManager] 获取路由参数失败:', error);
      return null;
    }
  }

  /**
   * 返回上一页
   */
  static async back(): Promise<void> {
    try {
      await router.back();
    } catch (error) {
      console.error('[RouteManager] 返回上一页失败:', error);
      // 如果返回失败，可能已经是首页，不做处理
    }
  }

  /**
   * 返回首页
   */
  static async backToHome(): Promise<void> {
    try {
      await router.clear();
      await router.pushUrl({
        url: 'pages/Index'
      });
    } catch (error) {
      console.error('[RouteManager] 返回首页失败:', error);
      promptAction.showToast({
        message: '返回首頁失敗',
        duration: 2000
      });
    }
  }

  /**
   * 替换当前页面（不增加历史记录）
   */
  static async replaceUrl(url: string, params?: ESObject): Promise<void> {
    try {
      const routeParams: ESObject = params ? params : {} as ESObject;
      await router.replaceUrl({
        url: url,
        params: routeParams
      });
    } catch (error) {
      console.error('[RouteManager] 替换页面失败:', error);
      promptAction.showToast({
        message: '頁面跳轉失敗',
        duration: 2000
      });
    }
  }
}
