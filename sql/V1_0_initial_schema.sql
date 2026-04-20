-- ============================================================
-- 汽车全生态客户管理系统 - 数据库初始化Schema
-- 版本: V1.0 | 日期: 2026-04-19
-- 作者: 痞老板
-- 说明: 
--   1. 所有表均包含审计字段(created_at/updated_at/created_by等)
--   2. 采用软删除(is_deleted)保留数据可追溯性
--   3. 所有模块通过customer_id关联统一客户中心
--   4. Supabase RLS策略另行配置(见 rls_policies.sql)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. 枚举类型定义 (ENUM)
-- ============================================================

-- 用户角色
CREATE TYPE user_role AS ENUM (
    'admin',        -- 系统管理员(全部权限)
    'manager',      -- 经理(所有数据读写+统计)
    'agent',        -- 业务员(本人数据读写)
    'finance',      -- 财务(财务数据只读+佣金核算)
    'viewer'        -- 查看者(只读)
);

-- 客户类型
CREATE TYPE customer_type AS ENUM (
    'individual',   -- 个人
    'company'        -- 企业
);

-- 客户来源
CREATE TYPE customer_source AS ENUM (
    'walk_in',      -- 自然到店
    'referral',     -- 客户转介绍
    'online',       -- 网络获客
    'partner',      -- 合作渠道
    'renewal',      -- 续保客户
    'other'         -- 其他
);

-- 客户状态
CREATE TYPE customer_status AS ENUM (
    'active',       -- 活跃
    'inactive',     -- 不活跃
    'lost'          -- 流失
);

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM (
    'normal',       -- 正常
    'annual_review',-- 年审到期
    'insurance_due',-- 保险到期
    'scrapped'      -- 已报废
);

-- 保险类型
CREATE TYPE insurance_type AS ENUM (
    'compulsory',   -- 交强险
    'commercial',   -- 商业险
    'third_party',  -- 三者险
    'driver',       -- 驾乘险
    'theft',        -- 盗抢险
    'fire',         -- 自燃险
    'water',        -- 涉水险
    'scratch',      -- 划痕险
    'glass',        -- 玻璃险
    'liability',    -- 责任险
    'accident',     -- 意外险
    'health',       -- 健康险
    'property',     -- 家财险
    'other'         -- 其他
);

-- 保单状态
CREATE TYPE policy_status AS ENUM (
    'pending',       -- 待生效
    'active',        -- 生效中
    'expired',       -- 已过期
    'cancelled',     -- 已退保
    'terminated'    -- 已终止
);

-- 支付状态
CREATE TYPE payment_status AS ENUM (
    'unpaid',        -- 未付款
    'paid',          -- 已付款
    'partial',       -- 部分付款
    'overdue',       -- 已逾期
    'refunded'       -- 已退款
);

-- 服务类型
CREATE TYPE service_type AS ENUM (
    'annual_review', -- 年审
    'maintenance',   -- 保养
    'repair',        -- 维修
    'beauty',        -- 美容
    'rescue',        -- 道路救援
    'parts',         -- 配件
    'modification',  -- 改装
    'carwash',       -- 洗车
    'other'          -- 其他
);

-- 服务状态
CREATE TYPE service_status AS ENUM (
    'pending',       -- 待处理
    'in_progress',   -- 进行中
    'completed',     -- 已完成
    'cancelled'     -- 已取消
);

-- 金融产品类型
CREATE TYPE finance_product_type AS ENUM (
    'car_loan',     -- 车贷
    'installment',   -- 分期
    'lease',        -- 融资租赁
    'guarantee'     -- 担保服务
);

-- 金融状态
CREATE TYPE finance_status AS ENUM (
    'pending',       -- 待审批
    'approved',      -- 已批准
    'rejected',      -- 已拒绝
    'active',        -- 还款中
    'completed',     -- 已结清
    'overdue'        -- 逾期
);

-- ============================================================
-- 2. 公共审计字段View (简化表定义)
-- ============================================================

COMMENT ON TYPE user_role IS '用户角色: admin=系统管理员, manager=经理, agent=业务员, finance=财务, viewer=查看者';
COMMENT ON TYPE customer_type IS '客户类型: individual=个人, company=企业';
COMMENT ON TYPE customer_source IS '客户来源: walk_in=到店, referral=转介绍, online=网络, partner=合作渠道, renewal=续保';
COMMENT ON TYPE customer_status IS '客户状态: active=活跃, inactive=不活跃, lost=流失';
COMMENT ON TYPE vehicle_status IS '车辆状态: normal=正常, annual_review=年审到期, insurance_due=保险到期, scrapped=报废';
COMMENT ON TYPE insurance_type IS '保险类型: compulsory=交强险, commercial=商业险, third_party=三者险等';
COMMENT ON TYPE policy_status IS '保单状态: pending=待生效, active=生效中, expired=已过期, cancelled=已退保, terminated=已终止';
COMMENT ON TYPE payment_status IS '支付状态: unpaid=未付款, paid=已付款, partial=部分, overdue=逾期, refunded=已退款';
COMMENT ON TYPE service_type IS '服务类型: annual_review=年审, maintenance=保养, repair=维修等';
COMMENT ON TYPE service_status IS '服务状态: pending=待处理, in_progress=进行中, completed=已完成, cancelled=已取消';
COMMENT ON TYPE finance_product_type IS '金融产品: car_loan=车贷, installment=分期, lease=融资租赁, guarantee=担保';
COMMENT ON TYPE finance_status IS '金融状态: pending=待审批, approved=已批准, rejected=已拒绝, active=还款中, completed=已结清, overdue=逾期';

