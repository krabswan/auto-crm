-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema V1.0
-- 创建日期：2026-04-19
-- 作者：痞老板
-- 说明：模块化设计，各模块独立又可整合
-- ============================================================

-- ============================================================
-- 第0部分：公共扩展
-- ============================================================

-- 创建UUID扩展（Supabase默认已开启，保留以确保兼容性）
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 创建时间戳带时区的别名
CREATE DOMAIN timestamptz AS TIMESTAMP WITH TIME ZONE;

-- ============================================================
-- 第1部分：系统基础表（必须首先创建）
-- ============================================================

-- -------------------------------------------------------
-- 1.1 用户表（内部团队成员）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    real_name VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'agent' CHECK (role IN ('admin', 'manager', 'agent', 'viewer')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    avatar_url TEXT,
    last_login_at TIMESTAMPTZ,
    last_login_ip VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID
);

COMMENT ON TABLE system_users IS '系统用户表 - 内部团队成员管理';
COMMENT ON COLUMN system_users.role IS '角色：admin=超级管理员,manager=经理,agent=业务员,viewer=查看者';

-- -------------------------------------------------------
-- 1.2 部门/团队表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    parent_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    manager_id UUID REFERENCES system_users(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE departments IS '部门表 - 团队组织架构';

-- -------------------------------------------------------
-- 1.3 系统配置表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    config_type VARCHAR(50) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json', 'text')),
    config_group VARCHAR(50) DEFAULT 'general',
    config_label VARCHAR(200),
    config_description TEXT,
    is_public BOOLEAN DEFAULT FALSE,  -- 是否公开（网站可展示）
    is_encrypted BOOLEAN DEFAULT FALSE, -- 是否加密存储
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1
);

COMMENT ON TABLE system_configs IS '系统配置表 - 键值对存储系统配置';

-- 初始化默认配置
INSERT INTO system_configs (config_key, config_value, config_type, config_group, config_label, is_public) VALUES
('system_name', '汽车全生态客户管理系统', 'string', 'general', '系统名称', TRUE),
('system_version', 'V1.0.0', 'string', 'general', '系统版本', TRUE),
('company_name', '蟹老板车险工作室', 'string', 'company', '公司名称', TRUE),
('contact_phone', '13328185024', 'string', 'company', '联系电话', TRUE),
('auto_backup_enabled', 'true', 'boolean', 'backup', '自动备份开关', FALSE),
('backup_retention_days', '365', 'number', 'backup', '备份保留天数', FALSE),
('renewal_reminder_days', '30', 'number', 'reminder', '续保提前提醒天数', FALSE),
('annual_inspection_reminder_days', '90', 'number', 'reminder', '年审提前提醒天数', FALSE),
('min_password_length', '8', 'number', 'security', '最小密码长度', FALSE),
('session_timeout_minutes', '480', 'number', 'security', '会话超时时间(分钟)', FALSE);

-- -------------------------------------------------------
-- 1.4 字典表（数据字典/枚举值）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_dicts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dict_type VARCHAR(50) NOT NULL,       -- 字典类型（模块）
    dict_code VARCHAR(100) NOT NULL,      -- 字典码
    dict_label VARCHAR(200) NOT NULL,     -- 显示标签
    dict_value TEXT,                       -- 字典值
    dict_sort INTEGER DEFAULT 0,
    is_enabled BOOLEAN DEFAULT TRUE,
    parent_code VARCHAR(100),             -- 父级字典码（树形结构）
    extra_data JSONB,                      -- 扩展数据
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    UNIQUE(dict_type, dict_code)
);

COMMENT ON TABLE data_dicts IS '数据字典表 - 统一管理枚举值和选项';

-- 初始化数据字典
INSERT INTO data_dicts (dict_type, dict_code, dict_label, dict_sort) VALUES
-- 客户类型
('customer_type', 'individual', '个人客户', 1),
('customer_type', 'enterprise', '企业客户', 2),
-- 客户来源
('customer_source', 'walk_in', '自然到店', 1),
('customer_source', 'referral', '老客推荐', 2),
('customer_source', 'online', '网络获客', 3),
('customer_source', 'partner', '合作伙伴', 4),
('customer_source', 'other', '其他渠道', 5),
-- 客户等级
('customer_level', 'vip', 'VIP客户', 1),
('customer_level', 'important', '重要客户', 2),
('customer_level', 'normal', '普通客户', 3),
('customer_level', 'potential', '潜在客户', 4),
-- 保险状态
('insurance_status', 'pending', '待生效', 1),
('insurance_status', 'active', '生效中', 2),
('insurance_status', 'expired', '已过期', 3),
('insurance_status', 'cancelled', '已退保', 4),
('insurance_status', 'renewed', '已续保', 5),
-- 承保公司
('insurance_company', 'pingan', '平安保险', 1),
('insurance_company', 'pacific', '太平洋保险', 2),
('insurance_company', 'renbao', '中国人保', 3),
('insurance_company', 'taiping', '太平保险', 4),
('insurance_company', 'anbang', '安邦保险', 5),
('insurance_company', 'guohua', '国华人寿', 6),
('insurance_company', 'other', '其他公司', 99),
-- 车辆状态
('vehicle_status', 'normal', '正常使用', 1),
('vehicle_status', 'maintenance', '维修中', 2),
('vehicle_status', 'scrapped', '已报废', 3),
('vehicle_status', 'transferred', '已过户', 4),
-- 保养类型
('maintenance_type', 'regular', '常规保养', 1),
('maintenance_type', 'repair', '维修', 2),
('maintenance_type', 'inspection', '年审', 3),
('maintenance_type', 'tire', '轮胎更换', 4),
('maintenance_type', 'battery', '电瓶更换', 5),
('maintenance_type', 'other', '其他', 99),
-- 支付方式
('payment_method', 'cash', '现金', 1),
('payment_method', 'transfer', '银行转账', 2),
('payment_method', 'wechat', '微信支付', 3),
('payment_method', 'alipay', '支付宝', 4),
('payment_method', 'insurance_claim', '保险理赔', 5),
('payment_method', 'installment', '分期付款', 6),
-- 订单状态
('order_status', 'pending', '待处理', 1),
('order_status', 'confirmed', '已确认', 2),
('order_status', 'processing', '处理中', 3),
('order_status', 'completed', '已完成', 4),
('order_status', 'cancelled', '已取消', 5),
('order_status', 'refunded', '已退款', 6),
-- 金融产品类型
('finance_type', 'new_car_loan', '新车贷款', 1),
('finance_type', 'used_car_loan', '二手车贷款', 2),
('finance_type', 'refinance', '车辆抵押贷款', 3),
('finance_type', 'leasing', '融资租赁', 4);

-- -------------------------------------------------------
-- 1.5 地区表（简化的行政区划）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS regions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,  -- 行政区划代码
    name VARCHAR(100) NOT NULL,         -- 地区名称
    level INTEGER DEFAULT 1 CHECK (level BETWEEN 1 AND 5),  -- 级别：1=省,2=市,3=区/县,4=街道,5=村
    parent_code VARCHAR(20),           -- 父级代码
    area_code VARCHAR(10),             -- 电话区号
    postal_code VARCHAR(10),           -- 邮政编码
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE regions IS '地区表 - 简化的行政区划数据';

