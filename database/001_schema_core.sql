-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本: V1.0 | 日期: 2026-04-19 | 作者: 痞老板
-- 数据库: PostgreSQL 15+ (Supabase托管)
-- ============================================================

-- ============================================================
-- 第一部分：核心基础设施表
-- ============================================================

-- ---------------------------------------------------
-- 1.1 组织/部门表 (organizations)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL COMMENT '组织名称',
    code VARCHAR(50) UNIQUE NOT NULL COMMENT '组织代码',
    parent_id UUID REFERENCES organizations(id) ON DELETE SET NULL COMMENT '上级组织ID',
    level INTEGER DEFAULT 1 COMMENT '组织层级(1=总公司,2=分公司,3=团队)',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','inactive','closed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_organizations_parent ON organizations(parent_id);
CREATE INDEX idx_organizations_status ON organizations(status);

-- ---------------------------------------------------
-- 1.2 用户表 (users)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    
    -- 认证信息
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    
    -- 基本信息
    real_name VARCHAR(50) NOT NULL COMMENT '真实姓名',
    nickname VARCHAR(50),
    avatar_url TEXT,
    gender VARCHAR(10) CHECK (gender IN ('male','female','other')),
    id_card VARCHAR(18),
    birthday DATE,
    
    -- 职业信息
    role VARCHAR(30) DEFAULT 'agent' CHECK (role IN ('admin','manager','agent','finance','viewer')),
    title VARCHAR(50) COMMENT '职位/职级',
    employee_no VARCHAR(30) UNIQUE COMMENT '员工工号',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','inactive','locked')),
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_users_org ON users(org_id);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);

-- 用户角色权限表
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL,
    scope VARCHAR(50) DEFAULT 'own' CHECK (scope IN ('own','team','org','all')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);

-- ---------------------------------------------------
-- 1.3 数据字典表 (lookups)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS lookups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL COMMENT '分类',
    code VARCHAR(50) NOT NULL COMMENT '代码',
    name VARCHAR(100) NOT NULL COMMENT '名称',
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    extra JSONB DEFAULT '{}' COMMENT '扩展字段',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category, code)
);

CREATE INDEX idx_lookups_category ON lookups(category);
CREATE INDEX idx_lookups_active ON lookups(is_active);

-- 初始化常用数据字典
INSERT INTO lookups (category, code, name, sort_order) VALUES
-- 车辆类型
('vehicle_type', 'sedan', '轿车', 1),
('vehicle_type', 'suv', 'SUV', 2),
('vehicle_type', 'mpv', 'MPV', 3),
('vehicle_type', 'truck', '卡车', 4),
('vehicle_type', 'van', '面包车', 5),
('vehicle_type', 'new_energy', '新能源汽车', 6),
-- 车辆状态
('vehicle_status', 'normal', '正常使用', 1),
('vehicle_status', 'transferring', '过户中', 2),
('vehicle_status', 'scrapped', '已报废', 3),
-- 客户类型
('customer_type', 'individual', '个人', 1),
('customer_type', 'company', '企业', 2),
-- 客户来源
('customer_source', 'walk_in', '自然到店', 1),
('customer_source', 'referral', '转介绍', 2),
('customer_source', 'online', '网络获客', 3),
('customer_source', 'partner', '合作渠道', 4),
('customer_source', 'drain', '同行导流', 5),
-- 跟进状态
('followup_status', 'pending', '待跟进', 1),
('followup_status', 'contacted', '已联系', 2),
('followup_status', 'interested', '有意向', 3),
('followup_status', 'negotiating', '洽谈中', 4),
('followup_status', 'converted', '已转化', 5),
('followup_status', 'lost', '流失', 6),
-- 业务状态
('business_status', 'active', '活跃客户', 1),
('business_status', 'dormant', '休眠客户', 2),
('business_status', 'churned', '流失客户', 3);

-- ---------------------------------------------------
-- 1.4 审计日志表 (audit_logs) - 核心可追溯机制
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 操作信息
    table_name VARCHAR(100) NOT NULL COMMENT '操作的表名',
    record_id UUID NOT NULL COMMENT '被操作的记录ID',
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE','SELECT','LOGIN','LOGOUT')),
    
    -- 变更详情
    old_data JSONB COMMENT '变更前的数据',
    new_data JSONB COMMENT '变更后的数据',
    changed_fields TEXT[] COMMENT '变更的字段列表',
    
    -- 执行人信息
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_name VARCHAR(50),
    user_ip INET,
    user_agent TEXT,
    
    -- 环境信息
    session_id VARCHAR(100),
    request_id VARCHAR(100) COMMENT '请求追踪ID',
    
    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_time ON audit_logs(created_at);
CREATE INDEX idx_audit_operation ON audit_logs(operation);

-- ============================================================
-- 第二部分：统一客户中心 (Core Customer Center)
-- ============================================================

-- ---------------------------------------------------
-- 2.1 客户主表 (customers) - 所有业务的核心
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 客户基本信息
    customer_no VARCHAR(30) UNIQUE NOT NULL COMMENT '客户编号',
    customer_type VARCHAR(20) DEFAULT 'individual' CHECK (customer_type IN ('individual','company')),
    
    -- 个人客户信息
    name VARCHAR(50) NOT NULL COMMENT '姓名/公司名',
    name_en VARCHAR(100),
    gender VARCHAR(10) CHECK (gender IN ('male','female','other')),
    birthday DATE,
    id_card VARCHAR(18),
    id_card_front_url TEXT COMMENT '身份证正面',
    id_card_back_url TEXT COMMENT '身份证反面',
    
    -- 联系信息
    phone_primary VARCHAR(20) NOT NULL COMMENT '主要联系电话',
    phone_secondary VARCHAR(20) COMMENT '备用电话',
    wechat VARCHAR(50) COMMENT '微信号',
    email VARCHAR(100),
    
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address_detail TEXT COMMENT '详细地址',
    address_lat DECIMAL(10,7) COMMENT '地址纬度',
    address_lng DECIMAL(11,7) COMMENT '地址经度',
    
    -- 职业信息
    occupation VARCHAR(100) COMMENT '职业',
    company_name VARCHAR(200) COMMENT '工作单位',
    annual_income DECIMAL(12,2) COMMENT '年收入(万元)',
    
    -- 客户画像
    source VARCHAR(50) COMMENT '客户来源',
    source_detail VARCHAR(200) COMMENT '来源详情',
    tags TEXT[] DEFAULT '{}' COMMENT '客户标签',
    remark TEXT COMMENT '备注',
    
    -- 客户评级
    customer_level VARCHAR(20) DEFAULT 'C' CHECK (customer_level IN ('A','B','C','D')),
    vip_level INTEGER DEFAULT 0 COMMENT 'VIP等级 0-9',
    
    -- 客户状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','inactive','blocked')),
    followup_status VARCHAR(30) DEFAULT 'pending',
    last_contact_at TIMESTAMPTZ,
    next_followup_at TIMESTAMPTZ,
    
    -- 归属信息
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL COMMENT '归属业务员',
    owner_name VARCHAR(50),
    team_id UUID REFERENCES organizations(id) ON DELETE SET NULL COMMENT '归属团队',
    
    -- 统计数据 (冗余字段，提升查询性能)
    total_policies INTEGER DEFAULT 0 COMMENT '累计保单数',
    total_premium DECIMAL(14,2) DEFAULT 0 COMMENT '累计保费(元)',
    total_commission DECIMAL(14,2) DEFAULT 0 COMMENT '累计佣金(元)',
    total_services INTEGER DEFAULT 0 COMMENT '累计服务次数',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_customers_no ON customers(customer_no);
