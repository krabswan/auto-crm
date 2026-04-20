-- ============================================================
-- 汽车全生态客户管理系统 - 核心数据库Schema
-- 版本：V1.0 | 日期：2026-04-19
-- 作者：痞老板
-- 
-- 设计原则：
-- 1. 统一客户ID关联所有模块
-- 2. 每表必备审计字段（created_at/updated_at/version/is_deleted）
-- 3. 数据可追溯（audit_logs）
-- 4. 软删除保护（is_deleted）
-- 5. 乐观锁（version）
-- ============================================================

-- ============================================================
-- 第一部分：系统基础设施（先执行）
-- ============================================================

-- 1.1 用户表
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    real_name VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(255),
    role VARCHAR(20) DEFAULT 'user',  -- admin/manager/user/viewer
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT users_role_check CHECK (role IN ('admin', 'manager', 'user', 'viewer'))
);

-- 1.2 客户表（核心表，所有模块的起点）
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 基本信息
    customer_no VARCHAR(20) UNIQUE NOT NULL,  -- 客户编号 C-YYYYMMDD-XXXX
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(10),
    id_card VARCHAR(18),
    phone VARCHAR(20) NOT NULL,
    phone_secondary VARCHAR(20),
    email VARCHAR(255),
    wechat VARCHAR(100),
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address TEXT,
    -- 客户分级
    customer_level VARCHAR(20) DEFAULT 'normal',  -- vip/silver/gold/normal
    customer_source VARCHAR(50),  -- 来源：线上/转介绍/陌拜/自然到店
    -- 归属
    owner_user_id UUID REFERENCES users(id),
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT customers_gender_check CHECK (gender IN ('男', '女', '其他') OR gender IS NULL),
    CONSTRAINT customers_level_check CHECK (customer_level IN ('vip', 'silver', 'gold', 'normal') OR customer_level IS NULL)
);

-- 1.3 车辆表（一个客户可以有多辆车）
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 车辆基本信息
    plate_no VARCHAR(20) NOT NULL,
    vin VARCHAR(17) NOT NULL,
    brand VARCHAR(50) NOT NULL,      -- 品牌
    model VARCHAR(100) NOT NULL,     -- 车型
    sub_model VARCHAR(100),           -- 子型号
    year VARCHAR(10),                -- 年款
    color VARCHAR(20),               -- 颜色
    engine_no VARCHAR(50),           -- 发动机号
    registration_date DATE,          -- 注册日期
    issue_date DATE,                 -- 发证日期
    -- 车辆类型
    vehicle_type VARCHAR(20),  -- 客车/货车/货车/新能源
    use_nature VARCHAR(20),    -- 家用/营运/非营运
    -- 车价
    purchase_price DECIMAL(12,2),
    current_value DECIMAL(12,2),
    -- 年审信息
    annual_review_month INTEGER,  -- 年审月份（1-12）
    annual_review_status VARCHAR(20) DEFAULT 'pending',  -- pending/ongoing/expired
    annual_review_expire_date DATE,
    -- 交强险
    compulsory_insurance_expire DATE,
    commercial_insurance_expire DATE,
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT vehicles_plate_unique UNIQUE (plate_no) WHERE is_deleted = FALSE,
    CONSTRAINT vehicles_vin_unique UNIQUE (vin) WHERE is_deleted = FALSE,
    CONSTRAINT vehicles_type_check CHECK (vehicle_type IN ('客车', '货车', 'SUV', 'MPV', '新能源', '其他') OR vehicle_type IS NULL),
    CONSTRAINT vehicles_nature_check CHECK (use_nature IN ('家用', '营运', '非营运', '租赁') OR use_nature IS NULL)
);

-- 1.4 审计日志表（所有操作的可追溯记录）
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 操作信息
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    operation VARCHAR(20) NOT NULL,  -- INSERT/UPDATE/DELETE/SELECT
    -- 变更内容（JSON格式）
    old_value JSONB,
    new_value JSONB,
    changed_fields TEXT[],  -- 变更的字段列表
    -- 操作者
    operator_id UUID REFERENCES users(id),
    operator_name VARCHAR(100),
    operator_ip INET,
    operator_user_agent TEXT,
    -- 时间
    operation_time TIMESTAMPTZ DEFAULT NOW(),
    -- 关联信息
    module VARCHAR(50),  -- 所属模块
    remark TEXT,
    CONSTRAINT audit_logs_op_check CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'EXPORT', 'IMPORT'))
);

