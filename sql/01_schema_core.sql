-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本：V1.0 | 日期：2026-04-19 | 作者：痞老板
-- 说明：按模块分组，每个模块独立可运行
-- ============================================================

-- ============================================================
-- 模块0: 核心基础 (必须首先执行)
-- ============================================================

-- 0.1 枚举类型定义
-- ------------------------------------------------
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'agent', 'readonly');
CREATE TYPE gender AS ENUM ('male', 'female', 'unknown');
CREATE TYPE data_status AS ENUM ('active', 'inactive', 'pending', 'archived');


-- 0.2 用户表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    real_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    role user_role DEFAULT 'agent',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    CONSTRAINT users_phone_format CHECK (phone ~ '^[0-9]{11}$' OR phone IS NULL)
);

-- 0.3 客户表 (核心表，所有模块通过customer_id关联)
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基本信息
    name VARCHAR(100) NOT NULL,
    gender gender DEFAULT 'unknown',
    id_card VARCHAR(18),
    phone VARCHAR(20) NOT NULL,
    phone_2 VARCHAR(20),
    email VARCHAR(100),
    
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address VARCHAR(255),
    address_lat DECIMAL(10, 7),
    address_lng DECIMAL(10, 7),
    
    -- 家庭关系 (用于家庭保单推荐)
    family_id UUID,                          -- 家庭ID，同一家庭客户关联
    family_relation VARCHAR(20),             -- 关系：本人/配偶/子女/父母/其他
    
    -- 来源信息
    source_from VARCHAR(50),                  -- 来源渠道
    source_agent UUID REFERENCES users(id),  -- 归属业务员
    first_contact_date DATE,
    
    -- 标签
    tags TEXT[],                              -- 标签数组，如['vip','老客户','高净值']
    
    -- 状态
    status data_status DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- 客户手机号唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone) WHERE is_deleted = FALSE;

-- 客户姓名+手机联合索引
CREATE INDEX IF NOT EXISTS idx_customers_name_phone ON customers(name, phone);

-- 客户归属索引
CREATE INDEX IF NOT EXISTS idx_customers_agent ON customers(source_agent) WHERE is_deleted = FALSE;


-- 0.4 车辆表 (与客户关联，一人多车)
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 车辆基本信息
    plate_number VARCHAR(20) NOT NULL,        -- 车牌号
    vehicle_type VARCHAR(20),                  -- 车辆类型：小型汽车/中型汽车/大型汽车
    brand VARCHAR(50),                         -- 品牌
    model VARCHAR(50),                         -- 车型
    sub_model VARCHAR(100),                    -- 子车型
    color VARCHAR(20),                         -- 颜色
    
    -- 车辆属性
    vin VARCHAR(17) NOT NULL,                 -- 车架号/VIN
    engine_number VARCHAR(50),                 -- 发动机号
    register_date DATE,                       -- 注册日期
    issue_date DATE,                          -- 发证日期
    exhaust_capacity DECIMAL(4,2),            -- 排量(升)
    power_kw DECIMAL(5,2),                    -- 功率(kW)
    seat_count INTEGER,                       -- 座位数
    curb_weight INTEGER,                      -- 整备质量(kg)
    fuel_type VARCHAR(20),                   -- 燃料类型：汽油/柴油/电动/混合
    energy_type VARCHAR(20),                  -- 能源类型：纯电动/插电混合
    
    -- 年审信息
    annual_review_date DATE,                  -- 年审有效期
    annual_review_status VARCHAR(20),        -- 需不需要年审/已年审
    next_review_month INTEGER,               -- 提前提醒月份
    
    -- 保险信息
    compulsory_insurance_date DATE,          -- 交强险到期
    commercial_insurance_date DATE,          -- 商业险到期
    last_insurance_company VARCHAR(100),     -- 上年承保公司
    
    -- 商业险信息
    insured_amount DECIMAL(12,2),             -- 投保额度
    insured_items TEXT[],                     -- 投保项目
    
    -- 状态
    status data_status DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    
    CONSTRAINT vehicles_plate_unique UNIQUE (plate_number) WHERE is_deleted = FALSE,
    CONSTRAINT vehicles_vin_unique UNIQUE (vin) WHERE is_deleted = FALSE
);

