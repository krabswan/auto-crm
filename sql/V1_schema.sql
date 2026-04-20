-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema V1.0
-- 创建日期：2026-04-19
-- 作者：痞老板
-- 说明：模块化设计，支持可持续更新
-- ============================================================

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 基础设施层：用户认证 + 审计日志
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 用户表（扩展Supabase auth.users）
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    nickname TEXT,
    role TEXT DEFAULT 'agent' CHECK (role IN ('admin', 'manager', 'agent', 'viewer')),
    phone TEXT,
    email TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

-- 角色权限表
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id SERIAL PRIMARY KEY,
    role TEXT NOT NULL,
    module TEXT NOT NULL,
    can_read BOOLEAN DEFAULT FALSE,
    can_write BOOLEAN DEFAULT FALSE,
    can_delete BOOLEAN DEFAULT FALSE,
    can_export BOOLEAN DEFAULT FALSE,
    UNIQUE(role, module)
);

-- 审计日志表（核心：数据可追溯）
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'EXPORT', 'IMPORT')),
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],
    user_id UUID REFERENCES public.users(id),
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs(table_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_logs(table_name, record_id);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 核心层：统一客户中心
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 客户主表（所有模块的数据关联中枢）
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 基础信息
    name TEXT NOT NULL,
    gender TEXT CHECK (gender IN ('男', '女', '未知')),
    phone TEXT NOT NULL,
    phone2 TEXT,
    email TEXT,
    id_card TEXT,
    id_card_hash TEXT,  -- 用于脱敏后快速匹配
    birth_date DATE,
    -- 地址信息
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    address_detail TEXT,
    -- 职业信息
    occupation TEXT,
    company_name TEXT,
    annual_income NUMERIC(12,2),
    -- 车辆信息（主车辆，多车辆在vehicles表）
    has_main_vehicle BOOLEAN DEFAULT FALSE,
    main_plate TEXT,
    main_vin TEXT,
    main_brand TEXT,
    main_model TEXT,
    main_register_date DATE,
    -- 归属信息
    owner_user_id UUID REFERENCES public.users(id),
    owner_team TEXT,
    source_channel TEXT,  -- 来源渠道：自然到店/朋友介绍/网络推广/车行合作/4S店合作
    -- 评级
    customer_level TEXT DEFAULT 'C' CHECK (customer_level IN ('A', 'B', 'C', 'D')),
    customer_tags TEXT[],  -- 标签：['高净值', '家庭客户', '企业主', '公务用车']
    -- 偏好
    preferred_contact TEXT DEFAULT 'phone' CHECK (preferred_contact IN ('phone', 'wechat', 'email', 'sms')),
    preferred_service_time TEXT,
    -- 统计字段（定期更新）
    total_premium NUMERIC(12,2) DEFAULT 0,       -- 累计保费
    total_commission NUMERIC(12,2) DEFAULT 0,     -- 累计佣金
    total_orders INTEGER DEFAULT 0,                -- 累计订单
    last_service_date DATE,
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_cust_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_cust_name ON customers(name);
CREATE INDEX IF NOT EXISTS idx_cust_plate ON customers(main_plate);
CREATE INDEX IF NOT EXISTS idx_cust_owner ON customers(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_cust_level ON customers(customer_level);
CREATE INDEX IF NOT EXISTS idx_cust_tags ON customers USING GIN(customer_tags);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 模块1：车辆管理
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 车辆表（一个客户可有多辆车）
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    plate TEXT NOT NULL,
    plate_province TEXT,
    vin TEXT NOT NULL,
    engine_no TEXT,
    brand TEXT,
    series TEXT,
    model TEXT,
    car_type TEXT CHECK (car_type IN ('轿车', 'SUV', 'MPV', '货车', '客车', '面包车', '新能源', '其他')),
    use_type TEXT DEFAULT '家庭自用' CHECK (use_type IN ('家庭自用', '企业非营业', '企业营业', '营运', '政府机关', '其他')),
    register_date DATE,
    issue_date DATE,
    car_color TEXT,
    fuel_type TEXT CHECK (fuel_type IN ('汽油', '柴油', '纯电动', '插电混动', '油电混动', '天然气', '其他')),
    emission_standard TEXT,
    -- 年审信息
    annual_inspection_date DATE,
    annual_inspection_remind BOOLEAN DEFAULT TRUE,
    annual_inspection_remind_days INTEGER DEFAULT 30,
    -- 交强险
    force_insurance_status TEXT CHECK (force_insurance_status IN ('有效', '过期', '待生效')),
    force_end_date DATE,
    -- 商业险
    biz_insurance_status TEXT CHECK (biz_insurance_status IN ('有效', '过期', '待生效', '未投保')),
    biz_end_date DATE,
    -- 当前保险
    current_policy_id UUID,
    -- 评估价值
    market_value NUMERIC(12,2),
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    UNIQUE(plate)
);

CREATE INDEX IF NOT EXISTS idx_veh_customer ON vehicles(customer_id);
CREATE INDEX IF NOT EXISTS idx_veh_plate ON vehicles(plate);
CREATE INDEX IF NOT EXISTS idx_veh_vin ON vehicles(vin);
CREATE INDEX IF NOT EXISTS idx_veh_annual ON vehicles(annual_inspection_date) WHERE is_deleted = FALSE;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 模块2：车险管理
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 车险保单表
CREATE TABLE IF NOT EXISTS public.car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    plate TEXT NOT NULL,
    -- 保单信息
    policy_no TEXT UNIQUE,
    company TEXT NOT NULL,  -- 保险公司：平安/太平洋/人保/国寿/中华/大地/阳光/其他
    company_code TEXT,
    product_name TEXT,       -- 险种组合名称
    -- 保费明细
    force_premium NUMERIC(10,2) DEFAULT 0,      -- 交强险
    force_travel_tax NUMERIC(10,2) DEFAULT 0,   -- 车船税
    biz_premium NUMERIC(10,2) DEFAULT 0,        -- 商业险合计
    premium_discount NUMERIC(10,2) DEFAULT 0,   -- 优惠金额
    total_premium NUMERIC(10,2) NOT NULL,       -- 总保费
    -- 险种明细（JSON存储灵活险种组合）
    coverage_details JSONB DEFAULT '{}',
    -- 佣金
    commission_rate NUMERIC(5,4),                -- 佣金比例
    commission_amount NUMERIC(10,2) DEFAULT 0,  -- 佣金金额
    net_commission NUMERIC(10,2) DEFAULT 0,     -- 净佣金（扣除税后）
    commission_status TEXT DEFAULT 'pending' CHECK (commission_status IN ('pending', 'confirmed', 'paid', 'rejected')),
    commission_paid_date DATE,
    -- 日期
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 状态
    policy_status TEXT DEFAULT 'active' CHECK (policy_status IN ('active', 'expired', 'cancelled', 'pending')),
    renewal_status TEXT CHECK (renewal_status IN ('pending', 'contacted', 'quoted', 'renewed', 'lost', 'transferred')),
    -- 理赔
    claim_count INTEGER DEFAULT 0,
    claim_amount NUMERIC(12,2) DEFAULT 0,
    last_claim_date DATE,
    -- 关联
    previous_policy_id UUID REFERENCES public.car_policies(id),  -- 续保关联
    source_channel TEXT,  -- 来源：自然客户/转介绍/车行/4S店/电网销
    -- 附件
    attachment_urls TEXT[],
    -- 备注
    remark TEXT,
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_carp_customer ON car_policies(customer_id);
CREATE INDEX IF NOT EXISTS idx_carp_plate ON car_policies(plate);
CREATE INDEX IF NOT EXISTS idx_carp_end_date ON car_policies(end_date) WHERE policy_status = 'active';
CREATE INDEX IF NOT EXISTS idx_carp_company ON car_policies(company);
CREATE INDEX IF NOT EXISTS idx_carp_sign_date ON car_policies(sign_date DESC);

-- 车险险种字典表
CREATE TABLE IF NOT EXISTS public.car_coverage_types (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,        -- 如: third_100
    name TEXT NOT NULL,               -- 如: 第三者责任险100万
    category TEXT NOT NULL,            -- 如: 商业险/交强险/附加险
    default_amount NUMERIC(12,2),      -- 默认保额
    unit TEXT DEFAULT '元',            -- 单位
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0
);

-- 保险公司字典表
CREATE TABLE IF NOT EXISTS public.insurance_companies (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    short_name TEXT,
    logo_url TEXT,
    hotline TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 模块3：非车险管理
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 非车险保单表
CREATE TABLE IF NOT EXISTS public.noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    -- 保单信息
    policy_no TEXT UNIQUE,
    company TEXT NOT NULL,
    company_code TEXT,
    insurance_type TEXT NOT NULL,  -- 意外险/健康险/家财险/责任险/信用保证险/其他
    product_name TEXT,
    -- 承保人信息
    insured_name TEXT,
    insured_id_card TEXT,
    insured_phone TEXT,
    insured_relation TEXT DEFAULT '本人',
    -- 保费
    premium NUMERIC(10,2) NOT NULL,
    premium_discount NUMERIC(10,2) DEFAULT 0,
    total_premium NUMERIC(10,2) NOT NULL,
    commission_rate NUMERIC(5,4),
    commission_amount NUMERIC(10,2) DEFAULT 0,
    net_commission NUMERIC(10,2) DEFAULT 0,
    commission_status TEXT DEFAULT 'pending' CHECK (commission_status IN ('pending', 'confirmed', 'paid', 'rejected')),
    -- 日期
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 状态
    policy_status TEXT DEFAULT 'active' CHECK (policy_status IN ('active', 'expired', 'cancelled', 'pending')),
    renewal_status TEXT CHECK (renewal_status IN ('pending', 'contacted', 'quoted', 'renewed', 'lost')),
    -- 关联车险
    related_car_policy_id UUID REFERENCES public.car_policies(id),
    -- 保障信息
    coverage_amount NUMERIC(14,2),
    coverage_details JSONB DEFAULT '{}',
    -- 附件
    attachment_urls TEXT[],
    -- 备注
    remark TEXT,
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_noncar_customer ON noncar_policies(customer_id);
CREATE INDEX IF NOT EXISTS idx_noncar_type ON noncar_policies(insurance_type);
CREATE INDEX IF NOT EXISTS idx_noncar_end_date ON noncar_policies(end_date) WHERE policy_status = 'active';

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 模块4：年审保养管理
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 保养记录表
CREATE TABLE IF NOT EXISTS public.service_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    plate TEXT,
    -- 服务类型
    service_type TEXT NOT NULL CHECK (service_type IN (
        '常规保养', '大保养', '维修', '年审', '过户', '上牌', '过户提档', '违章处理',
        '补领行驶证', '补领车牌', '改色', '改装', '加装', '其他'
    )),
    -- 服务信息
    service_date DATE NOT NULL,
    mileage INTEGER,                          -- 行驶里程
    service_provider TEXT,                    -- 服务商名称
    service_provider_contact TEXT,            -- 服务商联系方式
    service_provider_address TEXT,             -- 服务商地址
    -- 费用
    service_fee NUMERIC(10,2) DEFAULT 0,      -- 服务费
    parts_fee NUMERIC(10,2) DEFAULT 0,        -- 配件费
    total_fee NUMERIC(10,2) DEFAULT 0,        -- 总费用
    payment_status TEXT DEFAULT 'paid' CHECK (payment_status IN ('paid', 'unpaid', 'partial')),
    -- 佣金/返利
    rebate_amount NUMERIC(10,2) DEFAULT 0,    -- 返利金额
    rebate_status TEXT DEFAULT 'pending' CHECK (rebate_status IN ('pending', 'confirmed', 'received')),
    -- 详情
    service_items TEXT[],                    -- 服务项目列表
    service_remark TEXT,
    next_service_mileage INTEGER,             -- 下次保养里程
    next_service_date DATE,                   -- 下次保养日期
    next_remind_date DATE,                    -- 下次提醒日期
    -- 附件
    attachment_urls TEXT[],
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_svc_customer ON service_records(customer_id);
CREATE INDEX IF NOT EXISTS idx_svc_vehicle ON service_records(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_svc_type ON service_records(service_type);
CREATE INDEX IF NOT EXISTS idx_svc_date ON service_records(service_date DESC);
CREATE INDEX IF NOT EXISTS idx_svc_next_remind ON service_records(next_remind_date) WHERE next_remind_date IS NOT NULL AND is_deleted = FALSE;

-- 服务商管理表
CREATE TABLE IF NOT EXISTS public.service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('4S店', '修理厂', '养护中心', '美容店', '年审站', '车管所', '配件商', '其他')),
    contact_person TEXT,
    phone TEXT,
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    -- 合作信息
    cooperation_start DATE,
    cooperation_end DATE,
    rebate_rate NUMERIC(5,4) DEFAULT 0,       -- 返利比例
    rebate_remark TEXT,
    -- 评价
    rating NUMERIC(2,1) DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    -- 状态
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    -- 审计
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sp_type ON service_providers(type);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 模块5：汽车后市场服务
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 后市场订单表
CREATE TABLE IF NOT EXISTS public.am_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_no TEXT UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    plate TEXT,
    -- 订单类型
    order_type TEXT NOT NULL CHECK (order_type IN (
        '违章查询', '道路救援', '代驾服务', '洗车美容', '改装升级',
        '配件销售', '加油卡', '停车服务', '充电服务', '租车服务', '其他'
    )),
    -- 服务信息
    service_date DATE,
    service_provider_id UUID REFERENCES public.service_providers(id),
    service_provider_name TEXT,
    -- 商品/服务明细
    items JSONB DEFAULT '[]',   -- [{name, quantity, unit_price, amount}]
    -- 费用
    subtotal NUMERIC(10,2) DEFAULT 0,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    total_amount NUMERIC(10,2) DEFAULT 0,
    payment_method TEXT CHECK (payment_method IN ('微信', '支付宝', '现金', '银行转账', '其他')),
    payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
    paid_at TIMESTAMPTZ,
    -- 佣金/返利
    commission_amount NUMERIC(10,2) DEFAULT 0,
    rebate_amount NUMERIC(10,2) DEFAULT 0,
    -- 状态
    order_status TEXT DEFAULT 'pending' CHECK (order_status IN ('pending', 'processing', 'completed', 'cancelled', 'refunded')),
    completion_date DATE,
    -- 评价
    rating NUMERIC(2,1),
    rating_comment TEXT,
    -- 备注
    remark TEXT,
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_am_customer ON am_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_am_type ON am_orders(order_type);
CREATE INDEX IF NOT EXISTS idx_am_status ON am_orders(order_status);
CREATE INDEX IF NOT EXISTS idx_am_date ON am_orders(created_at DESC);

-- 配件/商品目录表
CREATE TABLE IF NOT EXISTS public.am_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    brand TEXT,
    model_spec TEXT,
    unit TEXT DEFAULT '个',
    cost_price NUMERIC(10,2) DEFAULT 0,
    retail_price NUMERIC(10,2) DEFAULT 0,
    stock_quantity INTEGER DEFAULT 0,
    supplier_id UUID REFERENCES public.service_providers(id),
    image_url TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_prod_category ON am_products(category);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 模块6：汽车消费金融
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 金融合同表
CREATE TABLE IF NOT EXISTS public.finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_no TEXT UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    plate TEXT,
    -- 贷款信息
    finance_type TEXT NOT NULL CHECK (finance_type IN ('车贷', '抵押贷', '信用贷', '融资租赁', '其他')),
    loan_amount NUMERIC(14,2) NOT NULL,           -- 贷款总额
    loan_term INTEGER NOT NULL,                    -- 贷款期数（月）
    annual_rate NUMERIC(6,4) NOT NULL,            -- 年利率
    monthly_rate NUMERIC(6,4) NOT NULL,           -- 月利率
    monthly_payment NUMERIC(12,2) NOT NULL,       -- 月供金额
    total_interest NUMERIC(12,2) NOT NULL,        -- 总利息
    total_amount NUMERIC(14,2) NOT NULL,          -- 还款总额
    -- 首付
    down_payment NUMERIC(14,2) NOT NULL,          -- 首付金额
    down_payment_rate NUMERIC(5,4),                -- 首付比例
    vehicle_price NUMERIC(14,2) NOT NULL,         -- 车辆总价
    -- 金融机构
    financial_institution TEXT NOT NULL,
    institution_type TEXT CHECK (institution_type IN ('银行', '汽车金融公司', '融资租赁公司', '小贷公司', '其他')),
    -- 日期
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 还款计划
    repayment_schedule JSONB DEFAULT '[]',         -- [{period, due_date, principal, interest, balance, status}]
    -- 已还情况
    repaid_periods INTEGER DEFAULT 0,
    repaid_amount NUMERIC(14,2) DEFAULT 0,
    outstanding_amount NUMERIC(14,2) NOT NULL,
    overdue_periods INTEGER DEFAULT 0,
    overdue_amount NUMERIC(14,2) DEFAULT 0,
    -- 状态
    contract_status TEXT DEFAULT 'active' CHECK (contract_status IN ('active', 'completed', 'cancelled', 'overdue', 'default')),
    -- 担保信息
    guarantee_type TEXT CHECK (guarantee_type IN ('信用', '抵押', '质押', '担保人')),
    collateral_info JSONB DEFAULT '{}',
    -- 附件
    attachment_urls TEXT[],
    -- 备注
    remark TEXT,
    -- 审计
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_fc_customer ON finance_contracts(customer_id);
CREATE INDEX IF NOT EXISTS idx_fc_plate ON finance_contracts(plate);
CREATE INDEX IF NOT EXISTS idx_fc_status ON finance_contracts(contract_status);
CREATE INDEX IF NOT EXISTS idx_fc_end_date ON finance_contracts(end_date);

-- 还款记录表
CREATE TABLE IF NOT EXISTS public.repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES public.finance_contracts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id),
    -- 期次信息
    period INTEGER NOT NULL,
    due_date DATE NOT NULL,
    -- 金额
    principal NUMERIC(12,2) NOT NULL,
    interest NUMERIC(12,2) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    -- 还款情况
    actual_date DATE,
    actual_amount NUMERIC(12,2),
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'overdue', 'advanced')),
    overdue_days INTEGER DEFAULT 0,
    penalty_interest NUMERIC(12,2) DEFAULT 0,
    -- 逾期记录
    is_overdue BOOLEAN DEFAULT FALSE,
    overdue_start_date DATE,
    -- 附件
    receipt_url TEXT,
    -- 审计
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rr_contract ON repayment_records(contract_id);
CREATE INDEX IF NOT EXISTS idx_rr_customer ON repayment_records(customer_id);
CREATE INDEX IF NOT EXISTS idx_rr_due_date ON repayment_records(due_date);
CREATE INDEX IF NOT EXISTS idx_rr_status ON repayment_records(payment_status) WHERE payment_status IN ('pending', 'overdue');

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 通用层：跟进记录 + 提醒 + 消息通知
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 跟进记录表（通用，所有模块共用）
CREATE TABLE IF NOT EXISTS public.followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    -- 关联业务（可选）
    related_module TEXT CHECK (related_module IN ('car_policy', 'noncar_policy', 'service', 'am_order', 'finance', 'general')),
    related_id UUID,
    -- 跟进信息
    followup_type TEXT NOT NULL CHECK (followup_type IN (
        '电话联系', '微信沟通', '上门拜访', '短信联系', '邮件联系',
        '报价跟进', '促成签单', '售后回访', '投诉处理', '其他'
    )),
    followup_content TEXT NOT NULL,
    followup_result TEXT,
    -- 下次跟进
    next_followup_date DATE,
    next_followup_remark TEXT,
    -- 状态
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    -- 附件
    attachment_urls TEXT[],
    -- 审计
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fu_customer ON followups(customer_id);
CREATE INDEX IF NOT EXISTS idx_fu_next ON followups(next_followup_date) WHERE is_completed = FALSE;
CREATE INDEX IF NOT EXISTS idx_fu_created ON followups(created_at DESC);

