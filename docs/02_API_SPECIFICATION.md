# API 规范文档

## 版本信息
- **版本**: V1.0
- **日期**: 2026-04-19
- **作者**: 痞老板
- **基础URL**: `https://your-domain.com/api/v1`

---

## 认证方式

### 登录获取Token
```
POST /auth/login
Content-Type: application/json

Request:
{
  "username": "string",
  "password": "string"
}

Response (200):
{
  "code": 0,
  "message": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 86400,
    "user": {
      "id": "uuid",
      "username": "string",
      "real_name": "string",
      "role": "admin|manager|agent",
      "avatar": "url"
    }
  }
}
```

### 刷新Token
```
POST /auth/refresh
Authorization: Bearer {refresh_token}

Response (200):
{
  "code": 0,
  "data": {
    "token": "new_token",
    "expires_in": 86400
  }
}
```

---

## 通用响应格式

### 成功响应
```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "timestamp": 1713500000000
}
```

### 错误响应
```json
{
  "code": 1001,
  "message": "错误描述",
  "error": {
    "field": "phone",
    "detail": "手机号格式不正确"
  },
  "timestamp": 1713500000000
}
```

### 分页响应
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100,
      "total_pages": 5
    }
  }
}
```

### 错误码说明
| 错误码 | 说明 |
|--------|------|
| 0 | 成功 |
| 1001 | 参数错误 |
| 1002 | 缺少必填参数 |
| 2001 | 未登录 |
| 2002 | 登录过期 |
| 2003 | 无权限 |
| 3001 | 资源不存在 |
| 3002 | 资源已存在 |
| 4001 | 服务器错误 |
| 4002 | 服务暂不可用 |

---

## 客户管理 API

### 创建客户
```
POST /customers
Authorization: Bearer {token}

Request:
{
  "name": "张三",
  "phone": "13312345678",
  "phone_2": "13812345678",
  "id_card": "320123199001011234",
  "gender": "male",
  "province": "江苏省",
  "city": "常州市",
  "district": "金坛区",
  "address": "东环二路焦园村170-1号",
  "tags": ["vip", "高净值"],
  "remark": "备注信息"
}

Response (201):
{
  "code": 0,
  "message": "创建成功",
  "data": {
    "id": "uuid",
    "customer_code": "C2026041900001",
    "name": "张三",
    "phone": "13312345678"
  }
}
```

### 查询客户列表
```
GET /customers
Authorization: Bearer {token}

Query Parameters:
- page: 页码 (默认1)
- page_size: 每页数量 (默认20, 最大100)
- keyword: 关键词搜索 (姓名/手机号)
- status: 客户状态
- level: 客户等级
- tags: 标签 (逗号分隔)
- owner_id: 归属业务员ID
- created_start: 创建时间开始
- created_end: 创建时间结束

Response (200):
{
  "code": 0,
  "data": {
    "list": [
      {
        "id": "uuid",
        "customer_code": "C2026041900001",
        "name": "张三",
        "phone": "133****5678",
        "customer_level": "A级",
        "status": "active",
        "owner_name": "蟹老板",
        "vehicle_count": 2,
        "total_premium": 15000.00,
        "created_at": "2026-04-19T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100,
      "total_pages": 5
    }
  }
}
```

### 获取客户详情
```
GET /customers/{id}
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "data": {
    "id": "uuid",
    "customer_code": "C2026041900001",
    "name": "张三",
    "phone": "13312345678",
    "id_card": "320123199001011234",
    "gender": "male",
    "birthday": "1990-01-01",
    "province": "江苏省",
    "city": "常州市",
    "district": "金坛区",
    "address": "东环二路焦园村170-1号",
    "source_from": "walk_in",
    "tags": ["vip"],
    "customer_level": "A级",
    "status": "active",
    "owner_id": "uuid",
    "owner_name": "蟹老板",
    "created_at": "2026-04-19T10:00:00Z",
    "updated_at": "2026-04-19T10:00:00Z",
    
    "vehicles": [
      {
        "id": "uuid",
        "plate_number": "苏D12345",
        "brand": "大众",
        "model": "帕萨特",
        "annual_review_date": "2026-05-01",
        "compulsory_insurance_date": "2026-06-01"
      }
    ],
    
    "policies": {
      "car_insurance": [...],
      "noncar_insurance": [...]
    },
    
    "services": {
      "maintenance": [...],
      "annual_review": [...]
    },
    
    "followups": [...]
  }
}
```

### 更新客户
```
PUT /customers/{id}
Authorization: Bearer {token}

