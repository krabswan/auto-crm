-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema V1.0
-- 数据库：Supabase PostgreSQL
-- 创建时间：2026-04-19
-- 作者：痞老板
-- ============================================================

-- ============================================================
-- 1. 基础工具函数
-- ============================================================

-- 创建UUID扩展（如不存在）
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 2. 枚举类型定义
-- ============================================================

-- 用户角色
CREATE TYPE user_role AS ENUM (
    'super_admin',    -- 超级管理员
    'admin',          -- 管理员
    'manager',        -- 经理
    'agent',          -- 业务员
    'viewer'          -- 查看者
);

-- 客户类型
CREATE TYPE customer_type AS ENUM (
    'individual',     -- 个人
    'enterprise'      -- 企业
);

-- 客户来源
CREATE TYPE customer_source AS ENUM (
    'self_develop',   -- 自开拓
    'referral',       -- 转介绍
    'platform',       -- 平台获客
    'renewal',        -- 续保客户
    'other'           -- 其他
);

-- 客户状态
CREATE TYPE customer_status AS ENUM (
    'active',         -- 活跃
    'inactive',       -- 不活跃
    'lost'            -- 流失
);

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM (
    'normal',         -- 正常
    'transferring',   -- 过户中
    'scrapped',       -- 报废
    'missing'         -- 失联
);

-- 车险状态
CREATE TYPE car_policy_status AS ENUM (
    'pending',        -- 待生效
    'active',         -- 生效中
    'expired',        -- 已过期
    'cancelled',      -- 已退保
    'claims'          -- 理赔中
);

-- 非车险状态
CREATE TYPE noncar_policy_status AS ENUM (
    'pending',
    'active',
    'expired',
    'cancelled',
    'claims'
);

-- 险种类型
CREATE TYPE insurance_category AS ENUM (
    'compulsory',     -- 交强险
    'commercial',     -- 商业险
    'liability',     -- 责任险
    'accident',       -- 意外险
    'health',         -- 健康险
    'property',       -- 家财险
    'theft',          -- 盗抢险
    'glass',          -- 玻璃险
    'driver',         -- 司机险
    'passenger',      -- 乘客险
    'other'           -- 其他
);

-- 年审状态
CREATE TYPE inspection_status AS ENUM (
    'not_due',        -- 未到期
    'due_soon',       -- 即将到期（30天内）
    'overdue',        -- 已过期
    'passed'          -- 已通过
);

-- 保养状态
CREATE TYPE maintenance_status AS ENUM (
    'scheduled',      -- 已预约
    'in_progress',    -- 进行中
    'completed',      -- 已完成
    'cancelled'       -- 已取消
);

-- 保养类型
CREATE TYPE maintenance_type AS ENUM (
    'regular',        -- 常规保养
    'repair',         -- 维修
    'body_work',     -- 钣金喷漆
    'tires',          -- 轮胎
    'battery',        -- 电瓶
    'brake',          -- 刹车
    'ac',             -- 空调
    'other'           -- 其他
);

-- 后市场订单状态
CREATE TYPE aftermarket_status AS ENUM (
    'pending',        -- 待处理
    'confirmed',      -- 已确认
    'in_progress',    -- 进行中
    'completed',      -- 已完成
    'cancelled'       -- 已取消
);

-- 后市场服务类型
CREATE TYPE aftermarket_type AS ENUM (
    'violation',      -- 违章处理
    'rescue',         -- 道路救援
    'beauty',         -- 美容洗车
    'modification',   -- 改装
    'parts',          -- 配件供应
    'rental',         -- 租赁
    'parking',        -- 停车
    'other'           -- 其他
);

-- 金融合同状态
CREATE TYPE finance_status AS ENUM (
    'pending',        -- 待审批
    'approved',       -- 已批准
    'rejected',       -- 已拒绝
    'active',         -- 还款中
    'completed',      -- 已结清
    'default'          -- 违约
);

-- 理赔状态
CREATE TYPE claim_status AS ENUM (
    'reported',       -- 已报案
    'surveying',      -- 查勘中
    'assessing',      -- 定损中
    'approved',       -- 已审批
    'settled',        -- 已结案
    'rejected'        -- 已拒赔
);

-- 操作类型（审计日志）
CREATE TYPE operation_type AS ENUM (
    'create',
    'read',
    'update',
    'delete',
    'restore',
    'export',
    'login',
    'logout'
);

-- ============================================================
-- 3. 用户和认证相关表
-- ============================================================