-- 1.5 系统配置表
CREATE TABLE IF NOT EXISTS system_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    config_type VARCHAR(50),  -- string/number/boolean/json/array
    config_group VARCHAR(50),  -- 分组
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,  -- 是否公开（网站可展示）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 1.6 文件存储表
CREATE TABLE IF NOT EXISTS file_storage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_type VARCHAR(50),  -- image/document/video/other
    file_size BIGINT,
    mime_type VARCHAR(100),
    storage_type VARCHAR(20) DEFAULT 'supabase',  -- supabase/cos/oss
    bucket_name VARCHAR(100),
    related_table VARCHAR(100),  -- 关联表
    related_id UUID,             -- 关联记录ID
    uploaded_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 第二部分：车险模块
-- ============================================================

CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    -- 保单基本信息
    policy_no VARCHAR(50) NOT NULL,
    insurance_company VARCHAR(100) NOT NULL,  -- 承保公司
    insurance_type VARCHAR(20) DEFAULT '商业险',  -- 交强险/商业险/全险
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL,
    compulsory_premium DECIMAL(12,2) DEFAULT 0,  -- 交强险保费
    commercial_premium DECIMAL(12,2) DEFAULT 0,  -- 商业险保费
    tax_amount DECIMAL(12,2) DEFAULT 0,         -- 车船税
    -- 佣金信息
    commission_rate DECIMAL(5,4),  -- 佣金比例
    commission_amount DECIMAL(12,2),  -- 佣金金额
    net_commission DECIMAL(12,2),    -- 净佣金（扣除税点后）
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 商业险详情（JSON格式，存储险种明细）
    coverage_details JSONB DEFAULT '{}',
    -- 状态
    status VARCHAR(20) DEFAULT 'active',  -- active/expired/cancelled/pending
    renewal_status VARCHAR(20) DEFAULT 'not_due',  -- not_due/due/overdue/renewed
    -- 来源
    source_channel VARCHAR(50),  -- 来源渠道
    is_first_year BOOLEAN DEFAULT FALSE,  -- 是否首年投保
    -- 关联
    previous_policy_id UUID REFERENCES car_policies(id),  -- 续保关联
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT car_policies_no_unique UNIQUE (policy_no) WHERE is_deleted = FALSE,
    CONSTRAINT car_policies_type_check CHECK (insurance_type IN ('交强险', '商业险', '全险') OR insurance_type IS NULL),
    CONSTRAINT car_policies_status_check CHECK (status IN ('active', 'expired', 'cancelled', 'pending') OR status IS NULL)
);

-- 保单险种明细表（商业险各险种）
CREATE TABLE IF NOT EXISTS policy_coverage_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES car_policies(id),
    coverage_code VARCHAR(50) NOT NULL,  -- 险种代码
    coverage_name VARCHAR(100) NOT NULL,  -- 险种名称
    coverage_type VARCHAR(20),  -- 主险/附加险
    -- 保险金额
    insured_amount DECIMAL(12,2),  -- 保额
    premium DECIMAL(12,2) NOT NULL,  -- 保费
    -- 免赔信息
    deductible DECIMAL(12,2) DEFAULT 0,  -- 免赔额
    deductible_rate DECIMAL(5,4) DEFAULT 0,  -- 免赔率
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT policy_coverage_policy_unique UNIQUE (policy_id, coverage_code) WHERE is_deleted = FALSE
);

