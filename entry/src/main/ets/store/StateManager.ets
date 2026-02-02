/**
 * StateManager - 响应式状态管理基类
 *
 * 功能：
 * - 观察者模式实现
 * - 自动触发 UI 更新
 * - 防止状态泄漏（返回只读副本）
 *
 * 使用示例：
 * ```typescript
 * export class CartState extends ReactiveState<CartStateData> {
 *   protected createReadonlyCopy(value: CartStateData): Readonly<CartStateData> {
 *     return {
 *       items: [...value.items],
 *       count: value.count,
 *       total: value.total
 *     };
 *   }
 * }
 * ```
 */

import { StateObserver } from './observers/StateObserver';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'StateManager';

/**
 * 响应式状态基类
 * @template T 状态数据类型
 */
export abstract class ReactiveState<T> {
  private _value: T;
  private observers: Set<StateObserver<T>> = new Set();

  /**
   * 构造函数
   * @param initialValue 初始状态值
   */
  constructor(initialValue: T) {
    this._value = initialValue;
  }

  /**
   * 获取只读状态副本（防止外部修改）
   */
  get value(): Readonly<T> {
    return this.createReadonlyCopy(this._value);
  }

  /**
   * 设置新状态并触发所有观察者
   * @param newValue 新的状态值
   */
  protected setValue(newValue: T): void {
    this._value = newValue;
    this.notifyObservers();
  }

  /**
   * 批量更新状态（减少通知次数）
   * @param updateFn 更新函数，接收当前值并返回新值
   */
  protected batchUpdate(updateFn: (currentValue: T) => T): void {
    this._value = updateFn(this._value);
    this.notifyObservers();
  }

  /**
   * 注册观察者
   * @param observer 观察者对象
   * @returns 取消订阅函数
   */
  subscribe(observer: StateObserver<T>): () => void {
    this.observers.add(observer);

    // 立即触发一次，同步当前状态
    try {
      observer.onStateChange(this.value);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Observer initial notification error: %{public}s', JSON.stringify(error));
    }

    // 返回取消订阅函数
    return () => {
      this.observers.delete(observer);
    };
  }

  /**
   * 通知所有观察者状态已变化
   */
  private notifyObservers(): void {
    const readonlyValue = this.value;

    this.observers.forEach((observer) => {
      try {
        observer.onStateChange(readonlyValue);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Observer notification error: %{public}s', JSON.stringify(error));
      }
    });

    hilog.debug(DOMAIN, TAG, 'Notified %{public}d observers', this.observers.size);
  }

  /**
   * 获取当前观察者数量（用于调试）
   */
  getObserverCount(): number {
    return this.observers.size;
  }

  /**
   * 子类必须实现：创建只读副本
   * 用于防止外部直接修改状态
   */
  protected abstract createReadonlyCopy(value: T): Readonly<T>;
}