-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE,
    phone TEXT UNIQUE,
    password_hash TEXT,
    real_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'agent',
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    CONSTRAINT users_email_check CHECK (
        (email IS NOT NULL AND email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        OR email IS NULL
    ),
    CONSTRAINT users_phone_check CHECK (
        (phone IS NOT NULL AND phone ~ '^1[3-9]\d{9}$')
        OR phone IS NULL
    )
);

-- 用户会话表
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    device_info TEXT,
    ip_address INET,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_revoked BOOLEAN DEFAULT FALSE
);

-- 角色权限表
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role user_role NOT NULL,
    resource TEXT NOT NULL,          -- 资源名称，如 'customers', 'car_policies'
    action TEXT NOT NULL,            -- 操作，如 'create', 'read', 'update', 'delete'
    is_allowed BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role, resource, action)
);

-- ============================================================
-- 4. 核心客户中心
-- ============================================================

-- 客户主表
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_code TEXT UNIQUE NOT NULL,  -- 客户编号，如 'CUST-2026-00001'
    
    -- 基本信息
    name TEXT NOT NULL,
    customer_type customer_type DEFAULT 'individual',
    id_card TEXT,                          -- 身份证号（加密存储）
    phone TEXT NOT NULL,
    phone_2 TEXT,                          -- 备用电话
    email TEXT,
    wechat TEXT,                           -- 微信号
    qq TEXT,
    
    -- 地址信息
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    
    -- 统计信息
    customer_type_attr customer_source DEFAULT 'self_develop',  -- 来源
    status customer_status DEFAULT 'active',
    total_policies INTEGER DEFAULT 0,      -- 累计保单数
    total_premium DECIMAL(12,2) DEFAULT 0,  -- 累计保费
    total_commission DECIMAL(12,2) DEFAULT 0,  -- 累计佣金
    total_services INTEGER DEFAULT 0,     -- 累计服务次数
    
    -- 客户经理
    assigned_user_id UUID REFERENCES users(id),
    assigned_at TIMESTAMPTZ,
    
    -- 标签
    tags TEXT[],                          -- JSON数组，如 ['vip', 'high_value']
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    
    -- 约束
    CONSTRAINT customers_phone_check CHECK (phone ~ '^1[3-9]\d{9}$'),
    CONSTRAINT customers_id_card_check CHECK (
        id_card IS NULL OR length(id_card) = 18
    )
);

-- 客户车辆表
CREATE TABLE customer_vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_code TEXT UNIQUE NOT NULL,   -- 车辆编号，如 'VEH-00001'
    
    -- 车辆信息
    plate_number TEXT NOT NULL,           -- 车牌号
    vehicle_type TEXT,                    -- 车辆类型：轿车/SUV/卡车等
    brand TEXT,                          -- 品牌
    model TEXT,                          -- 型号
    color TEXT,                          -- 颜色
    vin TEXT NOT NULL,                    -- VIN码
    engine_no TEXT,                      -- 发动机号
    registration_date DATE,              -- 注册日期
    issue_date DATE,                      -- 发证日期
    fuel_type TEXT,                      -- 燃料类型
    emission_standard TEXT,              -- 排放标准
    rated_passengers INTEGER,             -- 核定载客数
    gross_mass DECIMAL(10,2),            -- 总质量
    curb_weight DECIMAL(10,2),           -- 整备质量
    
    -- 年审信息
    inspection_expire DATE,              -- 年审到期日期
    inspection_status inspection_status DEFAULT 'not_due',
    inspection_count INTEGER DEFAULT 0,  -- 年审次数
    
    -- 交强险信息
    compulsory_insurance_expire DATE,    -- 交强险到期
    compulsory_insurance_company TEXT,   -- 交强险公司
    
    -- 状态
    status vehicle_status DEFAULT 'normal',
    is_default BOOLEAN DEFAULT FALSE,     -- 是否默认车辆
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    
    -- 约束
    CONSTRAINT vehicles_plate_unique UNIQUE (customer_id, plate_number),
    CONSTRAINT vehicles_vin_unique UNIQUE (vin)
);

-- ============================================================
-- 5. 车险管理模块
-- ============================================================