-- 车险理赔记录表
CREATE TABLE IF NOT EXISTS car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES car_policies(id),
    claim_no VARCHAR(50) NOT NULL,
    -- 理赔信息
    accident_date TIMESTAMPTZ NOT NULL,  -- 出险时间
    accident_location TEXT,               -- 出险地点
    accident_description TEXT,            -- 出险经过
    -- 损失信息
    damage_type VARCHAR(50),  -- 损失类型
    damage_amount DECIMAL(12,2) DEFAULT 0,  -- 损失金额
    claim_amount DECIMAL(12,2) DEFAULT 0,  -- 报案金额
    paid_amount DECIMAL(12,2) DEFAULT 0,   -- 实赔金额
    -- 理赔进度
    status VARCHAR(20) DEFAULT 'pending',  -- pending/reviewing/approved/paid/rejected/closed
    handler_name VARCHAR(100),  -- 理赔员
    claim_date TIMESTAMPTZ,      -- 报案时间
    settlement_date TIMESTAMPTZ, -- 结案时间
    -- 关联
    third_party_info JSONB,  -- 第三方信息（如有）
    repair_info JSONB,       -- 维修信息
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT car_claims_no_unique UNIQUE (claim_no) WHERE is_deleted = FALSE
);

-- ============================================================
-- 第三部分：非车险模块
-- ============================================================

CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 关联车辆（可选，部分非车险与车辆相关）
    vehicle_id UUID REFERENCES vehicles(id),
    -- 保单基本信息
    policy_no VARCHAR(50) NOT NULL,
    insurance_company VARCHAR(100) NOT NULL,
    insurance_type VARCHAR(50) NOT NULL,  -- 险种类型：意外险/健康险/家财险/责任险/信用保证险/其他
    insurance_subtype VARCHAR(50),  -- 细分类型
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL,
    -- 佣金信息
    commission_rate DECIMAL(5,4),
    commission_amount DECIMAL(12,2),
    net_commission DECIMAL(12,2),
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 被保险人信息
    insured_name VARCHAR(100),
    insured_id_card VARCHAR(18),
    insured_phone VARCHAR(20),
    -- 保险详情（JSON）
    coverage_details JSONB DEFAULT '{}',
    -- 状态
    status VARCHAR(20) DEFAULT 'active',
    renewal_status VARCHAR(20) DEFAULT 'not_due',
    -- 来源
    source_channel VARCHAR(50),
    cross_sell_from UUID,  -- 交叉销售来源（车险保单ID）
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT noncar_policies_no_unique UNIQUE (policy_no) WHERE is_deleted = FALSE,
    CONSTRAINT noncar_policies_type_check CHECK (insurance_type IN ('意外险', '健康险', '家财险', '责任险', '信用保证险', '工程险', '船舶险', '货物险', '其他') OR insurance_type IS NULL)
);

-- ============================================================
-- 第四部分：年审保养模块
-- ============================================================

CREATE TABLE IF NOT EXISTS annual_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 年审信息
    review_year INTEGER NOT NULL,  -- 年审年份
    review_type VARCHAR(20) DEFAULT 'annual',  -- annual/年审/semi/季度
    -- 时间
    due_date DATE NOT NULL,  -- 应审日期
    completed_date DATE,      -- 实审日期
    next_due_date DATE,       -- 下次应审日期
    -- 机构
    review_station VARCHAR(200),  -- 检测站
    review_station_address TEXT,
    -- 结果
    result VARCHAR(20),  -- pass/fail/pending
    result_certificate_no VARCHAR(50),  -- 合格证编号
    -- 费用
    review_fee DECIMAL(10,2) DEFAULT 0,
    repair_fee DECIMAL(10,2) DEFAULT 0,  -- 维修费用（如有）
    total_fee DECIMAL(10,2) DEFAULT 0,
    -- 状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/ongoing/passed/failed/expired
    reminder_sent BOOLEAN DEFAULT FALSE,  -- 是否已发送提醒
    reminder_dates TIMESTAMPTZ[],         -- 提醒发送记录
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT annual_reviews_vehicle_year_unique UNIQUE (vehicle_id, review_year) WHERE is_deleted = FALSE
);

CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 保养信息
    maintenance_no VARCHAR(30) UNIQUE NOT NULL,
    maintenance_type VARCHAR(20) NOT NULL,  -- routine/repair/inspection/other
    maintenance_name VARCHAR(200),          -- 保养项目名称
    -- 时间
    book_date TIMESTAMPTZ,     -- 预约时间
    service_date TIMESTAMPTZ NOT NULL,  -- 服务时间
    -- 服务商
    service_provider_id UUID,  -- 服务商ID（关联service_providers表）
    service_provider_name VARCHAR(200),
    service_provider_address TEXT,
    service_provider_phone VARCHAR(20),
    -- 费用
    service_fee DECIMAL(10,2) DEFAULT 0,    -- 工时费
    parts_fee DECIMAL(10,2) DEFAULT 0,      -- 配件费
    total_fee DECIMAL(10,2) DEFAULT 0,      -- 总费用
    -- 里程
    current_mileage INTEGER,  -- 保养时里程
    next_mileage INTEGER,    -- 下次保养里程
    next_maintenance_date DATE,  -- 下次保养日期
    -- 保养详情（JSON，包含所换配件、油品等）
    maintenance_details JSONB DEFAULT '{}',
    -- 状态
    status VARCHAR(20) DEFAULT 'completed',  -- booked/ongoing/completed/cancelled
    -- 评价
    rating INTEGER,  -- 1-5星评价
    rating_content TEXT,
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT maintenance_records_type_check CHECK (maintenance_type IN ('routine', 'repair', 'inspection', 'other') OR maintenance_type IS NULL)
);

-- 服务商表（年审站、维修厂、救援公司等）
CREATE TABLE IF NOT EXISTS service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_no VARCHAR(30) UNIQUE NOT NULL,
    provider_name VARCHAR(200) NOT NULL,
    provider_type VARCHAR(50) NOT NULL,  -- annual_review/maintenance/rescue/beauty/parts/insurance
    -- 联系方式
    contact_person VARCHAR(100),
    phone VARCHAR(20) NOT NULL,
    phone_secondary VARCHAR(20),
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address TEXT,
    -- 资质
    license_no VARCHAR(50),  -- 营业执照编号
    business_license_url TEXT,
    service_license_url TEXT,  -- 服务资质证书
    -- 合作信息
    cooperation_start_date DATE,
    cooperation_end_date DATE,
    cooperation_status VARCHAR(20) DEFAULT 'active',
    -- 评分
    avg_rating DECIMAL(3,2) DEFAULT 0,
    total_orders INTEGER DEFAULT 0,
    -- 结算信息
    settlement_type VARCHAR(20),  -- 月结/次结
    commission_rate DECIMAL(5,4),  -- 返佣比例
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 第五部分：汽车后市场服务模块
-- ============================================================

CREATE TABLE IF NOT EXISTS after_market_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    order_no VARCHAR(30) UNIQUE NOT NULL,
    -- 订单类型
    order_type VARCHAR(50) NOT NULL,  -- rescue/beauty/parts/accessories/other
    order_type_name VARCHAR(100),      -- 类型中文名
    -- 商品/服务信息
    product_name VARCHAR(200),
    product_brand VARCHAR(100),
    product_model VARCHAR(100),
    service_name VARCHAR(200),
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) DEFAULT 0,
    -- 服务商
    service_provider_id UUID REFERENCES service_providers(id),
    service_provider_name VARCHAR(200),
    -- 费用明细
    product_fee DECIMAL(12,2) DEFAULT 0,
    service_fee DECIMAL(10,2) DEFAULT 0,
    other_fee DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    final_amount DECIMAL(12,2) DEFAULT 0,
    -- 时间
    book_date TIMESTAMPTZ,
    service_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ,
    -- 状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/booked/ongoing/completed/cancelled
    payment_status VARCHAR(20) DEFAULT 'unpaid',  -- unpaid/paid/partially_paid/refunded
    -- 违章信息（违章代办场景）
    violation_count INTEGER DEFAULT 0,
    violation_fine DECIMAL(10,2) DEFAULT 0,
    violation_handling_fee DECIMAL(10,2) DEFAULT 0,
    violation_score INTEGER DEFAULT 0,  -- 扣分
    violation_info JSONB,  -- 违章详情
    -- 救援信息（道路救援场景）
    rescue_location TEXT,
    rescue_reason TEXT,
    rescue_distance DECIMAL(10,2),  -- 拖车里程
    -- 评价
    rating INTEGER,
    rating_content TEXT,
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT after_market_orders_type_check CHECK (order_type IN ('rescue', 'beauty', 'parts', 'accessories', 'violation', 'other') OR order_type IS NULL)
);