-- 车辆车牌号索引
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON vehicles(plate_number) WHERE is_deleted = FALSE;
-- 车辆客户索引
CREATE INDEX IF NOT EXISTS idx_vehicles_customer ON vehicles(customer_id) WHERE is_deleted = FALSE;
-- 车辆年审到期索引(提前提醒用)
CREATE INDEX IF NOT EXISTS idx_vehicles_review_date ON vehicles(annual_review_date) WHERE is_deleted = FALSE;
-- 车辆交强险到期索引
CREATE INDEX IF NOT EXISTS idx_vehicles_compulsory_date ON vehicles(compulsory_insurance_date) WHERE is_deleted = FALSE;


-- 0.5 审计日志表 (全局追溯)
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 操作信息
    table_name VARCHAR(50) NOT NULL,          -- 操作表名
    record_id UUID NOT NULL,                   -- 记录ID
    operation VARCHAR(10) NOT NULL,           -- 操作类型：INSERT/UPDATE/DELETE
    old_values JSONB,                          -- 变更前值
    new_values JSONB,                          -- 变更后值
    diff_fields TEXT[],                        -- 变更字段列表
    
    -- 执行信息
    user_id UUID REFERENCES users(id),
    user_ip INET,
    user_agent TEXT,
    
    -- 时间
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 关联业务
    business_type VARCHAR(50),                 -- 业务类型：车险/非车险/年审等
    business_id UUID,                          -- 业务记录ID
    remark TEXT                                -- 备注
);

-- 审计日志索引
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_business ON audit_logs(business_type, business_id);


-- 0.6 系统配置表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS system_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    config_type VARCHAR(20) DEFAULT 'string',  -- string/number/boolean/json
    config_group VARCHAR(50),                  -- 配置分组
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,           -- 是否公开(网站可展示)
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);


-- 0.7 消息模板表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(100) NOT NULL,                -- 模板名称
    type VARCHAR(30) NOT NULL,                 -- 模板类型：renew_reminder/annual_review/accident/notifications
    channel VARCHAR(20) DEFAULT 'sms',        -- 发送渠道：sms/wechat/email/app
    
    title VARCHAR(200),                         -- 标题模板
    content_template TEXT NOT NULL,            -- 内容模板，支持变量{{name}}
    variables JSONB,                           -- 变量说明
    
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0,                -- 优先级
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 模块1: 车险管理
-- ============================================================

-- 1.1 车险保单表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS car_insurance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    agent_id UUID REFERENCES users(id),       -- 业务员
    
    -- 保单基本信息
    policy_number VARCHAR(50) UNIQUE NOT NULL, -- 保单号
    insurance_company VARCHAR(100) NOT NULL,  -- 承保公司
    
    -- 投保人信息
    insured_name VARCHAR(100) NOT NULL,       -- 被保险人姓名
    insured_phone VARCHAR(20) NOT NULL,      -- 被保险人电话
    insured_id_card VARCHAR(18),              -- 被保险人身份证
    
    -- 车辆信息(冗余，加速查询)
    plate_number VARCHAR(20) NOT NULL,
    vin VARCHAR(17) NOT NULL,
    brand VARCHAR(50),
    model VARCHAR(50),
    
    -- 保险期间
    start_date DATE NOT NULL,                  -- 生效日期
    end_date DATE NOT NULL,                    -- 到期日期
    insurance_period INTEGER,                 -- 保险期间(天)
    
    -- 险种信息 (JSONB存储，可灵活扩展)
    coverage_types JSONB NOT NULL,             -- 投保险种，如[{"type":"第三方责任险","amount":1000000,"premium":800}]
    total_premium DECIMAL(12,2) NOT NULL,     -- 总保费
    compulsory_premium DECIMAL(10,2),         -- 交强险保费
    commercial_premium DECIMAL(10,2),        -- 商业险保费
    
    -- 佣金信息
    commission_rate DECIMAL(5,4),              -- 佣金比例
    commission_amount DECIMAL(12,2),         -- 佣金金额
    actual_commission DECIMAL(12,2),          -- 实际佣金
    commission_status VARCHAR(20),            -- 佣金状态：已结清/未结清/部分结清
    
    -- 返点信息
    rebate_rate DECIMAL(5,4),                 -- 返点比例
    rebate_amount DECIMAL(12,2),             -- 返点金额
    actual_rebate DECIMAL(12,2),             -- 实际返点
    
    -- 状态
    policy_status VARCHAR(20) DEFAULT 'effective',  -- 有效/退保/理赔中/已到期
    renewal_status VARCHAR(20),               -- 续保状态：待跟进/已报价/已续保/流失
    last_contact_date DATE,                   -- 最后联系日期
    next_followup_date DATE,                  -- 下次跟进日期
    
    -- 来源
    source VARCHAR(50),                        -- 来源：自然续保/转介绍/主动开拓/同行转入
    competitor_info VARCHAR(100),            -- 竞争对手信息(如有)
    
    -- 状态
    status data_status DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- 车险保单索引