-- 车险保单表
CREATE TABLE car_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    policy_code TEXT UNIQUE NOT NULL,     -- 保单号
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES customer_vehicles(id),
    
    -- 保险公司信息
    insurance_company TEXT NOT NULL,      -- 承保公司
    insurance_company_code TEXT,          -- 公司代码
    
    -- 基本信息
    policy_no TEXT NOT NULL,             -- 保单号
    policy_type TEXT,                    -- 保单类型
    coverage_start DATE NOT NULL,         -- 生效日期
    coverage_end DATE NOT NULL,          -- 到期日期
    
    -- 险种信息
    compulsory_premium DECIMAL(10,2),     -- 交强险保费
    compulsory_coverage DECIMAL(12,2),   -- 交强险保额
    commercial_premium DECIMAL(10,2),   -- 商业险保费
    commercial_coverage DECIMAL(12,2),   -- 商业险保额
    total_premium DECIMAL(10,2) NOT NULL,  -- 总保费
    
    -- 险种明细（JSON格式存储复杂结构）
    coverage_details JSONB,              -- 如：{"第三方责任": {"premium": 1000, "coverage": 1000000}}
    
    -- 佣金信息
    commission_rate DECIMAL(5,4),        -- 佣金比例
    commission_amount DECIMAL(10,2),    -- 佣金金额
    actual_commission DECIMAL(10,2),    -- 实际佣金
    commission_received BOOLEAN DEFAULT FALSE,
    
    -- 状态
    status car_policy_status DEFAULT 'active',
    renewal_reminder_sent BOOLEAN DEFAULT FALSE,
    
    -- 来源
    is_renewal BOOLEAN DEFAULT FALSE,    -- 是否续保
    previous_policy_id UUID REFERENCES car_policies(id),
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    
    -- 约束
    CONSTRAINT policies_premium_positive CHECK (total_premium >= 0)
);