-- 配件库存表
CREATE TABLE IF NOT EXISTS parts_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parts_no VARCHAR(50) UNIQUE NOT NULL,
    parts_name VARCHAR(200) NOT NULL,
    parts_brand VARCHAR(100),
    parts_model VARCHAR(100),
    category VARCHAR(50),  --机油/滤芯/刹车片/雨刮/灯泡/其他
    car_brand VARCHAR(50),  -- 适用品牌
    car_models JSONB DEFAULT '[]',  -- 适用车型列表
    -- 库存
    stock_quantity INTEGER DEFAULT 0,
    min_stock_level INTEGER DEFAULT 0,
    max_stock_level INTEGER DEFAULT 100,
    unit VARCHAR(20) DEFAULT '个',
    -- 价格
    cost_price DECIMAL(10,2) DEFAULT 0,
    retail_price DECIMAL(10,2) DEFAULT 0,
    wholesale_price DECIMAL(10,2) DEFAULT 0,
    -- OEM信息
    original_brand VARCHAR(100),  -- 原厂品牌
    original_part_no VARCHAR(100),  -- 原厂配件号
    -- 状态
    status VARCHAR(20) DEFAULT 'active',
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 第六部分：汽车消费金融模块
-- ============================================================

CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    contract_no VARCHAR(50) UNIQUE NOT NULL,
    -- 合同类型
    contract_type VARCHAR(50) NOT NULL,  -- car_loan/lease/insurance_loan/other
    contract_type_name VARCHAR(100),      -- 类型中文名
    -- 金融产品
    product_name VARCHAR(200),
    finance_company VARCHAR(200),  -- 金融机构
    -- 贷款金额
    loan_amount DECIMAL(14,2) NOT NULL,  -- 贷款总额
    down_payment DECIMAL(14,2) DEFAULT 0,  -- 首付金额
    loan_periods INTEGER NOT NULL,          -- 贷款期数
    interest_rate DECIMAL(8,4) NOT NULL,  -- 年利率
    monthly_payment DECIMAL(12,2),         -- 月供
    total_interest DECIMAL(12,2),         -- 总利息
    total_amount DECIMAL(14,2),            -- 还款总额
    -- 申请信息
    apply_date DATE,
    approve_date DATE,
    loan_start_date DATE,
    loan_end_date DATE,
    -- 审批信息
    approval_status VARCHAR(20) DEFAULT 'pending',  -- pending/approved/rejected
    approval_amount DECIMAL(14,2),         -- 审批金额
    approval_periods INTEGER,             -- 审批期数
    approver VARCHAR(100),                -- 审批人
    approval_remark TEXT,
    -- 担保信息
    guarantee_type VARCHAR(50),  -- 担保方式：无/抵押/质押/保证/信用
    guarantee_info JSONB,        -- 担保证件信息
    -- GPS信息
    has_gps BOOLEAN DEFAULT FALSE,
    gps_info JSONB,
    -- 状态
    status VARCHAR(20) DEFAULT 'active',  -- active/settled/overdue/default/cancelled
    -- 逾期信息
    overdue_periods INTEGER DEFAULT 0,
    overdue_amount DECIMAL(12,2) DEFAULT 0,
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 还款计划表
CREATE TABLE IF NOT EXISTS repayment_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES finance_contracts(id),
    -- 期次信息
    period_no INTEGER NOT NULL,
    due_date DATE NOT NULL,
    -- 应还金额
    principal DECIMAL(14,2) NOT NULL,      -- 本金
    interest DECIMAL(12,2) NOT NULL,       -- 利息
    total_payment DECIMAL(14,2) NOT NULL,  -- 应还总额
    -- 实际还款
    actual_payment_date DATE,
    actual_principal DECIMAL(14,2) DEFAULT 0,
    actual_interest DECIMAL(12,2) DEFAULT 0,
    actual_amount DECIMAL(14,2) DEFAULT 0,
    -- 状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/paid/overdue/partially_paid/default
    overdue_days INTEGER DEFAULT 0,
    -- 逾期费用
    penalty_interest DECIMAL(12,2) DEFAULT 0,
    late_fee DECIMAL(12,2) DEFAULT 0,
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT repayment_schedule_contract_period_unique UNIQUE (contract_id, period_no) WHERE is_deleted = FALSE
);