Request:
{
  "name": "张三",
  "phone": "13312345678",
  "tags": ["vip", "高净值", "老客户"]
}

Response (200):
{
  "code": 0,
  "message": "更新成功"
}
```

### 删除客户（软删除）
```
DELETE /customers/{id}
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "message": "删除成功"
}
```

---

## 车辆管理 API

### 添加车辆
```
POST /vehicles
Authorization: Bearer {token}

Request:
{
  "customer_id": "uuid",
  "plate_number": "苏D12345",
  "vin": "LSVAB4189DC123456",
  "engine_number": "ABC123456",
  "brand": "大众",
  "model": "帕萨特",
  "sub_model": "2023款 330TSI 豪华版",
  "color": "黑色",
  "register_date": "2023-01-01",
  "fuel_type": "汽油",
  "exhaust_capacity": 2.0,
  "seat_count": 5,
  "annual_review_date": "2026-01-01",
  "compulsory_insurance_date": "2026-06-01",
  "commercial_insurance_date": "2026-06-01"
}

Response (201):
{
  "code": 0,
  "message": "添加成功",
  "data": {
    "id": "uuid",
    "plate_number": "苏D12345"
  }
}
```

### 查询客户车辆列表
```
GET /customers/{customer_id}/vehicles
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "data": [
    {
      "id": "uuid",
      "plate_number": "苏D12345",
      "brand": "大众",
      "model": "帕萨特",
      "vin": "LSVAB4189DC123456",
      "annual_review_date": "2026-05-01",
      "insurance_status": "effective",
      "last_policy": {
        "policy_number": "PDAA20261234567890",
        "end_date": "2026-06-01",
        "insurance_company": "平安保险"
      }
    }
  ]
}
```

---

## 车险管理 API

### 创建车险保单
```
POST /car-insurance
Authorization: Bearer {token}

Request:
{
  "customer_id": "uuid",
  "vehicle_id": "uuid",
  "policy_number": "PDAA20261234567890",
  "insurance_company": "平安保险",
  "start_date": "2026-04-20",
  "end_date": "2027-04-19",
  "coverage_types": [
    {
      "type": "第三方责任险",
      "amount": 1000000,
      "premium": 1250.00
    },
    {
      "type": "车辆损失险",
      "amount": 200000,
      "premium": 2500.00
    },
    {
      "type": "不计免赔",
      "amount": 0,
      "premium": 562.50
    }
  ],
  "total_premium": 4312.50,
  "compulsory_premium": 950.00,
  "commercial_premium": 3362.50,
  "commission_rate": 0.15,
  "commission_amount": 646.88,
  "payment_method": "wechat",
  "payment_status": "paid",
  "source": "renewal",
  "remark": "续保客户"
}

Response (201):
{
  "code": 0,
  "message": "创建成功",
  "data": {
    "id": "uuid",
    "policy_number": "PDAA20261234567890"
  }
}
```

### 查询车险保单列表
```
GET /car-insurance
Authorization: Bearer {token}

Query Parameters:
- page: 页码
- page_size: 每页数量
- customer_id: 客户ID
- vehicle_id: 车辆ID
- insurance_company: 保险公司
- policy_status: 保单状态
- renewal_status: 续保状态
- start_date_start: 生效日期开始
- start_date_end: 生效日期结束
- expiring_days: 即将到期天数 (如30)

Response (200):
{
  "code": 0,
  "data": {
    "list": [
      {
        "id": "uuid",
        "policy_number": "PDAA20261234567890",
        "customer_name": "张三",
        "plate_number": "苏D12345",
        "insurance_company": "平安保险",
        "start_date": "2026-04-20",
        "end_date": "2027-04-19",
        "total_premium": 4312.50,
        "policy_status": "effective",
        "renewal_status": "pending",
        "days_to_expire": 365
      }
    ],
    "pagination": {...}
  }
}
```

### 获取保单详情
```
GET /car-insurance/{id}
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "data": {
    "id": "uuid",
    "policy_number": "PDAA20261234567890",
    "customer": {
      "id": "uuid",
      "name": "张三",
      "phone": "13312345678"
    },
    "vehicle": {
      "id": "uuid",
      "plate_number": "苏D12345",
      "brand": "大众",
      "model": "帕萨特",
      "vin": "LSVAB4189DC123456"
    },
    "insurance_company": "平安保险",
    "start_date": "2026-04-20",
    "end_date": "2027-04-19",
    "coverage_types": [...],
    "total_premium": 4312.50,
    "compulsory_premium": 950.00,
    "commercial_premium": 3362.50,
    "commission_rate": 0.15,
    "commission_amount": 646.88,
    "commission_status": "settled",
    "payment_status": "paid",
    "policy_status": "effective",
    "renewal_status": "pending",
    "created_at": "2026-04-19T10:00:00Z",
    "claims": [
      {
        "id": "uuid",
        "claim_number": "CL2026041900001",
        "accident_date": "2026-04-15",
        "claim_amount": 5000.00,
        "claim_status": "paid"
      }
    ]
  }
}
```

### 更新续保状态
```
PATCH /car-insurance/{id}/renewal-status
Authorization: Bearer {token}