-- 车险理赔表
CREATE TABLE car_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_code TEXT UNIQUE NOT NULL,     -- 理赔编号
    
    -- 关联信息
    policy_id UUID NOT NULL REFERENCES car_policies(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES customer_vehicles(id),
    
    -- 报案信息
    report_no TEXT,                      -- 报案号
    accident_time TIMESTAMPTZ,           -- 事故时间
    accident_location TEXT,              -- 事故地点
    accident_description TEXT,           -- 事故描述
    accident_type TEXT,                  -- 事故类型
    
    -- 损失信息
    damage_description TEXT,             -- 损失情况
    estimated_damage DECIMAL(12,2),     -- 估损金额
    actual_damage DECIMAL(12,2),        -- 实损金额
    deductible DECIMAL(10,2),           -- 免赔额
    
    -- 理赔进度
    status claim_status DEFAULT 'reported',
    claim_amount DECIMAL(12,2),         -- 理赔金额
    settled_amount DECIMAL(12,2),       -- 已结金额
    settled_time TIMESTAMPTZ,            -- 结案时间
    
    -- 责任人
    responsible_party TEXT,              -- 责任方
    liability_ratio DECIMAL(5,4),       -- 责任比例
    
    -- 维修信息
    repair_shop TEXT,                    -- 维修厂
    repair_start_date DATE,
    repair_end_date DATE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- ============================================================
-- 6. 非车险管理模块
-- ============================================================

-- 非车险保单表
CREATE TABLE noncar_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    policy_code TEXT UNIQUE NOT NULL,
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 关联车险（可选）
    related_car_policy_id UUID REFERENCES car_policies(id),
    
    -- 保险公司信息
    insurance_company TEXT NOT NULL,
    insurance_company_code TEXT,
    
    -- 基本信息
    policy_no TEXT NOT NULL,
    policy_type TEXT NOT NULL,           -- 险种类型
    category insurance_category NOT NULL,
    coverage_start DATE NOT NULL,
    coverage_end DATE NOT NULL,
    
    -- 投保人/被保险人
    policy_holder TEXT,                  -- 投保人
    insured_name TEXT,                   -- 被保险人
    insured_id_card TEXT,                -- 被保险人身份证
    insured_phone TEXT,                  -- 被保险人电话
    
    -- 保险信息
    premium DECIMAL(10,2) NOT NULL,
    coverage_amount DECIMAL(12,2),       -- 保额
    policy_details JSONB,                -- 详细条款
    
    -- 佣金
    commission_rate DECIMAL(5,4),
    commission_amount DECIMAL(10,2),
    actual_commission DECIMAL(10,2),
    commission_received BOOLEAN DEFAULT FALSE,
    
    -- 状态
    status noncar_policy_status DEFAULT 'active',
    renewal_reminder_sent BOOLEAN DEFAULT FALSE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- 非车险理赔表
CREATE TABLE noncar_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_code TEXT UNIQUE NOT NULL,
    
    policy_id UUID NOT NULL REFERENCES noncar_policies(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    report_no TEXT,
    accident_time TIMESTAMPTZ,
    accident_description TEXT,
    
    status claim_status DEFAULT 'reported',
    claim_amount DECIMAL(12,2),
    settled_amount DECIMAL(12,2),
    settled_time TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- ============================================================
-- 7. 年审保养模块
-- ============================================================

-- 年审记录表
CREATE TABLE vehicle_inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inspection_code TEXT UNIQUE NOT NULL,
    
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES customer_vehicles(id),
    
    -- 年审信息
    inspection_type TEXT NOT NULL,       -- 年审类型：上线年检/免检
    inspection_date DATE NOT NULL,       -- 年审日期
    expire_date DATE NOT NULL,           -- 到期日期
    status inspection_status DEFAULT 'not_due',
    
    -- 检测结果
    result TEXT,                          -- 合格/不合格
    result_details JSONB,                 -- 详细结果
    certificate_no TEXT,                  -- 合格证编号
    
    -- 费用
    inspection_fee DECIMAL(10,2),
    service_fee DECIMAL(10,2),           -- 服务费
    total_fee DECIMAL(10,2),
    
    -- 办理机构
    inspection_org TEXT,                  -- 检测站
    inspection_address TEXT,
    
    -- 提醒
    reminder_30d_sent BOOLEAN DEFAULT FALSE,
    reminder_7d_sent BOOLEAN DEFAULT FALSE,
    reminder_1d_sent BOOLEAN DEFAULT FALSE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- 保养记录表
CREATE TABLE maintenance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    maintenance_code TEXT UNIQUE NOT NULL,
    
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES customer_vehicles(id),
    
    -- 保养信息
    maintenance_type maintenance_type NOT NULL,
    maintenance_date DATE NOT NULL,
    next_maintenance_date DATE,
    next_maintenance_mileage INTEGER,
    
    -- 状态
    status maintenance_status DEFAULT 'completed',
    
    -- 车辆状态
    current_mileage INTEGER,             -- 当前里程
    fuel_level DECIMAL(4,2),             -- 油量百分比
    
    -- 项目和费用
    items JSONB,                          -- 保养项目列表
    parts_used JSONB,                    -- 使用的配件
    labor_hours DECIMAL(6,2),            -- 工时
    parts_cost DECIMAL(10,2),            -- 配件费
    labor_cost DECIMAL(10,2),            -- 工时费
    total_cost DECIMAL(10,2),
    
    -- 服务商
    service_provider TEXT,                -- 服务商名称
    service_provider_id UUID,            -- 服务商ID（关联维修厂表）
    mechanic_name TEXT,                  -- 维修技师
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- ============================================================
-- 8. 汽车后市场模块
-- ============================================================

-- 后市场服务订单表
CREATE TABLE aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_code TEXT UNIQUE NOT NULL,
    
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES customer_vehicles(id),
    
    -- 订单信息
    service_type aftermarket_type NOT NULL,
    service_items JSONB,                 -- 服务明细
    order_date TIMESTAMPTZ DEFAULT NOW(),
    scheduled_date DATE,
    completed_date DATE,
    
    -- 状态
    status aftermarket_status DEFAULT 'pending',
    
    -- 费用
    service_fee DECIMAL(10,2),
    parts_fee DECIMAL(10,2),
    total_fee DECIMAL(10,2),
    discount_amount DECIMAL(10,2) DEFAULT 0,
    actual_amount DECIMAL(10,2),         -- 实付金额
    
    -- 支付信息
    payment_method TEXT,
    payment_status TEXT DEFAULT 'unpaid',
    paid_at TIMESTAMPTZ,
    
    -- 服务商
    service_provider TEXT,
    service_address TEXT,
    contact_person TEXT,
    contact_phone TEXT,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- 维修厂/服务商表
CREATE TABLE service_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_code TEXT UNIQUE NOT NULL,
    
    name TEXT NOT NULL,
    provider_type TEXT NOT NULL,         -- 类型：维修厂/救援公司/配件商
    business_license TEXT,               -- 营业执照
    contact_person TEXT,
    contact_phone TEXT,
    
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    
    services TEXT[],                     -- 提供服务列表
    brands TEXT[],                       -- 合作品牌
    
    rating DECIMAL(2,1),                 -- 评分
    review_count INTEGER DEFAULT 0,
    
    business_hours TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    remark TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- ============================================================
-- 9. 汽车消费金融模块
-- ============================================================

-- 金融合同表
CREATE TABLE finance_contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_code TEXT UNIQUE NOT NULL,
    
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES customer_vehicles(id),
    
    -- 合同信息
    contract_type TEXT NOT NULL,         -- 贷款/分期/担保
    finance_type TEXT NOT NULL,          -- 购车贷/信用贷/抵押贷
    
    -- 金额
    loan_amount DECIMAL(12,2) NOT NULL,  -- 贷款金额
    loan_term INTEGER NOT NULL,          -- 期限（月）
    annual_rate DECIMAL(6,4) NOT NULL,  -- 年利率
    monthly_payment DECIMAL(10,2),       -- 月供
    total_interest DECIMAL(10,2),       -- 总利息
    total_amount DECIMAL(12,2),          -- 还款总额
    
    -- 放款信息
    disbursement_date DATE,
    disbursement_amount DECIMAL(12,2),
    first_repayment_date DATE,
    
    -- 还款信息
    repaid_terms INTEGER DEFAULT 0,
    repaid_amount DECIMAL(12,2) DEFAULT 0,
    outstanding_amount DECIMAL(12,2),
    overdue_terms INTEGER DEFAULT 0,
    overdue_amount DECIMAL(10,2),
    
    -- 担保信息
    guarantee_type TEXT,                  -- 担保方式
    guarantee_amount DECIMAL(12,2),     -- 担保金额
    collateral_info JSONB,              -- 抵押物信息
    
    -- 状态
    status finance_status DEFAULT 'pending',
    
    -- 合同文件
    contract_files JSONB,                -- 合同文件URL列表
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- 还款计划表
CREATE TABLE repayment_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    contract_id UUID NOT NULL REFERENCES finance_contracts(id) ON DELETE CASCADE,
    
    term_no INTEGER NOT NULL,            -- 期数
    due_date DATE NOT NULL,              -- 应还日期
    principal DECIMAL(12,2) NOT NULL,   -- 本金
    interest DECIMAL(10,2) NOT NULL,    -- 利息
    monthly_payment DECIMAL(10,2) NOT NULL,  -- 月供
    remaining_principal DECIMAL(12,2),  -- 剩余本金
    
    -- 实际还款
    actual_payment_date DATE,
    actual_principal DECIMAL(12,2),
    actual_interest DECIMAL(10,2),
    actual_amount DECIMAL(10,2),
    
    -- 状态
    is_overdue BOOLEAN DEFAULT FALSE,
    overdue_days INTEGER DEFAULT 0,
    overdue_penalty DECIMAL(10,2),     -- 逾期罚息
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    
    UNIQUE(contract_id, term_no)
);

-- ============================================================
-- 10. 审计日志模块
-- ============================================================

-- 审计日志表
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 操作信息
    operation_type operation_type NOT NULL,
    resource_type TEXT NOT NULL,         -- 操作的资源类型
    resource_id UUID,                    -- 操作的资源ID
    
    -- 操作详情
    operation_table TEXT,                -- 操作的表名
    operation_data JSONB,                -- 操作的数据
    old_data JSONB,                      -- 修改前的数据
    new_data JSONB,                      -- 修改后的数据
    change_summary TEXT,                 -- 变更摘要
    
    -- 执行人
    user_id UUID REFERENCES users(id),
    user_name TEXT,
    user_ip INET,
    user_agent TEXT,
    
    -- 时间
    operation_time TIMESTAMPTZ DEFAULT NOW(),
    
    -- 额外信息
    session_id UUID,
    request_id TEXT,
    additional_info JSONB
);