-- 初始化江苏省常州市金坛区
INSERT INTO regions (code, name, level, parent_code, area_code, postal_code) VALUES
('320000', '江苏省', 1, NULL, '025', '210000'),
('320400', '常州市', 2, '320000', '0519', '213000'),
('320412', '金坛区', 3, '320400', '0519', '213200');

-- ============================================================
-- 第2部分：客户中心（所有模块的核心）
-- ============================================================

-- -------------------------------------------------------
-- 2.1 客户主表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 基本信息
    customer_code VARCHAR(50) UNIQUE NOT NULL,  -- 客户编码（自动生成）
    customer_type VARCHAR(50) NOT NULL DEFAULT 'individual' CHECK (customer_type IN ('individual', 'enterprise')),
    customer_name VARCHAR(200) NOT NULL,         -- 客户姓名/企业名称
    customer_level VARCHAR(50) DEFAULT 'normal', -- 客户等级
    customer_source VARCHAR(50),                  -- 客户来源
    id_card_number VARCHAR(18),                   -- 身份证号（加密存储）
    id_card_hash VARCHAR(64),                     -- 身份证Hash（用于查重，不存储原文）
    
    -- 联系信息
    phone VARCHAR(20) NOT NULL,
    phone_hash VARCHAR(64),                        -- 手机号Hash（用于查重）
    alternative_phone VARCHAR(20),                 -- 备用电话
    email VARCHAR(255),
    wechat_openid VARCHAR(100),                   -- 微信OpenID（用于小程序）
    
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address_detail TEXT,                           -- 详细地址
    
    -- 附加信息
    birthday DATE,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'unknown')),
    occupation VARCHAR(100),                      -- 职业
    annual_income VARCHAR(50),                    -- 年收入
    hobbies TEXT,                                  -- 爱好（用于精准营销）
    
    -- 客户标签（JSON数组，方便统计）
    tags JSONB DEFAULT '[]',
    
    -- 客户评分（0-100）
    score INTEGER DEFAULT 50 CHECK (score BETWEEN 0 AND 100),
    
    -- 归属信息
    owner_user_id UUID REFERENCES system_users(id),  -- 归属业务员
    owner_department_id UUID REFERENCES departments(id),  -- 归属部门
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blacklist', 'lost')),
    
    -- 来源记录
    first_source VARCHAR(50),                      -- 首次来源
    first_contact_at TIMESTAMPTZ,                  -- 首次联系时间
    
    -- 统计字段
    total_policy_count INTEGER DEFAULT 0,          -- 总保单数
    total_premium DECIMAL(15,2) DEFAULT 0,          -- 总保费（累计）
    total_commission DECIMAL(15,2) DEFAULT 0,      -- 总佣金（累计）
    last_policy_at TIMESTAMPTZ,                    -- 最近一次保单时间
    last_service_at TIMESTAMPTZ,                   -- 最近一次服务时间
    
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
    deleted_by UUID
);

