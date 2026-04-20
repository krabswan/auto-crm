-- ================================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本: V1.0 | 日期: 2026-04-19
-- 数据库: Supabase PostgreSQL
-- ================================================================

-- ================================================================
-- 第一部分: ENUM类型定义
-- ================================================================

-- 客户类型
CREATE TYPE customer_type AS ENUM ('individual', 'enterprise', 'government');

-- 客户来源
CREATE TYPE customer_source AS ENUM ('walk_in', 'referral', 'online', 'partner', 'renewal', 'other');

-- 客户状态
CREATE TYPE customer_status AS ENUM ('active', 'inactive', 'lost');

-- 性别
CREATE TYPE gender_type AS ENUM ('male', 'female', 'unknown');

-- 婚姻状态
CREATE TYPE marital_status AS ENUM ('single', 'married', 'divorced', 'widowed');

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM ('normal', 'scrapped', 'transferred', 'mortgaged', 'missing');

-- 证件类型
CREATE TYPE id_type AS ENUM ('id_card', 'passport', 'military_id', 'other');

-- 品牌类型
CREATE TYPE brand_type AS ENUM ('domestic', 'joint_venture', 'imported');

-- 能源类型
CREATE TYPE energy_type AS ENUM ('gasoline', 'diesel', 'hybrid', 'electric', 'lpg', 'other');

-- 车身颜色
CREATE TYPE vehicle_color AS ENUM ('black', 'white', 'silver', 'gray', 'red', 'blue', 'brown', 'gold', 'other');

-- 使用性质
CREATE TYPE vehicle_usage AS ENUM ('family', 'business', 'rental', 'public', 'other');

-- ================================================================
-- 第二部分: 核心表 - 客户信息 (customers)
-- ================================================================

CREATE TABLE IF NOT EXISTS customers (
    -- 主键
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息
    name VARCHAR(100) NOT NULL COMMENT '客户姓名',
    gender gender_type DEFAULT 'unknown' COMMENT '性别',
    birth_date DATE COMMENT '出生日期',
    id_type id_type DEFAULT 'id_card' COMMENT '证件类型',
    id_number VARCHAR(50) COMMENT '证件号码（加密存储）',
    phone VARCHAR(20) NOT NULL COMMENT '手机号（主联系方式）',
    phone_2 VARCHAR(20) COMMENT '备用手机号',
    email VARCHAR(100) COMMENT '电子邮箱',
    wechat VARCHAR(50) COMMENT '微信号',
    
    -- 客户画像
    customer_type customer_type DEFAULT 'individual' COMMENT '客户类型：个人/企业/政府',
    customer_source customer_source DEFAULT 'walk_in' COMMENT '客户来源',
    occupation VARCHAR(100) COMMENT '职业',
    annual_income DECIMAL(12,2) COMMENT '年收入',
    
    -- 地址信息
    province VARCHAR(50) COMMENT '省份',
    city VARCHAR(50) COMMENT '城市',
    district VARCHAR(50) COMMENT '区县',
    address VARCHAR(255) COMMENT '详细地址',
    address_lat DECIMAL(10,7) COMMENT '纬度',
    address_lng DECIMAL(10,7) COMMENT '经度',
    
    -- 家庭信息
    marital_status marital_status DEFAULT 'single' COMMENT '婚姻状态',
    family_size INTEGER COMMENT '家庭人口',
    children_count INTEGER DEFAULT 0 COMMENT '子女数量',
    children_ages JSONB DEFAULT '[]'::JSONB COMMENT '子女年龄列表',
    
    -- 紧急联系人
    emergency_contact VARCHAR(100) COMMENT '紧急联系人姓名',
    emergency_phone VARCHAR(20) COMMENT '紧急联系电话',
    emergency_relation VARCHAR(50) COMMENT '与紧急联系人的关系',
    
    -- 偏好设置
    preferred_contact_method VARCHAR(20) DEFAULT 'phone' COMMENT '首选联系方式：phone/wechat/sms/email',
    preferred_contact_time VARCHAR(50) COMMENT '最佳联系时间',
    communication_preference JSONB DEFAULT '{"sms":true,"wechat":true,"call":true}'::JSONB COMMENT '沟通偏好',
    
    -- 客户等级
    vip_level INTEGER DEFAULT 1 CHECK (vip_level BETWEEN 1 AND 5) COMMENT 'VIP等级 1-5',
    total_spent DECIMAL(12,2) DEFAULT 0 COMMENT '累计消费金额',
    total_orders INTEGER DEFAULT 0 COMMENT '累计订单数',
    total_policies INTEGER DEFAULT 0 COMMENT '累计保单数',
    lifetime_value DECIMAL(12,2) DEFAULT 0 COMMENT '客户终身价值',
    
    -- 营销标签
    tags JSONB DEFAULT '[]'::JSONB COMMENT '标签列表，如["高净值","有孩家庭","新能源车主"]',
    interests JSONB DEFAULT '[]'::JSONB COMMENT '兴趣偏好',
    
    -- 状态
    status customer_status DEFAULT 'active' COMMENT '客户状态',
    first_contact_date DATE COMMENT '首次联系日期',
    last_contact_date DATE COMMENT '最后联系日期',
    next_followup_date DATE COMMENT '下次跟进日期',
    churn_risk VARCHAR(20) DEFAULT 'low' COMMENT '流失风险：low/medium/high',
    
    -- 归属
    owner_id UUID COMMENT '专属业务员ID（引用users表）',
    department_id UUID COMMENT '所属部门',
    
    -- 备注
    notes TEXT COMMENT '客户备注',
    internal_notes TEXT COMMENT '内部备注（不对外展示）',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 约束
    CONSTRAINT customers_phone_unique UNIQUE (phone)
);