-- ============================================================
-- 11. 跟进记录模块
-- ============================================================

-- 跟进记录表
CREATE TABLE followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    followup_code TEXT UNIQUE NOT NULL,
    
    customer_id UUID NOT NULL REFERENCES customers(id),
    related_type TEXT,                   -- 关联类型：policy/claim/vehicle/service
    related_id UUID,                      -- 关联ID
    
    -- 跟进信息
    followup_type TEXT NOT NULL,         -- 跟进方式：电话/微信/面谈/短信
    followup_purpose TEXT,               -- 跟进目的
    followup_content TEXT NOT NULL,      -- 跟进内容
    followup_result TEXT,                -- 跟进结果
    next_followup_date DATE,             -- 下次跟进日期
    next_followup_purpose TEXT,          -- 下次跟进目的
    
    -- 状态
    status TEXT DEFAULT 'pending',       -- pending/completed/cancelled
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- ============================================================
-- 12. 系统配置和键值存储
-- ============================================================

-- 系统配置表
CREATE TABLE system_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key TEXT UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    config_type TEXT DEFAULT 'string',  -- string/number/boolean/json
    config_group TEXT,                   -- 配置分组
    description TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    version INTEGER DEFAULT 1
);

-- 定时任务表
CREATE TABLE scheduled_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_name TEXT NOT NULL,
    task_type TEXT NOT NULL,             -- renewal_reminder/inspection_reminder/payment_reminder
    target_table TEXT,                    -- 目标表
    cron_expression TEXT,                 -- Cron表达式
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    run_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1
);

