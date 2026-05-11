# 跨层思考指南

> **目的**：实现前想清楚跨 layers 的数据流。

---

## 问题

**大多数 bug 发生在 layer 边界**，而不是 layer 内部。

常见 cross-layer bugs：
- API 返回格式 A，frontend 期望格式 B
- Database 存储 X，service 转换为 Y，但丢失数据
- 多个 layers 以不同方式实现同一逻辑

---

## 实现 Cross-Layer 功能前

### 第 1 步：绘制数据流

画出数据如何移动：

```
Source → Transform → Store → Retrieve → Transform → Display
```

对每个箭头提问：
- 数据是什么格式？
- 可能出什么错？
- 谁负责 validation？

### 第 2 步：识别边界

| 边界 | 常见问题 |
|----------|---------------|
| API ↔ Service | 类型不匹配、字段缺失 |
| Service ↔ Database | 格式转换、null 处理 |
| Backend ↔ Frontend | 序列化、日期格式 |
| Component ↔ Component | Props shape 变化 |

### 第 3 步：定义契约

对每个边界：
- 精确输入格式是什么？
- 精确输出格式是什么？
- 可能发生哪些错误？

---

## 常见 Cross-Layer 错误

### 错误 1：隐式格式假设

**Bad**：不检查就假设日期格式

**Good**：在边界显式格式转换

### 错误 2：分散的 validation

**Bad**：在多个 layers 验证同一件事

**Good**：在入口点验证一次

### 错误 3：泄漏的抽象

**Bad**：Component 知道 database schema

**Good**：每个 layer 只知道相邻 layers

---

## Cross-Layer 功能检查清单

实现前：
- [ ] 已绘制完整数据流
- [ ] 已识别所有 layer boundaries
- [ ] 已定义每个边界的格式
- [ ] 已决定 validation 发生在哪里

实现后：
- [ ] 用 edge cases（null、empty、invalid）测试
- [ ] 验证每个边界的 error handling
- [ ] 检查数据能通过 round-trip 保持不丢失

---

## 何时创建 Flow 文档

在以下情况创建详细 flow docs：
- 功能跨 3+ layers
- 涉及多个团队
- 数据格式复杂
- 该功能以前引发过 bugs