-- ============================================================
-- 3. 核心表 - 用户与认证
-- ============================================================

-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash TEXT NOT NULL,
    real_name VARCHAR(100) NOT NULL,
    nickname VARCHAR(100),
    role user_role NOT NULL DEFAULT 'agent',
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT users_email_format CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT users_phone_format CHECK (phone IS NULL OR phone ~ '^[0-9]{11}$')
);

CREATE INDEX idx_users_email ON users(email) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_phone ON users(phone) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_role ON users(role);

-- ============================================================
-- 4. 核心表 - 客户中心 (统一客户ID，所有模块以此为中心)
-- ============================================================

-- 客户主表
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基本信息
    customer_type customer_type NOT NULL DEFAULT 'individual',
    real_name VARCHAR(100) NOT NULL,
    id_card VARCHAR(20),
    phone VARCHAR(20) NOT NULL,
    phone_2 VARCHAR(20),                    -- 备用电话
    email VARCHAR(100),
    wechat VARCHAR(50),                      -- 微信号
    qq VARCHAR(20),
    
    -- 企业信息(当customer_type='company'时填写)
    company_name VARCHAR(200),
    company_address TEXT,
    tax_id VARCHAR(50),                     -- 税号/统一社会信用代码
    
    -- 客户画像
    source customer_source NOT NULL DEFAULT 'walk_in',
    source_detail TEXT,                      -- 来源详情(如转介绍人姓名)
    birthday DATE,
    gender VARCHAR(10),
    occupation VARCHAR(100),                -- 职业
    annual_income VARCHAR(50),              -- 年收入
    marital_status VARCHAR(20),
    
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address TEXT,
    
    -- 状态与评分
    status customer_status NOT NULL DEFAULT 'active',
    customer_level VARCHAR(20) DEFAULT 'C',  -- A/B/C级客户
    tags TEXT[],                             -- 标签数组
    remark TEXT,
    
    -- 归属
    owner_id UUID REFERENCES users(id),      -- 归属业务员
    team_id UUID,                            -- 归属团队(预留)
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT customers_phone_format CHECK (phone ~ '^[0-9]{11}$'),
    CONSTRAINT customers_id_card_format CHECK (id_card IS NULL OR length(id_card) >= 15)
);

CREATE INDEX idx_customers_phone ON customers(phone) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_id_card ON customers(id_card) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_owner ON customers(owner_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_level ON customers(customer_level);
CREATE INDEX idx_customers_created_at ON customers(created_at DESC);

-- ============================================================
-- 5. 车辆表 (一客户多车)
-- ============================================================

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 车辆基础信息
    plate_number VARCHAR(20) NOT NULL,       -- 车牌号
    vehicle_type VARCHAR(30),               -- 车辆类型(轿车/SUV/货车等)
    brand VARCHAR(50),                      -- 品牌
    model VARCHAR(50),                      -- 型号
    sub_model VARCHAR(50),                  -- 子型号
    year VARCHAR(10),                       -- 年款
    color VARCHAR(20),                      -- 颜色
    vin VARCHAR(50) NOT NULL UNIQUE,        -- 车架号(唯一)
    engine_no VARCHAR(50),                  -- 发动机号
    
    -- 证件信息
    register_date DATE,                     -- 注册日期
    issue_date DATE,                        -- 发证日期
    fuel_type VARCHAR(20),                  -- 燃料类型(汽油/电动/混动)
    emission_standard VARCHAR(20),          -- 排放标准
    
    -- 商业信息
    purchase_price DECIMAL(12,2),           -- 购车价格
    current_value DECIMAL(12,2),            -- 当前估值
    
    -- 状态
    status vehicle_status DEFAULT 'normal',
    is_main BOOLEAN DEFAULT FALSE,          -- 是否主车辆
    
    -- 年审信息
    annual_review_date DATE,                -- 年审到期日期
    annual_review_reminder BOOLEAN DEFAULT TRUE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT vehicles_plate_unique UNIQUE (plate_number) WHERE is_deleted = FALSE,
    CONSTRAINT vehicles_vin_unique UNIQUE (vin) WHERE is_deleted = FALSE
);

CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_vin ON vehicles(vin) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_annual_review ON vehicles(annual_review_date) WHERE is_deleted = FALSE;