-- ============================================================
-- 13. 索引创建
-- ============================================================

-- 客户索引
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_assigned_user ON customers(assigned_user_id);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_created_at ON customers(created_at);

-- 车辆索引
CREATE INDEX idx_vehicles_customer ON customer_vehicles(customer_id);
CREATE INDEX idx_vehicles_plate ON customer_vehicles(plate_number);
CREATE INDEX idx_vehicles_vin ON customer_vehicles(vin);
CREATE INDEX idx_vehicles_inspection_expire ON customer_vehicles(inspection_expire);
CREATE INDEX idx_vehicles_insurance_expire ON customer_vehicles(compulsory_insurance_expire);

-- 车险索引
CREATE INDEX idx_car_policies_customer ON car_policies(customer_id);
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id);
CREATE INDEX idx_car_policies_company ON car_policies(insurance_company);
CREATE INDEX idx_car_policies_expire ON car_policies(coverage_end);
CREATE INDEX idx_car_policies_status ON car_policies(status);

-- 理赔索引
CREATE INDEX idx_car_claims_policy ON car_claims(policy_id);
CREATE INDEX idx_car_claims_status ON car_claims(status);

-- 非车险索引
CREATE INDEX idx_noncar_policies_customer ON noncar_policies(customer_id);
CREATE INDEX idx_noncar_policies_category ON noncar_policies(category);
CREATE INDEX idx_noncar_policies_expire ON noncar_policies(coverage_end);

-- 年审索引
CREATE INDEX idx_inspections_vehicle ON vehicle_inspections(vehicle_id);
CREATE INDEX idx_inspections_expire ON vehicle_inspections(expire_date);
CREATE INDEX idx_inspections_status ON vehicle_inspections(status);

-- 保养索引
CREATE INDEX idx_maintenance_vehicle ON maintenance_records(vehicle_id);
CREATE INDEX idx_maintenance_date ON maintenance_records(maintenance_date);

-- 后市场索引
CREATE INDEX idx_aftermarket_customer ON aftermarket_orders(customer_id);
CREATE INDEX idx_aftermarket_type ON aftermarket_orders(service_type);
CREATE INDEX idx_aftermarket_status ON aftermarket_orders(status);

-- 金融索引
CREATE INDEX idx_finance_customer ON finance_contracts(customer_id);
CREATE INDEX idx_finance_vehicle ON finance_contracts(vehicle_id);
CREATE INDEX idx_finance_status ON finance_contracts(status);
CREATE INDEX idx_repayment_due ON repayment_schedules(due_date);
CREATE INDEX idx_repayment_contract ON repayment_schedules(contract_id);

-- 跟进索引
CREATE INDEX idx_followups_customer ON followups(customer_id);
CREATE INDEX idx_followups_next_date ON followups(next_followup_date);
CREATE INDEX idx_followups_created_by ON followups(created_by);

-- 审计日志索引
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_time ON audit_logs(operation_time);
CREATE INDEX idx_audit_operation ON audit_logs(operation_type);

-- ============================================================
-- 14. 视图创建
-- ============================================================

-- 客户综合视图（跨模块关联）
CREATE OR REPLACE VIEW v_customer_overview AS
SELECT 
    c.id,
    c.customer_code,
    c.name,
    c.phone,
    c.status,
    c.total_policies,
    c.total_premium,
    c.total_commission,
    c.total_services,
    c.assigned_user_id,
    u.real_name AS assigned_user_name,
    c.created_at,
    -- 车险信息
    (SELECT COUNT(*) FROM car_policies WHERE customer_id = c.id AND is_deleted = FALSE) AS car_policy_count,
    (SELECT COUNT(*) FROM car_policies WHERE customer_id = c.id AND coverage_end >= CURRENT_DATE AND is_deleted = FALSE) AS active_car_policy_count,
    -- 车辆信息
    (SELECT COUNT(*) FROM customer_vehicles WHERE customer_id = c.id AND is_deleted = FALSE) AS vehicle_count,
    -- 最近一次保单到期
    (SELECT MIN(coverage_end) FROM car_policies WHERE customer_id = c.id AND is_deleted = FALSE AND coverage_end >= CURRENT_DATE) AS next_policy_expire,
    -- 最近一次年审到期
    (SELECT MIN(inspection_expire) FROM customer_vehicles WHERE customer_id = c.id AND is_deleted = FALSE AND inspection_expire >= CURRENT_DATE) AS next_inspection_expire,
    -- 待还款金额
    (SELECT COALESCE(SUM(outstanding_amount), 0) FROM finance_contracts WHERE customer_id = c.id AND status IN ('active', 'pending') AND is_deleted = FALSE) AS outstanding_loan