-- 客户手机号脱敏索引（用于展示）
CREATE INDEX idx_customers_phone_mask ON customers(substring(phone, 1, 3));

-- 客户姓名索引
CREATE INDEX idx_customers_name ON customers(name);

-- 客户状态索引
CREATE INDEX idx_customers_status ON customers(status);

-- VIP等级索引
CREATE INDEX idx_customers_vip ON customers(vip_level);

-- 归属业务员索引
CREATE INDEX idx_customers_owner ON customers(owner_id);

-- 下次跟进日期索引（续保提醒用）
CREATE INDEX idx_customers_followup ON customers(next_followup_date) WHERE is_deleted = FALSE;

-- 流失风险索引
CREATE INDEX idx_customers_churn ON customers(churn_risk);

-- ================================================================
-- 第三部分: 核心表 - 车辆信息 (vehicles)
-- ================================================================

CREATE TABLE IF NOT EXISTS vehicles (
    -- 主键
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联客户（核心外键）
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 车辆基础信息
    plate_number VARCHAR(20) NOT NULL COMMENT '车牌号',
    plate_province VARCHAR(10) COMMENT '车牌省份',
    plate_city VARCHAR(10) COMMENT '车牌城市',
    vin VARCHAR(50) NOT NULL UNIQUE COMMENT '车架号/VIN码',
    engine_number VARCHAR(50) COMMENT '发动机号',
    
    -- 品牌型号
    vehicle_brand VARCHAR(50) NOT NULL COMMENT '品牌',
    vehicle_series VARCHAR(50) COMMENT '车系',
    vehicle_model VARCHAR(100) NOT NULL COMMENT '型号',
    vehicle_year INTEGER COMMENT '年款',
    brand_type brand_type DEFAULT 'domestic' COMMENT '品牌类型',
    
    -- 车辆参数
    energy_type energy_type DEFAULT 'gasoline' COMMENT '能源类型',
    displacement DECIMAL(3,1) COMMENT '排量（升）',
    horsepower INTEGER COMMENT '马力',
    transmission VARCHAR(20) COMMENT '变速箱：AT/MT/CVT',
    color vehicle_color DEFAULT 'other' COMMENT '车身颜色',
    vehicle_usage vehicle_usage DEFAULT 'family' COMMENT '使用性质',
    
    -- 车辆状态
    status vehicle_status DEFAULT 'normal' COMMENT '车辆状态',
    purchase_date DATE COMMENT '购车日期',
    purchase_price DECIMAL(12,2) COMMENT '购车价格',
    current_value DECIMAL(12,2) COMMENT '当前估值',
    mileage INTEGER DEFAULT 0 COMMENT '当前里程数',
    last_maintenance_mileage INTEGER DEFAULT 0 COMMENT '上次保养里程',
    
    -- 证件信息
    registration_date DATE COMMENT '注册日期',
    issue_date DATE COMMENT '发证日期',
    certificate_number VARCHAR(50) COMMENT '登记证书编号',
    
    -- 年审信息
    annual_inspection_date DATE COMMENT '年审到期日期',
    annual_inspection_status VARCHAR(20) DEFAULT 'valid' COMMENT '年审状态：valid/due/expired',
    annual_inspection_reminder_sent BOOLEAN DEFAULT FALSE COMMENT '年审提醒是否已发送',
    
    -- 交强险信息
    compulsory_insurance_company VARCHAR(100) COMMENT '交强险承保公司',
    compulsory_policy_number VARCHAR(50) COMMENT '交强险保单号',
    compulsory_start_date DATE COMMENT '交强险生效日期',
    compulsory_end_date DATE COMMENT '交强险到期日期',
    compulsory_insurance_status VARCHAR(20) DEFAULT 'valid' COMMENT '交强险状态',
    compulsory_reminder_sent BOOLEAN DEFAULT FALSE COMMENT '交强险提醒是否已发送',
    
    -- 商业险信息
    commercial_insurance_company VARCHAR(100) COMMENT '商业险承保公司',
    commercial_policy_number VARCHAR(50) COMMENT '商业险保单号',
    commercial_start_date DATE COMMENT '商业险生效日期',
    commercial_end_date DATE COMMENT '商业险到期日期',
    commercial_insurance_status VARCHAR(20) DEFAULT 'valid' COMMENT '商业险状态',
    commercial_reminder_sent BOOLEAN DEFAULT FALSE COMMENT '商业险提醒是否已发送',
    
    -- 延保信息
    extended_warranty_company VARCHAR(100) COMMENT '延保公司',
    extended_warranty_end_date DATE COMMENT '延保到期日期',
    extended_warranty_status VARCHAR(20) DEFAULT 'valid' COMMENT '延保状态',
    
    -- 当前位置
    current_lat DECIMAL(10,7) COMMENT '当前位置纬度',
    current_lng DECIMAL(10,7) COMMENT '当前位置经度',
    current_location VARCHAR(100) COMMENT '当前位置描述',
    
    -- 车辆照片
    vehicle_photos JSONB DEFAULT '[]'::JSONB COMMENT '车辆照片URL列表',
    
    -- 备注
    notes TEXT COMMENT '车辆备注',
    internal_notes TEXT COMMENT '内部备注',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 约束
    CONSTRAINT vehicles_vin_unique UNIQUE (vin),
    CONSTRAINT vehicles_plate_unique UNIQUE (plate_number)
);