-- ============================================================
-- 6. 模块1: 车险保单表
-- ============================================================

CREATE TABLE car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    
    -- 保单基本信息
    policy_no VARCHAR(100) NOT NULL,        -- 保单号
    insurance_company VARCHAR(100) NOT NULL, -- 承保公司
    insurance_type insurance_type NOT NULL,  -- 保险类型
    
    -- 时间
    start_date DATE NOT NULL,               -- 生效日期
    end_date DATE NOT NULL,                 -- 到期日期
    issue_date DATE DEFAULT CURRENT_DATE,   -- 出单日期
    
    -- 保费信息(单位:元)
    premium DECIMAL(10,2) NOT NULL,          -- 保费
    commission DECIMAL(10,2),               -- 佣金
    commission_rate DECIMAL(5,4),           -- 佣金比例
    net_premium DECIMAL(10,2),               -- 净保费(保费-佣金)
    
    -- 状态
    status policy_status DEFAULT 'pending',
    
    -- 付款
    payment_status payment_status DEFAULT 'unpaid',
    payment_date DATE,
    payment_method VARCHAR(50),
    
    -- 保险详情(JSON,灵活存储各险种详情)
    coverage_details JSONB,
    /*
    格式示例:
    {
        "第三方责任险": {"amount": 1000000, "premium": 1250.00},
        "车辆损失险": {"amount": 50000, "premium": 1800.00},
        "司机座位险": {"amount": 100000, "premium": 150.00},
        "乘客座位险": {"amount": 100000, "premium": 200.00}
    }
    */
    
    -- 理赔信息
    claim_count INTEGER DEFAULT 0,          -- 理赔次数
    claim_amount DECIMAL(10,2) DEFAULT 0,   -- 理赔金额
    last_claim_date DATE,
    
    -- 来源
    renewal_from VARCHAR(100),              -- 续保来源(哪家保险公司)
    channel VARCHAR(50),                    -- 渠道
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT car_policies_policy_no_unique UNIQUE (policy_no) WHERE is_deleted = FALSE,
    CONSTRAINT car_policies_dates CHECK (end_date > start_date),
    CONSTRAINT car_policies_premium CHECK (premium >= 0)
);

CREATE INDEX idx_car_policies_customer ON car_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_end_date ON car_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_status ON car_policies(status);
CREATE INDEX idx_car_policies_company ON car_policies(insurance_company);
CREATE INDEX idx_car_policies_renewal ON car_policies(renewal_from) WHERE is_deleted = FALSE;

-- ============================================================
-- 7. 模块1: 理赔记录表
-- ============================================================

CREATE TABLE car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES car_policies(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    
    -- 理赔信息
    claim_no VARCHAR(100) NOT NULL,         -- 理赔号
    claim_type VARCHAR(50),                  -- 理赔类型
    accident_date TIMESTAMPTZ,              -- 事故时间
    accident_location TEXT,                 -- 事故地点
    accident_description TEXT,              -- 事故描述
    
    -- 金额
    estimated_amount DECIMAL(10,2),          -- 预估金额
    approved_amount DECIMAL(10,2),           -- 核定金额
    actual_amount DECIMAL(10,2),             -- 实际赔付
    
    -- 状态
    status VARCHAR(50) DEFAULT 'pending',   -- pending/approved/paid/rejected
    handler VARCHAR(100),                   -- 处理人
    settlement_date DATE,                   -- 结算日期
    
    -- 关联保单时信息快照(保单变更后仍可追溯)
    policy_no_snapshot VARCHAR(100),
    insurance_company_snapshot VARCHAR(100),
    plate_number_snapshot VARCHAR(20),
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT car_claims_claim_no_unique UNIQUE (claim_no) WHERE is_deleted = FALSE
);

CREATE INDEX idx_car_claims_policy ON car_claims(policy_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_claims_customer ON car_claims(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_claims_status ON car_claims(status);

-- ============================================================
-- 8. 模块2: 非车险保单表
-- ============================================================

CREATE TABLE noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 关联车险(可选,用于交叉销售追踪)
    linked_car_policy_id UUID REFERENCES car_policies(id),
    linked_vehicle_id UUID REFERENCES vehicles(id),
    
    -- 保单信息
    policy_no VARCHAR(100) NOT NULL,
    insurance_type insurance_type NOT NULL,
    insurance_company VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200),               -- 保单名称/产品名
    
    -- 被保险人信息
    insured_name VARCHAR(100),              -- 被保险人姓名
    insured_id_card VARCHAR(20),            -- 被保险人身份证
    insured_phone VARCHAR(20),               -- 被保险人电话
    
    -- 时间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    issue_date DATE DEFAULT CURRENT_DATE,
    
    -- 保费
    premium DECIMAL(10,2) NOT NULL,
    commission DECIMAL(10,2),
    commission_rate DECIMAL(5,4),
    net_premium DECIMAL(10,2),
    
    -- 状态
    status policy_status DEFAULT 'pending',
    payment_status payment_status DEFAULT 'unpaid',
    payment_date DATE,
    
    -- 详情(JSON)
    coverage_details JSONB,
    
    -- 来源
    channel VARCHAR(50),
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT noncar_policies_policy_no_unique UNIQUE (policy_no) WHERE is_deleted = FALSE,
    CONSTRAINT noncar_policies_dates CHECK (end_date > start_date)
);

