/**
 * DataLoader 数据加载工具类
 *
 * 功能：
 * - 统一 try-catch-finally 模式
 * - 统一错误处理
 * - 统一 Loading 状态管理
 *
 * 替换位置：
 * - Index.ets、MenuPage.ets、CheckoutPage.ets、OrderDetailPage.ets、CouponPage.ets 的数据加载方法
 */

import { promptAction } from '@kit.ArkUI';

export interface LoaderConfig<T> {
  loadFn: () => Promise<T>;
  onSuccess: (data: T) => void;
  onError?: (error: Error) => void;
  onFinally?: () => void;
  errorMessage?: string;
  showErrorToast?: boolean;
}

export class DataLoader {
  /**
   * 统一数据加载模式
   *
   * 使用示例：
   * await DataLoader.load({
   *   loadFn: async () => await apiService.getHomeData(),
   *   onSuccess: (data) => { this.homeData = data; },
   *   onFinally: () => { this.isLoading = false; },
   *   errorMessage: '加載店鋪信息失敗'
   * });
   */
  static async load<T>(config: LoaderConfig<T>): Promise<void> {
    try {
      const data = await config.loadFn();
      config.onSuccess(data);
    } catch (error) {
      const errorObj = error as Error;
      console.error('[DataLoader] 数据加载失败:', errorObj);

      if (config.onError) {
        config.onError(errorObj);
      }

      if (config.showErrorToast !== false) {
        const message = config.errorMessage || '加載數據失敗，請重試';
        promptAction.showToast({
          message: message,
          duration: 2000
        });
      }
    } finally {
      if (config.onFinally) {
        config.onFinally();
      }
    }
  }

  /**
   * 带重试的数据加载
   *
   * 使用示例：
   * await DataLoader.loadWithRetry({
   *   loadFn: async () => await api.getHomeData(),
   *   onSuccess: (data) => { this.homeData = data; },
   *   maxRetries: 3,
   *   retryDelay: 1000
   * });
   */
  static async loadWithRetry<T>(
    config: LoaderConfig<T>,
    maxRetries: number = 3,
    retryDelay: number = 1000
  ): Promise<void> {
    let lastError: Error | null = null;

    for (let i = 0; i < maxRetries; i++) {
      try {
        const data = await config.loadFn();
        config.onSuccess(data);
        return;
      } catch (error) {
        lastError = error as Error;
        console.warn(`[DataLoader] 数据加载失败 (尝试 ${i + 1}/${maxRetries}):`, error);

        if (i < maxRetries - 1) {
          await new Promise<void>((resolve) => setTimeout(resolve, retryDelay));
        }
      }
    }

    // 所有重试都失败
    console.error('[DataLoader] 数据加载失败（已达最大重试次数）:', lastError);

    if (config.onError && lastError) {
      config.onError(lastError);
    }

    if (config.showErrorToast !== false) {
      const message = config.errorMessage || '加載數據失敗，請檢查網絡連接';
      promptAction.showToast({
        message: message,
        duration: 2000
      });
    }

    if (config.onFinally) {
      config.onFinally();
    }
  }

  /**
   * 带超时的数据加载
   */
  static async loadWithTimeout<T>(
    config: LoaderConfig<T>,
    timeout: number = 30000
  ): Promise<void> {
    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(() => reject(new Error('请求超时')), timeout);
    });

    try {
      const data = await Promise.race([
        config.loadFn(),
        timeoutPromise
      ]) as T;
      config.onSuccess(data);
    } catch (error) {
      const errorObj = error as Error;
      console.error('[DataLoader] 数据加载失败:', errorObj);

      if (config.onError) {
        config.onError(errorObj);
      }

      if (config.showErrorToast !== false) {
        const message = errorObj.message === '请求超时' ?
          '請求超時，請檢查網絡連接' :
          (config.errorMessage || '加載數據失敗，請重試');
        promptAction.showToast({
          message: message,
          duration: 2000
        });
      }
    } finally {
      if (config.onFinally) {
        config.onFinally();
      }
    }
  }
}