-- 车牌号索引
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number);

-- VIN码索引
CREATE INDEX idx_vehicles_vin ON vehicles(vin);

-- 客户ID索引
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id);

-- 年审到期索引
CREATE INDEX idx_vehicles_annual ON vehicles(annual_inspection_date) WHERE is_deleted = FALSE;

-- 交强险到期索引
CREATE INDEX idx_vehicles_compulsory ON vehicles(compulsory_end_date) WHERE is_deleted = FALSE;

-- 商业险到期索引
CREATE INDEX idx_vehicles_commercial ON vehicles(commercial_end_date) WHERE is_deleted = FALSE;

-- 能源类型索引
CREATE INDEX idx_vehicles_energy ON vehicles(energy_type);

-- ================================================================
-- 第四部分: 车险模块 (car_insurance)
-- ================================================================

CREATE TABLE IF NOT EXISTS car_policies (
    -- 主键
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 保单基本信息
    policy_number VARCHAR(50) NOT NULL UNIQUE COMMENT '保单号',
    policy_type VARCHAR(20) DEFAULT 'new' COMMENT '保单类型：new/renewal/transfer',
    previous_policy_id UUID COMMENT '上一期保单ID（续保关联）',
    insurance_company VARCHAR(100) NOT NULL COMMENT '承保公司',
    branch_office VARCHAR(100) COMMENT '承保分支机构',
    
    -- 投保人信息
    policy_holder_name VARCHAR(100) NOT NULL COMMENT '投保人姓名',
    policy_holder_phone VARCHAR(20) COMMENT '投保人电话',
    policy_holder_id_number VARCHAR(50) COMMENT '投保人身份证号',
    insured_name VARCHAR(100) NOT NULL COMMENT '被保险人姓名',
    insured_phone VARCHAR(20) COMMENT '被保险人电话',
    
    -- 车辆信息（快照）
    plate_number VARCHAR(20) NOT NULL COMMENT '车牌号（快照）',
    vin VARCHAR(50) NOT NULL COMMENT 'VIN码（快照）',
    vehicle_model VARCHAR(100) COMMENT '车型（快照）',
    vehicle_price DECIMAL(12,2) COMMENT '车辆购置价（快照）',
    
    -- 保险期间
    insurance_start_date DATE NOT NULL COMMENT '保险生效日期',
    insurance_end_date DATE NOT NULL COMMENT '保险到期日期',
    insurance_period INTEGER COMMENT '保险期间（天）',
    
    -- 险种信息（JSON存储所有险种明细）
    coverage_details JSONB NOT NULL DEFAULT '[]'::JSONB COMMENT '险种明细数组',
    /*
    格式示例：
    [
      {"type":"compulsory","premium":950,"coverage":122000},
      {"type":"third_party_100","premium":1200,"coverage":1000000},
      {"type":"driver_duty","premium":300,"coverage":100000},
      {"type":"passenger_duty","premium":200,"coverage":100000},
      {"type":"glass","premium":500,"coverage":5000,"type_detail":"国产玻璃"},
      {"type":"scratch_5000","premium":800,"coverage":5000},
      {"type":"water_damage","premium":300,"coverage":50000},
      {"type":"specific_scratch","premium":1000,"coverage":2000000}
    ]
    */
    
    -- 保费信息
    total_premium DECIMAL(10,2) NOT NULL COMMENT '总保费',
    compulsory_premium DECIMAL(10,2) DEFAULT 0 COMMENT '交强险保费',
    commercial_premium DECIMAL(10,2) DEFAULT 0 COMMENT '商业险保费',
    tax_amount DECIMAL(10,2) DEFAULT 0 COMMENT '车船税',
    actual_premium DECIMAL(10,2) COMMENT '实际保费（优惠后）',
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    discount_rate DECIMAL(5,4) COMMENT '折扣率',
    
    -- 佣金信息
    commission_rate DECIMAL(5,4) COMMENT '佣金比例',
    commission_amount DECIMAL(10,2) COMMENT '佣金金额',
    actual_commission DECIMAL(10,2) COMMENT '实际佣金（扣除税点后）',
    commission_received BOOLEAN DEFAULT FALSE COMMENT '佣金是否到账',
    commission_received_date DATE COMMENT '佣金到账日期',
    
    -- 费用信息
    service_fee DECIMAL(10,2) DEFAULT 0 COMMENT '服务费',
    handling_fee DECIMAL(10,2) DEFAULT 0 COMMENT '手续费',
    
    -- 出险信息
    claim_count_current INTEGER DEFAULT 0 COMMENT '本保期出险次数',
    claim_amount_current DECIMAL(12,2) DEFAULT 0 COMMENT '本保期出险金额',
    claim_history JSONB DEFAULT '[]'::JSONB COMMENT '出险历史',
    /*
    格式示例：
    [
      {"date":"2025-06-15","type":"collision","amount":5000,"description":"追尾"},
      {"date":"2025-09-20","type":"scratch","amount":2000,"description":"刮擦"}
    ]
    */
    
    -- 状态
    policy_status VARCHAR(20) DEFAULT 'active' COMMENT '保单状态：pending/active/expired/cancelled/renewed',
    renewal_status VARCHAR(20) DEFAULT 'pending' COMMENT '续保状态：pending/contacted/quoted/renewed/lost',
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '支付状态：unpaid/paid/partially_paid/refunded',
    payment_date DATE COMMENT '支付日期',
    payment_method VARCHAR(20) COMMENT '支付方式：transfer/wechat/alipay/cash',
    
    -- 归属
    owner_id UUID COMMENT '业务员ID',
    department_id UUID COMMENT '部门ID',
    source_channel VARCHAR(50) COMMENT '来源渠道',
    
    -- 关联
    quote_id UUID COMMENT '报价单ID',
    claim_ids JSONB DEFAULT '[]'::JSONB COMMENT '关联理赔单ID列表',
    
    -- 续保跟进
    renewal_contact_date DATE COMMENT '续保联系日期',
    renewal_contact_count INTEGER DEFAULT 0 COMMENT '续保联系次数',
    renewal_quote_amount DECIMAL(10,2) COMMENT '续保报价金额',
    renewal_intent VARCHAR(20) COMMENT '续保意向：strong/medium/low/no',
    competitor_quotes JSONB DEFAULT '[]'::JSONB COMMENT '竞品报价记录',
    
    -- 文件
    policy_documents JSONB DEFAULT '[]'::JSONB COMMENT '保单文件URL列表',
    
    -- 备注
    notes TEXT COMMENT '备注',
    internal_notes TEXT COMMENT '内部备注',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 保单号索引
CREATE INDEX idx_car_policies_number ON car_policies(policy_number);

-- 客户ID索引
CREATE INDEX idx_car_policies_customer ON car_policies(customer_id);

-- 车辆ID索引
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id);