CREATE INDEX idx_noncar_policies_customer ON noncar_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_type ON noncar_policies(insurance_type);
CREATE INDEX idx_noncar_policies_end_date ON noncar_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_linked_car ON noncar_policies(linked_car_policy_id) WHERE is_deleted = FALSE;

-- ============================================================
-- 9. 模块3: 年审保养记录表
-- ============================================================

CREATE TABLE vehicle_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    
    -- 服务信息
    service_type service_type NOT NULL,
    service_name VARCHAR(200),              -- 服务名称(如"小保养"/"大保养")
    
    -- 时间
    service_date DATE NOT NULL,              -- 服务日期
    next_service_date DATE,                  -- 下次服务日期
    next_service_mileage INTEGER,            -- 下次保养里程
    
    -- 地点与对象
    service_provider VARCHAR(200),           -- 服务商(修理厂/4S店)
    service_provider_phone VARCHAR(20),      -- 服务商电话
    mechanic_name VARCHAR(100),             -- 技师姓名
    
    -- 车辆当时状态
    mileage INTEGER,                        -- 当时里程数
    plate_number_snapshot VARCHAR(20),
    
    -- 金额
    service_fee DECIMAL(10,2) DEFAULT 0,    -- 服务费
    parts_fee DECIMAL(10,2) DEFAULT 0,      -- 配件费
    total_fee DECIMAL(10,2) DEFAULT 0,      -- 总费用
    commission DECIMAL(10,2),               -- 返佣
    payment_status payment_status DEFAULT 'unpaid',
    
    -- 服务内容(JSON)
    service_items JSONB,
    /*
    格式示例:
    {
        "保养项目": ["更换机油", "更换机滤"],
        "使用配件": ["嘉实多全合成5W-30", "马勒机滤"],
        "配件数量": {"机油": "4L", "机滤": "1个"}
    }
    */
    
    -- 状态
    status service_status DEFAULT 'completed',
    
    -- 年审专用字段
    annual_review_result VARCHAR(20),        -- 年审结果(pass/fail)
    annual_review_certificate_no VARCHAR(50),-- 年审证书编号
    next_annual_review_date DATE,           -- 下次年审日期
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_vehicle_services_customer ON vehicle_services(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicle_services_vehicle ON vehicle_services(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicle_services_type ON vehicle_services(service_type);
CREATE INDEX idx_vehicle_services_date ON vehicle_services(service_date DESC);
CREATE INDEX idx_vehicle_services_next ON vehicle_services(next_service_date) WHERE next_service_date IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX idx_vehicle_services_annual ON vehicle_services(next_annual_review_date) WHERE next_annual_review_date IS NOT NULL AND is_deleted = FALSE;

-- ============================================================
-- 10. 模块3: 合作服务商表
-- ============================================================

CREATE TABLE service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_name VARCHAR(200) NOT NULL,
    provider_type VARCHAR(50) NOT NULL,      -- 4S店/修理厂/养护店/救援公司
    
    -- 联系方式
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    phone_2 VARCHAR(20),
    address TEXT,
    
    -- 位置
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    
    -- 服务能力
    service_types service_type[],           -- 可提供的服务类型数组
    brands VARCHAR(200)[],                   -- 可服务品牌
    availability VARCHAR(20) DEFAULT '24h',  -- 可用时间
    
    -- 合作信息
    is_cooperated BOOLEAN DEFAULT FALSE,
    cooperation_start_date DATE,
    commission_rate DECIMAL(5,4),           -- 返佣比例
    discount_rate DECIMAL(5,4),             -- 客户折扣
    
    -- 评分
    rating DECIMAL(3,2) DEFAULT 0,          -- 评分(5分制)
    review_count INTEGER DEFAULT 0,
    
    -- 状态
    is_active BOOLEAN DEFAULT TRUE,
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_service_providers_type ON service_providers(provider_type);
CREATE INDEX idx_service_providers_city ON service_providers(city);
CREATE INDEX idx_service_providers_active ON service_providers(is_active) WHERE is_deleted = FALSE;

-- ============================================================
-- 11. 模块4: 后市场订单表
-- ============================================================

CREATE TABLE aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 订单信息
    order_no VARCHAR(50) NOT NULL,          -- 订单号
    order_type VARCHAR(50) NOT NULL,         -- 订单类型(违章/救援/配件/美容等)
    
    -- 商品/服务信息
    product_name VARCHAR(200),
    product_brand VARCHAR(100),
    product_model VARCHAR(100),
    
    -- 数量与金额
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(10,2),
    total_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    actual_amount DECIMAL(10,2),             -- 实付金额
    
    -- 服务信息
    service_date DATE,
    service_address TEXT,
    service_provider_id UUID REFERENCES service_providers(id),
    
    -- 状态
    status VARCHAR(50) DEFAULT 'pending',   -- pending/paid/in_progress/completed/cancelled
    payment_status payment_status DEFAULT 'unpaid',
    payment_method VARCHAR(50),
    payment_date DATE,
    
    -- 违章查询专用
    violation_date DATE,
    violation_location TEXT,
    violation_amount DECIMAL(10,2),          -- 罚款金额
    violation_points INTEGER,                -- 扣分
    has_handled BOOLEAN DEFAULT FALSE,      -- 是否已处理
    
    -- 物流信息
    express_company VARCHAR(50),
    tracking_no VARCHAR(100),
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT aftermarket_orders_no_unique UNIQUE (order_no) WHERE is_deleted = FALSE,
    CONSTRAINT aftermarket_orders_amount CHECK (total_amount >= 0)
);

CREATE INDEX idx_aftermarket_orders_customer ON aftermarket_orders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_aftermarket_orders_type ON aftermarket_orders(order_type);
CREATE INDEX idx_aftermarket_orders_status ON aftermarket_orders(status);
CREATE INDEX idx_aftermarket_orders_date ON aftermarket_orders(created_at DESC);

-- ============================================================
-- 12. 模块5: 汽车消费金融表
-- ============================================================

CREATE TABLE finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 合同信息
    contract_no VARCHAR(100) NOT NULL,
    product_type finance_product_type NOT NULL,
    product_name VARCHAR(200),              -- 产品名称
    
    -- 合作机构
    financial_institution VARCHAR(200),     -- 金融机构(银行/融资公司)
    institution_phone VARCHAR(20),           -- 机构电话
    
    -- 借款人信息
    borrower_name VARCHAR(100),             -- 借款人
    borrower_id_card VARCHAR(20),
    borrower_phone VARCHAR(20),
    
    -- 担保信息
    guarantor_name VARCHAR(100),            -- 担保人
    guarantor_id_card VARCHAR(20),
    guarantor_phone VARCHAR(20),
    guarantor_relationship VARCHAR(50),     -- 与借款人关系
    
    -- 金额
    loan_amount DECIMAL(12,2) NOT NULL,     -- 贷款金额
    down_payment DECIMAL(12,2),             -- 首付金额
    interest_rate DECIMAL(8,4),             -- 年利率
    loan_term INTEGER,                      -- 贷款期限(月)
    monthly_payment DECIMAL(10,2),          -- 月供
    total_interest DECIMAL(10,2),          -- 总利息
    total_repayment DECIMAL(12,2),         -- 还款总额
    
    -- 状态
    status finance_status DEFAULT 'pending',
    
    -- 还款信息
    first_repayment_date DATE,              -- 首次还款日
    repayment_day INTEGER,                  -- 每月还款日(1-28)
    repaid_periods INTEGER DEFAULT 0,      -- 已还期数
    remaining_periods INTEGER,              -- 剩余期数
    repaid_amount DECIMAL(12,2) DEFAULT 0, -- 已还金额
    remaining_amount DECIMAL(12,2),         -- 剩余金额
    overdue_amount DECIMAL(10,2) DEFAULT 0,-- 逾期金额
    overdue_periods INTEGER DEFAULT 0,    -- 逾期期数
    
    -- 时间
    application_date DATE DEFAULT CURRENT_DATE,
    approval_date DATE,
    loan_start_date DATE,
    loan_end_date DATE,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT finance_contracts_no_unique UNIQUE (contract_no) WHERE is_deleted = FALSE,
    CONSTRAINT finance_contracts_term CHECK (loan_term > 0 AND loan_term <= 120)
);