FROM customers c
LEFT JOIN users u ON c.assigned_user_id = u.id
WHERE c.is_deleted = FALSE;

-- 续保提醒视图
CREATE OR REPLACE VIEW v_renewal_reminders AS
SELECT 
    p.id AS policy_id,
    p.policy_code,
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone AS customer_phone,
    v.id AS vehicle_id,
    v.plate_number,
    v.brand,
    v.model,
    p.insurance_company,
    p.coverage_end,
    p.total_premium,
    p.commission_amount,
    u.real_name AS assigned_user_name,
    -- 计算到期天数
    (p.coverage_end - CURRENT_DATE) AS days_until_expire,
    -- 判断是否需要提醒
    CASE 
        WHEN p.coverage_end <= CURRENT_DATE + INTERVAL '30 days' AND p.coverage_end >= CURRENT_DATE THEN 'due_soon'
        WHEN p.coverage_end < CURRENT_DATE THEN 'expired'
        ELSE 'normal'
    END AS renewal_status
FROM car_policies p
JOIN customers c ON p.customer_id = c.id
LEFT JOIN customer_vehicles v ON p.vehicle_id = v.id
LEFT JOIN users u ON c.assigned_user_id = u.id
WHERE p.is_deleted = FALSE 
    AND p.status IN ('active', 'pending')
    AND p.coverage_end <= CURRENT_DATE + INTERVAL '30 days';

-- 年审到期提醒视图
CREATE OR REPLACE VIEW v_inspection_reminders AS
SELECT 
    i.id AS inspection_id,
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone AS customer_phone,
    v.id AS vehicle_id,
    v.plate_number,
    v.brand,
    v.model,
    v.inspection_expire,
    v.inspection_status,
    i.inspection_type,
    u.real_name AS assigned_user_name,
    (v.inspection_expire - CURRENT_DATE) AS days_until_expire,
    CASE 
        WHEN v.inspection_expire <= CURRENT_DATE THEN 'expired'
        WHEN v.inspection_expire <= CURRENT_DATE + INTERVAL '30 days' THEN 'due_soon'
        ELSE 'normal'
    END AS status
FROM customer_vehicles v
JOIN customers c ON v.customer_id = c.id
LEFT JOIN vehicle_inspections i ON v.id = i.vehicle_id AND i.is_deleted = FALSE
LEFT JOIN users u ON c.assigned_user_id = u.id
WHERE v.is_deleted = FALSE
    AND v.inspection_expire <= CURRENT_DATE + INTERVAL '30 days';

-- ============================================================
-- 15. 触发器函数
-- ============================================================

-- 更新时间戳的函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 自动更新客户统计的函数
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- 更新客户的保单数量和保费统计
    UPDATE customers SET
        total_policies = (
            SELECT COUNT(*) FROM car_policies WHERE customer_id = NEW.customer_id AND is_deleted = FALSE
        ) + (
            SELECT COUNT(*) FROM noncar_policies WHERE customer_id = NEW.customer_id AND is_deleted = FALSE
        ),
        total_premium = (
            SELECT COALESCE(SUM(total_premium), 0) FROM car_policies WHERE customer_id = NEW.customer_id AND is_deleted = FALSE
        ) + (
            SELECT COALESCE(SUM(premium), 0) FROM noncar_policies WHERE customer_id = NEW.customer_id AND is_deleted = FALSE
        ),
        total_commission = (
            SELECT COALESCE(SUM(actual_commission), 0) FROM car_policies WHERE customer_id = NEW.customer_id AND is_deleted = FALSE
        ) + (
            SELECT COALESCE(SUM(actual_commission), 0) FROM noncar_policies WHERE customer_id = NEW.customer_id AND is_deleted = FALSE
        ),
        updated_at = NOW()
    WHERE id = NEW.customer_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建更新时间戳的触发器