CREATE INDEX idx_customers_phone ON customers(phone_primary);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_owner ON customers(owner_id);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_level ON customers(customer_level);
CREATE INDEX idx_customers_tags ON customers USING GIN(tags);

-- ---------------------------------------------------
-- 2.2 车辆信息表 (vehicles) - 以车为核心
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 车辆标识
    vehicle_no VARCHAR(50) UNIQUE NOT NULL COMMENT '车辆编号',
    plate_number VARCHAR(20) UNIQUE NOT NULL COMMENT '车牌号',
    plate_province VARCHAR(10) COMMENT '车牌省份',
    plate_city VARCHAR(10) COMMENT '车牌城市',
    
    -- VIN信息
    vin VARCHAR(50) UNIQUE NOT NULL COMMENT '车架号/VIN',
    engine_no VARCHAR(50) COMMENT '发动机号',
    
    -- 车辆基本信息
    brand VARCHAR(50) NOT NULL COMMENT '品牌',
    series VARCHAR(50) NOT NULL COMMENT '车系',
    model VARCHAR(100) NOT NULL COMMENT '车型(型号)',
    vehicle_type VARCHAR(30) COMMENT '车辆类型',
    color VARCHAR(30) COMMENT '车身颜色',
    
    -- 新能源信息
    is_new_energy BOOLEAN DEFAULT FALSE COMMENT '是否新能源汽车',
    energy_type VARCHAR(20) CHECK (energy_type IN ('pure_ev','hybrid','fuel')),
    battery_capacity DECIMAL(8,2) COMMENT '电池容量(kWh)',
    
    -- 注册信息
    register_date DATE COMMENT '注册日期',
    issue_date DATE COMMENT '发证日期',
    plate_color VARCHAR(10) CHECK (plate_color IN ('blue','yellow','green','black','white')),
    
    -- 车辆状态
    status VARCHAR(20) DEFAULT 'normal' CHECK (status IN ('normal','transferring','scrapped','auction')),
    mileage DECIMAL(12,1) COMMENT '当前里程数(km)',
    last_service_mileage DECIMAL(12,1) COMMENT '上次保养里程',
    
    -- 商业信息
    market_price DECIMAL(12,2) COMMENT '市场价值(万元)',
    purchase_price DECIMAL(12,2) COMMENT '购买价格(万元)',
    purchase_date DATE COMMENT '购买日期',
    
    -- 关联客户
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 年审信息
    annual_review_date DATE COMMENT '年审到期日期',
    annual_review_status VARCHAR(20) DEFAULT 'valid' CHECK (annual_review_status IN ('valid','expiring','expired')),
    
    -- 交强险信息
    compulsory_insurance_company VARCHAR(100) COMMENT '交强险公司',
    compulsory_insurance_expire DATE COMMENT '交强险到期',
    
    -- 商业险信息
    commercial_insurance_company VARCHAR(100) COMMENT '商业险公司',
    commercial_insurance_expire DATE COMMENT '商业险到期',
    
    -- 统计数据
    total_insurance DECIMAL(12,2) DEFAULT 0 COMMENT '累计保险费',
    total_service DECIMAL(12,2) DEFAULT 0 COMMENT '累计服务费',
    total_claims INTEGER DEFAULT 0 COMMENT '累计理赔次数',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_vehicles_plate ON vehicles(plate_number);
CREATE INDEX idx_vehicles_vin ON vehicles(vin);
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id);
CREATE INDEX idx_vehicles_annual_review ON vehicles(annual_review_date);
CREATE INDEX idx_vehicles_status ON vehicles(status);

-- ---------------------------------------------------
-- 2.3 家庭/企业关系表 (customer_relations)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    related_customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    relation_type VARCHAR(30) NOT NULL COMMENT '关系类型',
    
    is_primary BOOLEAN DEFAULT FALSE COMMENT '是否主要关系人',
    is_emergency_contact BOOLEAN DEFAULT FALSE COMMENT '是否紧急联系人',
    remark TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(customer_id, related_customer_id)
);

CREATE INDEX idx_customer_relations_customer ON customer_relations(customer_id);
CREATE INDEX idx_customer_relations_type ON customer_relations(relation_type);

-- 预定义关系类型
INSERT INTO lookups (category, code, name, sort_order) VALUES
('relation_type', 'self', '本人', 0),
('relation_type', 'spouse', '配偶', 1),
('relation_type', 'parent', '父母', 2),
('relation_type', 'child', '子女', 3),
('relation_type', 'sibling', '兄弟姐妹', 4),
('relation_type', 'friend', '朋友', 5),
('relation_type', 'colleague', '同事', 6),
('relation_type', 'business_partner', '商业伙伴', 7),
('relation_type', 'driver', '司机', 8),
('relation_type', 'company', '公司', 9);

-- ---------------------------------------------------
-- 2.4 跟进记录表 (followups)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 跟进信息
    followup_type VARCHAR(50) NOT NULL COMMENT '跟进类型',
    subject VARCHAR(200) NOT NULL COMMENT '跟进主题',
    content TEXT NOT NULL COMMENT '跟进内容',
    result VARCHAR(30) COMMENT '跟进结果',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','completed','cancelled')),
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
    
    -- 时间安排
    plan_at TIMESTAMPTZ COMMENT '计划跟进时间',
    completed_at TIMESTAMPTZ COMMENT '实际完成时间',
    
    -- 关联业务
    related_module VARCHAR(30) COMMENT '关联模块(car_insurance/noncar/maintenance/aftermarket/finance)',
    related_id UUID COMMENT '关联记录ID',
    
    -- 附件
    attachments JSONB DEFAULT '[]' COMMENT '[{name, url, type}]',
    
    -- 下次跟进
    next_followup_at TIMESTAMPTZ,
    next_followup_content TEXT,
    
    -- 归属
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    owner_name VARCHAR(50),
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_followups_customer ON followups(customer_id);
CREATE INDEX idx_followups_vehicle ON followups(vehicle_id);
CREATE INDEX idx_followups_owner ON followups(owner_id);
CREATE INDEX idx_followups_status ON followups(status);
CREATE INDEX idx_followups_plan_at ON followups(plan_at);

