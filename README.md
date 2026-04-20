# 蟹老板车险CRM V4.0 - 联网版

## 版本信息
- **版本号**: V4.0
- **发布日期**: 2026-04-20
- **类型**: 联网版（支持离线/在线切换）

## 功能特点

### 核心功能（继承自 auto-crm V3.0）
- ✅ 8个数据模块：客户、车辆、车险、非车险、售后、续保提醒、年检提醒、跟进记录
- ✅ 折页显示（每页10条）
- ✅ Excel导出（纯JS生成XLSX，无第三方库）
- ✅ Excel导入（6个模块支持）
- ✅ 年检提醒逻辑（注册日期+10年后开始提醒）
- ✅ 登录页毛玻璃美化
- ✅ 深色侧边栏 + 渐变统计卡片 + 斑马纹表格

### V4.0 新增功能
- ✅ Supabase 云端数据同步
- ✅ 离线/在线一键切换
- ✅ 自动同步状态徽章
- ✅ 断网自动降级到离线模式

## 使用方法

### 离线模式（默认）
- 直接打开 `index.html` 即可使用
- 数据存储在浏览器 localStorage

### 在线模式
1. 点击侧边栏底部的"离线"徽章
2. 系统会连接 Supabase 云端
3. 连接成功后，徽章变绿显示"已同步"
4. 之后所有操作自动同步到云端

### 切换回离线模式
- 再次点击徽章即可切换回离线模式
- 离线模式下数据仍保存在本地

## 云端配置

### Supabase 数据库
- **URL**: https://yjnkbippailouqoqivtv.supabase.co
- **数据表**: customers, vehicles, car_policies, noncar_policies, services, followups

### 数据表结构

#### customers（客户表）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | text | 主键 |
| name | text | 姓名 |
| phone | text | 电话 |
| id_card | text | 身份证 |
| address | text | 地址 |
| remark | text | 备注 |
| created_at | text | 创建时间 |

#### vehicles（车辆表）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | text | 主键 |
| customer_id | text | 客户ID |
| plate | text | 车牌 |
| vin | text | 车架号 |
| brand | text | 品牌 |
| model | text | 型号 |
| reg_date | text | 注册日期 |
| vehicle_type | text | 车辆种类 |
| usage | text | 使用性质 |

#### car_policies（车险保单表）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | text | 主键 |
| customer_id | text | 客户ID |
| vehicle_id | text | 车辆ID |
| company | text | 保险公司 |
| policy_no | text | 保单号 |
| biz_premium | decimal | 商业险保费 |
| compulsory_premium | decimal | 交强险保费 |
| tax_amount | decimal | 车船税 |
| total_premium | decimal | 总保费 |
| commission_amount | decimal | 佣金 |
| start_date | date | 起保日期 |
| end_date | date | 终保日期 |
| status | text | 状态 |

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| V4.0 | 2026-04-20 | 联网版，支持云端同步 |
| V3.0 | 2026-04-20 | 完整版，8模块+折页+Excel导入导出 |
| V2.9 | 2026-04-19 | 线上版，GitHub Pages |
| V2.0 | 2026-04-18 | 基础版，localStorage存储 |

## 本地文件路径
```
file:///C:/Users/58984/.qclaw/workspace/auto-crm-online/index.html
```

## 注意事项
1. 首次使用在线模式需要网络连接
2. 在线模式下，每次操作都会同步到云端
3. 如果网络断开，系统会自动降级到离线模式
4. 数据同时保存在 localStorage 和云端，双重备份

---
*蟹老板车险CRM - 专业的车险客户管理系统*