-- 到期日期索引（续保提醒核心索引）
CREATE INDEX idx_car_policies_expiry ON car_policies(insurance_end_date) WHERE is_deleted = FALSE;

-- 续保状态索引
CREATE INDEX idx_car_policies_renewal ON car_policies(renewal_status);

-- 业务员索引
CREATE INDEX idx_car_policies_owner ON car_policies(owner_id);

-- 承保公司索引
CREATE INDEX idx_car_policies_company ON car_policies(insurance_company);

-- 保单状态索引
CREATE INDEX idx_car_policies_status ON car_policies(policy_status);

-- ================================================================
-- 第五部分: 非车险模块 (noncar_insurance)
-- ================================================================

CREATE TYPE noncar_policy_category AS ENUM (
    'accident',        -- 意外险
    'health',          -- 健康险
    'life',            -- 寿险
    'property',        -- 家财险
    'liability',       -- 责任险
    'engineering',     -- 工程险
    'cargo',           -- 货运险
    'credit',          -- 信用保证险
    'other'            -- 其他
);

CREATE TYPE noncar_policy_status AS ENUM (
    'quoting',        -- 询价中
    'pending',         -- 待支付
    'active',         -- 生效中
    'expired',        -- 已过期
    'cancelled',      -- 已退保
    'claimed'         -- 已理赔
);