-- ---------------------------------------------------
-- 2.5 提醒任务表 (reminders)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
    
    -- 提醒信息
    title VARCHAR(200) NOT NULL,
    content TEXT,
    reminder_type VARCHAR(50) NOT NULL COMMENT 'reminder_type',
    
    -- 提醒时间
    remind_at TIMESTAMPTZ NOT NULL,
    is_repeated BOOLEAN DEFAULT FALSE,
    repeat_rule VARCHAR(100) COMMENT 'repeat_type',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','sent','cancelled','expired')),
    sent_at TIMESTAMPTZ,
    
    -- 推送渠道
    channels TEXT[] DEFAULT ARRAY['system'],
    
    -- 归属
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_reminders_customer ON reminders(customer_id);
CREATE INDEX idx_reminders_remind_at ON reminders(remind_at);
CREATE INDEX idx_reminders_status ON reminders(status);

-- ============================================================
-- 第三部分：模块一 - 车险管理 (Car Insurance)
-- ============================================================

-- ---------------------------------------------------
-- 3.1 车险保单表 (car_policies)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 保单标识
    policy_no VARCHAR(50) UNIQUE NOT NULL COMMENT '保单号',
    policy_no_insurer VARCHAR(50) COMMENT '保险公司保单号',
    
    -- 保险信息
    insurer_id VARCHAR(50) NOT NULL COMMENT '承保公司代码',
    insurer_name VARCHAR(100) NOT NULL COMMENT '承保公司名称',
    insurance_type VARCHAR(30) DEFAULT 'compulsory_plus_commercial' CHECK (insurance_type IN ('compulsory_only','commercial_only','compulsory_plus_commercial')),
    
    -- 保险期间
    start_date DATE NOT NULL COMMENT '保险生效日期',
    end_date DATE NOT NULL COMMENT '保险到期日期',
    period_months INTEGER NOT NULL COMMENT '保险期间(月)',
    
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL COMMENT '总保费(元)',
    compulsory_premium DECIMAL(10,2) DEFAULT 0 COMMENT '交强险保费',
    commercial_premium DECIMAL(10,2) DEFAULT 0 COMMENT '商业险保费',
    tax_amount DECIMAL(10,2) DEFAULT 0 COMMENT '车船税',
    discount_rate DECIMAL(5,4) DEFAULT 1 COMMENT '折扣率',
    
    -- 商业险详情 (JSONB存储)
    commercial_details JSONB DEFAULT '{}' COMMENT '商业险险种详情',
    /*
    {
        "third_party": {premium: 1000, coverage: 500000},
        "driver": {premium: 200, coverage: 10000},
        "passenger": {premium: 300, coverage: 10000},
        "glass": {premium: 150, type: "imported"},
        "scratch": {premium: 500, coverage: 5000},
        "自然损坏": {premium: 800, coverage: 50000},
        "special": []
    }
    */
    
    -- 佣金信息
    commission_rate DECIMAL(5,4) COMMENT '佣金比例',
    commission_amount DECIMAL(12,2) COMMENT '佣金金额',
    commission_status VARCHAR(20) DEFAULT 'pending' CHECK (commission_status IN ('pending','confirmed','paid','rejected')),
    commission_paid_at TIMESTAMPTZ,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft','active','expired','cancelled','renewed')),
    renewal_status VARCHAR(20) DEFAULT 'not_due' CHECK (renewal_status IN ('not_due','expiring','expired','renewed','lost')),
    
    -- 来源信息
    source_channel VARCHAR(50) COMMENT '出单渠道',
    source_agent VARCHAR(100) COMMENT '出单员',
    is_first_policy BOOLEAN DEFAULT FALSE COMMENT '是否新车首保',
    
    -- 证件信息
    policy_pdf_url TEXT COMMENT '电子保单PDF',
    invoice_url TEXT COMMENT '发票URL',
    
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

CREATE INDEX idx_car_policies_customer ON car_policies(customer_id);
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id);
CREATE INDEX idx_car_policies_policy_no ON car_policies(policy_no);
CREATE INDEX idx_car_policies_end_date ON car_policies(end_date);
CREATE INDEX idx_car_policies_renewal_status ON car_policies(renewal_status);
CREATE INDEX idx_car_policies_owner ON car_policies(owner_id);
CREATE INDEX idx_car_policies_status ON car_policies(status);

-- ---------------------------------------------------
-- 3.2 续保记录表 (car_policy_renewals)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS car_policy_renewals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    old_policy_id UUID REFERENCES car_policies(id),
    new_policy_id UUID REFERENCES car_policies(id),
    
    -- 续保对比
    old_premium DECIMAL(12,2) COMMENT '上年保费',
    new_premium DECIMAL(12,2) COMMENT '续保保费',
    premium_change DECIMAL(12,2) COMMENT '保费变化',
    premium_change_rate DECIMAL(5,4) COMMENT '保费变化率',
    
    -- 续保分析
    renewal_type VARCHAR(30) CHECK (renewal_type IN ('same_company','switch_company','lost')),
    lost_reason VARCHAR(100) COMMENT '流失原因',
    
    -- 时间
    original_end_date DATE,
    renewed_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_car_renewals_old_policy ON car_policy_renewals(old_policy_id);
CREATE INDEX idx_car_renewals_new_policy ON car_policy_renewals(new_policy_id);