CREATE INDEX IF NOT EXISTS idx_car_policy_customer ON car_insurance_records(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_car_policy_vehicle ON car_insurance_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_car_policy_end_date ON car_insurance_records(end_date) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_car_policy_plate ON car_insurance_records(plate_number) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_car_policy_renewal ON car_insurance_records(renewal_status) WHERE is_deleted = FALSE;


-- 1.2 车险跟进记录表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS car_insurance_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    policy_id UUID REFERENCES car_insurance_records(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    agent_id UUID REFERENCES users(id),
    
    -- 跟进信息
    followup_type VARCHAR(30) NOT NULL,        -- 跟进类型：首次联系/报价/促成/签约/售后
    followup_date DATE NOT NULL,
    followup_time TIME,
    
    -- 跟进内容
    content TEXT NOT NULL,                    -- 跟进内容
    next_plan TEXT,                          -- 下一步计划
    next_followup_date DATE,                 -- 下次跟进日期
    
    -- 报价信息(如有)
    quote_company VARCHAR(100),              -- 报价公司
    quote_premium DECIMAL(12,2),             -- 报价保费
    quote_result VARCHAR(20),                -- 报价结果：接受/拒绝/考虑中
    
    -- 状态
    is_closed BOOLEAN DEFAULT FALSE,
    close_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_car_followup_policy ON car_insurance_followups(policy_id);


-- 1.3 理赔记录表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    policy_id UUID NOT NULL REFERENCES car_insurance_records(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    agent_id UUID REFERENCES users(id),
    
    -- 理赔信息
    claim_number VARCHAR(50) UNIQUE NOT NULL, -- 理赔编号
    claim_type VARCHAR(30) NOT NULL,         -- 理赔类型：车损/三者/人伤/盗抢/自燃/玻璃
    accident_date TIMESTAMPTZ NOT NULL,       -- 事故时间
    accident_location VARCHAR(255),          -- 事故地点
    accident_description TEXT,               -- 事故描述
    
    -- 金额信息
    estimated_loss DECIMAL(12,2),            -- 预估损失
    claim_amount DECIMAL(12,2),             -- 报案金额
    approved_amount DECIMAL(12,2),          -- 核定金额
    actual_paid DECIMAL(12,2),              -- 实际赔付
    
    -- 进度
    claim_status VARCHAR(20) DEFAULT 'reported',  -- 已报案/已定损/已核赔/已结案/已拒赔
    progress_detail TEXT,                   -- 进度详情
    
    -- 结案信息
    close_date DATE,
    close_reason TEXT,
    
    -- 状态
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_car_claims_policy ON car_claims(policy_id) WHERE is_deleted = FALSE;


-- ============================================================
-- 模块2: 非车险管理
-- ============================================================

-- 2.1 非车险保单表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS noncar_insurance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    agent_id UUID REFERENCES users(id),
    
    -- 关联车险(如有交叉销售)
    related_car_policy_id UUID REFERENCES car_insurance_records(id),
    
    -- 保单基本信息
    policy_number VARCHAR(50) UNIQUE NOT NULL,
    insurance_company VARCHAR(100) NOT NULL,
    insurance_type VARCHAR(30) NOT NULL,       -- 险种类型：意外险/健康险/家财险/责任险/旅行险/其他
    
    -- 被保险人
    insured_name VARCHAR(100) NOT NULL,
    insured_phone VARCHAR(20) NOT NULL,
    insured_id_card VARCHAR(18),
    
    -- 保险标的
    insured_object TEXT,                      -- 保险标的描述
    insured_address VARCHAR(255),             -- 标的地址(家财险用)
    
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 保费
    premium DECIMAL(12,2) NOT NULL,
    payment_type VARCHAR(20),                -- 缴费方式：趸交/年交/月交
    
    -- 佣金
    commission_rate DECIMAL(5,4),
    commission_amount DECIMAL(12,2),
    actual_commission DECIMAL(12,2),
    
    -- 状态
    policy_status VARCHAR(20) DEFAULT 'effective',
    renewal_status VARCHAR(20),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT FALSE,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_noncar_policy_customer ON noncar_insurance_records(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_noncar_policy_type ON noncar_insurance_records(insurance_type) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_noncar_policy_end_date ON noncar_insurance_records(end_date) WHERE is_deleted = FALSE;


-- ============================================================
-- 模块3: 年审保养管理
-- ============================================================

-- 3.1 年审记录表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS annual_review_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    agent_id UUID REFERENCES users(id),
    
    -- 年审信息
    review_year INTEGER NOT NULL,             -- 年审年份
    review_type VARCHAR(30) DEFAULT 'annual',  -- 年审类型：年审/季审/月审
    
    -- 时间
    latest_review_date DATE,                  -- 最近一次年审日期
    next_review_date DATE,                    -- 下次年审日期
    reminder_30_days DATE,                    -- 30天提醒日期
    reminder_7_days DATE,                     -- 7天提醒日期
    
    -- 状态
    review_status VARCHAR(20) DEFAULT 'pending', -- 待年审/已年审/逾期未检/已注销
    is_passed BOOLEAN,                        -- 是否通过
    inspection_station VARCHAR(100),          -- 检测站
    fee DECIMAL(10,2),                       -- 费用
    
    -- 结果
    passed_date DATE,
    failure_items TEXT[],                     -- 不合格项目
    
    -- 跟进
    is_reminded BOOLEAN DEFAULT FALSE,        -- 是否已提醒
    remind_count INTEGER DEFAULT 0,            -- 提醒次数
    last_remind_date DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_review_vehicle_year ON annual_review_records(vehicle_id, review_year) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_review_next_date ON annual_review_records(next_review_date) WHERE is_deleted = FALSE;


-- 3.2 保养记录表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    service_provider_id UUID,                  -- 服务商ID
    
    -- 保养信息
    maintenance_type VARCHAR(30) NOT NULL,    -- 保养类型：小保/大保/专项保养
    maintenance_date DATE NOT NULL,
    mileage INTEGER,                         -- 保养时里程
    
    -- 保养项目
    items JSONB NOT NULL,                     -- 保养项目JSON，如[{"name":"更换机油","amount":300},{"name":"更换机滤","amount":50}]
    total_amount DECIMAL(10,2) NOT NULL,
    
    -- 服务商信息
    shop_name VARCHAR(100),
    shop_address VARCHAR(255),
    technician VARCHAR(50),
    
    -- 下次保养提醒
    next_maintenance_mileage INTEGER,         -- 下次保养里程
    next_maintenance_date DATE,              -- 或按时间
    
    -- 状态
    status VARCHAR(20) DEFAULT 'completed',
    is_deleted BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON maintenance_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_maintenance_date ON maintenance_records(maintenance_date) WHERE is_deleted = FALSE;


-- 3.3 维修记录表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS repair_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    service_provider_id UUID,
    related_claim_id UUID,                    -- 关联理赔(如走保险)
    
    -- 维修信息
    repair_type VARCHAR(30) NOT NULL,        -- 维修类型：事故维修/故障维修/保养维修
    repair_date DATE NOT NULL,
    start_date DATE,
    end_date DATE,
    
    -- 维修详情
    fault_description TEXT,                   -- 故障描述
    repair_items JSONB NOT NULL,             -- 维修项目
    total_amount DECIMAL(12,2) NOT NULL,
    
    -- 保险信息
    insurance_claim BOOLEAN DEFAULT FALSE,   -- 是否走保险
    insurance_company VARCHAR(100),
    claim_amount DECIMAL(12,2),
    
    -- 服务商
    shop_name VARCHAR(100),
    technician VARCHAR(50),
    
    -- 状态
    repair_status VARCHAR(20) DEFAULT 'repairing', -- 维修中/已修好/已取车
    customer_confirmed BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);


-- ============================================================
-- 模块4: 汽车后市场服务
-- ============================================================

-- 4.1 服务商表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基本信息
    name VARCHAR(100) NOT NULL,
    type VARCHAR(30) NOT NULL,               -- 类型：4S店/修理厂/美容店/加油站/配件店/救援公司
    contact_person VARCHAR(50),
    contact_phone VARCHAR(20) NOT NULL,
    
    -- 地址
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address VARCHAR(255),
    lat DECIMAL(10,7),
    lng DECIMAL(10,7),
    
    -- 资质
    business_license VARCHAR(100),
    certification VARCHAR(50),                -- 认证级别
    rating DECIMAL(2,1),                     -- 评分(1-5)
    
    -- 合作信息
    is_cooperated BOOLEAN DEFAULT FALSE,
    cooperation_level VARCHAR(20),           -- 合作级别：普通/战略/独家
    commission_rate DECIMAL(5,4),            -- 返佣比例
    settlement_type VARCHAR(20),             -- 结算方式
    
    -- 服务能力
    service_items TEXT[],                    -- 服务项目
    brands TEXT[],                           -- 代理品牌
    working_hours VARCHAR(100),             -- 营业时间
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_providers_type ON service_providers(type) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_providers_city ON service_providers(city, district) WHERE is_deleted = FALSE;


-- 4.2 后市场订单表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE NOT NULL, -- 订单号
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    provider_id UUID REFERENCES service_providers(id),
    agent_id UUID REFERENCES users(id),
    
    -- 订单信息
    order_type VARCHAR(30) NOT NULL,         -- 订单类型：违章处理/道路救援/美容服务/配件销售/改装服务/洗车服务
    order_date DATE NOT NULL,
    
    -- 服务详情
    service_items JSONB NOT NULL,            -- 服务项目JSON
    total_amount DECIMAL(10,2) NOT NULL,    -- 订单总额
    discount_amount DECIMAL(10,2) DEFAULT 0, -- 优惠金额
    actual_amount DECIMAL(10,2) NOT NULL,   -- 实付金额
    
    -- 支付信息
    payment_method VARCHAR(20),              -- 支付方式：微信/支付宝/现金/转账
    payment_status VARCHAR(20) DEFAULT 'pending', -- 待支付/已支付/已退款
    
    -- 佣金
    provider_commission DECIMAL(10,2),      -- 给服务商返佣
    agent_commission DECIMAL(10,2),         -- 业务员佣金
    
    -- 状态
    order_status VARCHAR(20) DEFAULT 'pending', -- 待服务/服务中/已完成/已取消
    completion_date DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_aftermarket_customer ON aftermarket_orders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_aftermarket_order_type ON aftermarket_orders(order_type) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_aftermarket_date ON aftermarket_orders(order_date) WHERE is_deleted = FALSE;


-- ============================================================
-- 模块5: 汽车消费金融
-- ============================================================

-- 5.1 车贷合同表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    agent_id UUID REFERENCES users(id),
    lender_id UUID,                          -- 金融机构ID
    
    -- 合同信息
    contract_number VARCHAR(50) UNIQUE NOT NULL,
    contract_date DATE NOT NULL,
    
    -- 贷款信息
    loan_type VARCHAR(30) NOT NULL,         -- 贷款类型：银行贷款/汽车金融/担保贷款/抵押贷款
    loan_amount DECIMAL(12,2) NOT NULL,     -- 贷款金额
    loan_term INTEGER NOT NULL,              -- 贷款期限(月)
    annual_rate DECIMAL(6,4) NOT NULL,       -- 年利率
    monthly_payment DECIMAL(12,2) NOT NULL,  -- 月供
    total_interest DECIMAL(12,2) NOT NULL,  -- 总利息
    
    -- 费用
    handling_fee DECIMAL(10,2),             -- 手续费
    guarantee_fee DECIMAL(10,2),             -- 担保费
    other_fees DECIMAL(10,2),
    
    -- 还款信息
    repayment_method VARCHAR(30),            -- 还款方式：等额本息/等额本金/先息后本
    first_repayment_date DATE,               -- 首次还款日
    repayment_day INTEGER,                   -- 每月还款日
    remaining_principal DECIMAL(12,2),      -- 剩余本金
    
    -- 抵押信息
    mortgage_type VARCHAR(20),              -- 抵押类型：无抵押/车辆抵押/房产抵押
    mortgage_status VARCHAR(20),            -- 抵押状态：未抵押/已抵押/已解押
    mortgage_cert_number VARCHAR(50),       -- 抵押登记证明号
    
    -- 状态
    loan_status VARCHAR(20) DEFAULT 'repaying', -- 已结清/还款中/逾期/违约
    overdue_amount DECIMAL(12,2) DEFAULT 0,  -- 逾期金额
    overdue_days INTEGER DEFAULT 0,         -- 逾期天数
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_finance_customer ON finance_contracts(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_finance_status ON finance_contracts(loan_status) WHERE is_deleted = FALSE;


-- 5.2 还款记录表
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    contract_id UUID NOT NULL REFERENCES finance_contracts(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 期次信息
    period_number INTEGER NOT NULL,          -- 期次号
    due_date DATE NOT NULL,                  -- 应还日期
    
    -- 金额
    principal DECIMAL(12,2) NOT NULL,        -- 本金
    interest DECIMAL(12,2) NOT NULL,         -- 利息
    total_payment DECIMAL(12,2) NOT NULL,   -- 应还总额
    actual_payment DECIMAL(12,2),            -- 实还金额
    overdue_penalty DECIMAL(10,2) DEFAULT 0, -- 逾期罚息
    
    -- 还款信息
    actual_repayment_date DATE,              -- 实还日期
    repayment_status VARCHAR(20) DEFAULT 'pending', -- 待还/已还/逾期/代偿
    repayment_method VARCHAR(20),            -- 还款方式
    
    -- 逾期信息
    overdue_days INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_repayment_contract ON repayment_records(contract_id);
CREATE INDEX IF NOT EXISTS idx_repayment_due_date ON repayment_records(due_date) WHERE repayment_status = 'pending';


-- ============================================================
-- 触发器函数: 自动更新审计字段
-- ============================================================

-- 自动更新updated_at触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    IF TG_OP = 'UPDATE' THEN
        NEW.version = OLD.version + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表添加updated_at触发器
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_car_insurance_updated_at BEFORE UPDATE ON car_insurance_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_noncar_updated_at BEFORE UPDATE ON noncar_insurance_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_annual_review_updated_at BEFORE UPDATE ON annual_review_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_maintenance_updated_at BEFORE UPDATE ON maintenance_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_repair_updated_at BEFORE UPDATE ON repair_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_aftermarket_updated_at BEFORE UPDATE ON aftermarket_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_finance_updated_at BEFORE UPDATE ON finance_contracts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- RLS策略: 行级安全
-- ============================================================

-- 启用RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_insurance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_insurance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE annual_review_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE aftermarket_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 用户只能看自己的客户(admin看全部)
CREATE POLICY "Users can view own customers" ON customers FOR SELECT USING (source_agent = auth.uid() OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'manager')));
CREATE POLICY "Users can update own customers" ON customers FOR UPDATE USING (source_agent = auth.uid() OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'manager')));
CREATE POLICY "Users can insert own customers" ON customers FOR INSERT WITH CHECK (source_agent = auth.uid() OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'manager')));

-- 车险策略(类似)
CREATE POLICY "Car policy view policy" ON car_insurance_records FOR SELECT USING (TRUE);
CREATE POLICY "Car policy insert policy" ON car_insurance_records FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "Car policy update policy" ON car_insurance_records FOR UPDATE USING (TRUE);