-- ============================================================
-- 第七部分：跟进记录与提醒（通用）
-- ============================================================

CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 关联信息
    related_table VARCHAR(50),  -- 关联表：car_policies/noncar_policies/vehicles等
    related_id UUID,
    -- 跟进信息
    followup_type VARCHAR(50) NOT NULL,  -- call/visit/wechat/sms/email/other
    followup_purpose VARCHAR(100),         -- 跟进目的
    content TEXT NOT NULL,                 -- 跟进内容
    -- 结果
    result VARCHAR(20),  -- success/no_answer/busy/refused/pending
    next_followup_date TIMESTAMPTZ,  -- 下次跟进时间
    -- 附件
    attachments JSONB DEFAULT '[]',  -- 附件列表
    -- 状态
    status VARCHAR(20) DEFAULT 'completed',  -- pending/completed/cancelled
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 提醒任务表
CREATE TABLE IF NOT EXISTS reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    -- 关联信息
    related_table VARCHAR(50),
    related_id UUID,
    -- 提醒信息
    reminder_type VARCHAR(50) NOT NULL,  -- renewal/annual_review/maintenance/payment/followup/custom
    reminder_title VARCHAR(200) NOT NULL,
    reminder_content TEXT,
    -- 时间
    remind_at TIMESTAMPTZ NOT NULL,
    remind_date DATE GENERATED ALWAYS AS (DATE(remind_at)) STORED,  -- 方便查询
    -- 执行状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/sent/failed/cancelled
    sent_at TIMESTAMPTZ,
    sent_channel VARCHAR(20),  -- sms/wechat/email/system
    sent_result TEXT,
    -- 重复规则
    repeat_type VARCHAR(20),  -- none/daily/weekly/monthly/yearly
    repeat_interval INTEGER DEFAULT 1,
    next_repeat_at TIMESTAMPTZ,
    -- 备注
    remark TEXT,
    -- 标准审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT reminders_type_check CHECK (reminder_type IN ('renewal', 'annual_review', 'maintenance', 'payment', 'followup', 'custom') OR reminder_type IS NULL)
);

-- ============================================================
-- 索引创建（性能优化）
-- ============================================================