-- ---------------------------------------------------
-- 3.3 理赔记录表 (car_claims)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    policy_id UUID NOT NULL REFERENCES car_policies(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    
    -- 理赔信息
    claim_no VARCHAR(50) UNIQUE NOT NULL COMMENT '理赔号',
    accident_time TIMESTAMPTZ NOT NULL COMMENT '出险时间',
    accident_location TEXT COMMENT '出险地点',
    accident_description TEXT COMMENT '出险经过',
    accident_type VARCHAR(50) COMMENT '出险类型',
    
    -- 损失信息
    damage_amount DECIMAL(12,2) COMMENT '损失金额(估)',
    repair_amount DECIMAL(12,2) COMMENT '维修金额(定)',
    claim_amount DECIMAL(12,2) COMMENT '理赔金额',
    third_party_amount DECIMAL(12,2) DEFAULT 0 COMMENT '三者损失',
    
    -- 理赔状态
    status VARCHAR(20) DEFAULT 'reported' CHECK (status IN ('reported','surveying','assessing','approved','paid','rejected','closed')),
    report_time TIMESTAMPTZ COMMENT '报案时间',
    survey_time TIMESTAMPTZ COMMENT '查勘时间',
    assess_time TIMESTAMPTZ COMMENT '定损时间',
    approval_time TIMESTAMPTZ COMMENT '审批时间',
    pay_time TIMESTAMPTZ COMMENT '支付时间',
    close_time TIMESTAMPTZ COMMENT '结案时间',
    
    -- 关联信息
    claim_handler VARCHAR(100) COMMENT '理赔员',
    repair_shop VARCHAR(100) COMMENT '维修厂',
    
    -- 附件
    photos JSONB DEFAULT '[]' COMMENT '现场照片',
    documents JSONB DEFAULT '[]' COMMENT '理赔单证',
    
    -- 影响分析
    ncd_years INTEGER DEFAULT 0 COMMENT 'NCD年数(无赔款优待)',
    premium_impact DECIMAL(10,2) COMMENT '对保费影响',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_car_claims_policy ON car_claims(policy_id);
CREATE INDEX idx_car_claims_customer ON car_claims(customer_id);
CREATE INDEX idx_car_claims_status ON car_claims(status);
CREATE INDEX idx_car_claims_accident_time ON car_claims(accident_time);

-- ---------------------------------------------------
-- 3.4 佣金记录表 (car_commissions)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS car_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    policy_id UUID REFERENCES car_policies(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 佣金信息
    commission_type VARCHAR(30) CHECK (commission_type IN ('policy','renewal','recommend','team','special')),
    amount DECIMAL(12,2) NOT NULL COMMENT '佣金金额',
    rate DECIMAL(5,4) COMMENT '佣金比例',
    
    -- 计算明细
    premium DECIMAL(12,2) COMMENT '保费基数',
    calculate_details JSONB DEFAULT '{}',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','calculated','confirmed','paid','cancelled')),
    paid_at TIMESTAMPTZ,
    paid_method VARCHAR(30),
    
    -- 结算周期
    settle_period VARCHAR(20) COMMENT '结算周期',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_car_commissions_policy ON car_commissions(policy_id);
CREATE INDEX idx_car_commissions_owner ON car_commissions(owner_id);
CREATE INDEX idx_car_commissions_status ON car_commissions(status);

-- ============================================================
-- 第四部分：模块二 - 非车险管理 (Non-Car Insurance)
-- ============================================================

-- ---------------------------------------------------
-- 4.1 非车险保单表 (noncar_policies)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL COMMENT '关联车辆(可选)',
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 保单标识
    policy_no VARCHAR(50) UNIQUE NOT NULL,
    
    -- 险种信息
    insurance_category VARCHAR(50) NOT NULL COMMENT '险种类别',
    insurance_name VARCHAR(100) NOT NULL COMMENT '险种名称',
    /*
    类别包括:
    - 意外险: 意外伤害、意外医疗、交通意外、旅游意外
    - 健康险: 医疗险、重疾险、防癌险
    - 家财险: 房屋险、家财险、责任险
    - 责任险: 雇主责任、公众责任、产品责任
    - 信用保证险: 贷款保证险、履约保证险
    - 货运险: 国内货运、跨境货运
    - 其他: 宠物险、账户安全险等
    */
    
    insurer_id VARCHAR(50) NOT NULL,
    insurer_name VARCHAR(100) NOT NULL,
    
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    period_months INTEGER NOT NULL,
    
    -- 被保险人信息
    insured_name VARCHAR(50) NOT NULL,
    insured_type VARCHAR(20) CHECK (insured_type IN ('person','company')),
    insured_id_card VARCHAR(18),
    insured_phone VARCHAR(20),
    
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL,
    coverage_amount DECIMAL(14,2) COMMENT '保额',
    premium_rate DECIMAL(8,4) COMMENT '费率',
    
    -- 佣金
    commission_rate DECIMAL(5,4),
    commission_amount DECIMAL(12,2),
    commission_status VARCHAR(20) DEFAULT 'pending',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft','active','expired','cancelled','renewed')),
    
    -- 附件
    policy_pdf_url TEXT,
    clause_url TEXT,
    
    -- 备注
    remark TEXT,
    
    -- 关联车险
    related_car_policy_id UUID REFERENCES car_policies(id) ON DELETE SET NULL COMMENT '关联车险保单',
    
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
CREATE INDEX idx_noncar_policies_category ON noncar_policies(insurance_category);
CREATE INDEX idx_noncar_policies_status ON noncar_policies(status);
CREATE INDEX idx_noncar_policies_end_date ON noncar_policies(end_date);

-- 初始化非车险类型字典
INSERT INTO lookups (category, code, name, sort_order) VALUES
('noncar_category', 'accident', '意外险', 1),
('noncar_category', 'health', '健康险', 2),
('noncar_category', 'property', '家财险', 3),
('noncar_category', 'liability', '责任险', 4),
('noncar_category', 'credit', '信用保证险', 5),
('noncar_category', 'freight', '货运险', 6),
('noncar_category', 'other', '其他险种', 99);

-- ============================================================
-- 第五部分：模块三 - 年审保养管理 (Inspection & Maintenance)
-- ============================================================

-- ---------------------------------------------------
-- 5.1 服务站/维修厂表 (service_stations)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS service_stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    station_no VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    short_name VARCHAR(50),
    
    -- 类型
    station_type VARCHAR(50) NOT NULL COMMENT 'station_type',
    /*
    - annual_review: 年审站
    - maintenance: 保养维修站
    - 4s: 4S店
    - repair: 快修店
    - beauty: 美容店
    - rescue: 救援公司
    */
    
    -- 联系方式
    contact_person VARCHAR(50),
    phone VARCHAR(20),
    wechat VARCHAR(50),
    
    -- 地址
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address_detail TEXT,
    lat DECIMAL(10,7),
    lng DECIMAL(11,7),
    
    -- 资质
    certifications JSONB DEFAULT '[]' COMMENT '资质证书',
    license_no VARCHAR(100) COMMENT '营业执照号',
    
    -- 合作信息
    is_partner BOOLEAN DEFAULT TRUE,
    partnership_level VARCHAR(20) DEFAULT 'normal',
    commission_rate DECIMAL(5,4) DEFAULT 0 COMMENT '返佣比例',
    settlement_cycle VARCHAR(20) DEFAULT 'monthly',
    
    -- 评价
    rating DECIMAL(3,2) DEFAULT 5.0,
    total_reviews INTEGER DEFAULT 0,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','inactive','suspended')),
    
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

CREATE INDEX idx_service_stations_type ON service_stations(station_type);
CREATE INDEX idx_service_stations_city ON service_stations(city);
CREATE INDEX idx_service_stations_status ON service_stations(status);

-- 初始化服务站类型
INSERT INTO lookups (category, code, name, sort_order) VALUES
('service_station_type', 'annual_review', '年审站', 1),
('service_station_type', 'maintenance', '保养维修站', 2),
('service_station_type', '4s', '4S店', 3),
('service_station_type', 'repair', '快修店', 4),
('service_station_type', 'beauty', '美容店', 5),
('service_station_type', 'rescue', '救援公司', 6);

-- ---------------------------------------------------
-- 5.2 年审记录表 (vehicle_inspections)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicle_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 年审信息
    inspection_type VARCHAR(30) NOT NULL CHECK (inspection_type IN ('annual','transfer','special')),
    inspection_no VARCHAR(50) COMMENT '年审编号',
    
    -- 年审时间
    inspection_date DATE NOT NULL COMMENT '年审日期',
    expire_date DATE NOT NULL COMMENT '到期日期',
    next_inspection_date DATE COMMENT '下次年审日期',
    
    -- 年审结果
    result VARCHAR(20) DEFAULT 'pending' CHECK (result IN ('pending','pass','fail','revoked')),
    fail_reason TEXT,
    recheck_date DATE COMMENT '复检日期',
    
    -- 服务站
    station_id UUID REFERENCES service_stations(id),
    station_name VARCHAR(100),
    
    -- 费用
    inspection_fee DECIMAL(10,2) DEFAULT 0 COMMENT '年审费用',
    repair_fee DECIMAL(10,2) DEFAULT 0 COMMENT '维修费用(复检前)',
    total_fee DECIMAL(10,2) DEFAULT 0 COMMENT '总费用',
    
    -- 报告
    report_url TEXT COMMENT '年审报告URL',
    
    -- 提醒设置
    remind_days_before INTEGER DEFAULT 30 COMMENT '提前提醒天数',
    remind_status VARCHAR(20) DEFAULT 'pending',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_inspections_vehicle ON vehicle_inspections(vehicle_id);
CREATE INDEX idx_inspections_expire_date ON vehicle_inspections(expire_date);
CREATE INDEX idx_inspections_status ON vehicle_inspections(result);

-- ---------------------------------------------------
-- 5.3 保养记录表 (maintenance_records)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 保养信息
    maintenance_no VARCHAR(30) UNIQUE NOT NULL,
    maintenance_type VARCHAR(50) NOT NULL COMMENT 'maintenance_type',
    /*
    - routine: 常规保养
    - repair: 维修
    - warranty: 质保维修
    - accident: 事故维修
    */
    
    -- 时间里程
    maintenance_date DATE NOT NULL,
    current_mileage DECIMAL(12,1) NOT NULL COMMENT '进场里程',
    next_mileage DECIMAL(12,1) COMMENT '建议下次里程',
    next_maintenance_days INTEGER COMMENT '建议下次保养天数',
    
    -- 服务站
    station_id UUID REFERENCES service_stations(id),
    station_name VARCHAR(100),
    
    -- 保养项目
    items JSONB DEFAULT '[]' COMMENT '保养项目列表',
    /*
    [{item: "更换机油", amount: 200, quantity: 4},
     {item: "更换机滤", amount: 50, quantity: 1}]
    */
    
    -- 配件
    parts JSONB DEFAULT '[]' COMMENT '配件列表',
    
    -- 费用
    labor_fee DECIMAL(10,2) DEFAULT 0 COMMENT '工时费',
    parts_fee DECIMAL(10,2) DEFAULT 0 COMMENT '配件费',
    other_fee DECIMAL(10,2) DEFAULT 0 COMMENT '其他费用',
    total_fee DECIMAL(10,2) DEFAULT 0 COMMENT '总费用',
    
    -- 结算
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','unpaid','refunded')),
    payment_method VARCHAR(20),
    paid_at TIMESTAMPTZ,
    
    -- 返佣
    commission_amount DECIMAL(10,2) DEFAULT 0 COMMENT '返佣金额',
    
    -- 报告
    report_url TEXT,
    photos JSONB DEFAULT '[]',
    
    -- 下次保养
    next_maintenance_date DATE COMMENT '建议下次保养日期',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_maintenance_vehicle ON maintenance_records(vehicle_id);
CREATE INDEX idx_maintenance_date ON maintenance_records(maintenance_date);
CREATE INDEX idx_maintenance_type ON maintenance_records(maintenance_type);
CREATE INDEX idx_maintenance_station ON maintenance_records(station_id);

-- 初始化保养类型
INSERT INTO lookups (category, code, name, sort_order) VALUES
('maintenance_type', 'routine', '常规保养', 1),
('maintenance_type', 'repair', '维修', 2),
('maintenance_type', 'warranty', '质保维修', 3),
('maintenance_type', 'accident', '事故维修', 4),
('maintenance_type', 'beauty', '美容', 5),
('maintenance_type', 'modification', '改装', 6);

-- ============================================================
-- 第六部分：模块四 - 汽车后市场服务 (After-Market Services)
-- ============================================================

-- ---------------------------------------------------
-- 6.1 违章记录表 (traffic_violations)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS traffic_violations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 违章信息
    violation_no VARCHAR(50) COMMENT '违章编号',
    violation_time TIMESTAMPTZ NOT NULL COMMENT '违章时间',
    violation_location TEXT NOT NULL COMMENT '违章地点',
    violation_type VARCHAR(50) NOT NULL COMMENT '违章类型',
    violation_code VARCHAR(20) COMMENT '违章代码',
    
    -- 处罚信息
    penalty_points INTEGER NOT NULL COMMENT '扣分数',
    penalty_amount DECIMAL(10,2) NOT NULL COMMENT '罚款金额',
    penalty_status VARCHAR(20) DEFAULT 'unpaid' CHECK (penalty_status IN ('unpaid','paid','appealing','waived')),
    
    -- 处理信息
    handled BOOLEAN DEFAULT FALSE,
    handled_at TIMESTAMPTZ,
    handled_channel VARCHAR(50) COMMENT '处理渠道',
    
    -- 来源
    source VARCHAR(30) DEFAULT 'manual' CHECK (source IN ('manual','api','partner')),
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_violations_vehicle ON traffic_violations(vehicle_id);
CREATE INDEX idx_violations_status ON traffic_violations(penalty_status);
CREATE INDEX idx_violations_time ON traffic_violations(violation_time);

-- ---------------------------------------------------
-- 6.2 后市场订单表 (after_market_orders)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS after_market_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 订单信息
    order_no VARCHAR(30) UNIQUE NOT NULL,
    order_type VARCHAR(50) NOT NULL COMMENT 'order_type',
    /*
    - rescue: 道路救援
    - beauty: 美容服务
    - modification: 改装服务
    - parts: 配件销售
    - accessories: 汽车用品
    - cleaning: 清洗服务
    - coating: 镀晶镀膜
    - tinting: 贴膜服务
    */
    
    -- 时间
    order_date TIMESTAMPTZ DEFAULT NOW(),
    service_date TIMESTAMPTZ COMMENT '预约服务时间',
    completed_date TIMESTAMPTZ COMMENT '完成时间',
    
    -- 服务站
    station_id UUID REFERENCES service_stations(id),
    station_name VARCHAR(100),
    
    -- 订单详情
    items JSONB DEFAULT '[]' COMMENT '服务项目',
    total_amount DECIMAL(12,2) DEFAULT 0 COMMENT '订单金额',
    
    -- 优惠
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    final_amount DECIMAL(12,2) DEFAULT 0 COMMENT '实付金额',
    
    -- 支付
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','refunded')),
    payment_method VARCHAR(30),
    paid_at TIMESTAMPTZ,
    
    -- 返佣
    commission_amount DECIMAL(10,2) DEFAULT 0 COMMENT '返佣金额',
    commission_status VARCHAR(20) DEFAULT 'pending',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'created' CHECK (status IN ('created','paid','processing','completed','cancelled','refunded')),
    
    -- 评价
    rating DECIMAL(3,2),
    review_content TEXT,
    review_time TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_am_orders_customer ON after_market_orders(customer_id);
CREATE INDEX idx_am_orders_type ON after_market_orders(order_type);
CREATE INDEX idx_am_orders_status ON after_market_orders(status);
CREATE INDEX idx_am_orders_date ON after_market_orders(order_date);

-- 初始化后市场订单类型
INSERT INTO lookups (category, code, name, sort_order) VALUES
('order_type', 'rescue', '道路救援', 1),
('order_type', 'beauty', '美容服务', 2),
('order_type', 'modification', '改装服务', 3),
('order_type', 'parts', '配件销售', 4),
('order_type', 'accessories', '汽车用品', 5),
('order_type', 'cleaning', '清洗服务', 6),
('order_type', 'coating', '镀晶镀膜', 7),
('order_type', 'tinting', '贴膜服务', 8);

-- ============================================================
-- 第七部分：模块五 - 汽车消费金融 (Auto Finance)
-- ============================================================

-- ---------------------------------------------------
-- 7.1 贷款合同表 (finance_contracts)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- 合同信息
    contract_no VARCHAR(50) UNIQUE NOT NULL,
    contract_type VARCHAR(30) NOT NULL COMMENT 'contract_type',
    /*
    - new_car_loan: 新车贷款
    - used_car_loan: 二手车贷款
    - refinancing: 抵押贷款
    - lease: 融资租赁
    */
    
    -- 金融机构
    finance_company VARCHAR(100) NOT NULL COMMENT '金融机构',
    finance_company_id VARCHAR(50) COMMENT '机构代码',
    product_name VARCHAR(100) COMMENT '产品名称',
    
    -- 贷款信息
    vehicle_price DECIMAL(14,2) NOT NULL COMMENT '车辆价格(万元)',
    loan_amount DECIMAL(14,2) NOT NULL COMMENT '贷款金额(元)',
    down_payment DECIMAL(14,2) NOT NULL COMMENT '首付金额(元)',
    down_payment_rate DECIMAL(5,4) COMMENT '首付比例',
    
    -- 利率信息
    interest_rate DECIMAL(8,4) NOT NULL COMMENT '年利率',
    rate_type VARCHAR(20) CHECK (rate_type IN ('fixed','floating')),
    base_rate DECIMAL(8,4) COMMENT '基准利率',
    spread_rate DECIMAL(8,4) COMMENT '浮动利率',
    
    -- 期限
    loan_term_months INTEGER NOT NULL COMMENT '贷款期限(月)',
    start_date DATE NOT NULL COMMENT '起贷日期',
    end_date DATE NOT NULL COMMENT '到期日期',
    
    -- 月供
    monthly_payment DECIMAL(12,2) NOT NULL COMMENT '月供金额',
    total_interest DECIMAL(12,2) COMMENT '总利息',
    total_payment DECIMAL(14,2) COMMENT '还款总额',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('pending','approved','active','completed','overdue','default','cancelled')),
    approval_date DATE,
    disbursement_date DATE COMMENT '放款日期',
    completion_date DATE COMMENT '结清日期',
    
    -- 抵押信息
    mortgage_status VARCHAR(20) DEFAULT 'unmortgaged' CHECK (mortgage_status IN ('unmortgaged','mortgaging','mortgaged','released')),
    mortgage_bank VARCHAR(100) COMMENT '抵押银行',
    mortgage_date DATE COMMENT '抵押日期',
    mortgage_release_date DATE COMMENT '解押日期',
    
    -- 附件
    contract_pdf_url TEXT,
    mortgage_cert_url TEXT,
    
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

CREATE INDEX idx_finance_contracts_customer ON finance_contracts(customer_id);
CREATE INDEX idx_finance_contracts_vehicle ON finance_contracts(vehicle_id);
CREATE INDEX idx_finance_contracts_type ON finance_contracts(contract_type);
CREATE INDEX idx_finance_contracts_status ON finance_contracts(status);
CREATE INDEX idx_finance_contracts_end_date ON finance_contracts(end_date);

-- 初始化金融合同类型
INSERT INTO lookups (category, code, name, sort_order) VALUES
('contract_type', 'new_car_loan', '新车贷款', 1),
('contract_type', 'used_car_loan', '二手车贷款', 2),
('contract_type', 'refinancing', '抵押贷款', 3),
('contract_type', 'lease', '融资租赁', 4);

-- ---------------------------------------------------
-- 7.2 还款记录表 (repayment_records)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    contract_id UUID NOT NULL REFERENCES finance_contracts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 期次信息
    period_no INTEGER NOT NULL COMMENT '期次',
    due_date DATE NOT NULL COMMENT '应还日期',
    
    -- 金额明细
    principal DECIMAL(14,2) NOT NULL COMMENT '本金',
    interest DECIMAL(14,2) NOT NULL COMMENT '利息',
    penalty DECIMAL(14,2) DEFAULT 0 COMMENT '罚息',
    total_amount DECIMAL(14,2) NOT NULL COMMENT '应还总额',
    actual_amount DECIMAL(14,2) COMMENT '实还金额',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','paid','overdue','waived')),
    paid_date DATE COMMENT '实还日期',
    paid_days INTEGER DEFAULT 0 COMMENT '逾期天数',
    
    -- 支付方式
    payment_method VARCHAR(30),
    transaction_no VARCHAR(50) COMMENT '交易流水号',
    
    -- 提醒
    remind_status VARCHAR(20) DEFAULT 'pending',
    remind_count INTEGER DEFAULT 0,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_repayments_contract ON repayment_records(contract_id);
CREATE INDEX idx_repayments_due_date ON repayment_records(due_date);
CREATE INDEX idx_repayments_status ON repayment_records(status);

-- ---------------------------------------------------
-- 7.3 担保记录表 (guarantee_records)
-- ---------------------------------------------------
CREATE TABLE IF NOT EXISTS guarantee_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 担保合同
    guarantee_contract_no VARCHAR(50) UNIQUE NOT NULL,
    contract_id UUID REFERENCES finance_contracts(id) ON DELETE CASCADE,
    
    -- 担保人信息
    guarantor_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    guarantor_name VARCHAR(50) NOT NULL,
    guarantor_phone VARCHAR(20) NOT NULL,
    guarantor_id_card VARCHAR(18),
    guarantor_relation VARCHAR(30) COMMENT '与借款人关系',
    
    -- 担保信息
    guarantee_type VARCHAR(30) CHECK (guarantee_type IN ('joint_liability','limited','counter_guarantee')),
    guarantee_amount DECIMAL(14,2) NOT NULL COMMENT '担保金额',
    guarantee_scope TEXT COMMENT '担保范围',
    
    -- 担保物
    collateral_type VARCHAR(30),
    collateral_desc TEXT,
    collateral_value DECIMAL(14,2),
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','released','default')),
    effective_date DATE,
    expire_date DATE,
    release_date DATE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_guarantee_contract ON guarantee_records(contract_id);
CREATE INDEX idx_guarantee_guarantor ON guarantee_records(guarantor_id);
CREATE INDEX idx_guarantee_status ON guarantee_records(status);

-- ============================================================
-- 第八部分：函数与触发器 (Functions & Triggers)
-- ============================================================

-- 触发器: 自动更新审计字段
CREATE OR REPLACE FUNCTION update_audit_fields()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = COALESCE(OLD.version, 0) + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 客户表触发器
CREATE TRIGGER trg_customers_audit
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_audit_fields();

-- 车辆表触发器
CREATE TRIGGER trg_vehicles_audit
    BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_audit_fields();

-- 保单表触发器
CREATE TRIGGER trg_car_policies_audit
    BEFORE UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION update_audit_fields();

-- 触发器: 自动生成客户编号
CREATE OR REPLACE FUNCTION generate_customer_no()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_no IS NULL THEN
        NEW.customer_no = 'C' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(NEXTVAL('seq_customer_no')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS seq_customer_no START 1;

CREATE TRIGGER trg_customers_no
    BEFORE INSERT ON customers
    FOR EACH ROW EXECUTE FUNCTION generate_customer_no();

-- 触发器: 自动生成车辆编号
CREATE OR REPLACE FUNCTION generate_vehicle_no()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.vehicle_no IS NULL THEN
        NEW.vehicle_no = 'V' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(NEXTVAL('seq_vehicle_no')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS seq_vehicle_no START 1;

CREATE TRIGGER trg_vehicles_no
    BEFORE INSERT ON vehicles
    FOR EACH ROW EXECUTE FUNCTION generate_vehicle_no();

-- 触发器: 审计日志
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
DECLARE
    audit_op VARCHAR(20);
BEGIN
    IF TG_OP = 'INSERT' THEN
        audit_op := 'INSERT';
        INSERT INTO audit_logs(table_name, record_id, operation, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, audit_op, to_jsonb(NEW), NEW.created_by);
    ELSIF TG_OP = 'UPDATE' THEN
        audit_op := 'UPDATE';
        INSERT INTO audit_logs(table_name, record_id, operation, old_data, new_data, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, audit_op, to_jsonb(OLD), to_jsonb(NEW), NEW.updated_by);
    ELSIF TG_OP = 'DELETE' THEN
        audit_op := 'DELETE';
        INSERT INTO audit_logs(table_name, record_id, operation, old_data, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, audit_op, to_jsonb(OLD), OLD.updated_by);
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 为敏感表添加审计触发器
CREATE TRIGGER trg_customers_audit_log
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION log_audit();

CREATE TRIGGER trg_car_policies_audit_log
    AFTER INSERT OR UPDATE OR DELETE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION log_audit();

CREATE TRIGGER trg_finance_contracts_audit_log
    AFTER INSERT OR UPDATE OR DELETE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION log_audit();

-- ============================================================
-- 第九部分：RLS行级安全策略
-- ============================================================

-- 启用RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;

-- 客户表RLS策略
CREATE POLICY customer_own ON customers
    FOR ALL USING (owner_id = auth.uid());

CREATE POLICY customer_manager ON customers
    FOR ALL USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','manager'))
    );

-- 车辆表RLS策略
CREATE POLICY vehicle_own ON vehicles
    FOR ALL USING (
        customer_id IN (SELECT id FROM customers WHERE owner_id = auth.uid())
    );

CREATE POLICY vehicle_manager ON vehicles
    FOR ALL USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','manager'))
    );

-- 保单表RLS策略
CREATE POLICY policy_own ON car_policies
    FOR ALL USING (owner_id = auth.uid());

CREATE POLICY policy_manager ON car_policies
    FOR ALL USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','manager'))
    );