-- 提醒任务表
CREATE TABLE IF NOT EXISTS public.reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    -- 关联
    related_module TEXT,
    related_id UUID,
    -- 提醒内容
    title TEXT NOT NULL,
    content TEXT,
    reminder_type TEXT NOT NULL CHECK (reminder_type IN (
        '续保提醒', '年审提醒', '保养提醒', '还款提醒', '生日祝福',
        '节日关怀', '理赔跟进', '合同到期', '其他'
    )),
    -- 时间
    remind_at TIMESTAMPTZ NOT NULL,
    -- 状态
    reminder_status TEXT DEFAULT 'pending' CHECK (reminder_status IN ('pending', 'done', 'cancelled', 'snoozed')),
    done_at TIMESTAMPTZ,
    done_remark TEXT,
    snooze_count INTEGER DEFAULT 0,
    -- 推送
    push_channels TEXT[],  -- ['app', 'sms', 'wechat']
    push_status TEXT DEFAULT 'pending',
    -- 审计
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rem_customer ON reminders(customer_id);
CREATE INDEX IF NOT EXISTS idx_rem_at ON reminders(remind_at) WHERE reminder_status = 'pending';

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RLS策略（数据安全）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 启用RLS
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.am_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

-- 客户表RLS策略：管理员看全部，业务员只看自己
CREATE POLICY "Customers: Admin/Manager view all" ON public.customers
    FOR SELECT USING (
        auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin', 'manager'))
    );

