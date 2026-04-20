-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema V1.0
-- 数据库：Supabase PostgreSQL
-- 日期：2026-04-19
-- ============================================================

-- ============================================================
-- 第一部分：扩展启用
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- 模糊搜索支持

-- ============================================================
-- 第二部分：枚举类型定义
-- ============================================================

-- 客户类型
CREATE TYPE customer_type AS ENUM ('individual', 'corporate');

-- 客户来源
CREATE TYPE customer_source AS ENUM (
    'referral',      -- 转介绍
    'walk_in',       -- 自然到店
    'online',         -- 网络获客
    'partner',       -- 合作渠道
    'renewal',       -- 续保客户
    'cold_call',     -- 陌生拜访
    'other'          -- 其他
);

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM (
    'active',        -- 正常使用
    'scrapped',      -- 已报废
    'transferred',   -- 已过户
    'insurance_only' -- 仅投保不上路
);

-- 车险状态
CREATE TYPE car_policy_status AS ENUM (
    'active',        -- 生效中
    'expired',       -- 已过期
    'cancelled',     -- 已退保
    'pending',       -- 待生效
    'renewed'        -- 已续保
);

-- 非车险类型
CREATE TYPE noncar_type AS ENUM (
    'accident',      -- 意外险
    'health',        -- 健康险
    'property',      -- 家财险
    'liability',     -- 责任险
    'travel',        -- 旅行险
    'education',     -- 教育金
    'pension',       -- 养老险
    'other'          -- 其他
);

-- 非车险状态
CREATE TYPE noncar_policy_status AS ENUM (
    'active',
    'expired',
    'cancelled',
    'pending',
    'renewed'
);

-- 服务类型
CREATE TYPE service_type AS ENUM (
    'annual_inspection', -- 年检
    'maintenance',      -- 保养
    'repair',            -- 维修
    'beauty',            -- 美容
    'modification',     -- 改装
    'rescue',           -- 救援
    'parts',            -- 配件
    'other'             -- 其他
);

-- 服务状态
CREATE TYPE service_status AS ENUM (
    'scheduled',      -- 已预约
    'in_progress',    -- 进行中
    'completed',       -- 已完成
    'cancelled',       -- 已取消
    'pending_payment'  -- 待付款
);

-- 金融产品类型
CREATE TYPE finance_product_type AS ENUM (
    'new_car_loan',       -- 新车贷款
    'used_car_loan',      -- 二手车贷款
    'refinance',          -- 抵押贷款
    'leasing',            -- 融资租赁
    'insurance_finance'   -- 保单贷款
);

-- 金融状态
CREATE TYPE finance_status AS ENUM (
    'applying',       -- 申请中
    'approved',       -- 已审批
    'rejected',       -- 已拒绝
    'active',         -- 还款中
    'completed',      -- 已结清
    'overdue',        -- 逾期
    'cancelled'       -- 已取消
);

-- 跟进类型
CREATE TYPE followup_type AS ENUM (
    'phone_call',     -- 电话
    'visit',          -- 上门拜访
    'wechat',         -- 微信
    'sms',            -- 短信
    'email',          -- 邮件
    'meeting',        -- 面谈
    'other'           -- 其他
);

-- 操作类型（审计日志）
CREATE TYPE audit_action AS ENUM (
    'create',
    'read',
    'update',
    'delete',
    'login',
    'logout',
    'export',
    'import',
    'restore'
);

-- ============================================================
-- 第三部分：核心客户表（所有模块的关联中枢）
-- ============================================================

CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 基本信息
    name TEXT NOT NULL,                        -- 姓名/公司名
    name_pinyin TEXT,                          -- 姓名拼音（用于搜索）
    phone TEXT NOT NULL,                        -- 手机号（唯一）
    phone_2 TEXT,                              -- 备用手机
    id_card TEXT,                               -- 身份证号（加密存储）
    id_card_encrypted TEXT,                    -- 加密后的身份证
    
    -- 扩展信息
    customer_type customer_type DEFAULT 'individual',
    source customer_source DEFAULT 'other',
    birthday DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    email TEXT,
    
    -- 地址信息
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    
    -- 车辆关联
    vehicle_count INTEGER DEFAULT 0,           -- 车辆数量
    
    -- 业务标签（JSON数组，方便查询）
    tags TEXT[] DEFAULT '{}',                   -- ['vip', 'large_premium', 'referee']
    remark TEXT,                                -- 备注
    
    -- 系统字段
    version INTEGER DEFAULT 1,                  -- 版本号（乐观锁）
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- 客户手机号唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone) WHERE NOT is_deleted;