Request:
{
  "renewal_status": "renewed",
  "new_policy_id": "uuid"
}

Response (200):
{
  "code": 0,
  "message": "更新成功"
}
```

---

## 非车险管理 API

### 创建非车险保单
```
POST /noncar-insurance
Authorization: Bearer {token}

Request:
{
  "customer_id": "uuid",
  "policy_number": "FA2026041900001",
  "insurance_company": "太平洋保险",
  "insurance_type": "意外险",
  "product_name": "驾乘人员意外险",
  "start_date": "2026-04-20",
  "end_date": "2027-04-19",
  "total_premium": 500.00,
  "sum_insured": 500000.00,
  "commission_rate": 0.20,
  "commission_amount": 100.00,
  "related_car_policy_id": "uuid",
  "payment_status": "paid"
}

Response (201):
{
  "code": 0,
  "message": "创建成功"
}
```

### 查询非车险列表
```
GET /noncar-insurance
Authorization: Bearer {token}

Query Parameters:
- page: 页码
- page_size: 每页数量
- customer_id: 客户ID
- insurance_type: 险种类型
- insurance_company: 保险公司
- expiring_days: 即将到期天数

Response (200):
{
  "code": 0,
  "data": {
    "list": [...],
    "pagination": {...}
  }
}
```

---

## 年审保养 API

### 创建保养记录
```
POST /maintenance
Authorization: Bearer {token}

Request:
{
  "customer_id": "uuid",
  "vehicle_id": "uuid",
  "service_type": "小保养",
  "service_date": "2026-04-15",
  "mileage": 50000,
  "items": [
    {
      "name": "更换机油",
      "brand": "壳牌",
      "spec": "5W-30",
      "quantity": 1,
      "price": 350.00
    },
    {
      "name": "更换机滤",
      "brand": "马勒",
      "quantity": 1,
      "price": 80.00
    }
  ],
  "total_amount": 430.00,
  "service_provider": "某某修理厂",
  "technician": "李师傅",
  "next_maintenance_mileage": 55000,
  "next_maintenance_date": "2026-10-15"
}

Response (201):
{
  "code": 0,
  "message": "创建成功"
}
```

### 查询保养记录
```
GET /maintenance
Authorization: Bearer {token}

Query Parameters:
- page: 页码
- page_size: 每页数量
- customer_id: 客户ID
- vehicle_id: 车辆ID
- service_type: 服务类型
- service_date_start: 服务日期开始
- service_date_end: 服务日期结束

Response (200):
{
  "code": 0,
  "data": {
    "list": [
      {
        "id": "uuid",
        "customer_name": "张三",
        "plate_number": "苏D12345",
        "service_type": "小保养",
        "service_date": "2026-04-15",
        "mileage": 50000,
        "total_amount": 430.00,
        "service_provider": "某某修理厂"
      }
    ],
    "pagination": {...}
  }
}
```

### 年审提醒列表
```
GET /annual-review/reminders
Authorization: Bearer {token}

Query Parameters:
- days: 提前提醒天数 (默认30)

Response (200):
{
  "code": 0,
  "data": [
    {
      "id": "uuid",
      "customer_name": "张三",
      "phone": "13312345678",
      "plate_number": "苏D12345",
      "annual_review_date": "2026-05-01",
      "days_to_expire": 12,
      "reminder_count": 2,
      "last_reminder_date": "2026-04-25"
    }
  ]
}
```

---

## 后市场 API

### 创建后市场订单
```
POST /aftermarket/orders
Authorization: Bearer {token}

Request (违章查询):
{
  "customer_id": "uuid",
  "vehicle_id": "uuid",
  "order_type": "violation_query",
  "service_items": [
    {
      "name": "违章查询",
      "quantity": 1,
      "price": 30.00
    }
  ],
  "total_amount": 30.00
}