-- customers 索引
CREATE INDEX idx_customers_phone ON customers(phone) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_name ON customers(name) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_owner ON customers(owner_user_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_level ON customers(customer_level) WHERE is_deleted = FALSE;

-- vehicles 索引
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_plate ON vehicles(plate_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_vin ON vehicles(vin) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_annual_review ON vehicles(annual_review_expire_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_compulsory ON vehicles(compulsory_insurance_expire) WHERE is_deleted = FALSE;

-- car_policies 索引
CREATE INDEX idx_car_policies_customer ON car_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_end_date ON car_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_company ON car_policies(insurance_company) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_renewal ON car_policies(renewal_status) WHERE is_deleted = FALSE;

-- noncar_policies 索引
CREATE INDEX idx_noncar_policies_customer ON noncar_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_end_date ON noncar_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_type ON noncar_policies(insurance_type) WHERE is_deleted = FALSE;

-- annual_reviews 索引
CREATE INDEX idx_annual_reviews_vehicle ON annual_reviews(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_annual_reviews_due_date ON annual_reviews(due_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_annual_reviews_status ON annual_reviews(status) WHERE is_deleted = FALSE;

-- maintenance_records 索引
CREATE INDEX idx_maintenance_vehicle ON maintenance_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_date ON maintenance_records(service_date) WHERE is_deleted = FALSE;

-- after_market_orders 索引
CREATE INDEX idx_orders_customer ON after_market_orders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_orders_type ON after_market_orders(order_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_orders_status ON after_market_orders(status) WHERE is_deleted = FALSE;

-- finance_contracts 索引
CREATE INDEX idx_finance_customer ON finance_contracts(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_status ON finance_contracts(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_due_date ON finance_contracts(loan_end_date) WHERE is_deleted = FALSE;

-- repayment_schedules 索引
CREATE INDEX idx_repayment_contract ON repayment_schedules(contract_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_due_date ON repayment_schedules(due_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_status ON repayment_schedules(status) WHERE is_deleted = FALSE;

-- followups 索引
CREATE INDEX idx_followups_customer ON followups(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_followups_date ON followups(created_at) WHERE is_deleted = FALSE;

-- reminders 索引
CREATE INDEX idx_reminders_remind_at ON reminders(remind_at) WHERE is_deleted = FALSE;
CREATE INDEX idx_reminders_status ON reminders(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_reminders_customer ON reminders(customer_id) WHERE is_deleted = FALSE;

-- audit_logs 索引
CREATE INDEX idx_audit_table ON audit_logs(table_name) WHERE is_deleted = FALSE;
CREATE INDEX idx_audit_record ON audit_logs(record_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_audit_operator ON audit_logs(operator_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_audit_time ON audit_logs(operation_time) WHERE is_deleted = FALSE;

-- ============================================================
-- 视图创建（方便网站展示）
-- ============================================================

-- 客户车辆联合视图（网站展示用）
CREATE OR REPLACE VIEW v_customer_vehicles AS
SELECT 
    c.id AS customer_id,
    c.customer_no,
    c.name AS customer_name,
    c.phone,
    c.province,
    c.city,
    c.district,
    c.customer_level,
    c.owner_user_id,
    v.id AS vehicle_id,
    v.plate_no,
    v.brand,
    v.model,
    v.year AS car_year,
    v.vehicle_type,
    v.use_nature,
    v.annual_review_month,
    v.annual_review_expire_date,
    v.compulsory_insurance_expire,
    v.commercial_insurance_expire
FROM customers c
LEFT JOIN vehicles v ON c.id = v.customer_id AND v.is_deleted = FALSE
WHERE c.is_deleted = FALSE;

-- 车险到期提醒视图
CREATE OR REPLACE VIEW v_car_policy_renewals AS
SELECT 
    p.id AS policy_id,
    p.policy_no,
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate_no,
    v.brand,
    v.model,
    p.insurance_company,
    p.insurance_type,
    p.total_premium,
    p.end_date,
    p.renewal_status,
    p.commission_amount,
    p.net_commission,
    -- 计算距到期天数
    (p.end_date - CURRENT_DATE) AS days_to_expire,
    -- 计算佣金率
    CASE WHEN p.total_premium > 0 
         THEN ROUND((p.net_commission / p.total_premium)::numeric, 4) 
         ELSE 0 
    END AS net_commission_rate
FROM car_policies p
JOIN customers c ON p.customer_id = c.id
JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.is_deleted = FALSE 
    AND p.status = 'active'
    AND (p.end_date - CURRENT_DATE) <= 90  -- 90天内到期
ORDER BY p.end_date ASC;

-- 年审到期提醒视图
CREATE OR REPLACE VIEW v_annual_review_renewals AS
SELECT 
    a.id AS review_id,
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate_no,
    v.brand,
    v.model,
    a.review_year,
    a.due_date,
    a.completed_date,
    a.result,
    a.review_fee,
    a.status,
    (a.due_date - CURRENT_DATE) AS days_to_due
FROM annual_reviews a
JOIN customers c ON a.customer_id = c.id
JOIN vehicles v ON a.vehicle_id = v.id
WHERE a.is_deleted = FALSE
    AND a.status IN ('pending', 'ongoing')
    AND (a.due_date - CURRENT_DATE) <= 90  -- 90天内到期
ORDER BY a.due_date ASC;

-- 客户价值分析视图（聚合数据）
CREATE OR REPLACE VIEW v_customer_value_analysis AS
SELECT 
    c.id AS customer_id,
    c.customer_no,
    c.name AS customer_name,
    c.phone,
    c.customer_level,
    COUNT(DISTINCT v.id) AS vehicle_count,
    COALESCE(SUM(cp.total_premium) FILTER (WHERE cp.status = 'active' OR cp.status = 'expired'), 0) AS total_car_premium,
    COALESCE(SUM(cp.net_commission) FILTER (WHERE cp.status = 'active' OR cp.status = 'expired'), 0) AS total_car_commission,
    COUNT(DISTINCT np.id) AS noncar_policy_count,
    COALESCE(SUM(np.total_premium) FILTER (WHERE np.status = 'active' OR np.status = 'expired'), 0) AS total_noncar_premium,
    COALESCE(SUM(np.net_commission) FILTER (WHERE np.status = 'active' OR np.status = 'expired'), 0) AS total_noncar_commission,
    COUNT(DISTINCT am.id) AS after_market_orders,
    COALESCE(SUM(am.final_amount) FILTER (WHERE am.status = 'completed'), 0) AS total_after_market_amount,
    COUNT(DISTINCT fc.id) AS finance_contracts,
    COALESCE(SUM(fc.loan_amount) FILTER (WHERE fc.status IN ('active', 'settled')), 0) AS total_finance_amount
FROM customers c
LEFT JOIN vehicles v ON c.id = v.customer_id AND v.is_deleted = FALSE
LEFT JOIN car_policies cp ON c.id = cp.customer_id AND cp.is_deleted = FALSE
LEFT JOIN noncar_policies np ON c.id = np.customer_id AND np.is_deleted = FALSE
LEFT JOIN after_market_orders am ON c.id = am.customer_id AND am.is_deleted = FALSE
LEFT JOIN finance_contracts fc ON c.id = fc.customer_id AND fc.is_deleted = FALSE
WHERE c.is_deleted = FALSE
GROUP BY c.id, c.customer_no, c.name, c.phone, c.customer_level;

-- ============================================================
-- RLS策略（行级安全）
-- ============================================================

-- 启用RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE annual_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_market_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repayment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE file_storage ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_coverage_items ENABLE ROW LEVEL SECURITY;

-- 基础策略：只看自己的数据
CREATE POLICY "用户只能看到自己的数据" ON customers
    FOR ALL USING (owner_user_id = auth.uid() OR auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "管理员可看到所有数据" ON customers
    FOR ALL USING (auth.jwt() ->> 'role' = 'admin');

-- 其他表类似策略...

-- ============================================================
-- 触发器（自动更新审计字段）
-- ============================================================

-- 自动更新updated_at触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表创建updated_at触发器
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_policies_updated_at BEFORE UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_noncar_policies_updated_at BEFORE UPDATE ON noncar_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_annual_reviews_updated_at BEFORE UPDATE ON annual_reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_maintenance_records_updated_at BEFORE UPDATE ON maintenance_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_after_market_orders_updated_at BEFORE UPDATE ON after_market_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_finance_contracts_updated_at BEFORE UPDATE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_repayment_schedules_updated_at BEFORE UPDATE ON repayment_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_followups_updated_at BEFORE UPDATE ON followups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reminders_updated_at BEFORE UPDATE ON reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 初始化数据
-- ============================================================

-- 插入管理员用户（密码：589842，需要在应用层哈希）
INSERT INTO users (username, password_hash, real_name, role, is_active)
VALUES ('admin', '$2a$10$placeholder_hash_replace_in_app', '系统管理员', 'admin', TRUE)
ON CONFLICT (username) DO NOTHING;

-- 插入通用系统配置
INSERT INTO system_configs (config_key, config_value, config_type, config_group, description, is_public) VALUES
('app_name', '"汽车全生态客户管理系统"', 'string', 'basic', '系统名称', TRUE),
('app_version', '"V1.0"', 'string', 'basic', '系统版本', TRUE),
('company_name', '"蟹老板车险工作室"', 'string', 'basic', '公司名称', TRUE),
('contact_phone', '"13328185024"', 'string', 'basic', '联系电话', TRUE),
('renewal_reminder_days', '30', 'number', 'reminder', '续保提前提醒天数', FALSE),
('annual_review_reminder_days', '30', 'number', 'reminder', '年审提前提醒天数', FALSE),
('maintenance_reminder_days', '7', 'number', 'reminder', '保养到期提醒天数', FALSE),
('commission_tax_rate', '0.08', 'number', 'finance', '佣金税点(8%)', FALSE),
('default_page_size', '20', 'number', 'ui', '默认分页大小', FALSE),
('data_retention_days', '365', 'number', 'system', '数据保留天数', FALSE);

-- ============================================================
-- 完成标记
-- ============================================================
-- Schema创建完成时间：2026-04-19
-- 执行顺序：01_core_schema.sql → 02_functions.sql → 03_seed_data.sql