-- 客户姓名模糊搜索索引
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm ON customers USING gin(name gin_trgm_ops);

-- 客户标签索引
CREATE INDEX IF NOT EXISTS idx_customers_tags ON customers USING gin(tags);

-- ============================================================
-- 第四部分：车辆表（一个客户可有多辆车）
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 车辆基本信息
    plate TEXT NOT NULL,                       -- 车牌号
    plate_province TEXT,                       -- 车牌省份
    vin TEXT NOT NULL,                         -- VIN码（车架号）
    brand TEXT,                                -- 品牌
    series TEXT,                               -- 车系
    car_model TEXT,                            -- 车型
    color TEXT,                                -- 颜色
    vehicle_type TEXT,                         -- 车辆类型（轿车/SUV/货车等）
    
    -- 使用信息
    register_date DATE,                        -- 注册日期
    plate_date DATE,                           -- 上牌日期
    mileage DECIMAL(12, 2),                   -- 行驶里程
    fuel_type TEXT,                            -- 燃料类型
    status vehicle_status DEFAULT 'active',
    
    -- 年审信息
    annual_inspection_date DATE,               -- 年审到期日
    next_inspection_date DATE,                 -- 下次年审日期
    inspection_status TEXT DEFAULT 'valid',    -- 年审状态
    
    -- 商业险信息（方便快速查询）
    current_policy_id UUID,                    -- 当前保单ID
    current_policy_expire DATE,                -- 当前保单到期
    
    -- 系统字段
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    -- 约束
    CONSTRAINT unique_vin UNIQUE (vin)
);

-- 车辆车牌号索引
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON vehicles(plate) WHERE NOT is_deleted;

-- 车辆VIN索引
CREATE INDEX IF NOT EXISTS idx_vehicles_vin ON vehicles(vin) WHERE NOT is_deleted;

-- 车辆客户索引
CREATE INDEX IF NOT EXISTS idx_vehicles_customer ON vehicles(customer_id) WHERE NOT is_deleted;

-- 年审到期预警索引
CREATE INDEX IF NOT EXISTS idx_vehicles_inspection ON vehicles(next_inspection_date) 
    WHERE NOT is_deleted AND status = 'active';

-- ============================================================
-- 第五部分：车险保单表
-- ============================================================

CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 保单基本信息
    policy_no TEXT NOT NULL,                  -- 保单号（唯一）
    company TEXT NOT NULL,                     -- 承保公司
    
    -- 险种明细（JSON存储，方便扩展）
    biz_coverage JSONB DEFAULT '{}',          -- 商业险详情
    force_coverage JSONB DEFAULT '{}',         -- 交强险详情
    
    -- 保费信息
    biz_premium DECIMAL(12, 2),               -- 商业险保费
    force_premium DECIMAL(12, 2),              -- 交强险保费
    tax_premium DECIMAL(12, 2) DEFAULT 0,      -- 车船税
    total_premium DECIMAL(12, 2),              -- 总保费
    
    -- 佣金信息
    commission_rate DECIMAL(6, 4),             -- 佣金比例
    commission_amount DECIMAL(12, 2),          -- 佣金金额
    net_commission DECIMAL(12, 2),             -- 净佣金（扣除税后）
    commission_received BOOLEAN DEFAULT FALSE,  -- 佣金是否到账
    
    -- 日期信息
    sign_date DATE NOT NULL,                   -- 签单日期
    start_date DATE NOT NULL,                  -- 生效日期
    end_date DATE NOT NULL,                    -- 到期日期
    
    -- 状态
    status car_policy_status DEFAULT 'pending',
    
    -- 关联保单
    previous_policy_id UUID,                   -- 上年保单ID
    renewed_policy_id UUID,                    -- 续保保单ID
    
    -- 业务员信息
    agent_name TEXT,                           -- 业务员姓名
    agent_phone TEXT,                          -- 业务员电话
    
    -- 备注
    remark TEXT,
    
    -- 附件URL
    attachment_urls TEXT[],                    -- 保单附件（JSON数组）
    
    -- 系统字段
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    -- 约束
    CONSTRAINT unique_policy_no UNIQUE (policy_no)
);