Request (道路救援):
{
  "customer_id": "uuid",
  "vehicle_id": "uuid",
  "order_type": "road_rescue",
  "service_items": [
    {
      "name": "拖车服务",
      "distance": 20,
      "price": 200.00
    }
  ],
  "total_amount": 200.00,
  "rescue_location": "G25高速某处"
}

Response (201):
{
  "code": 0,
  "message": "创建成功",
  "data": {
    "id": "uuid",
    "order_number": "A2026041900001"
  }
}
```

---

## 金融管理 API

### 创建车贷合同
```
POST /finance/contracts
Authorization: Bearer {token}

Request:
{
  "customer_id": "uuid",
  "vehicle_id": "uuid",
  "contract_number": "F2026041900001",
  "loan_type": "bank_loan",
  "lender_name": "工商银行",
  "contract_date": "2026-04-19",
  "loan_amount": 100000.00,
  "loan_term": 36,
  "annual_rate": 0.0495,
  "monthly_payment": 2976.00,
  "total_interest": 7136.00,
  "handling_fee": 3000.00,
  "first_repayment_date": "2026-05-19",
  "repayment_day": 19,
  "down_payment": 50000.00,
  "vehicle_price": 150000.00
}

Response (201):
{
  "code": 0,
  "message": "创建成功"
}
```

### 还款记录列表
```
GET /finance/contracts/{contract_id}/repayments
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "data": [
    {
      "id": "uuid",
      "period_number": 1,
      "due_date": "2026-05-19",
      "principal": 2560.50,
      "interest": 415.50,
      "total_payment": 2976.00,
      "actual_payment_date": "2026-05-19",
      "repayment_status": "paid"
    },
    {
      "id": "uuid",
      "period_number": 2,
      "due_date": "2026-06-19",
      "principal": 2571.18,
      "interest": 404.82,
      "total_payment": 2976.00,
      "repayment_status": "pending"
    }
  ]
}
```

### 更新还款状态
```
PATCH /finance/repayments/{id}
Authorization: Bearer {token}

Request:
{
  "repayment_status": "paid",
  "actual_payment_date": "2026-06-19",
  "actual_payment": 2976.00
}

Response (200):
{
  "code": 0,
  "message": "更新成功"
}
```

---

## 跟进管理 API

### 创建跟进记录
```
POST /followups
Authorization: Bearer {token}

Request:
{
  "customer_id": "uuid",
  "vehicle_id": "uuid",
  "related_policy_id": "uuid",
  "followup_type": "电话",
  "content": "客户表示价格有点高，考虑中",
  "customer_intent": "medium",
  "next_followup_date": "2026-04-25",
  "next_plan": "再次联系，争取优惠"
}

Response (201):
{
  "code": 0,
  "message": "创建成功"
}
```

### 查询跟进记录
```
GET /followups
Authorization: Bearer {token}

Query Parameters:
- page: 页码
- page_size: 每页数量
- customer_id: 客户ID
- owner_id: 归属人ID
- followup_type: 跟进类型
- start_date: 开始日期
- end_date: 结束日期

Response (200):
{
  "code": 0,
  "data": {
    "list": [
      {
        "id": "uuid",
        "customer_name": "张三",
        "plate_number": "苏D12345",
        "followup_type": "电话",
        "content": "客户表示价格有点高，考虑中",
        "customer_intent": "medium",
        "next_followup_date": "2026-04-25",
        "created_at": "2026-04-19T10:00:00Z"
      }
    ],
    "pagination": {...}
  }
}
```

### 待跟进列表（今日待办）
```
GET /followups/pending
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "data": [
    {
      "id": "uuid",
      "customer_name": "张三",
      "phone": "13312345678",
      "plate_number": "苏D12345",
      "followup_type": "电话",
      "next_followup_date": "2026-04-19",
      "followup_purpose": "续保跟进",
      "last_followup_content": "客户表示价格有点高，考虑中"
    }
  ]
}
```

---

## 统计报表 API

### 客户统计
```
GET /stats/customers
Authorization: Bearer {token}

Query Parameters:
- start_date: 开始日期
- end_date: 结束日期
- group_by: 分组维度 (day/week/month)

Response (200):
{
  "code": 0,
  "data": {
    "total": 1000,
    "new_today": 10,
    "new_this_month": 200,
    "active": 800,
    "inactive": 150,
    "lost": 50,
    "trend": [
      {"date": "2026-04-01", "new": 5, "active": 780},
      {"date": "2026-04-02", "new": 8, "active": 785}
    ]
  }
}
```

### 保险业绩统计
```
GET /stats/insurance
Authorization: Bearer {token}