-- ============================================================
-- 第十部分：视图 (Views)
-- ============================================================

-- 客户全息视图 (整合客户+车辆+主要业务)
CREATE OR REPLACE VIEW v_customer_overview AS
SELECT 
    c.id,
    c.customer_no,
    c.name,
    c.phone_primary,
    c.customer_level,
    c.status,
    c.total_policies,
    c.total_premium,
    c.total_commission,
    c.owner_name,
    
    -- 车辆信息
    (
        SELECT json_agg(json_build_object(
            'id', v.id,
            'plate_number', v.plate_number,
            'brand', v.brand,
            'model', v.model,
            'annual_review_date', v.annual_review_date,
            'annual_review_status', v.annual_review_status,
            'compulsory_insurance_expire', v.compulsory_insurance_expire,
            'commercial_insurance_expire', v.commercial_insurance_expire
        ))
        FROM vehicles v
        WHERE v.customer_id = c.id AND v.is_deleted = FALSE
    ) AS vehicles,
    
    -- 最新保单
    (
        SELECT json_build_object(
            'policy_no', cp.policy_no,
            'insurer_name', cp.insurer_name,
            'total_premium', cp.total_premium,
            'end_date', cp.end_date,
            'renewal_status', cp.renewal_status
        )
        FROM car_policies cp
        WHERE cp.customer_id = c.id AND cp.is_deleted = FALSE
        ORDER BY cp.end_date DESC
        LIMIT 1
    ) AS latest_policy,
    
    -- 待跟进任务数
    (
        SELECT COUNT(*)
        FROM followups f
        WHERE f.customer_id = c.id AND f.status = 'pending' AND f.is_deleted = FALSE
    ) AS pending_followups
    