CREATE TABLE IF NOT EXISTS noncar_policies (
    -- 主键
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL COMMENT '关联车辆（可选）',
    car_policy_id UUID REFERENCES car_policies(id) ON DELETE SET NULL COMMENT '关联车险保单（交叉销售）',
    
    -- 保单基本信息
    policy_number VARCHAR(50) NOT NULL UNIQUE COMMENT '保单号',
    policy_name VARCHAR(200) NOT NULL COMMENT '产品名称',
    policy_category noncar_policy_category NOT NULL COMMENT '险种类别',
    insurance_company VARCHAR(100) NOT NULL COMMENT '承保公司',
    plan_name VARCHAR(100) COMMENT '方案名称',
    
    -- 投保人/被保险人
    policy_holder_name VARCHAR(100) NOT NULL COMMENT '投保人姓名',
    policy_holder_phone VARCHAR(20) COMMENT '投保人电话',
    policy_holder_id_number VARCHAR(50) COMMENT '投保人身份证',
    insured_name VARCHAR(100) COMMENT '被保险人姓名',
    
    -- 保险期间
    insurance_start_date DATE NOT NULL COMMENT '生效日期',
    insurance_end_date DATE NOT NULL COMMENT '到期日期',
    
    -- 保障信息
    coverage_amount DECIMAL(12,2) COMMENT '保额',
    coverage_details JSONB DEFAULT '{}'::JSONB COMMENT '保障详情',
    /*
    示例：
    {
      "death_disability": 500000,
      "medical": 50000,
      "hospitalization": 200,
      "accident": 100000
    }
    */
    
    -- 保费信息
    premium DECIMAL(10,2) NOT NULL COMMENT '保费',
    actual_premium DECIMAL(10,2) COMMENT '实收保费',
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    
    -- 佣金信息
    commission_rate DECIMAL(5,4) COMMENT '佣金比例',
    commission_amount DECIMAL(10,2) COMMENT '佣金金额',
    actual_commission DECIMAL(10,2) COMMENT '实际佣金',
    commission_received BOOLEAN DEFAULT FALSE COMMENT '佣金到账',
    
    -- 状态
    policy_status noncar_policy_status DEFAULT 'quoting' COMMENT '保单状态',
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '支付状态',
    payment_date DATE COMMENT '支付日期',
    
    -- 归属
    owner_id UUID COMMENT '业务员ID',
    cross_sell_source VARCHAR(50) COMMENT '交叉销售来源（from_car_policy等）',
    
    -- 续费
    auto_renewal BOOLEAN DEFAULT FALSE COMMENT '是否自动续费',
    renewal_reminder_sent BOOLEAN DEFAULT FALSE COMMENT '续费提醒是否发送',
    
    -- 文件
    policy_documents JSONB DEFAULT '[]'::JSONB COMMENT '保单文件',
    
    -- 备注
    notes TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_noncar_policies_customer ON noncar_policies(customer_id);
CREATE INDEX idx_noncar_policies_expiry ON noncar_policies(insurance_end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_category ON noncar_policies(policy_category);
CREATE INDEX idx_noncar_policies_status ON noncar_policies(policy_status);
CREATE INDEX idx_noncar_policies_owner ON noncar_policies(owner_id);

-- ================================================================
-- 第六部分: 年审保养模块 (vehicle_services)
-- ================================================================

CREATE TYPE service_type AS ENUM (
    'annual_inspection',   -- 年审
    'maintenance',         -- 保养
    'repair',              -- 维修
    'tire',                -- 轮胎更换
    'battery',             -- 电瓶更换
    'brake',               -- 刹车维修
    'other'                -- 其他
);

CREATE TYPE service_status AS ENUM (
    'scheduled',       -- 已预约
    'confirmed',       -- 已确认
    'in_progress',      -- 服务中
    'completed',       -- 已完成
    'cancelled',       -- 已取消
    'postponed'        -- 已延期
);

CREATE TYPE service_provider_type AS ENUM (
    '4s_store',        -- 4S店
    'authorized_shop', -- 授权店
    'independent_shop',-- 修理厂
    'gas_station',     -- 加油站
    'mobile_service',  -- 上门服务
    'other'            -- 其他
);

CREATE TABLE IF NOT EXISTS vehicle_services (
    -- 主键
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 服务信息
    service_type service_type NOT NULL COMMENT '服务类型',
    service_name VARCHAR(200) COMMENT '服务名称/项目',
    service_date DATE NOT NULL COMMENT '服务日期',
    service_time TIME COMMENT '服务时间',
    
    -- 服务机构
    provider_id UUID COMMENT '服务商ID（关联service_providers表）',
    provider_name VARCHAR(200) NOT NULL COMMENT '服务商名称',
    provider_type service_provider_type DEFAULT 'independent_shop' COMMENT '服务商类型',
    provider_phone VARCHAR(20) COMMENT '服务商电话',
    provider_address VARCHAR(255) COMMENT '服务商地址',
    
    -- 车辆状态（服务前）
    mileage_before INTEGER COMMENT '服务前里程',
    vehicle_condition TEXT COMMENT '服务前车辆状况描述',
    
    -- 服务内容
    service_items JSONB NOT NULL DEFAULT '[]'::JSONB COMMENT '服务项目明细',
    /*
    格式示例：
    [
      {"item":"机油机滤更换","quantity":1,"unit":"次","unit_price":300,"subtotal":300,"brand":"壳牌","spec":"5W-30"},
      {"item":"空气滤芯","quantity":1,"unit":"个","unit_price":80,"subtotal":80},
      {"item":"工时费","quantity":1,"unit":"次","unit_price":100,"subtotal":100}
    ]
    */
    
    -- 费用信息
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '总费用',
    parts_cost DECIMAL(10,2) DEFAULT 0 COMMENT '配件费用',
    labor_cost DECIMAL(10,2) DEFAULT 0 COMMENT '工时费用',
    other_costs DECIMAL(10,2) DEFAULT 0 COMMENT '其他费用',
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    actual_amount DECIMAL(10,2) COMMENT '实收金额',
    
    -- 返佣信息
    commission_rate DECIMAL(5,4) COMMENT '返佣比例',
    commission_amount DECIMAL(10,2) COMMENT '返佣金额',
    commission_received BOOLEAN DEFAULT FALSE COMMENT '返佣是否到账',
    
    -- 状态
    service_status service_status DEFAULT 'scheduled' COMMENT '服务状态',
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '支付状态：unpaid/paid/partially_paid/refunded',
    payment_method VARCHAR(20) COMMENT '支付方式',
    payment_date DATE COMMENT '支付日期',
    
    -- 发票
    invoice_issued BOOLEAN DEFAULT FALSE COMMENT '是否开票',
    invoice_number VARCHAR(50) COMMENT '发票号',
    invoice_amount DECIMAL(10,2) COMMENT '发票金额',
    
    -- 质量保证
    warranty_period INTEGER COMMENT '质保期（天）',
    warranty_end_date DATE COMMENT '质保到期日期',
    quality_issues TEXT COMMENT '质量问题记录',
    
    -- 车辆状态（服务后）
    mileage_after INTEGER COMMENT '服务后里程',
    next_service_mileage INTEGER COMMENT '下次保养里程',
    next_service_date DATE COMMENT '下次保养日期',
    next_service_items JSONB DEFAULT '[]'::JSONB COMMENT '建议下次保养项目',
    
    -- 评价
    customer_rating INTEGER CHECK (customer_rating BETWEEN 1 AND 5) COMMENT '客户评分1-5',
    customer_feedback TEXT COMMENT '客户反馈',
    customer_review_photos JSONB DEFAULT '[]'::JSONB COMMENT '客户评价照片',
    
    -- 归属
    owner_id UUID COMMENT '跟进业务员ID',
    
    -- 备注
    notes TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_services_customer ON vehicle_services(customer_id);
CREATE INDEX idx_services_vehicle ON vehicle_services(vehicle_id);
CREATE INDEX idx_services_date ON vehicle_services(service_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_services_type ON vehicle_services(service_type);
CREATE INDEX idx_services_status ON vehicle_services(service_status);
CREATE INDEX idx_services_provider ON vehicle_services(provider_id);
CREATE INDEX idx_services_next ON vehicle_services(next_service_date) WHERE is_deleted = FALSE AND next_service_date IS NOT NULL;

-- 服务商表
CREATE TABLE IF NOT EXISTS service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL COMMENT '服务商名称',
    type service_provider_type NOT NULL COMMENT '服务商类型',
    brand VARCHAR(200) COMMENT '合作品牌',
    phone VARCHAR(20),
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address VARCHAR(255),
    lat DECIMAL(10,7),
    lng DECIMAL(10,7),
    business_hours VARCHAR(100) COMMENT '营业时间',
    rating DECIMAL(3,2) CHECK (rating BETWEEN 0 AND 5),
    review_count INTEGER DEFAULT 0,
    services JSONB DEFAULT '[]'::JSONB COMMENT '提供的服务类型列表',
    certifications JSONB DEFAULT '[]'::JSONB COMMENT '资质证书',
    photos JSONB DEFAULT '[]'::JSONB COMMENT '门店照片',
    contract_status VARCHAR(20) DEFAULT 'none' COMMENT '签约状态：none/pending/active/expired',
    commission_rate DECIMAL(5,4) COMMENT '返佣比例',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_providers_type ON service_providers(type);
CREATE INDEX idx_providers_city ON service_providers(city);

-- ================================================================
-- 第七部分: 汽车后市场模块 (after_market)
-- ================================================================

CREATE TYPE order_type AS ENUM (
    'rescue',           -- 道路救援
    'beauty',           -- 汽车美容
    'modification',     -- 汽车改装
    'accessories',      -- 配件商城
    'car_wash',         -- 洗车
    'coating',          -- 镀晶镀膜
    'window_film',      -- 贴膜
    'lighting',         -- 车灯升级
    'audio',            -- 音响改装
    'parking',          -- 行车记录仪/停车监控
    '违章',             -- 违章代办
    'other'             -- 其他
);

CREATE TYPE order_status AS ENUM (
    'created',          -- 已创建
    'confirmed',        -- 已确认
    'processing',       -- 处理中
    'dispatched',       -- 已派单
    'in_service',       -- 服务中
    'completed',        -- 已完成
    'cancelled',        -- 已取消
    'refunded'          -- 已退款
);

CREATE TYPE payment_method AS ENUM (
    'wechat',           -- 微信支付
    'alipay',           -- 支付宝
    'transfer',         -- 银行转账
    'cash',             -- 现金
    'card',             -- 刷卡
    'points',           -- 积分抵扣
    'mixed'             -- 混合支付
);

CREATE TABLE IF NOT EXISTS after_market_orders (
    -- 主键
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 订单信息
    order_number VARCHAR(50) NOT NULL UNIQUE COMMENT '订单号',
    order_type order_type NOT NULL COMMENT '订单类型',
    order_name VARCHAR(200) COMMENT '订单名称/项目',
    
    -- 紧急程度
    urgency VARCHAR(20) DEFAULT 'normal' COMMENT '紧急程度：normal/urgent/emergency',
    
    -- 服务信息
    service_address VARCHAR(255) COMMENT '服务地址',
    service_lat DECIMAL(10,7) COMMENT '服务地址纬度',
    service_lng DECIMAL(10,7) COMMENT '服务地址经度',
    service_date DATE COMMENT '服务日期',
    service_time TIME COMMENT '服务时间',
    estimated_duration INTEGER COMMENT '预计时长（分钟）',
    
    -- 服务商
    provider_id UUID REFERENCES service_providers(id) ON DELETE SET NULL,
    provider_name VARCHAR(200) COMMENT '服务商名称',
    assigned_worker VARCHAR(100) COMMENT '服务人员姓名',
    assigned_worker_phone VARCHAR(20) COMMENT '服务人员电话',
    
    -- 订单明细
    order_items JSONB NOT NULL DEFAULT '[]'::JSONB COMMENT '订单明细',
    /*
    格式示例：
    [
      {"product":"全车镀晶","quantity":1,"unit":"次","unit_price":1500,"subtotal":1500},
      {"product":"洗车","quantity":1,"unit":"次","unit_price":50,"subtotal":50}
    ]
    */
    
    -- 费用
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '小计',
    service_fee DECIMAL(10,2) DEFAULT 0 COMMENT '服务费',
    delivery_fee DECIMAL(10,2) DEFAULT 0 COMMENT '上门费/配送费',
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    coupon_id UUID COMMENT '使用的优惠券ID',
    coupon_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠券抵扣',
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '订单总金额',
    actual_amount DECIMAL(10,2) COMMENT '实收金额',
    
    -- 支付
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '支付状态',
    payment_method payment_method COMMENT '支付方式',
    payment_date DATE COMMENT '支付日期',
    payment_screenshot JSONB DEFAULT '[]'::JSONB COMMENT '支付截图URL',
    
    -- 佣金
    commission_rate DECIMAL(5,4) COMMENT '返佣比例',
    commission_amount DECIMAL(10,2) COMMENT '返佣金额',
    commission_received BOOLEAN DEFAULT FALSE COMMENT '返佣到账',
    
    -- 状态
    order_status order_status DEFAULT 'created' COMMENT '订单状态',
    
    -- 违章信息（仅违章代办类型）
    violation_province VARCHAR(20) COMMENT '违章省份',
    violation_city VARCHAR(50) COMMENT '违章城市',
    violation_count INTEGER COMMENT '违章次数',
    violation_details JSONB DEFAULT '[]'::JSONB COMMENT '违章明细',
    violation_handling_fee DECIMAL(10,2) COMMENT '代办手续费',
    violation_fine_total DECIMAL(10,2) COMMENT '罚款总额',
    violation_score_total INTEGER COMMENT '扣分总额',
    
    -- 救援信息（仅道路救援类型）
    rescue_type VARCHAR(50) COMMENT '救援类型：搭电/换胎/拖车/送油/开锁等',
    rescue_reason TEXT COMMENT '救援原因',
    rescue_location VARCHAR(255) COMMENT '救援地点',
    rescue_lat DECIMAL(10,7) COMMENT '救援地点纬度',
    rescue_lng DECIMAL(10,7) COMMENT '救援地点经度',
    rescue_start_time TIMESTAMPTZ COMMENT '救援开始时间',
    rescue_end_time TIMESTAMPTZ COMMENT '救援结束时间',
    rescue_duration INTEGER COMMENT '救援时长（分钟）',
    rescue_distance DECIMAL(8,2) COMMENT '拖车距离（公里）',
    
    -- 完成信息
    completion_date TIMESTAMPTZ COMMENT '完成时间',
    completion_photos JSONB DEFAULT '[]'::JSONB COMMENT '完成照片',
    
    -- 评价
    customer_rating INTEGER CHECK (customer_rating BETWEEN 1 AND 5),
    customer_feedback TEXT,
    owner_rating INTEGER CHECK (owner_rating BETWEEN 1 AND 5),
    owner_feedback TEXT,
    
    -- 归属
    owner_id UUID COMMENT '业务员ID',
    
    -- 备注
    notes TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_orders_customer ON after_market_orders(customer_id);
CREATE INDEX idx_orders_vehicle ON after_market_orders(vehicle_id);
CREATE INDEX idx_orders_number ON after_market_orders(order_number);
CREATE INDEX idx_orders_type ON after_market_orders(order_type);
CREATE INDEX idx_orders_status ON after_market_orders(order_status);
CREATE INDEX idx_orders_date ON after_market_orders(service_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_orders_owner ON after_market_orders(owner_id);