Query Parameters:
- start_date: 开始日期
- end_date: 结束日期
- owner_id: 业务员ID (可选)
- type: 类型 (car/noncar)

Response (200):
{
  "code": 0,
  "data": {
    "total_policies": 500,
    "total_premium": 5000000.00,
    "total_commission": 750000.00,
    "new_policies": 100,
    "new_premium": 1000000.00,
    "renewal_policies": 400,
    "renewal_premium": 4000000.00,
    "renewal_rate": 0.85,
    "by_company": [
      {"name": "平安保险", "count": 150, "premium": 1500000.00},
      {"name": "太平洋保险", "count": 120, "premium": 1200000.00}
    ],
    "trend": [
      {"month": "2026-01", "policies": 50, "premium": 500000.00},
      {"month": "2026-02", "policies": 60, "premium": 600000.00}
    ]
  }
}
```

### 业务员业绩排名
```
GET /stats/agents/ranking
Authorization: Bearer {token}

Query Parameters:
- start_date: 开始日期
- end_date: 结束日期
- sort_by: 排序字段 (premium/commission/policies)
- limit: 返回数量

Response (200):
{
  "code": 0,
  "data": [
    {
      "rank": 1,
      "agent_id": "uuid",
      "agent_name": "蟹老板",
      "policies": 50,
      "premium": 500000.00,
      "commission": 75000.00,
      "renewal_rate": 0.85
    },
    {
      "rank": 2,
      "agent_id": "uuid",
      "agent_name": "小李",
      "policies": 45,
      "premium": 450000.00,
      "commission": 67500.00,
      "renewal_rate": 0.82
    }
  ]
}
```

### 仪表盘数据
```
GET /dashboard
Authorization: Bearer {token}

Response (200):
{
  "code": 0,
  "data": {
    "today": {
      "new_customers": 5,
      "new_policies": 3,
      "new_premium": 12000.00,
      "new_commission": 1800.00
    },
    "this_month": {
      "new_customers": 50,
      "new_policies": 30,
      "new_premium": 300000.00,
      "new_commission": 45000.00
    },
    "expiring": {
      "policies_30_days": 20,
      "policies_7_days": 5,
      "annual_review_30_days": 10
    },
    "pending": {
      "followups_today": 15,
      "renewal_intent": 8,
      "claims_processing": 2
    },
    "performance": {
      "monthly_target": 1000000.00,
      "monthly_achieved": 650000.00,
      "achievement_rate": 0.65
    }
  }
}
```

---

## 文件上传 API

### 上传客户证件
```
POST /upload
Authorization: Bearer {token}
Content-Type: multipart/form-data

Form Data:
- file: 文件
- type: 文件类型 (id_card_front/id_card_back/drivers_license/vehicle_photo/other)
- customer_id: 客户ID (可选)

Response (200):
{
  "code": 0,
  "data": {
    "url": "https://cdn.example.com/uploads/xxx.jpg",
    "filename": "xxx.jpg",
    "size": 102400,
    "width": 800,
    "height": 600
  }
}
```

---

## WebSocket 实时推送

### 连接方式
```
wss://your-domain.com/ws?token={jwt_token}
```

### 消息格式
```json
{
  "type": "event_type",
  "data": {},
  "timestamp": 1713500000000
}
```

### 推送事件类型
| 事件类型 | 说明 | data |
|---------|------|------|
| new_customer | 新建客户 | 客户信息 |
| new_policy | 新建保单 | 保单信息 |
| policy_expiring | 保单即将到期提醒 | 保单信息 |
| followup_reminder | 跟进提醒 | 跟进信息 |
| claim_update | 理赔状态更新 | 理赔信息 |
| message | 系统消息 | 消息内容 |

---

## 附录

### 支持的险种类型
```json
[
  "交强险",
  "第三方责任险",
  "车辆损失险",
  "全车盗抢险",
  "司机座位险",
  "乘客座位险",
  "玻璃破碎险",
  "自燃损失险",
  "车身划痕险",
  "发动机涉水险",
  "不计免赔险"
]
```

### 支持的非车险类型
```json
[
  "意外险",
  "健康险",
  "医疗险",
  "重疾险",
  "防癌险",
  "家财险",
  "责任险",
  "雇主责任险",
  "公众责任险",
  "旅游险",
  "宠物险"
]
```

### 客户来源
```json
[
  "自然增长",
  "转介绍",
  "电话营销",
  "网络推广",
  "合作渠道",
  "老客户复购",
  "其他"
]
```