FROM customers c
WHERE c.is_deleted = FALSE;

-- 续保到期提醒视图
CREATE OR REPLACE VIEW v_renewal_reminder AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone_primary,
    v.id AS vehicle_id,
    v.plate_number,
    v.brand,
    v.model,
    cp.id AS policy_id,
    cp.policy_no,
    cp.end_date,
    cp.insurer_name,
    cp.total_premium,
    cp.renewal_status,
    cp.owner_id,
    cp.owner_name,
    cp.total_commission,
    
    -- 距离到期天数
    (cp.end_date - CURRENT_DATE) AS days_to_expire,
    
    -- 去年理赔次数
    (
        SELECT COUNT(*)
        FROM car_claims cc
        WHERE cc.policy_id = cp.id 
        AND cc.accident_time >= cp.start_date - INTERVAL '1 year'
        AND cc.is_deleted = FALSE
    ) AS last_year_claims
    
FROM customers c
JOIN vehicles v ON v.customer_id = c.id
JOIN car_policies cp ON cp.vehicle_id = v.id
WHERE cp.is_deleted = FALSE
    AND cp.status = 'active'
    AND v.is_deleted = FALSE
    AND c.is_deleted = FALSE
    AND cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
ORDER BY cp.end_date ASC;

-- 年审到期提醒视图
CREATE OR REPLACE VIEW v_annual_review_reminder AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone_primary,
    v.id AS vehicle_id,
    v.plate_number,
    v.brand,
    v.model,
    v.annual_review_date,
    v.annual_review_status,
    vi.id AS inspection_id,
    vi.station_name,
    vi.inspection_fee,
    
    (v.annual_review_date - CURRENT_DATE) AS days_to_inspection
    