CREATE POLICY "Customers: Agent view own" ON public.customers
    FOR SELECT USING (owner_user_id = auth.uid());

CREATE POLICY "Customers: Admin write" ON public.customers
    FOR ALL USING (
        auth.uid() IN (SELECT id FROM public.users WHERE role = 'admin')
    );

CREATE POLICY "Customers: Manager write own team" ON public.customers
    FOR INSERT WITH CHECK (owner_user_id = auth.uid());

-- 审计日志：admin可读，system可写
CREATE POLICY "Audit: Admin read" ON public.audit_logs
    FOR SELECT USING (
        auth.uid() IN (SELECT id FROM public.users WHERE role = 'admin')
    );

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 触发器：自动更新updated_at + 审计日志
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 自动更新updated_at的函数
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS 
BEGIN
    NEW.updated_at = NOW();
    NEW.version = COALESCE(OLD.version, 0) + 1;
    RETURN NEW;
END;
 LANGUAGE plpgsql;

-- 为所有表创建updated_at触发器
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_car_policies_updated_at BEFORE UPDATE ON public.car_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_noncar_policies_updated_at BEFORE UPDATE ON public.noncar_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_vehicles_updated_at BEFORE UPDATE ON public.vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_service_records_updated_at BEFORE UPDATE ON public.service_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_am_orders_updated_at BEFORE UPDATE ON public.am_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_finance_contracts_updated_at BEFORE UPDATE ON public.finance_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 审计日志记录触发器
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS 
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs (table_name, record_id, action, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP::audit_logs.action%TYPE, to_jsonb(NEW), auth.uid());
    ELSIF TG_OP = 'UPDATE' AND OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
        INSERT INTO public.audit_logs (table_name, record_id, action, old_data, new_data, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), to_jsonb(NEW), auth.uid());
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (table_name, record_id, action, old_data, new_data, changed_fields, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW),
                array_remove(ARRAY[
                    CASE WHEN OLD.name IS DISTINCT FROM NEW.name THEN 'name' END,
                    CASE WHEN OLD.phone IS DISTINCT FROM NEW.phone THEN 'phone' END,
                    CASE WHEN OLD.total_premium IS DISTINCT FROM NEW.total_premium THEN 'total_premium' END
                ], NULL), auth.uid());
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
 LANGUAGE plpgsql SECURITY DEFINER;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 视图：可对外展示的脱敏数据
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 客户公开视图（脱敏）
CREATE OR REPLACE VIEW public.v_customers_public AS
SELECT
    id,
    name,
    phone,
    province,
    city,
    district,
    customer_level,
    customer_tags,
    has_main_vehicle,
    main_plate,
    main_brand,
    main_model,
    total_orders,
    last_service_date,
    created_at