COMMENT ON TABLE customers IS '客户主表 - 统一客户数据中心';
CREATE INDEX idx_customers_phone ON customers(phone_hash) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_idcard ON customers(id_card_hash) WHERE is_deleted = FALSE AND id_card_hash IS NOT NULL;
CREATE INDEX idx_customers_owner ON customers(owner_user_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_status ON customers(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_level ON customers(customer_level) WHERE is_deleted = FALSE;

-- 自动生成客户编码的函数
CREATE OR REPLACE FUNCTION generate_customer_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_code IS NULL OR NEW.customer_code = '' THEN
        NEW.customer_code := 'C' || TO_CHAR(NOW(), 'YYYYMMDD') || 
                              SUBSTR(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_customer_code
    BEFORE INSERT ON customers
    FOR EACH ROW
    EXECUTE FUNCTION generate_customer_code();

-- -------------------------------------------------------
-- 2.2 车辆表（关联客户，一人可以多车）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 客户关联（核心外键）
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 车辆基本信息
    plate_number VARCHAR(20) NOT NULL,            -- 车牌号（脱敏存储）
    plate_number_hash VARCHAR(64) NOT NULL,        -- 车牌号Hash（用于查重）
    plate_province VARCHAR(20),                    -- 车牌省份
    plate_city VARCHAR(20),                        -- 车牌城市
    
    vehicle_type VARCHAR(50) NOT NULL CHECK (vehicle_type IN ('passenger', 'truck', 'bus', 'other')),
    vehicle_use_type VARCHAR(50) DEFAULT 'family' CHECK (vehicle_use_type IN ('family', 'business', 'rental', 'government', 'other')),
    brand VARCHAR(100),                             -- 品牌
    series VARCHAR(100),                           -- 车系
    model VARCHAR(200),                             -- 车型（具体型号）
    vin VARCHAR(50) NOT NULL UNIQUE,               -- 车架号（唯一）
    vin_hash VARCHAR(64) NOT NULL,                  -- VIN Hash
    
    -- 车辆参数
    register_date DATE,                            -- 注册日期
    manufacture_date DATE,                         -- 制造日期
    engine_number VARCHAR(50),                      -- 发动机号
    displacement DECIMAL(5,2),                    -- 排量(L)
    emission_standard VARCHAR(20),                  -- 排放标准
    seater_count INTEGER DEFAULT 5,                -- 座位数
    curb_weight DECIMAL(8,2),                      -- 整备质量(kg)
    
    -- 年审信息
    annual_inspection_date DATE,                   -- 年审有效期
    annual_inspection_reminded BOOLEAN DEFAULT FALSE,  -- 是否已提醒
    
    -- 交强险信息
    compulsory_insurance_policy_id UUID,           -- 最新交强险保单ID
    compulsory_insurance_expire_date DATE,         -- 交强险到期日
    
    -- 商业险信息
    commercial_insurance_policy_id UUID,            -- 最新商业险保单ID
    commercial_insurance_expire_date DATE,         -- 商业险到期日
    
    -- 车船税信息
    vehicle_tax_status VARCHAR(20) DEFAULT 'paid',  -- 车船税缴纳状态
    vehicle_tax_amount DECIMAL(10,2),              -- 车船税金额
    vehicle_tax_year INTEGER,                       -- 车船税年度
    
    -- 车辆状态
    status VARCHAR(20) DEFAULT 'normal' CHECK (status IN ('normal', 'maintenance', 'scrapped', 'transferred', 'mortgaged')),
    current_mileage DECIMAL(12,1),                 -- 当前里程数(km)
    last_maintenance_date DATE,                     -- 最近保养日期
    last_maintenance_mileage DECIMAL(12,1),        -- 最近保养里程
    
    -- 保险配置（默认方案）
    prefer_insurance_company VARCHAR(50),          -- 偏好保险公司
    prefer_insurance_agent VARCHAR(50),            -- 偏好保险方案
    is_high_risk BOOLEAN DEFAULT FALSE,            -- 高风险车辆标记
    
    -- 外观信息（图片URL）
    vehicle_photos JSONB DEFAULT '[]',              -- 车辆照片
    vehicle_condition VARCHAR(50),                  -- 车辆状况
    
    -- 估值信息
    estimated_value DECIMAL(15,2),                 -- 估值(元)
    residual_value DECIMAL(15,2),                  -- 残值(元)
    
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
    deleted_by UUID
);

COMMENT ON TABLE vehicles IS '车辆表 - 一客户多车辆管理';
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number_hash) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_vin ON vehicles(vin_hash) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_annual ON vehicles(annual_inspection_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_compulsory_expire ON vehicles(compulsory_insurance_expire_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_commercial_expire ON vehicles(commercial_insurance_expire_date) WHERE is_deleted = FALSE;

-- -------------------------------------------------------
-- 2.3 车辆补充信息表（扩展字段）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicle_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    
    -- 颜色
    color VARCHAR(50),
    
    -- 购车信息
    purchase_price DECIMAL(15,2),                  -- 购车价格
    purchase_date DATE,                             -- 购车日期
    purchase_dealer VARCHAR(200),                   -- 购车经销商
    
    -- 贷款信息
    has_loan BOOLEAN DEFAULT FALSE,
    loan_amount DECIMAL(15,2),
    loan_bank VARCHAR(100),
    loan_months INTEGER,
    loan_monthly_payment DECIMAL(10,2),
    loan_remaining DECIMAL(15,2),
    loan_end_date DATE,
    
    -- 首保信息
    first_insurance_company VARCHAR(100),
    first_insurance_date DATE,
    first_insurance_premium DECIMAL(10,2),
    
    -- 环保信息
    emission_standard_detail VARCHAR(50),          -- 排放标准详情
    
    -- 行驶证信息
    driving_license_number VARCHAR(50),
    driving_license_issued_date DATE,
    driving_license_photo_url TEXT,
    
    -- 登记证信息
    vehicle_certificate_number VARCHAR(50),
    vehicle_certificate_photo_url TEXT,
    
    -- 其他图片
    insurance_photos JSONB DEFAULT '[]',            -- 保险单照片
    accident_photos JSONB DEFAULT '[]',             -- 出险照片
    
    -- 扩展字段（JSON自由扩展）
    extra_data JSONB DEFAULT '{}',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1
);

COMMENT ON TABLE vehicle_profiles IS '车辆补充信息表 - 存放详细扩展信息';

-- ============================================================
-- 第3部分：车险模块
-- ============================================================

-- -------------------------------------------------------
-- 3.1 车险保单表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS car_insurance_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    previous_policy_id UUID REFERENCES car_insurance_policies(id) ON DELETE SET NULL,  -- 续保关联
    
    -- 保单基本信息
    policy_number VARCHAR(100) UNIQUE NOT NULL,     -- 保单号
    policy_type VARCHAR(50) NOT NULL CHECK (policy_type IN ('compulsory', 'commercial', 'combined')),
    
    -- 保险公司
    insurance_company VARCHAR(50) NOT NULL,         -- 保险公司编码
    insurance_company_name VARCHAR(200),            -- 保险公司名称
    
    -- 保险期间
    start_date DATE NOT NULL,                       -- 生效日期
    end_date DATE NOT NULL,                         -- 到期日期
    insurance_period INTEGER,                       -- 保险期限(天)
    
    -- 保费信息
    premium_total DECIMAL(12,2) NOT NULL DEFAULT 0, -- 总保费
    compulsory_premium DECIMAL(10,2) DEFAULT 0,    -- 交强险保费
    commercial_premium DECIMAL(10,2) DEFAULT 0,    -- 商业险保费
    vehicle_tax DECIMAL(10,2) DEFAULT 0,            -- 车船税
    
    -- 佣金信息
    commission_rate DECIMAL(6,4),                  -- 佣金比例
    commission_amount DECIMAL(12,2) DEFAULT 0,     -- 佣金金额
    commission_received DECIMAL(12,2) DEFAULT 0,   -- 已收佣金
    commission_received_at TIMESTAMPTZ,            -- 佣金到账时间
    
    -- 承保险种（JSON存储具体险种）
    coverage_items JSONB DEFAULT '[]',             -- 商业险明细
    /* 格式示例：
    [
        {"code": "车损险", "name": "车辆损失险", "premium": 1500.00, "sum_insured": 80000},
        {"code": "三者险", "name": "第三者责任险", "premium": 800.00, "sum_insured": 1000000},
        ...
    ]
    */
    
    -- 车辆信息（快照，保存投保时信息）
    vehicle_snapshot JSONB,                         -- 投保时车辆信息快照
    
    -- 投保人信息（快照）
    holder_snapshot JSONB,                          -- 投保人信息快照
    
    -- 被保险人信息（快照）
    insured_snapshot JSONB,                         -- 被保险人信息快照
    
    -- 受益人信息
    beneficiary_name VARCHAR(200),
    beneficiary_id_card VARCHAR(18),
    beneficiary_relationship VARCHAR(50),
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'claim', 'renewed')),
    
    -- 渠道信息
    channel VARCHAR(50),                            -- 销售渠道
    source VARCHAR(50),                             -- 来源
    
    -- 费用信息
    discount_rate DECIMAL(6,4),                     -- 折扣率
    discount_amount DECIMAL(12,2),                 -- 折扣金额
    
    -- 出险信息
    claim_count INTEGER DEFAULT 0,                  -- 出险次数
    claim_amount DECIMAL(12,2) DEFAULT 0,          -- 出险金额
    claim_details JSONB DEFAULT '[]',              -- 出险明细
    
    -- 附件
    policy_doc_url TEXT,                           -- 保单PDF链接
    invoice_url TEXT,                             -- 发票链接
    
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
    deleted_by UUID
);