FROM customers c
JOIN vehicles v ON v.customer_id = c.id
LEFT JOIN vehicle_inspections vi ON vi.vehicle_id = v.id AND vi.is_deleted = FALSE
WHERE v.is_deleted = FALSE
    AND c.is_deleted = FALSE
    AND v.annual_review_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
ORDER BY v.annual_review_date ASC;

-- ============================================================
-- 第十一部分：定期任务配置 (Cron Jobs)
-- ============================================================

-- 续保状态更新 (每天凌晨2点执行)
SELECT cron.schedule(
    'update-renewal-status',
    '0 2 * * *',
    $$UPDATE car_policies 
      SET renewal_status = CASE 
          WHEN end_date < CURRENT_DATE THEN 'expired'
          WHEN end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring'
          ELSE 'not_due'
      END
      WHERE is_deleted = FALSE AND status = 'active'$$
);

-- 年审状态更新 (每天凌晨3点执行)
SELECT cron.schedule(
    'update-annual-review-status',
    '0 3 * * *',
    $$UPDATE vehicles 
      SET annual_review_status = CASE 
          WHEN annual_review_date < CURRENT_DATE THEN 'expired'
          WHEN annual_review_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring'
          ELSE 'valid'
      END
      WHERE is_deleted = FALSE$$
);

