/**
 * StateObserver - 状态观察者接口
 *
 * 用于观察状态变化并作出响应
 */

export interface StateObserver<T> {
  /**
   * 当状态发生变化时调用
   * @param newState 新的状态值（只读副本）
   */
  onStateChange(newState: Readonly<T>): void;
}