CREATE INDEX idx_finance_contracts_customer ON finance_contracts(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_contracts_vehicle ON finance_contracts(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_contracts_status ON finance_contracts(status);
CREATE INDEX idx_finance_contracts_institution ON finance_contracts(financial_institution);

-- ============================================================
-- 13. 还款记录表
-- ============================================================

CREATE TABLE repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES finance_contracts(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 期次信息
    period INTEGER NOT NULL,               -- 期次(第几期)
    due_date DATE NOT NULL,                 -- 应还日期
    
    -- 金额
    principal DECIMAL(10,2) NOT NULL,       -- 本金
    interest DECIMAL(10,2) NOT NULL,        -- 利息
    amount DECIMAL(10,2) NOT NULL,         -- 应还总额
    actual_amount DECIMAL(10,2),            -- 实还金额
    
    -- 状态
    status VARCHAR(20) DEFAULT 'unpaid',   -- unpaid/paid/overdue/partially
    paid_date DATE,
    paid_method VARCHAR(50),
    
    -- 逾期
    overdue_days INTEGER DEFAULT 0,
    overdue_fee DECIMAL(10,2) DEFAULT 0,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_repayment_records_contract ON repayment_records(contract_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_records_customer ON repayment_records(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_records_due ON repayment_records(due_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_records_status ON repayment_records(status);

-- ============================================================
-- 14. 通用审计日志表 (全表可追溯)
-- ============================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 操作者
    operator_id UUID REFERENCES users(id),
    operator_name VARCHAR(100),
    operator_role VARCHAR(50),
    operator_ip INET,
    
    -- 操作目标
    table_name VARCHAR(100) NOT NULL,       -- 操作表名
    record_id UUID,                         -- 操作记录ID
    record_key VARCHAR(200),                -- 业务标识(如保单号/车牌号)
    
    -- 操作类型
    action VARCHAR(20) NOT NULL,            -- INSERT/UPDATE/DELETE/SELECT/LOGIN/EXPORT
    field_name VARCHAR(100),                -- 变更字段(当UPDATE时)
    
    -- 变更前后值(当UPDATE/DELETE时)
    old_value JSONB,
    new_value JSONB,
    change_summary TEXT,                    -- 变更摘要(用于展示)
    
    -- 上下文
    session_id VARCHAR(100),
    user_agent TEXT,
    request_id VARCHAR(100),               -- 请求追踪ID
    
    -- 时间
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_operator ON audit_logs(operator_id);
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_record ON audit_logs(record_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);

-- ============================================================
-- 15. 系统配置表 (KV Store)
-- ============================================================

CREATE TABLE kv_store (
    key VARCHAR(200) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    category VARCHAR(50),                   -- config/system/reminder/template
    
    -- 版本控制
    version INTEGER DEFAULT 1,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_kv_store_category ON kv_store(category) WHERE is_deleted = FALSE;

-- ============================================================
-- 16. 跟进记录表 (所有模块通用)
-- ============================================================

CREATE TABLE followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES customers(id),
    related_table VARCHAR(100),             -- 关联表名(car_policies/noncar_policies等)
    related_id UUID,                        -- 关联记录ID
    
    -- 跟进信息
    followup_type VARCHAR(50) NOT NULL,    -- 跟进类型(电话/微信/面谈/短信等)
    content TEXT NOT NULL,                 -- 跟进内容
    
    -- 意向
    customer_intent VARCHAR(50),            -- 客户意向(强烈/一般/冷淡/拒绝)
    next_followup_date DATE,               -- 下次跟进日期
    next_followup_content TEXT,            -- 下次跟进计划
    
    -- 附件
    attachments JSONB,                      -- 附件列表(图片/文件URL)
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_followups_customer ON followups(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_followups_related ON followups(related_table, related_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_followups_next ON followups(next_followup_date) WHERE next_followup_date IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX idx_followups_created_by ON followups(created_by) WHERE is_deleted = FALSE;
CREATE INDEX idx_followups_created_at ON followups(created_at DESC);

-- ============================================================
-- 17. 提醒任务表 (统一提醒中心)
-- ============================================================

CREATE TABLE reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联
    customer_id UUID REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    related_table VARCHAR(100),
    related_id UUID,
    
    -- 提醒信息
    reminder_type VARCHAR(50) NOT NULL,     -- 续保/年审/还款/保养/跟进等
    title VARCHAR(200) NOT NULL,            -- 提醒标题
    content TEXT,
    
    -- 时间
    due_date TIMESTAMPTZ NOT NULL,          -- 提醒时间
    remind_before INTEGER DEFAULT 0,        -- 提前N天提醒
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/sent/completed/dismissed
    sent_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- 通知方式
    notify_ways VARCHAR(50)[],              -- 数组: ['sms', 'wechat', 'app']
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_reminders_customer ON reminders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_reminders_due ON reminders(due_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_reminders_status ON reminders(status);
CREATE INDEX idx_reminders_type ON reminders(reminder_type);

-- ============================================================
-- 18. 仪表盘统计数据表 (定期汇总，加速前端展示)
-- ============================================================

CREATE TABLE dashboard_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 统计维度
    stat_date DATE NOT NULL,                -- 统计日期
    stat_type VARCHAR(50) NOT NULL,         -- 统计类型(日报/周报/月报)
    
    -- 统计对象
    scope VARCHAR(50),                      -- 统计范围(all/team/agent)
    scope_id UUID,                          -- 范围ID(owner_id或team_id)
    
    -- 业务统计
    new_customers INTEGER DEFAULT 0,       -- 新增客户
    new_policies INTEGER DEFAULT 0,         -- 新增保单
    new_premium DECIMAL(14,2) DEFAULT 0,   -- 新增保费
    new_commission DECIMAL(14,2) DEFAULT 0,-- 新增佣金
    renewals INTEGER DEFAULT 0,             -- 续保数
    renewal_rate DECIMAL(5,4) DEFAULT 0,   -- 续保率
    claims INTEGER DEFAULT 0,               -- 理赔数
    claim_amount DECIMAL(14,2) DEFAULT 0,  -- 理赔金额
    
    -- 客户统计
    active_customers INTEGER DEFAULT 0,   -- 活跃客户
    expiring_soon INTEGER DEFAULT 0,       -- 即将到期(7天内)
    overdue INTEGER DEFAULT 0,              -- 已逾期
    
    -- 服务统计
    new_services INTEGER DEFAULT 0,        -- 新增服务
    service_revenue DECIMAL(14,2) DEFAULT 0,-- 服务收入
    
    -- 财务统计
    total_receivable DECIMAL(14,2) DEFAULT 0, -- 应收保费
    total_received DECIMAL(14,2) DEFAULT 0,   -- 已收保费
    total_commission_payable DECIMAL(14,2) DEFAULT 0, -- 应付佣金
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    
    CONSTRAINT dashboard_stats_unique UNIQUE (stat_date, stat_type, scope, scope_id)
);

CREATE INDEX idx_dashboard_stats_date ON dashboard_stats(stat_date DESC);
CREATE INDEX idx_dashboard_stats_type ON dashboard_stats(stat_type);

-- ============================================================
-- 19. 公共查询View (常用数据组合)
-- ============================================================

-- 客户+最新车辆View
CREATE OR REPLACE VIEW v_customer_vehicles AS
SELECT 
    c.id AS customer_id,
    c.real_name,
    c.phone,
    c.status AS customer_status,
    c.customer_level,
    c.owner_id,
    v.id AS vehicle_id,
    v.plate_number,
    v.brand,
    v.model,
    v.vin,
    v.annual_review_date,
    v.status AS vehicle_status,
    -- 最新车险
    cp.policy_no AS latest_car_policy_no,
    cp.end_date AS car_policy_end_date,
    cp.status AS car_policy_status,
    cp.premium AS car_policy_premium,
    -- 下次保养
    vs.service_date AS last_service_date,
    vs.next_service_date
FROM customers c
LEFT JOIN vehicles v ON v.customer_id = c.id AND v.is_deleted = FALSE
LEFT JOIN LATERAL (
    SELECT policy_no, end_date, status, premium
    FROM car_policies
    WHERE customer_id = c.id AND is_deleted = FALSE
    ORDER BY end_date DESC
    LIMIT 1
) cp ON TRUE
LEFT JOIN LATERAL (
    SELECT service_date, next_service_date
    FROM vehicle_services
    WHERE vehicle_id = v.id AND is_deleted = FALSE
    ORDER BY service_date DESC
    LIMIT 1
) vs ON TRUE
WHERE c.is_deleted = FALSE;

-- 客户财务汇总View
CREATE OR REPLACE VIEW v_customer_finance_summary AS
SELECT 
    c.id AS customer_id,
    c.real_name,
    c.phone,
    c.owner_id,
    -- 车险
    COALESCE(SUM(cp.premium), 0) AS total_car_premium,
    COALESCE(SUM(cp.commission), 0) AS total_car_commission,
    COUNT(cp.id) AS car_policy_count,
    -- 非车险
    COALESCE(SUM(np.premium), 0) AS total_noncar_premium,
    COALESCE(SUM(np.commission), 0) AS total_noncar_commission,
    COUNT(np.id) AS noncar_policy_count,
    -- 服务
    COALESCE(SUM(vs.total_fee), 0) AS total_service_fee,
    COALESCE(SUM(vs.commission), 0) AS total_service_commission,
    COUNT(vs.id) AS service_count,
    -- 后市场
    COALESCE(SUM(ao.actual_amount), 0) AS total_aftermarket_amount,
    COUNT(ao.id) AS aftermarket_count,
    -- 金融
    COALESCE(SUM(fc.loan_amount), 0) AS total_loan_amount,
    COUNT(fc.id) AS finance_count,
    -- 综合
    COALESCE(SUM(cp.premium), 0) + COALESCE(SUM(np.premium), 0) AS total_premium,
    COALESCE(SUM(cp.commission), 0) + COALESCE(SUM(np.commission), 0) + COALESCE(SUM(vs.commission), 0) AS total_commission
FROM customers c
LEFT JOIN car_policies cp ON cp.customer_id = c.id AND cp.is_deleted = FALSE
LEFT JOIN noncar_policies np ON np.customer_id = c.id AND np.is_deleted = FALSE
LEFT JOIN vehicle_services vs ON vs.customer_id = c.id AND vs.is_deleted = FALSE
LEFT JOIN aftermarket_orders ao ON ao.customer_id = c.id AND ao.is_deleted = FALSE
LEFT JOIN finance_contracts fc ON fc.customer_id = c.id AND fc.is_deleted = FALSE
WHERE c.is_deleted = FALSE
GROUP BY c.id, c.real_name, c.phone, c.owner_id;

-- 待办事项View (统一汇总各类待办)
CREATE OR REPLACE VIEW v_todos AS
SELECT 
    'car_policy_renewal' AS todo_type,
    cp.id,
    c.id AS customer_id,
    c.real_name,
    c.phone,
    v.plate_number,
    cp.end_date AS due_date,
    cp.insurance_company,
    cp.premium,
    (cp.end_date - CURRENT_DATE) AS days_until_due,
    '续保提醒' AS title
FROM car_policies cp
JOIN customers c ON c.id = cp.customer_id
JOIN vehicles v ON v.id = cp.vehicle_id
WHERE cp.is_deleted = FALSE 
  AND cp.status = 'active'
  AND cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'

UNION ALL

SELECT 
    'annual_review' AS todo_type,
    v.id,
    c.id AS customer_id,
    c.real_name,
    c.phone,
    v.plate_number,
    v.annual_review_date AS due_date,
    NULL AS insurance_company,
    NULL::DECIMAL AS premium,
    (v.annual_review_date - CURRENT_DATE) AS days_until_due,
    '年审到期' AS title
FROM vehicles v
JOIN customers c ON c.id = v.customer_id
WHERE v.is_deleted = FALSE
  AND v.annual_review_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'

UNION ALL

SELECT 
    'repayment' AS todo_type,
    rr.id,
    c.id AS customer_id,
    c.real_name,
    c.phone,
    v.plate_number,
    rr.due_date,
    NULL AS insurance_company,
    rr.amount AS premium,
    (rr.due_date - CURRENT_DATE) AS days_until_due,
    '还款提醒' AS title
FROM repayment_records rr
JOIN finance_contracts fc ON fc.id = rr.contract_id
JOIN customers c ON c.id = rr.customer_id
LEFT JOIN vehicles v ON v.id = fc.vehicle_id
WHERE rr.is_deleted = FALSE
  AND rr.status IN ('unpaid', 'overdue')
  AND rr.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'

UNION ALL

SELECT 
    'followup' AS todo_type,
    f.id,
    c.id AS customer_id,
    c.real_name,
    c.phone,
    NULL AS plate_number,
    f.next_followup_date AS due_date,
    NULL AS insurance_company,
    NULL::DECIMAL AS premium,
    (f.next_followup_date - CURRENT_DATE) AS days_until_due,
    '客户跟进' AS title
FROM followups f
JOIN customers c ON c.id = f.customer_id
WHERE f.is_deleted = FALSE
  AND f.next_followup_date IS NOT NULL
  AND f.next_followup_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days';

-- ============================================================
-- 20. 触发器函数 (自动审计)
-- ============================================================

-- 自动更新updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表自动添加updated_at触发器(批量)
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users',
        'customers',
        'vehicles',
        'car_policies',
        'car_claims',
        'noncar_policies',
        'vehicle_services',
        'service_providers',
        'aftermarket_orders',
        'finance_contracts',
        'repayment_records',
        'audit_logs',
        'kv_store',
        'followups',
        'reminders',
        'dashboard_stats'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS update_%s_updated_at ON %s; CREATE TRIGGER update_%s_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()',
            t, t, t, t
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 自动审计日志触发器
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    audit_row audit_logs;
    action_name VARCHAR(20);
    old_vals JSONB;
    new_vals JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        action_name := 'INSERT';
        old_vals := NULL;
        new_vals := row_to_json(NEW)::JSONB;
    ELSIF TG_OP = 'UPDATE' THEN
        action_name := 'UPDATE';
        old_vals := row_to_json(OLD)::JSONB;
        new_vals := row_to_json(NEW)::JSONB;
    ELSIF TG_OP = 'DELETE' THEN
        action_name := 'DELETE';
        old_vals := row_to_json(OLD)::JSONB;
        new_vals := NULL;
    END IF;
    
    -- 跳过内部字段变更(如updated_at, version)
    IF action_name = 'UPDATE' AND 
       jsonb_strict_eq(old_vals - ARRAY['updated_at','version','updated_by'], new_vals - ARRAY['updated_at','version','updated_by']) THEN
        RETURN NEW;
    END IF;
    
    INSERT INTO audit_logs (
        operator_id,
        operator_name,
        operator_role,
        table_name,
        record_id,
        action,
        old_value,
        new_value
    ) VALUES (
        NEW.updated_by,
        NULL,
        NULL,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        action_name,
        old_vals,
        new_vals
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为关键业务表添加审计触发器
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'customers',
        'vehicles',
        'car_policies',
        'car_claims',
        'noncar_policies',
        'vehicle_services',
        'aftermarket_orders',
        'finance_contracts',
        'repayment_records'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS audit_%s ON %s; CREATE TRIGGER audit_%s AFTER INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION audit_trigger()',
            t, t, t, t
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================================
-- 执行说明
-- ============================================================
-- 1. 在Supabase SQL Editor中执行此脚本
-- 2. 执行前确保已选择目标项目
-- 3. 执行后检查Tables列表确认所有表创建成功
-- 4. RLS策略见 rls_policies.sql
-- 5. 种子数据见 seed_data.sql
-- ============================================================