-- 客户统计数据更新 (每周日凌晨1点执行)
SELECT cron.schedule(
    'update-customer-stats',
    '0 1 * * 0',
    $$UPDATE customers SET 
        total_policies = (SELECT COUNT(*) FROM car_policies WHERE customer_id = customers.id AND is_deleted = FALSE),
        total_premium = (SELECT COALESCE(SUM(total_premium),0) FROM car_policies WHERE customer_id = customers.id AND is_deleted = FALSE),
        total_commission = (SELECT COALESCE(SUM(commission_amount),0) FROM car_policies WHERE customer_id = customers.id AND is_deleted = FALSE),
        updated_at = NOW()
      WHERE is_deleted = FALSE$$
);

-- 车辆统计数据更新 (每周日凌晨1点半执行)
SELECT cron.schedule(
    'update-vehicle-stats',
    '30 1 * * 0',
    $$UPDATE vehicles SET 
        total_insurance = (SELECT COALESCE(SUM(total_premium),0) FROM car_policies WHERE vehicle_id = vehicles.id AND is_deleted = FALSE),
        total_service = (SELECT COALESCE(SUM(total_fee),0) FROM maintenance_records WHERE vehicle_id = vehicles.id AND is_deleted = FALSE),
        total_claims = (SELECT COUNT(*) FROM car_claims WHERE vehicle_id = vehicles.id AND is_deleted = FALSE),
        updated_at = NOW()
      WHERE is_deleted = FALSE$$
);

-- ============================================================
-- 第十二部分：数据导出函数 (Backup Functions)
-- ============================================================

-- 完整数据导出
CREATE OR REPLACE FUNCTION export_full_backup()
RETURNS JSON AS $$
DECLARE
    backup_data JSON;
BEGIN
    backup_data := json_build_object(
        'version', '1.0',
        'export_time', NOW(),
        'customers', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM customers t WHERE is_deleted = FALSE),
        'vehicles', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM vehicles t WHERE is_deleted = FALSE),
        'car_policies', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM car_policies t WHERE is_deleted = FALSE),
        'noncar_policies', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM noncar_policies t WHERE is_deleted = FALSE),
        'finance_contracts', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM finance_contracts t WHERE is_deleted = FALSE),
        'maintenance_records', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM maintenance_records t WHERE is_deleted = FALSE),
        'followups', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM followups t WHERE is_deleted = FALSE),
        'audit_logs', (SELECT json_agg(json_strip_nulls(to_jsonb(t))) FROM audit_logs t WHERE created_at > NOW() - INTERVAL '90 days')
    );
    RETURN backup_data;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 完成标记
-- ============================================================
-- 数据库Schema初始化完成
-- 版本: V1.0
-- 日期: 2026-04-19
-- 总表数: 20+
-- 视图数: 3
-- 定时任务: 4