COMMENT ON TABLE car_insurance_policies IS '车险保单表 - 完整的保单生命周期管理';
CREATE INDEX idx_car_policy_customer ON car_insurance_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policy_vehicle ON car_insurance_policies(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policy_number ON car_insurance_policies(policy_number);
CREATE INDEX idx_car_policy_company ON car_insurance_policies(insurance_company) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policy_status ON car_insurance_policies(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policy_expire ON car_insurance_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policy_renewal ON car_insurance_policies(customer_id, end_date) WHERE is_deleted = FALSE AND status = 'active';

-- -------------------------------------------------------
-- 3.2 出险记录表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS car_insurance_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    policy_id UUID NOT NULL REFERENCES car_insurance_policies(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 出险信息
    claim_number VARCHAR(100) UNIQUE NOT NULL,     -- 报案号
    accident_date DATE NOT NULL,                    -- 事故日期
    accident_time TIME,                             -- 事故时间
    accident_location TEXT,                         -- 事故地点
    accident_description TEXT,                      -- 事故描述
    accident_type VARCHAR(100),                    -- 事故类型
    
    -- 责任划分
    liability_ratio DECIMAL(5,2),                  -- 责任比例(%)
    is_claim BOOLEAN DEFAULT TRUE,                 -- 是否索赔
    
    -- 损失信息
    loss_description TEXT,                          -- 损失描述
    repair_amount DECIMAL(12,2),                   -- 修理费用
    total_claim_amount DECIMAL(12,2),              -- 总索赔金额
    
    -- 理算信息
    assessed_amount DECIMAL(12,2),                 -- 定损金额
    settled_amount DECIMAL(12,2),                 -- 实际赔付
    deductible DECIMAL(10,2),                     -- 免赔额
    
    -- 状态
    status VARCHAR(20) DEFAULT 'reported' CHECK (status IN ('reported', 'investigating', 'assessed', 'settled', 'rejected', 'closed')),
    
    -- 时间节点
    report_date DATE,                               -- 报案日期
    survey_date DATE,                              -- 查勘日期
    assess_date DATE,                              -- 定损日期
    settle_date DATE,                              -- 赔付日期
    close_date DATE,                               -- 结案日期
    
    -- 附件
    accident_photos JSONB DEFAULT '[]',             -- 事故现场照片
    repair_photos JSONB DEFAULT '[]',             -- 维修照片
    doc_urls JSONB DEFAULT '[]',                  -- 文档链接
    
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

COMMENT ON TABLE car_insurance_claims IS '出险记录表 - 车险理赔全流程管理';
CREATE INDEX idx_claims_policy ON car_insurance_claims(policy_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_claims_customer ON car_insurance_claims(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_claims_status ON car_insurance_claims(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_claims_accident_date ON car_insurance_claims(accident_date) WHERE is_deleted = FALSE;

-- ============================================================
-- 第4部分：非车险模块
-- ============================================================

-- -------------------------------------------------------
-- 4.1 非车险保单表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS noncar_insurance_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    car_policy_id UUID REFERENCES car_insurance_policies(id) ON DELETE SET NULL,  -- 关联车险（交叉销售）
    
    -- 保单基本信息
    policy_number VARCHAR(100) UNIQUE NOT NULL,    -- 保单号
    
    -- 保险类型（使用字典）
    insurance_category VARCHAR(50) NOT NULL,       -- 险种类别：accident/health/home/liability/travel/other
    insurance_type VARCHAR(50) NOT NULL,           -- 具体险种
    insurance_type_name VARCHAR(200),              -- 险种名称
    
    -- 保险公司
    insurance_company VARCHAR(50) NOT NULL,
    insurance_company_name VARCHAR(200),
    
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 保费信息
    premium DECIMAL(12,2) NOT NULL DEFAULT 0,
    premium_paid DECIMAL(12,2) DEFAULT 0,
    
    -- 佣金信息
    commission_rate DECIMAL(6,4),
    commission_amount DECIMAL(12,2) DEFAULT 0,
    commission_received DECIMAL(12,2) DEFAULT 0,
    
    -- 被保险人信息
    insured_name VARCHAR(200),
    insured_id_card VARCHAR(18),
    insured_phone VARCHAR(20),
    
    -- 受益人信息
    beneficiary_name VARCHAR(200),
    beneficiary_relationship VARCHAR(50),
    
    -- 保险金额/保额
    sum_insured DECIMAL(15,2),
    
    -- 保障内容（JSON）
    coverage_details JSONB DEFAULT '{}',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'claim', 'renewed')),
    
    -- 渠道
    channel VARCHAR(50),
    source VARCHAR(50),
    
    -- 附件
    policy_doc_url TEXT,
    
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
    deleted_by UUID
);

COMMENT ON TABLE noncar_insurance_policies IS '非车险保单表 - 意外险/健康险/家财险等';
CREATE INDEX idx_noncar_policy_customer ON noncar_insurance_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policy_category ON noncar_insurance_policies(insurance_category) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policy_type ON noncar_insurance_policies(insurance_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policy_expire ON noncar_insurance_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policy_car ON noncar_insurance_policies(car_policy_id) WHERE car_policy_id IS NOT NULL;

-- -------------------------------------------------------
-- 4.2 非车险出险记录表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS noncar_insurance_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    policy_id UUID NOT NULL REFERENCES noncar_insurance_policies(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 出险信息
    claim_number VARCHAR(100) UNIQUE NOT NULL,
    accident_date DATE NOT NULL,
    accident_description TEXT,
    accident_location TEXT,
    
    -- 理赔信息
    claim_amount DECIMAL(12,2) DEFAULT 0,
    assessed_amount DECIMAL(12,2),
    settled_amount DECIMAL(12,2),
    
    -- 状态
    status VARCHAR(20) DEFAULT 'reported' CHECK (status IN ('reported', 'investigating', 'assessed', 'settled', 'rejected', 'closed')),
    
    report_date DATE,
    settle_date DATE,
    
    -- 附件
    doc_urls JSONB DEFAULT '[]',
    
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

COMMENT ON TABLE noncar_insurance_claims IS '非车险出险记录表';
CREATE INDEX idx_noncar_claims_policy ON noncar_insurance_claims(policy_id) WHERE is_deleted = FALSE;

-- ============================================================
-- 第5部分：年审保养模块
-- ============================================================

-- -------------------------------------------------------
-- 5.1 保养记录表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 保养类型
    maintenance_type VARCHAR(50) NOT NULL,
    maintenance_type_name VARCHAR(200),
    
    -- 保养日期和时间
    maintenance_date DATE NOT NULL,
    maintenance_mileage DECIMAL(12,1),
    
    -- 维修厂/服务商
    service_provider_id UUID,                      -- 服务商ID（关联service_providers表）
    service_provider_name VARCHAR(200),
    service_provider_address TEXT,
    service_provider_phone VARCHAR(20),
    
    -- 保养项目（JSON数组）
    items JSONB DEFAULT '[]',
    /* 格式示例：
    [
        {"name": "更换机油", "quantity": 1, "unit": "桶", "price": 300},
        {"name": "更换机滤", "quantity": 1, "unit": "个", "price": 50}
    ]
    */
    
    -- 配件使用（JSON数组）
    parts JSONB DEFAULT '[]',
    /* 格式示例：
    [
        {"name": "嘉实多机油5W-30", "brand": "嘉实多", "quantity": 1, "unit": "桶", "price": 280}
    ]
    */
    
    -- 费用信息
    labor_cost DECIMAL(10,2) DEFAULT 0,            -- 工时费
    parts_cost DECIMAL(10,2) DEFAULT 0,            -- 配件费
    total_cost DECIMAL(10,2) DEFAULT 0,            -- 总费用
    
    -- 支付信息
    payment_method VARCHAR(50),
    payment_status VARCHAR(20) DEFAULT 'paid' CHECK (payment_status IN ('pending', 'paid', 'partial', 'refunded')),
    paid_amount DECIMAL(10,2) DEFAULT 0,
    
    -- 保修信息
    warranty_months INTEGER,                        -- 保修期(月)
    warranty_end_date DATE,
    
    -- 维修技师
    technician_name VARCHAR(100),
    technician_phone VARCHAR(20),
    
    -- 服务评价
    customer_rating INTEGER CHECK (customer_rating BETWEEN 1 AND 5),
    customer_feedback TEXT,
    
    -- 下次保养提醒
    next_maintenance_date DATE,
    next_maintenance_mileage DECIMAL(12,1),
    next_maintenance_reminded BOOLEAN DEFAULT FALSE,
    
    -- 附件
    invoice_url TEXT,
    receipt_url TEXT,
    photos JSONB DEFAULT '[]',
    
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
    deleted_by UUID
);

COMMENT ON TABLE maintenance_records IS '保养记录表 - 车辆保养维修全记录';
CREATE INDEX idx_maintenance_vehicle ON maintenance_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_customer ON maintenance_records(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_date ON maintenance_records(maintenance_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_type ON maintenance_records(maintenance_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_provider ON maintenance_records(service_provider_id) WHERE service_provider_id IS NOT NULL;

-- -------------------------------------------------------
-- 5.2 年审记录表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS annual_inspection_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 年审信息
    inspection_year INTEGER NOT NULL,               -- 年审年度
    inspection_date DATE NOT NULL,                 -- 年审日期
    inspection_deadline DATE,                       -- 最晚期限
    
    -- 检验机构
    inspection_station_name VARCHAR(200),
    inspection_station_address TEXT,
    
    -- 检验结果
    result VARCHAR(20) CHECK (result IN ('pass', 'fail', 'pending')),
    fail_items JSONB DEFAULT '[]',                  -- 不合格项目
    
    -- 费用
    inspection_fee DECIMAL(10,2) DEFAULT 0,
    
    -- 合格标志
    certificate_number VARCHAR(100),               -- 合格证编号
    certificate_photo_url TEXT,
    
    -- 下次年审
    next_inspection_date DATE,
    
    -- 提醒状态
    reminded_30_days BOOLEAN DEFAULT FALSE,
    reminded_7_days BOOLEAN DEFAULT FALSE,
    reminded_1_day BOOLEAN DEFAULT FALSE,
    
    -- 附件
    report_photo_url TEXT,
    
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

COMMENT ON TABLE annual_inspection_records IS '年审记录表 - 车辆年审历史';
CREATE INDEX idx_inspection_vehicle ON annual_inspection_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_inspection_year ON annual_inspection_records(inspection_year) WHERE is_deleted = FALSE;
CREATE INDEX idx_inspection_deadline ON annual_inspection_records(inspection_deadline) WHERE is_deleted = FALSE;

-- -------------------------------------------------------
-- 5.3 服务商表（维修厂、洗车店等）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 基本信息
    provider_code VARCHAR(50) UNIQUE NOT NULL,
    provider_name VARCHAR(200) NOT NULL,
    provider_type VARCHAR(50) NOT NULL,            -- 维修厂/洗车店/加油站/配件商
    
    -- 联系方式
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    hotline VARCHAR(20),
    
    -- 地址
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address_detail TEXT,
    full_address TEXT,
    
    -- 经营信息
    business_hours VARCHAR(200),
    business_license VARCHAR(100),
    
    -- 服务能力
    service_scope JSONB DEFAULT '[]',              -- ["小保养","大保养","钣金喷漆",...]
    brands JSONB DEFAULT '[]',                     -- 擅长品牌
    capacity_per_day INTEGER,                      -- 日接待量
    
    -- 合作信息
    is_partner BOOLEAN DEFAULT FALSE,
    partner_level VARCHAR(20),                     -- 合作等级
    commission_rate DECIMAL(6,4),                  -- 返佣比例
    settlement_cycle VARCHAR(20),                  -- 结算周期
    
    -- 评分
    rating DECIMAL(3,2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    
    -- 位置
    longitude DECIMAL(11,7),
    latitude DECIMAL(10,7),
    
    -- 附件
    license_photo_url TEXT,
    environment_photos JSONB DEFAULT '[]',
    
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

COMMENT ON TABLE service_providers IS '服务商表 - 维修厂/洗车店/配件商等合作伙伴';
CREATE INDEX idx_providers_type ON service_providers(provider_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_providers_status ON service_providers(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_providers_city ON service_providers(province, city, district) WHERE is_deleted = FALSE;

-- ============================================================
-- 第6部分：汽车后市场模块
-- ============================================================

-- -------------------------------------------------------
-- 6.1 后市场订单表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS after_market_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 订单信息
    order_number VARCHAR(50) UNIQUE NOT NULL,       -- 订单号
    order_type VARCHAR(50) NOT NULL,               -- 订单类型：wash/oil/ tires/battery/ accessories/towing/other
    
    -- 服务/商品
    service_name VARCHAR(200) NOT NULL,
    service_provider_id UUID REFERENCES service_providers(id),
    service_provider_name VARCHAR(200),
    
    -- 数量/规格
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) DEFAULT 0,
    
    -- 商品信息（如果卖配件）
    product_brand VARCHAR(100),
    product_model VARCHAR(200),
    product_code VARCHAR(100),
    
    -- 订单信息
    order_date DATE NOT NULL,
    service_date DATE,
    service_time TIME,
    
    -- 地址（上门服务）
    service_address TEXT,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'completed', 'cancelled', 'refunded')),
    
    -- 支付信息
    payment_method VARCHAR(50),
    payment_status VARCHAR(20) DEFAULT 'pending',
    paid_amount DECIMAL(10,2) DEFAULT 0,
    paid_at TIMESTAMPTZ,
    
    -- 优惠信息
    discount_amount DECIMAL(10,2) DEFAULT 0,
    coupon_code VARCHAR(50),
    
    -- 佣金（如果有返佣）
    commission_amount DECIMAL(10,2) DEFAULT 0,
    commission_paid BOOLEAN DEFAULT FALSE,
    
    -- 用户评价
    customer_rating INTEGER CHECK (customer_rating BETWEEN 1 AND 5),
    customer_feedback TEXT,
    
    -- 附件
    before_photos JSONB DEFAULT '[]',
    after_photos JSONB DEFAULT '[]',
    
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
    deleted_by UUID
);

COMMENT ON TABLE after_market_orders IS '后市场订单表 - 洗车/配件/救援等服务订单';
CREATE INDEX idx_am_order_customer ON after_market_orders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_am_order_vehicle ON after_market_orders(vehicle_id) WHERE vehicle_id IS NOT NULL;
CREATE INDEX idx_am_order_type ON after_market_orders(order_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_am_order_status ON after_market_orders(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_am_order_date ON after_market_orders(order_date) WHERE is_deleted = FALSE;

-- 自动生成订单号的函数
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
        NEW.order_number := 'AM' || TO_CHAR(NOW(), 'YYYYMMDD') || 
                            SUBSTR(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_order_number
    BEFORE INSERT ON after_market_orders
    FOR EACH ROW
    EXECUTE FUNCTION generate_order_number();

-- -------------------------------------------------------
-- 6.2 道路救援记录表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS roadside_assistance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 救援信息
    assistance_type VARCHAR(50) NOT NULL,           -- 拖车/搭电/换胎/送油/开锁/其他
    request_time TIMESTAMPTZ NOT NULL,             -- 求救时间
    
    -- 位置信息
    location_address TEXT,
    longitude DECIMAL(11,7),
    latitude DECIMAL(10,7),
    
    -- 故障描述
    fault_description TEXT,
    fault_photos JSONB DEFAULT '[]',
    
    -- 救援服务
    service_provider_id UUID REFERENCES service_providers(id),
    service_provider_name VARCHAR(200),
    
    -- 救援时间
    dispatch_time TIMESTAMPTZ,                     -- 派单时间
    arrival_time TIMESTAMPTZ,                       -- 到达时间
    complete_time TIMESTAMPTZ,                      -- 完成时间
    
    -- 费用
    service_fee DECIMAL(10,2) DEFAULT 0,
    mileage_fee DECIMAL(10,2) DEFAULT 0,           -- 里程费
    total_fee DECIMAL(10,2) DEFAULT 0,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'requested' CHECK (status IN ('requested', 'dispatched', 'en_route', 'arrived', 'processing', 'completed', 'cancelled')),
    
    -- 客户评价
    customer_rating INTEGER CHECK (customer_rating BETWEEN 1 AND 5),
    customer_feedback TEXT,
    
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

COMMENT ON TABLE roadside_assistance_records IS '道路救援记录表';
CREATE INDEX idx_assistance_customer ON roadside_assistance_records(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_assistance_status ON roadside_assistance_records(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_assistance_request_time ON roadside_assistance_records(request_time) WHERE is_deleted = FALSE;

-- ============================================================
-- 第7部分：汽车消费金融模块
-- ============================================================

-- -------------------------------------------------------
-- 7.1 金融合同表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS auto_finance_contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 合同信息
    contract_number VARCHAR(100) UNIQUE NOT NULL,
    finance_type VARCHAR(50) NOT NULL,             -- new_car_loan/used_car_loan/refinance/leasing
    
    -- 金融机构
    finance_company VARCHAR(100) NOT NULL,         -- 金融机构名称
    finance_company_code VARCHAR(50),               -- 金融机构编码
    
    -- 贷款信息
    loan_amount DECIMAL(15,2) NOT NULL,           -- 贷款金额
    loan_term INTEGER NOT NULL,                   -- 贷款期限(月)
    interest_rate DECIMAL(8,4) NOT NULL,          -- 年利率
    monthly_payment DECIMAL(12,2) NOT NULL,       -- 月供
    total_interest DECIMAL(15,2) NOT NULL,        -- 总利息
    total_repayment DECIMAL(15,2) NOT NULL,      -- 总还款额
    
    -- 贷款详情
    down_payment DECIMAL(15,2),                   -- 首付金额
    down_payment_rate DECIMAL(6,4),              -- 首付比例
    loan_to_value DECIMAL(6,4),                   -- 贷款成数(LTV)
    
    -- 合同日期
    contract_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 还款信息
    repayment_method VARCHAR(20) DEFAULT 'equal_principal' CHECK (repayment_method IN ('equal_principal', 'equal_payment', 'balloon', 'other')),
    repayment_day INTEGER DEFAULT 15,             -- 每月还款日
    repayment_account VARCHAR(50),                -- 还款账户
    auto_repay BOOLEAN DEFAULT FALSE,             -- 自动扣款
    
    -- 担保信息
    collateral_type VARCHAR(50),                   -- 担保方式：抵押/质押/信用
    collateral_vin VARCHAR(50),                   -- 抵押物VIN（车贷抵押车）
    gps_installed BOOLEAN DEFAULT FALSE,           -- 已安装GPS
    
    -- 保险要求（贷款要求购买的保险）
    required_insurance JSONB DEFAULT '[]',
    
    -- 提前还款
    early_repayment_fee DECIMAL(10,2),            -- 提前还款违约金
    early_repayment_allowed BOOLEAN DEFAULT TRUE,
    min_early_repayment_months INTEGER,            -- 最短提前还款月数
    
    -- 当前状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'active', 'completed', 'defaulted', 'cancelled', 'transferred')),
    
    -- 逾期信息
    current_overdue_count INTEGER DEFAULT 0,       -- 当前逾期期数
    current_overdue_amount DECIMAL(12,2) DEFAULT 0,
    total_overdue_amount DECIMAL(12,2) DEFAULT 0,
    overdue_days INTEGER DEFAULT 0,
    
    -- 附件
    contract_doc_url TEXT,                         -- 合同PDF
    approval_doc_url TEXT,                        -- 审批文件
    
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID
);

COMMENT ON TABLE auto_finance_contracts IS '汽车消费金融合同表';
CREATE INDEX idx_finance_customer ON auto_finance_contracts(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_vehicle ON auto_finance_contracts(vehicle_id) WHERE vehicle_id IS NOT NULL;
CREATE INDEX idx_finance_type ON auto_finance_contracts(finance_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_status ON auto_finance_contracts(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_contract_date ON auto_finance_contracts(contract_date) WHERE is_deleted = FALSE;

-- -------------------------------------------------------
-- 7.2 还款计划表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS finance_repayment_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联合同
    contract_id UUID NOT NULL REFERENCES auto_finance_contracts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 期数信息
    period_number INTEGER NOT NULL,                -- 期数（第几期）
    due_date DATE NOT NULL,                        -- 应还日期
    
    -- 还款金额
    principal_amount DECIMAL(12,2) NOT NULL,      -- 本金
    interest_amount DECIMAL(12,2) NOT NULL,       -- 利息
    total_amount DECIMAL(12,2) NOT NULL,         -- 本息合计
    
    -- 实际还款
    actual_repayment_date DATE,
    actual_principal DECIMAL(12,2) DEFAULT 0,
    actual_interest DECIMAL(12,2) DEFAULT 0,
    actual_amount DECIMAL(12,2) DEFAULT 0,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'partial', 'waived')),
    
    -- 逾期信息
    overdue_days INTEGER DEFAULT 0,
    overdue_penalty DECIMAL(10,2) DEFAULT 0,
    
    -- 扣款信息
    auto_debit_attempted BOOLEAN DEFAULT FALSE,
    auto_debit_success BOOLEAN DEFAULT FALSE,
    auto_debit_fail_reason TEXT,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE
);

COMMENT ON TABLE finance_repayment_schedules IS '还款计划表';
CREATE INDEX idx_repayment_contract ON finance_repayment_schedules(contract_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_customer ON finance_repayment_schedules(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_status ON finance_repayment_schedules(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_due_date ON finance_repayment_schedules(due_date) WHERE is_deleted = FALSE;

-- ============================================================
-- 第8部分：跟进记录（通用）
-- ============================================================

CREATE TABLE IF NOT EXISTS followup_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    related_id UUID,                                -- 关联ID（保单ID/订单ID等）
    related_type VARCHAR(50),                       -- 关联类型：car_policy/noncar_policy/maintenance/order/finance/other
    
    -- 跟进信息
    followup_type VARCHAR(50) NOT NULL,             -- 跟进方式：call/visit/wechat/sms/email/other
    followup_content TEXT NOT NULL,                -- 跟进内容
    
    -- 时间
    followup_date DATE NOT NULL,
    followup_time TIME,
    next_followup_date DATE,                      -- 下次跟进日期
    next_followup_content TEXT,                    -- 下次跟进内容
    
    -- 结果
    result VARCHAR(50),                            -- 跟进结果
    customer_feedback TEXT,                        -- 客户反馈
    customer_intent VARCHAR(50),                   -- 客户意向
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    
    -- 状态
    is_completed BOOLEAN DEFAULT FALSE,            -- 是否已完成
    completion_date DATE,
    
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE followup_records IS '跟进记录表 - 所有业务通用的跟进记录';
CREATE INDEX idx_followup_customer ON followup_records(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_followup_related ON followup_records(related_id, related_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_followup_date ON followup_records(followup_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_followup_next ON followup_records(next_followup_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_followup_user ON followup_records(created_by) WHERE is_deleted = FALSE;

-- ============================================================
-- 第9部分：提醒任务表
-- ============================================================

CREATE TABLE IF NOT EXISTS reminder_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 关联信息
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    related_id UUID,                                -- 关联业务ID
    related_type VARCHAR(50),                       -- 关联业务类型
    
    -- 提醒信息
    reminder_type VARCHAR(50) NOT NULL,             -- reminder_type: renewal/inspection/maintenance/payment/followup/custom
    reminder_title VARCHAR(200) NOT NULL,           -- 提醒标题
    reminder_content TEXT,                          -- 提醒内容
    
    -- 提醒时间
    remind_at TIMESTAMPTZ NOT NULL,                  -- 提醒时间
    remind_days_before INTEGER DEFAULT 0,           -- 提前N天提醒
    
    -- 触发条件（用于动态计算提醒时间）
    trigger_type VARCHAR(50),                      -- trigger_type: date/days_before/condition
    trigger_date DATE,                             -- 触发日期
    trigger_field VARCHAR(100),                    -- 触发字段
    trigger_value TEXT,                            -- 触发值
    
    -- 执行状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'cancelled', 'completed')),
    sent_at TIMESTAMPTZ,
    send_attempts INTEGER DEFAULT 0,
    last_error TEXT,
    
    -- 推送方式
    push_channels JSONB DEFAULT '["system"]',        -- ["system","wechat","sms","email"]
    
    -- 重复规则
    is_repeat BOOLEAN DEFAULT FALSE,
    repeat_rule VARCHAR(200),                      -- 重复规则JSON
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1
);

COMMENT ON TABLE reminder_tasks IS '提醒任务表 - 统一的提醒管理';
CREATE INDEX idx_reminder_customer ON reminder_tasks(customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX idx_reminder_vehicle ON reminder_tasks(vehicle_id) WHERE vehicle_id IS NOT NULL;
CREATE INDEX idx_reminder_remind_at ON reminder_tasks(remind_at) WHERE status = 'pending';
CREATE INDEX idx_reminder_status ON reminder_tasks(status);

-- ============================================================
-- 第10部分：审计日志表（必须最后创建）
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 操作信息
    action VARCHAR(50) NOT NULL,                   -- 操作类型：CREATE/READ/UPDATE/DELETE/LOGIN/LOGOUT/EXPORT/IMPORT
    table_name VARCHAR(100) NOT NULL,             -- 操作表名
    record_id UUID,                                 -- 记录ID
    
    -- 操作详情
    operation_type VARCHAR(20) NOT NULL,           -- 操作类型：INSERT/UPDATE/DELETE/SELECT
    old_values JSONB,                              -- 修改前的值
    new_values JSONB,                              -- 修改后的值
    changed_fields JSONB,                          -- 修改的字段列表
    
    -- SQL信息（用于回放）
    sql_query TEXT,
    
    -- 结果
    result VARCHAR(20) DEFAULT 'success' CHECK (result IN ('success', 'failed', 'rollback')),
    error_message TEXT,
    
    -- 访问信息
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- 性能信息
    execution_time_ms INTEGER,                    -- 执行时间(毫秒)
    
    -- 操作人
    user_id UUID REFERENCES system_users(id),
    username VARCHAR(100),
    real_name VARCHAR(100),
    
    -- 时间
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS '审计日志表 - 记录所有数据变更操作';
CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_record ON audit_logs(record_id) WHERE record_id IS NOT NULL;
CREATE INDEX idx_audit_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);

-- 创建审计日志自动写入的函数
CREATE OR REPLACE FUNCTION write_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    audit_action VARCHAR(50);
    old_data JSONB;
    new_data JSONB;
    changed JSONB;
    col_name TEXT;
    old_val TEXT;
    new_val TEXT;
BEGIN
    -- 确定操作类型
    IF TG_OP = 'INSERT' THEN
        audit_action := 'CREATE';
        new_data := to_jsonb(NEW);
        old_data := NULL;
        changed := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        audit_action := 'UPDATE';
        new_data := to_jsonb(NEW);
        old_data := to_jsonb(OLD);
        
        -- 计算变化的字段
        changed := '[]'::JSONB;
        FOR col_name IN SELECT jsonb_object_keys(old_data)
        LOOP
            old_val := old_data->>col_name;
            new_val := new_data->>col_name;
            IF old_val IS DISTINCT FROM new_val THEN
                changed := changed || jsonb_build_array(col_name);
            END IF;
        END LOOP;
    ELSIF TG_OP = 'DELETE' THEN
        audit_action := 'DELETE';
        old_data := to_jsonb(OLD);
        new_data := NULL;
        changed := NULL;
    END IF;
    
    -- 插入审计日志
    INSERT INTO audit_logs (
        action, table_name, record_id, operation_type,
        old_values, new_values, changed_fields,
        user_id
    ) VALUES (
        audit_action, TG_TABLE_NAME, COALESCE(NEW.id, OLD.id), TG_OP,
        old_data, new_data, changed,
        current_setting('app.current_user_id', TRUE)::UUID
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为主要业务表创建审计触发器
CREATE TRIGGER trigger_audit_customers
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trigger_audit_vehicles
    AFTER INSERT OR UPDATE OR DELETE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trigger_audit_car_policies
    AFTER INSERT OR UPDATE OR DELETE ON car_insurance_policies
    FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trigger_audit_noncar_policies
    AFTER INSERT OR UPDATE OR DELETE ON noncar_insurance_policies
    FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trigger_audit_maintenance
    AFTER INSERT OR UPDATE OR DELETE ON maintenance_records
    FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trigger_audit_finance
    AFTER INSERT OR UPDATE OR DELETE ON auto_finance_contracts
    FOR EACH ROW EXECUTE FUNCTION write_audit_log();

-- ============================================================
-- 第11部分：RLS行级安全策略
-- ============================================================

-- 启用RLS
ALTER TABLE system_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_insurance_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_insurance_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE annual_inspection_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_market_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_finance_contracts ENABLE ROW LEVEL SECURITY;

-- 创建RLS策略（示例）
-- 客户表：只看自己的客户（管理员和经理看全部）
CREATE POLICY "Users can view own customers" ON customers
    FOR SELECT USING (
        (current_setting('app.current_user_role', TRUE) IN ('admin', 'manager'))
        OR owner_user_id = current_setting('app.current_user_id', TRUE)::UUID
    );

-- 车辆表：基于客户权限
CREATE POLICY "Users can view own vehicle customers" ON vehicles
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM customers 
            WHERE owner_user_id = current_setting('app.current_user_id', TRUE)::UUID
            OR current_setting('app.current_user_role', TRUE) IN ('admin', 'manager')
        )
    );

-- ============================================================
-- 第12部分：常用视图（方便查询）
-- ============================================================

-- 客户360视图（整合客户+车辆+最新保单）
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT 
    c.id,
    c.customer_code,
    c.customer_name,
    c.phone,
    c.customer_level,
    c.status,
    c.total_policy_count,
    c.total_premium,
    c.total_commission,
    c.last_policy_at,
    -- 车辆数量
    (SELECT COUNT(*) FROM vehicles v WHERE v.customer_id = c.id AND v.is_deleted = FALSE) as vehicle_count,
    -- 最新车险
    (SELECT jsonb_build_object(
        'policy_number', policy_number,
        'insurance_company', insurance_company_name,
        'end_date', end_date,
        'premium_total', premium_total,
        'status', status
    ) FROM car_insurance_policies p 
    WHERE p.customer_id = c.id AND p.is_deleted = FALSE 
    ORDER BY p.created_at DESC LIMIT 1) as latest_car_policy,
    -- 最新保养
    (SELECT maintenance_date FROM maintenance_records m 
    WHERE m.customer_id = c.id AND m.is_deleted = FALSE 
    ORDER BY m.maintenance_date DESC LIMIT 1) as last_maintenance_date,
    -- 归属人
    u.real_name as owner_name
FROM customers c
LEFT JOIN system_users u ON c.owner_user_id = u.id
WHERE c.is_deleted = FALSE;

-- 续保提醒视图
CREATE OR REPLACE VIEW v_renewal_reminders AS
SELECT 
    c.id as customer_id,
    c.customer_code,
    c.customer_name,
    c.phone,
    v.id as vehicle_id,
    v.plate_number,
    v.vehicle_type,
    p.id as policy_id,
    p.policy_number,
    p.insurance_company_name,
    p.end_date as expire_date,
    p.premium_total,
    p.commission_amount,
    p.status,
    u.real_name as owner_name,
    -- 计算到期天数
    (p.end_date - CURRENT_DATE) as days_to_expire,
    -- 判断是否需要提醒
    CASE 
        WHEN p.end_date - CURRENT_DATE <= 30 AND p.end_date >= CURRENT_DATE THEN 'urgent'
        WHEN p.end_date - CURRENT_DATE <= 60 AND p.end_date >= CURRENT_DATE THEN 'soon'
        WHEN p.end_date - CURRENT_DATE > 60 THEN 'normal'
        ELSE 'expired'
    END as renewal_priority
FROM customers c
JOIN vehicles v ON v.customer_id = c.id
JOIN car_insurance_policies p ON p.vehicle_id = v.id
LEFT JOIN system_users u ON c.owner_user_id = u.id
WHERE c.is_deleted = FALSE 
    AND v.is_deleted = FALSE 
    AND p.is_deleted = FALSE
    AND p.status = 'active'
    AND p.end_date >= CURRENT_DATE
ORDER BY (p.end_date - CURRENT_DATE) ASC;

-- 统计汇总视图
CREATE OR REPLACE VIEW v_statistics_summary AS
SELECT 
    -- 客户统计
    (SELECT COUNT(*) FROM customers WHERE is_deleted = FALSE) as total_customers,
    (SELECT COUNT(*) FROM customers WHERE is_deleted = FALSE AND DATE(created_at) = CURRENT_DATE) as new_customers_today,
    (SELECT COUNT(*) FROM customers WHERE is_deleted = FALSE AND DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE)) as new_customers_month,
    
    -- 车辆统计
    (SELECT COUNT(*) FROM vehicles WHERE is_deleted = FALSE) as total_vehicles,
    
    -- 车险统计
    (SELECT COUNT(*) FROM car_insurance_policies WHERE is_deleted = FALSE AND status = 'active') as active_car_policies,
    (SELECT COUNT(*) FROM car_insurance_policies WHERE is_deleted = FALSE AND status = 'active' AND end_date >= CURRENT_DATE AND end_date < CURRENT_DATE + INTERVAL '30 days') as expire_soon_30,
    (SELECT COALESCE(SUM(premium_total), 0) FROM car_insurance_policies WHERE is_deleted = FALSE AND status IN ('active', 'renewed')) as total_car_premium,
    (SELECT COALESCE(SUM(commission_amount), 0) FROM car_insurance_policies WHERE is_deleted = FALSE) as total_car_commission,
    
    -- 非车险统计
    (SELECT COUNT(*) FROM noncar_insurance_policies WHERE is_deleted = FALSE AND status = 'active') as active_noncar_policies,
    (SELECT COALESCE(SUM(premium), 0) FROM noncar_insurance_policies WHERE is_deleted = FALSE AND status IN ('active', 'renewed')) as total_noncar_premium,
    
    -- 保养统计
    (SELECT COUNT(*) FROM maintenance_records WHERE is_deleted = FALSE AND DATE(maintenance_date) = CURRENT_DATE) as maintenance_today,
    (SELECT COALESCE(SUM(total_cost), 0) FROM maintenance_records WHERE is_deleted = FALSE) as total_maintenance_cost,
    
    -- 后市场统计
    (SELECT COUNT(*) FROM after_market_orders WHERE is_deleted = FALSE AND DATE(order_date) = CURRENT_DATE) as orders_today,
    (SELECT COALESCE(SUM(total_amount), 0) FROM after_market_orders WHERE is_deleted = FALSE) as total_aftermarket_sales,

    -- 金融统计
    (SELECT COUNT(*) FROM auto_finance_contracts WHERE is_deleted = FALSE AND status = 'active') as active_finance_contracts,
    (SELECT COALESCE(SUM(loan_amount), 0) FROM auto_finance_contracts WHERE is_deleted = FALSE AND status IN ('active', 'completed')) as total_loan_amount;

-- ============================================================
-- 第13部分：自动触发器（业务逻辑）
-- ============================================================

-- 更新客户统计字段（车险保单新增/变更时）
CREATE OR REPLACE FUNCTION update_customer_stats_on_policy()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE customers SET 
            total_policy_count = total_policy_count + 1,
            total_premium = total_premium + NEW.premium_total,
            total_commission = total_commission + NEW.commission_amount,
            last_policy_at = COALESCE(NEW.created_at, NOW()),
            updated_at = NOW()
        WHERE id = NEW.customer_id;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE customers SET 
            total_premium = total_premium - OLD.premium_total + NEW.premium_total,
            total_commission = total_commission - OLD.commission_amount + NEW.commission_amount,
            updated_at = NOW()
        WHERE id = NEW.customer_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE customers SET 
            total_policy_count = GREATEST(0, total_policy_count - 1),
            total_premium = GREATEST(0, total_premium - OLD.premium_total),
            total_commission = GREATEST(0, total_commission - OLD.commission_amount),
            updated_at = NOW()
        WHERE id = OLD.customer_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_customer_stats
    AFTER INSERT OR UPDATE OR DELETE ON car_insurance_policies
    FOR EACH ROW EXECUTE FUNCTION update_customer_stats_on_policy();

-- 更新车辆年审信息（年审记录新增时）
CREATE OR REPLACE FUNCTION update_vehicle_inspection()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE vehicles SET 
            annual_inspection_date = NEW.next_inspection_date,
            updated_at = NOW()
        WHERE id = NEW.vehicle_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vehicle_inspection
    AFTER INSERT ON annual_inspection_records
    FOR EACH ROW EXECUTE FUNCTION update_vehicle_inspection();

-- ============================================================
-- 完成标记
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE 'AutoCRM V1.0 数据库Schema创建完成！';
    RAISE NOTICE '共计创建表: 20+';
    RAISE NOTICE '包含模块: 客户/车辆/车险/非车险/保养/年审/后市场/金融';
END;
$$ LANGUAGE plpgsql;