FROM public.customers
WHERE is_deleted = FALSE;

-- 客户统计视图
CREATE OR REPLACE VIEW public.v_customer_stats AS
SELECT
    c.id,
    c.name,
    c.phone,
    c.customer_level,
    COUNT(DISTINCT cp.id) FILTER (WHERE cp.policy_status = 'active') as active_car_policies,
    COUNT(DISTINCT np.id) FILTER (WHERE np.policy_status = 'active') as active_noncar_policies,
    COUNT(DISTINCT v.id) as total_vehicles,
    COUNT(DISTINCT sr.id) as total_services,
    COUNT(DISTINCT ao.id) as total_orders,
    COALESCE(SUM(cp.total_premium), 0) as total_premium,
    COALESCE(SUM(cp.commission_amount), 0) as total_commission,
    c.last_service_date
FROM public.customers c
LEFT JOIN public.car_policies cp ON c.id = cp.customer_id AND cp.is_deleted = FALSE
LEFT JOIN public.noncar_policies np ON c.id = np.customer_id AND np.is_deleted = FALSE
LEFT JOIN public.vehicles v ON c.id = v.customer_id AND v.is_deleted = FALSE
LEFT JOIN public.service_records sr ON c.id = sr.customer_id AND sr.is_deleted = FALSE
LEFT JOIN public.am_orders ao ON c.id = ao.customer_id AND ao.is_deleted = FALSE
WHERE c.is_deleted = FALSE
GROUP BY c.id, c.name, c.phone, c.customer_level, c.last_service_date;

-- 待办事项视图（合并所有待办）
CREATE OR REPLACE VIEW public.v_pending_tasks AS
SELECT 'car_renewal' as task_type, end_date as due_date, customer_id, id, company as title, total_premium as amount
FROM public.car_policies WHERE policy_status = 'active' AND is_deleted = FALSE
UNION ALL
SELECT 'noncar_renewal', end_date, customer_id, id, product_name, total_premium
FROM public.noncar_policies WHERE policy_status = 'active' AND is_deleted = FALSE
UNION ALL
SELECT 'annual_inspection', annual_inspection_date, customer_id, id, plate, NULL
FROM public.vehicles WHERE is_deleted = FALSE
UNION ALL
SELECT 'service_reminder', next_remind_date, customer_id, id, service_type, total_fee
FROM public.service_records WHERE is_deleted = FALSE AND next_remind_date IS NOT NULL
UNION ALL
SELECT 'repayment', due_date, customer_id, id, '还款', amount
FROM public.repayment_records WHERE payment_status = 'pending'
UNION ALL
SELECT 'followup', next_followup_date, customer_id, id, followup_content, NULL
FROM public.followups WHERE is_completed = FALSE AND next_followup_date IS NOT NULL;