-- 保单号唯一索引
CREATE INDEX IF NOT EXISTS idx_car_policies_no ON car_policies(policy_no) WHERE NOT is_deleted;

-- 客户索引
CREATE INDEX IF NOT EXISTS idx_car_policies_customer ON car_policies(customer_id) WHERE NOT is_deleted;

-- 车辆索引
CREATE INDEX IF NOT EXISTS idx_car_policies_vehicle ON car_policies(vehicle_id) WHERE NOT is_deleted;

-- 到期日期索引（续保提醒用）
CREATE INDEX IF NOT EXISTS idx_car_policies_expire ON car_policies(end_date) 
    WHERE NOT is_deleted AND status = 'active';

-- 公司统计索引
CREATE INDEX IF NOT EXISTS idx_car_policies_company ON car_policies(company) WHERE NOT is_deleted;

-- 签单日期索引
CREATE INDEX IF NOT EXISTS idx_car_policies_sign ON car_policies(sign_date) WHERE NOT is_deleted;

-- ============================================================
-- 第六部分：非车险保单表
-- ============================================================

CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 保单基本信息
    policy_no TEXT NOT NULL,                  -- 保单号
    insurance_type noncar_type NOT NULL,       -- 险种类型
    company TEXT NOT NULL,                     -- 承保公司
    product_name TEXT,                         -- 产品名称
    
    -- 保费信息
    premium DECIMAL(12, 2) NOT NULL,          -- 保费
    commission_rate DECIMAL(6, 4),             -- 佣金比例
    commission_amount DECIMAL(12, 2),          -- 佣金金额
    net_commission DECIMAL(12, 2),             -- 净佣金
    
    -- 日期信息
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 状态
    status noncar_policy_status DEFAULT 'pending',
    
    -- 关联车险
    linked_car_policy_id UUID,                -- 关联的车险保单ID
    
    -- 被保险人信息
    insured_name TEXT,                         -- 被保险人
    insured_id_card TEXT,                      -- 被保险人身份证
    
    -- 受益人
    beneficiary TEXT,
    
    -- 保障内容（JSON）
    coverage JSONB DEFAULT '{}',
    
    -- 备注
    remark TEXT,
    
    -- 附件
    attachment_urls TEXT[],
    
    -- 系统字段
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    CONSTRAINT unique_noncar_policy_no UNIQUE (policy_no)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_noncar_policies_customer ON noncar_policies(customer_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_noncar_policies_expire ON noncar_policies(end_date) 
    WHERE NOT is_deleted AND status = 'active';
CREATE INDEX IF NOT EXISTS idx_noncar_policies_type ON noncar_policies(insurance_type) WHERE NOT is_deleted;

-- ============================================================
-- 第七部分：年审保养服务表
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicle_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 服务类型
    service_type service_type NOT NULL,
    
    -- 服务详情
    title TEXT NOT NULL,                       -- 服务标题
    description TEXT,                          -- 服务描述
    service_items JSONB DEFAULT '[]',          -- 服务项目明细
    
    -- 预约信息
    appointment_date TIMESTAMPTZ,              -- 预约时间
    garage_id UUID,                            -- 维修厂ID
    garage_name TEXT,                           -- 维修厂名称
    garage_address TEXT,                        -- 维修厂地址
    
    -- 费用信息
    estimated_cost DECIMAL(12, 2),            -- 预估费用
    actual_cost DECIMAL(12, 2),                -- 实际费用
    discount DECIMAL(12, 2) DEFAULT 0,        -- 优惠金额
    paid_amount DECIMAL(12, 2) DEFAULT 0,     -- 已付金额
    payment_status TEXT DEFAULT 'unpaid',     -- 支付状态
    
    -- 执行信息
    service_date TIMESTAMPTZ,                  -- 实际服务时间
    mechanic_name TEXT,                         -- 技师姓名
    completion_date TIMESTAMPTZ,               -- 完成时间
    
    -- 状态
    status service_status DEFAULT 'scheduled',
    
    -- 客户评价
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    review_date TIMESTAMPTZ,
    
    -- 关联车险（用于计算推荐）
    linked_policy_id UUID,
    
    -- 下次提醒
    next_service_date DATE,                    -- 下次服务日期
    next_reminder_date DATE,                   -- 下次提醒日期
    
    -- 备注
    remark TEXT,
    
    -- 附件
    attachment_urls TEXT[],
    photo_urls TEXT[],
    
    -- 系统字段
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_vehicle_services_customer ON vehicle_services(customer_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_vehicle_services_vehicle ON vehicle_services(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_vehicle_services_type ON vehicle_services(service_type) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_vehicle_services_status ON vehicle_services(status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_vehicle_services_next_reminder ON vehicle_services(next_reminder_date) 
    WHERE NOT is_deleted AND next_reminder_date IS NOT NULL;

-- ============================================================
-- 第八部分：汽车后市场订单表
-- ============================================================

CREATE TABLE IF NOT EXISTS aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 订单信息
    order_no TEXT NOT NULL,                    -- 订单号
    order_type TEXT NOT NULL,                  -- 订单类型
    
    -- 商品/服务信息
    items JSONB NOT NULL DEFAULT '[]',         -- 订单项目明细
    
    -- 费用
    subtotal DECIMAL(12, 2),                   -- 小计
    service_fee DECIMAL(12, 2) DEFAULT 0,     -- 服务费
    delivery_fee DECIMAL(12, 2) DEFAULT 0,    -- 配送费
    discount DECIMAL(12, 2) DEFAULT 0,        -- 优惠
    total_amount DECIMAL(12, 2),               -- 总金额
    
    -- 支付
    paid_amount DECIMAL(12, 2) DEFAULT 0,
    payment_method TEXT,                        -- 支付方式
    payment_date TIMESTAMPTZ,
    payment_status TEXT DEFAULT 'pending',
    
    -- 配送
    delivery_type TEXT,                         -- 配送方式
    delivery_address TEXT,
    delivery_date TIMESTAMPTZ,
    tracking_no TEXT,
    
    -- 状态
    status TEXT DEFAULT 'pending',
    
    -- 退款
    refund_amount DECIMAL(12, 2) DEFAULT 0,
    refund_reason TEXT,
    refund_date TIMESTAMPTZ,
    
    -- 来源
    source TEXT DEFAULT 'app',                  -- app/wechat/website/phone
    
    -- 备注
    remark TEXT,
    
    -- 系统字段
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    CONSTRAINT unique_order_no UNIQUE (order_no)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_aftermarket_orders_customer ON aftermarket_orders(customer_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_aftermarket_orders_status ON aftermarket_orders(status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_aftermarket_orders_created ON aftermarket_orders(created_at DESC) WHERE NOT is_deleted;

-- ============================================================
-- 第九部分：汽车消费金融表
-- ============================================================

CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 合同信息
    contract_no TEXT NOT NULL,                 -- 合同号
    product_type finance_product_type NOT NULL, -- 产品类型
    
    -- 贷款信息
    loan_amount DECIMAL(12, 2) NOT NULL,       -- 贷款金额
    loan_term INTEGER NOT NULL,                -- 贷款期限（月）
    interest_rate DECIMAL(8, 4) NOT NULL,      -- 年利率
    monthly_payment DECIMAL(12, 2),            -- 月供
    total_interest DECIMAL(12, 2),             -- 总利息
    total_amount DECIMAL(12, 2),               -- 还款总额
    
    -- 首付
    down_payment DECIMAL(12, 2),               -- 首付金额
    down_payment_rate DECIMAL(6, 4),           -- 首付比例
    
    -- 车辆信息（贷款购买时）
    vehicle_price DECIMAL(12, 2),               -- 车辆价格
    vehicle_new BOOLEAN DEFAULT TRUE,          -- 是否新车
    
    -- 合作机构
    finance_company TEXT,                       -- 金融机构
    agent_name TEXT,                           -- 办理业务员
    agent_commission DECIMAL(12, 2),          -- 业务员佣金
    
    -- 日期
    apply_date DATE,                           -- 申请日期
    approve_date DATE,                         -- 审批日期
    loan_start_date DATE,                      -- 贷款开始日期
    loan_end_date DATE,                        -- 贷款结束日期
    
    -- 还款进度
    paid_terms INTEGER DEFAULT 0,              -- 已还期数
    remaining_amount DECIMAL(12, 2),           -- 剩余本金
    next_payment_date DATE,                   -- 下次还款日
    next_payment_amount DECIMAL(12, 2),       -- 下次还款额
    
    -- 状态
    status finance_status DEFAULT 'applying',
    
    -- 逾期记录
    overdue_count INTEGER DEFAULT 0,           -- 逾期次数
    max_overdue_days INTEGER DEFAULT 0,       -- 最大逾期天数
    overdue_amount DECIMAL(12, 2) DEFAULT 0,  -- 逾期金额
    
    -- 担保信息
    guarantor_name TEXT,                       -- 担保人
    guarantor_phone TEXT,
    collateral_type TEXT,                      -- 抵押物类型
    collateral_no TEXT,                        -- 抵押物编号
    
    -- 备注
    remark TEXT,
    
    -- 附件
    attachment_urls TEXT[],
    
    -- 系统字段
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    CONSTRAINT unique_contract_no UNIQUE (contract_no)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_finance_contracts_customer ON finance_contracts(customer_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_finance_contracts_status ON finance_contracts(status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_finance_contracts_next_payment ON finance_contracts(next_payment_date) 
    WHERE NOT is_deleted AND status = 'active';

-- ============================================================
-- 第十部分：还款记录表
-- ============================================================

CREATE TABLE IF NOT EXISTS finance_repayments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID NOT NULL REFERENCES finance_contracts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 期数信息
    term_no INTEGER NOT NULL,                  -- 期数
    due_date DATE NOT NULL,                    -- 应还日期
    
    -- 金额
    principal DECIMAL(12, 2),                  -- 本金
    interest DECIMAL(12, 2),                   -- 利息
    penalty DECIMAL(12, 2) DEFAULT 0,          -- 罚息
    total_due DECIMAL(12, 2),                  -- 应还总额
    
    -- 还款信息
    paid_date DATE,                            -- 实还日期
    paid_principal DECIMAL(12, 2),            -- 实还本金
    paid_interest DECIMAL(12, 2),             -- 实还利息
    paid_penalty DECIMAL(12, 2) DEFAULT 0,    -- 实还罚息
    total_paid DECIMAL(12, 2),                 -- 实还总额
    
    -- 状态
    status TEXT DEFAULT 'pending',            -- pending/paid/overdue
    
    -- 逾期天数
    overdue_days INTEGER DEFAULT 0,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_finance_repayments_contract ON finance_repayments(contract_id);
CREATE INDEX IF NOT EXISTS idx_finance_repayments_customer ON finance_repayments(customer_id);
CREATE INDEX IF NOT EXISTS idx_finance_repayments_status ON finance_repayments(status);
CREATE INDEX IF NOT EXISTS idx_finance_repayments_due ON finance_repayments(due_date) WHERE status = 'pending';

-- ============================================================
-- 第十一部分：维修厂管理表
-- ============================================================

CREATE TABLE IF NOT EXISTS garages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 基本信息
    name TEXT NOT NULL,                       -- 维修厂名称
    name_pinyin TEXT,
    
    -- 联系方式
    contact_person TEXT,                       -- 联系人
    phone TEXT NOT NULL,                       -- 电话
    phone_2 TEXT,
    
    -- 地址
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    longitude DECIMAL(10, 7),
    latitude DECIMAL(10, 7),
    
    -- 营业信息
    business_hours TEXT,                       -- 营业时间
    night_service BOOLEAN DEFAULT FALSE,       -- 夜间服务
    door_to_door BOOLEAN DEFAULT FALSE,       -- 上门服务
    
    -- 服务类型
    service_types service_type[] DEFAULT '{}', -- 提供服务类型
    brands TEXT[],                             -- 擅长品牌
    certification TEXT[],                      -- 资质认证
    
    -- 评级
    rating DECIMAL(3, 2),                      -- 评分
    review_count INTEGER DEFAULT 0,
    
    -- 合作信息
    is_partner BOOLEAN DEFAULT FALSE,         -- 是否合作
    commission_rate DECIMAL(6, 4),             -- 佣金比例
    settlement_cycle TEXT,                     -- 结算周期
    
    -- 状态
    status TEXT DEFAULT 'active',
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_garages_city ON garages(city) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_garages_partner ON garages(is_partner) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_garages_status ON garages(status) WHERE NOT is_deleted;

-- ============================================================
-- 第十二部分：跟进记录表（所有模块共用）
-- ============================================================

CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 关联业务（可选，用于关联具体保单/服务/订单）
    related_type TEXT,                         -- car_policy/noncar_policy/service/order/finance
    related_id UUID,
    
    -- 跟进信息
    followup_type followup_type NOT NULL,
    subject TEXT NOT NULL,                     -- 跟进主题
    content TEXT NOT NULL,                     -- 跟进内容
    result TEXT,                               -- 跟进结果
    
    -- 下次跟进
    next_followup_date DATE,
    next_followup_type followup_type,
    next_followup_remark TEXT,
    
    -- 状态
    status TEXT DEFAULT 'pending',             -- pending/completed/cancelled
    
    -- 附件
    attachment_urls TEXT[],
    
    -- 系统字段
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

CREATE INDEX IF NOT EXISTS idx_followups_customer ON followups(customer_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_followups_related ON followups(related_type, related_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_followups_date ON followups(created_at DESC) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_followups_next ON followups(next_followup_date) 
    WHERE NOT is_deleted AND next_followup_date IS NOT NULL AND status = 'pending';

-- ============================================================
-- 第十三部分：审计日志表（核心！保证数据可追溯）
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 操作信息
    table_name TEXT NOT NULL,                  -- 操作表名
    record_id UUID,                            -- 操作记录ID
    action audit_action NOT NULL,              -- 操作类型
    
    -- 变更前后数据
    old_data JSONB,                            -- 变更前数据
    new_data JSONB,                            -- 变更后数据
    changes JSONB,                             -- 变更字段明细
    
    -- 操作者
    user_id UUID,                              -- 操作用户ID
    user_name TEXT,                            -- 操作用户名
    user_ip TEXT,                              -- IP地址
    user_agent TEXT,                           -- 浏览器信息
    
    -- 时间
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_record ON audit_logs(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);

-- ============================================================
-- 第十四部分：系统配置表
-- ============================================================

CREATE TABLE IF NOT EXISTS system_configs (
    id TEXT PRIMARY KEY,                       -- 配置键
    value JSONB NOT NULL,                      -- 配置值
    description TEXT,                          -- 配置描述
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- ============================================================
-- 第十五部分：消息/通知表
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 通知内容
    type TEXT NOT NULL,                        -- renewal/reminder/payment/overdue/promotion
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    
    -- 关联
    related_type TEXT,
    related_id UUID,
    
    -- 状态
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    read_by UUID,
    
    -- 推送状态
    push_status TEXT DEFAULT 'pending',        -- pending/sent/failed
    push_at TIMESTAMPTZ,
    
    -- 审计
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

CREATE INDEX IF NOT EXISTS idx_notifications_customer ON notifications(customer_id) WHERE NOT is_read;
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- 第十六部分：备份记录表
-- ============================================================

CREATE TABLE IF NOT EXISTS backup_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 备份信息
    backup_type TEXT NOT NULL,                 -- full/incremental/table
    backup_level TEXT NOT NULL,                -- local/cloud/email
    
    -- 文件信息
    file_name TEXT,
    file_path TEXT,
    file_size BIGINT,
    
    -- 状态
    status TEXT DEFAULT 'pending',            -- pending/in_progress/completed/failed
    error_message TEXT,
    
    -- 统计
    tables_count INTEGER,
    records_count INTEGER,
    duration_seconds INTEGER,
    
    -- 审计
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_by UUID
);

CREATE INDEX IF NOT EXISTS idx_backup_records_status ON backup_records(status);
CREATE INDEX IF NOT EXISTS idx_backup_records_created ON backup_records(created_at DESC);

-- ============================================================
-- 第十七部分：RLS策略（行级安全）
-- ============================================================

-- 启用RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE aftermarket_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_repayments ENABLE ROW LEVEL SECURITY;
ALTER TABLE garages ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE backup_records ENABLE ROW LEVEL SECURITY;

-- 创建服务角色策略（允许所有人读取，登录用户可读写自己的数据）
-- 注意：实际策略需要根据Supabase Auth配置调整

-- ============================================================
-- 第十八部分：触发器（自动更新审计字段）
-- ============================================================

-- 审计字段自动更新函数
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为需要自动更新时间的表创建触发器
CREATE OR REPLACE FUNCTION set_audit_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_at = NOW();
        NEW.updated_at = NOW();
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_at = NOW();
        NEW.version = OLD.version + 1;
        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器（示例）
CREATE TRIGGER trg_customers_audit
    BEFORE INSERT OR UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_audit_fields();

CREATE TRIGGER trg_vehicles_audit
    BEFORE INSERT OR UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION set_audit_fields();

CREATE TRIGGER trg_car_policies_audit
    BEFORE INSERT OR UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION set_audit_fields();

-- 软删除触发器
CREATE OR REPLACE FUNCTION soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE customers SET is_deleted = TRUE, deleted_at = NOW() WHERE id = OLD.id;
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 第十九部分：视图（方便前端查询）
-- ============================================================

-- 客户完整视图（包含车辆数量等信息）
CREATE OR REPLACE VIEW v_customers_full AS
SELECT 
    c.*,
    COUNT(DISTINCT v.id) AS vehicle_count,
    COUNT(DISTINCT cp.id) FILTER (WHERE cp.status = 'active') AS active_car_policies,
    COUNT(DISTINCT np.id) FILTER (WHERE np.status = 'active') AS active_noncar_policies
FROM customers c
LEFT JOIN vehicles v ON c.id = v.customer_id AND NOT v.is_deleted
LEFT JOIN car_policies cp ON c.id = cp.customer_id AND NOT cp.is_deleted
LEFT JOIN noncar_policies np ON c.id = np.customer_id AND NOT np.is_deleted
WHERE NOT c.is_deleted
GROUP BY c.id;

-- 续保到期提醒视图
CREATE OR REPLACE VIEW v_renewal_reminders AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate,
    cp.id AS policy_id,
    cp.end_date,
    cp.company,
    cp.total_premium,
    cp.renewed_policy_id IS NULL AS is_pending,
    cp.end_date - CURRENT_DATE AS days_until_expiry
FROM customers c
JOIN vehicles v ON c.id = v.customer_id AND NOT v.is_deleted
JOIN car_policies cp ON c.id = cp.customer_id AND NOT cp.is_deleted
WHERE cp.status IN ('active', 'expired')
    AND cp.end_date <= CURRENT_DATE + INTERVAL '90 days'
    AND cp.renewed_policy_id IS NULL;

-- 年审到期提醒视图
CREATE OR REPLACE VIEW v_inspection_reminders AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate,
    v.vin,
    v.next_inspection_date,
    v.next_inspection_date - CURRENT_DATE AS days_until_inspection
FROM customers c
JOIN vehicles v ON c.id = v.customer_id AND NOT v.is_deleted
WHERE NOT v.is_deleted
    AND v.status = 'active'
    AND v.next_inspection_date <= CURRENT_DATE + INTERVAL '90 days';

-- ============================================================
-- 第二十部分：初始数据
-- ============================================================

-- 插入系统配置
INSERT INTO system_configs (id, value, description) VALUES
('system_version', '{"version": "1.0.0", "release_date": "2026-04-19"}', '系统版本信息'),
('backup_config', '{"auto_backup": true, "backup_time": "02:00", "retention_days": 365}', '备份配置'),
('notification_config', '{"renewal_reminder_days": [30, 15, 7, 3, 1], "inspection_reminder_days": [30, 15, 7, 1]}', '提醒配置')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 完成
-- ============================================================