CREATE TRIGGER update_customers_timestamp BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_users_timestamp BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_vehicles_timestamp BEFORE UPDATE ON customer_vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_car_policies_timestamp BEFORE UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_noncar_policies_timestamp BEFORE UPDATE ON noncar_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_maintenance_timestamp BEFORE UPDATE ON maintenance_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_aftermarket_timestamp BEFORE UPDATE ON aftermarket_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_finance_timestamp BEFORE UPDATE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

CREATE TRIGGER update_repayment_timestamp BEFORE UPDATE ON repayment_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_timestamp();

-- ============================================================
-- 16. RLS 策略（行级安全）
-- ============================================================

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE aftermarket_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repayment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 默认策略：用户只能看到自己的数据
CREATE POLICY "Users can view own data" ON customers
    FOR SELECT USING (created_by = auth.uid() OR created_by IS NULL);

CREATE POLICY "Users can insert own data" ON customers
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update own data" ON customers
    FOR UPDATE USING (created_by = auth.uid());

-- 管理员可以查看所有数据
CREATE POLICY "Admins can view all customers" ON customers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('super_admin', 'admin')
        )
    );

-- ============================================================
-- 17. 初始数据
-- ============================================================

-- 插入超级管理员用户（密码：589842）
INSERT INTO users (id, email, phone, password_hash, real_name, role, is_active)
VALUES (
    uuid_generate_v4(),
    'admin@krabs.cn',
    '13328185024',
    '--',  -- 实际使用Supabase Auth处理
    '蟹老板',
    'super_admin',
    TRUE
);

-- 插入保险公司列表
INSERT INTO system_config (config_key, config_value, config_type, config_group, description) VALUES
('insurance_companies', '["中国人保","平安保险","太平洋保险","中国人寿","中华联合","大地保险","阳光保险","天安保险","华安保险","太平保险"]', 'json', 'insurance', '车险保险公司列表'),
('car_policy_status_options', '["pending","active","expired","cancelled","claims"]', 'json', 'car_policy', '车险状态选项'),
('maintenance_types', '["regular","repair","body_work","tires","battery","brake","ac","other"]', 'json', 'maintenance', '保养类型列表'),
('aftermarket_types', '["violation","rescue","beauty","modification","parts","rental","parking","other"]', 'json', 'aftermarket', '后市场服务类型'),
('finance_types', '["购车贷","信用贷","抵押贷","担保"]', 'json', 'finance', '金融类型列表');

-- ============================================================
-- 18. 存储过程（常用业务逻辑）
-- ============================================================

-- 计算续保佣金的存储过程
CREATE OR REPLACE FUNCTION calculate_renewal_commission(
    p_company TEXT,
    p_total_premium DECIMAL,
    p_is_renewal BOOLEAN
)
RETURNS DECIMAL AS $$
DECLARE
    v_rate DECIMAL;
BEGIN
    -- 根据公司和是否续保计算佣金比例
    -- 这里需要根据实际情况调整
    IF p_is_renewal THEN
        -- 续保客户佣金略低
        v_rate := 0.15;
    ELSE
        -- 新保客户佣金
        v_rate := 0.20;
    END IF;
    
    -- 根据公司调整
    CASE p_company
        WHEN '中国人保' THEN v_rate := v_rate * 0.95;
        WHEN '平安保险' THEN v_rate := v_rate * 0.90;
        WHEN '太平洋保险' THEN v_rate := v_rate * 0.92;
        ELSE v_rate := v_rate * 0.85;
    END CASE;
    
    RETURN ROUND(p_total_premium * v_rate, 2);
END;
$$ LANGUAGE plpgsql;

-- 生成唯一编码的函数
CREATE OR REPLACE FUNCTION generate_code(prefix TEXT, table_name TEXT)
RETURNS TEXT AS $$
DECLARE
    v_year TEXT := to_char(NOW(), 'YYYY');
    v_seq INTEGER;
    v_code TEXT;
BEGIN
    -- 获取当前序列值
    EXECUTE format('SELECT COALESCE(MAX(
        CAST(SUBSTRING(%I FROM ''-([^'']+)$'') AS INTEGER)
    ), 0) FROM %I WHERE customer_code LIKE %L', 
        table_name, table_name, prefix || '-' || v_year || '-%'
    ) INTO v_seq;
    
    v_seq := v_seq + 1;
    v_code := prefix || '-' || v_year || '-' || LPAD(v_seq::TEXT, 5, '0');
    
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 19. 完成标记
-- ============================================================

-- 创建版本记录表
CREATE TABLE schema_versions (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    description TEXT
);

INSERT INTO schema_versions (version, description) 
VALUES ('1.0.0', 'Initial schema - 汽车全生态客户管理系统');
