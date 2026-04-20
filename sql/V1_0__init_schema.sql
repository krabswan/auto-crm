-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema V1.0
-- 版本: V1.0 | 日期: 2026-04-19 | 作者: 痞老板
-- 说明: 模块化设计，支持车险/非车险/年审保养/后市场/消费金融
-- ============================================================

-- ============================================================
-- 模块1: 系统基础 (System Foundation)
-- ============================================================

-- 1.1 用户表 (系统用户/员工)
CREATE TABLE IF NOT EXISTS sys_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    real_name VARCHAR(100),
    role VARCHAR(20) DEFAULT 'staff' CHECK (role IN ('admin', 'manager', 'staff', 'readonly')),
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 1.2 权限表
CREATE TABLE IF NOT EXISTS sys_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    module VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.3 用户权限关联表
CREATE TABLE IF NOT EXISTS sys_user_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES sys_users(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES sys_permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES sys_users(id),
    UNIQUE(user_id, permission_id)
);

-- 1.4 审计日志表 (核心可追溯性)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'SELECT', 'LOGIN', 'EXPORT')),
    old_value JSONB,
    new_value JSONB,
    change_summary TEXT,
    user_id UUID REFERENCES sys_users(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.5 系统配置表 (KV存储)
CREATE TABLE IF NOT EXISTS sys_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id)
);

-- ============================================================
-- 模块2: 统一客户中心 (Customer Core)
-- 所有模块通过 customer_id 关联到此表
-- ============================================================

CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(10) CHECK (gender IN ('男', '女', '未知')),
    birth_date DATE,
    id_card VARCHAR(18) UNIQUE,
    phone VARCHAR(20) NOT NULL,
    phone_secondary VARCHAR(20),
    email VARCHAR(255),
    
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address_detail TEXT,
    
    -- 客户分级
    customer_level VARCHAR(20) DEFAULT 'C' CHECK (customer_level IN ('A', 'B', 'C', 'D')),
    customer_source VARCHAR(50),  -- 来源：自然流入/转介绍/网络获客/活动获客
    
    -- 标签系统 (JSON数组)
    tags TEXT[] DEFAULT '{}',
    
    -- 关联家庭ID (家庭客户识别)
    family_id UUID,
    family_relation VARCHAR(20),  -- 本人与户主关系：本人/配偶/子女/父母
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 客户扩展信息表
CREATE TABLE IF NOT EXISTS customer_extensions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 职业信息
    occupation VARCHAR(100),
    company_name VARCHAR(200),
    annual_income VARCHAR(50),
    
    -- 家庭信息
    family_size INTEGER,
    has_children BOOLEAN,
    children_count INTEGER,
    
    -- 驾驶信息
    has_driving_license BOOLEAN,
    driving_license_no VARCHAR(30),
    license_issue_date DATE,
    
    -- 风险评估
    risk_level VARCHAR(20) DEFAULT 'NORMAL' CHECK (risk_level IN ('LOW', 'NORMAL', 'HIGH')),
    risk_notes TEXT,
    
    -- 偏好设置
    preferred_contact_way VARCHAR(20),  -- 微信/电话/短信/邮件
    preferred_service_time VARCHAR(50),  -- 上午/下午/晚上
    
    -- 营销偏好
    allow_sms BOOLEAN DEFAULT TRUE,
    allow_call BOOLEAN DEFAULT TRUE,
    allow_wechat BOOLEAN DEFAULT TRUE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块3: 车辆信息表 (Vehicle Core - 所有车的统一台账)
-- 无论哪个业务模块，车辆信息统一存储在此表
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 车辆基本信息
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type VARCHAR(20) CHECK (vehicle_type IN ('轿车', 'SUV', 'MPV', '面包车', '货车', '客车', '新能源', '其他')),
    brand VARCHAR(50),          -- 品牌：丰田/大众/比亚迪等
    model VARCHAR(100),          -- 车型：凯美瑞 2023款 2.5L
    color VARCHAR(20),
    
    -- VIN码
    vin VARCHAR(17) UNIQUE,
    
    -- 注册信息
    register_date DATE,         -- 注册日期
    plate_province VARCHAR(50),
    plate_city VARCHAR(50),
    
    -- 发动机信息
    engine_no VARCHAR(50),
    fuel_type VARCHAR(20) CHECK (fuel_type IN ('汽油', '柴油', '纯电', '混动', '天然气', '其他')),
    
    -- 商业险信息
    commercial_insurance_company VARCHAR(100),
    commercial_insurance_expire DATE,
    
    -- 交强险信息
    compulsory_insurance_company VARCHAR(100),
    compulsory_insurance_expire DATE,
    
    -- 年审信息
    annual_review_expire DATE,
    annual_review_status VARCHAR(20) DEFAULT '正常' CHECK (annual_review_status IN ('正常', '即将到期', '已过期', '已报废')),
    
    -- 当前状态
    current_mileage DECIMAL(12, 2),  -- 行驶里程（公里）
    vehicle_status VARCHAR(20) DEFAULT '在用' CHECK (vehicle_status IN ('在用', '闲置', '已售', '已报废')),
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块4: 车险管理 (Car Insurance)
-- ============================================================

CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    
    -- 保单基本信息
    policy_no VARCHAR(50) UNIQUE NOT NULL,
    policy_type VARCHAR(20) CHECK (policy_type IN ('商业险', '交强险', '双险')),
    
    -- 承保公司
    insurance_company VARCHAR(100) NOT NULL,
    branch_company VARCHAR(100),  -- 分支机构
    
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    insurance_period INTEGER,  -- 保险期间（天）
    
    -- 保费信息
    total_premium DECIMAL(12, 2),  -- 总保费
    compulsory_premium DECIMAL(12, 2),  -- 交强险保费
    commercial_premium DECIMAL(12, 2),  -- 商业险保费
    tax_amount DECIMAL(12, 2),  -- 车船税
    
    -- 佣金信息
    commission_rate DECIMAL(6, 4),  -- 佣金比例
    commission_amount DECIMAL(12, 2),  -- 佣金金额
    actual_commission DECIMAL(12, 2),  -- 实际佣金（可能有折扣）
    commission_status VARCHAR(20) DEFAULT '未结算' CHECK (commission_status IN ('未结算', '部分结算', '已结算', '已到账')),
    
    -- 险种明细 (JSONB存储)
    coverage_details JSONB DEFAULT '[]',
    /*
    格式示例:
    [
      {"险种": "第三者责任险", "保额": "100万", "保费": 1200.00},
      {"险种": "车辆损失险", "保额": "车价", "保费": 2500.00},
      {"险种": "全车盗抢险", "保额": "车价", "保费": 500.00}
    ]
    */
    
    -- 投保渠道
    channel VARCHAR(50),  -- 直客/代理/电销/网销
    
    -- 来源业务员
    agent_id UUID REFERENCES sys_users(id),
    agent_name VARCHAR(100),
    
    -- 保单状态
    policy_status VARCHAR(20) DEFAULT '有效' CHECK (policy_status IN ('有效', '退保', '批改', '理赔中', '已失效')),
    
    -- 续保信息
    is_renewal BOOLEAN DEFAULT FALSE,  -- 是否续保
    previous_policy_id UUID REFERENCES car_policies(id),  -- 上年保单
    
    -- 附件
    attachments JSONB DEFAULT '[]',  -- [{"name": "保单.jpg", "url": "..."}]
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 车险理赔记录
CREATE TABLE IF NOT EXISTS car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES car_policies(id),
    claim_no VARCHAR(50) UNIQUE,
    
    -- 出险信息
    accident_date TIMESTAMPTZ,
    accident_place TEXT,
    accident_description TEXT,
    
    -- 责任划分
    liability_ratio VARCHAR(20),  -- 我方责任：无责/次责/同责/主责/全责
    
    -- 理赔金额
    estimated_damage DECIMAL(12, 2),  -- 预估损失
    claim_amount DECIMAL(12, 2),  -- 申请理赔金额
    approved_amount DECIMAL(12, 2),  -- 核定金额
    actual_paid DECIMAL(12, 2),  -- 实际赔付
    
    -- 理赔状态
    claim_status VARCHAR(20) DEFAULT '待处理' CHECK (claim_status IN ('待处理', '调查中', '核定中', '已结案', '已拒赔')),
    
    -- 理赔进度
    progress_notes TEXT,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块5: 非车险管理 (Non-Car Insurance)
-- ============================================================

CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 保单基本信息
    policy_no VARCHAR(50) UNIQUE NOT NULL,
    insurance_type VARCHAR(50) NOT NULL CHECK (insurance_type IN (
        '意外险', '健康险', '医疗险', '寿险', 
        '家财险', '责任险', '信用险', '保证险',
        '工程险', '船舶险', '货物运输险', '其他'
    )),
    insurance_subtype VARCHAR(100),  -- 子类型：驾乘意外险/团体意外险/百万医疗等
    
    -- 承保公司
    insurance_company VARCHAR(100) NOT NULL,
    
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 被保险人信息
    insured_name VARCHAR(100),
    insured_id_card VARCHAR(18),
    insured_relation VARCHAR(20) DEFAULT '本人',  -- 与投保人关系
    
    -- 保费信息
    total_premium DECIMAL(12, 2) NOT NULL,
    
    -- 佣金信息
    commission_rate DECIMAL(6, 4),
    commission_amount DECIMAL(12, 2),
    actual_commission DECIMAL(12, 2),
    commission_status VARCHAR(20) DEFAULT '未结算' CHECK (commission_status IN ('未结算', '已结算', '已到账')),
    
    -- 销售渠道
    channel VARCHAR(50),
    agent_id UUID REFERENCES sys_users(id),
    agent_name VARCHAR(100),
    
    -- 保单状态
    policy_status VARCHAR(20) DEFAULT '有效' CHECK (policy_status IN ('有效', '退保', '批改', '已失效')),
    
    -- 保障内容 (JSONB)
    coverage_details JSONB DEFAULT '{}',
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块6: 年审保养管理 (Annual Review & Maintenance)
-- ============================================================

CREATE TABLE IF NOT EXISTS vehicle_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    
    -- 服务类型
    service_type VARCHAR(50) NOT NULL CHECK (service_type IN (
        '年审', '保养', '维修', '检测', '过户', '上牌', '注销'
    )),
    
    -- 服务详情
    service_date DATE NOT NULL,
    due_date DATE,  -- 到期日期（年审用）
    
    -- 服务商
    service_provider_name VARCHAR(200),
    service_provider_id UUID,  -- 关联服务商表
    service_provider_contact VARCHAR(50),
    service_provider_address TEXT,
    
    -- 服务费用
    service_fee DECIMAL(12, 2),  -- 服务费
    material_fee DECIMAL(12, 2),  -- 材料费
    other_fee DECIMAL(12, 2),  -- 其他费用
    total_fee DECIMAL(12, 2),
    
    -- 返佣信息
    rebate_rate DECIMAL(6, 4),
    rebate_amount DECIMAL(12, 2),
    
    -- 服务结果
    result VARCHAR(20) DEFAULT '进行中' CHECK (result IN ('进行中', '已完成', '未通过', '已取消')),
    fail_reason TEXT,  -- 未通过原因
    
    -- 保养记录详情
    service_details JSONB DEFAULT '[]',
    /*
    保养示例:
    [
      {"项目": "更换机油", "品牌": "壳牌", "规格": "5W-40", "数量": 1, "金额": 300},
      {"项目": "更换机滤", "品牌": "马勒", "规格": "ML1015", "数量": 1, "金额": 50}
    ]
    */
    
    -- 下次保养提醒
    next_service_date DATE,
    next_service_mileage DECIMAL(12, 2),
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 服务商表 (维修厂/检测站/4S店)
CREATE TABLE IF NOT EXISTS service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    name VARCHAR(200) NOT NULL,
    type VARCHAR(50) CHECK (type IN ('4S店', '综合维修厂', '专修店', '检测站', '美容店', '养护中心')),
    license_no VARCHAR(50),
    contact_person VARCHAR(100),
    contact_phone VARCHAR(20),
    address TEXT,
    business_scope TEXT[],
    
    rating DECIMAL(3, 2) CHECK (rating >= 0 AND rating <= 5),  -- 0-5分
    review_count INTEGER DEFAULT 0,
    
    -- 合作信息
    is_cooperated BOOLEAN DEFAULT FALSE,
    cooperation_start_date DATE,
    commission_rate DECIMAL(6, 4),  -- 返佣比例
    settlement_cycle VARCHAR(20),  -- 结算周期：月结/季结
    
    -- 账户信息
    bank_name VARCHAR(100),
    bank_account VARCHAR(50),
    bank_account_name VARCHAR(100),
    
    -- 状态
    status VARCHAR(20) DEFAULT '正常' CHECK (status IN ('正常', '暂停', '终止')),
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块7: 汽车后市场服务 (After Market Services)
-- ============================================================

CREATE TABLE IF NOT EXISTS after_market_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 订单基本信息
    order_no VARCHAR(50) UNIQUE NOT NULL,
    order_type VARCHAR(50) NOT NULL CHECK (order_type IN (
        '违章处理', '道路救援', '美容洗车', '贴膜隔热', 
        '改装升级', '配件销售', '代驾服务', '停车服务', '其他'
    )),
    
    -- 订单金额
    order_amount DECIMAL(12, 2) NOT NULL,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    actual_amount DECIMAL(12, 2),
    profit_amount DECIMAL(12, 2),  -- 利润
    
    -- 服务商
    provider_id UUID REFERENCES service_providers(id),
    provider_name VARCHAR(200),
    
    -- 订单状态
    order_status VARCHAR(20) DEFAULT '待处理' CHECK (order_status IN (
        '待处理', '处理中', '已完成', '已取消', '退款中', '已退款'
    )),
    
    -- 服务详情
    service_content TEXT,
    service_result TEXT,
    
    -- 违章处理专用
    violation_count INTEGER,  -- 违章条数
    violation_points INTEGER,  -- 扣分
    violation_fine DECIMAL(12, 2),  -- 罚款金额
    
    -- 完成时间
    completed_at TIMESTAMPTZ,
    
    -- 支付信息
    payment_status VARCHAR(20) DEFAULT '待支付' CHECK (payment_status IN ('待支付', '部分支付', '已支付', '已退款')),
    payment_method VARCHAR(20),  -- 微信/支付宝/现金/转账
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块8: 汽车消费金融 (Auto Finance)
-- ============================================================

CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 合同基本信息
    contract_no VARCHAR(50) UNIQUE NOT NULL,
    contract_type VARCHAR(30) NOT NULL CHECK (contract_type IN (
        '车贷', '分期', '融资租赁', '抵押贷款', '担保服务'
    )),
    
    -- 金融机构
    finance_company VARCHAR(100) NOT NULL,
    branch_company VARCHAR(100),
    
    -- 贷款金额
    loan_amount DECIMAL(14, 2) NOT NULL,  -- 贷款本金
    loan_term INTEGER NOT NULL,  -- 贷款期限（月）
    annual_rate DECIMAL(8, 4) NOT NULL,  -- 年利率
    monthly_payment DECIMAL(12, 2),  -- 月供
    total_interest DECIMAL(12, 2),  -- 总利息
    total_amount DECIMAL(14, 2),  -- 还款总额
    
    -- 费用
    service_fee DECIMAL(12, 2),  -- 服务费
    guarantee_fee DECIMAL(12, 2),  -- 担保费
    other_fee DECIMAL(12, 2),
    
    -- 返佣信息
    rebate_rate DECIMAL(6, 4),
    rebate_amount DECIMAL(12, 2),
    
    -- 合同期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 还款计划
    repayment_type VARCHAR(20) DEFAULT '等额本息' CHECK (repayment_type IN ('等额本息', '等额本金', '先息后本', '气球贷')),
    first_repayment_date DATE,
    
    -- 当前状态
    contract_status VARCHAR(20) DEFAULT '正常' CHECK (contract_status IN (
        '正常', '逾期', '提前还清', '展期', '代偿', '已结清'
    )),
    
    -- 已还期数
    repaid_periods INTEGER DEFAULT 0,
    remaining_periods INTEGER,
    
    -- 抵押物信息
    collateral_type VARCHAR(50),
    collateral_value DECIMAL(14, 2),
    collateral_status VARCHAR(20),
    
    -- 担保人信息
    guarantor_name VARCHAR(100),
    guarantor_id_card VARCHAR(18),
    guarantor_phone VARCHAR(20),
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 还款计划表
CREATE TABLE IF NOT EXISTS repayment_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES finance_contracts(id) ON DELETE CASCADE,
    
    period_no INTEGER NOT NULL,  -- 期次
    due_date DATE NOT NULL,  -- 应还日期
    
    -- 应还金额
    principal_due DECIMAL(14, 2),  -- 应还本金
    interest_due DECIMAL(14, 2),  -- 应还利息
    total_due DECIMAL(14, 2),  -- 应还总额
    
    -- 实还金额
    principal_paid DECIMAL(14, 2) DEFAULT 0,
    interest_paid DECIMAL(14, 2) DEFAULT 0,
    total_paid DECIMAL(14, 2) DEFAULT 0,
    
    -- 罚息
    penalty_interest DECIMAL(14, 2) DEFAULT 0,
    
    -- 状态
    status VARCHAR(20) DEFAULT '待还' CHECK (status IN ('待还', '已还', '逾期', '代偿')),
    
    -- 实际还款日期
    actual_repayment_date DATE,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块9: 跟进记录 (Follow-up - 贯穿所有模块)
-- ============================================================

CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 关联业务
    related_type VARCHAR(50) CHECK (related_type IN (
        'car_policy', 'noncar_policy', 'vehicle_service', 
        'after_market', 'finance_contract', 'customer'
    )),
    related_id UUID,
    
    -- 跟进信息
    followup_type VARCHAR(50) CHECK (followup_type IN (
        '电话拜访', '微信沟通', '上门拜访', '短信回访',
        '续保提醒', '到期提醒', '理赔跟进', '投诉处理',
        '活动邀请', '产品推荐', '满意度回访', '其他'
    )),
    
    content TEXT NOT NULL,
    result VARCHAR(20) CHECK (result IN ('待处理', '进行中', '已解决', '无意向', '已成交')),
    
    -- 下次跟进
    next_followup_date DATE,
    next_followup_content TEXT,
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块10: 提醒任务 (Reminders)
-- ============================================================

CREATE TABLE IF NOT EXISTS reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 关联业务
    related_type VARCHAR(50),
    related_id UUID,
    
    -- 提醒信息
    reminder_type VARCHAR(50) NOT NULL CHECK (reminder_type IN (
        '续保到期', '年审到期', '保养到期', '还贷提醒',
        '保单到期', '生日提醒', '节日关怀', '回访提醒', '自定义'
    )),
    
    title VARCHAR(200) NOT NULL,
    content TEXT,
    remind_date DATE NOT NULL,
    remind_time TIME,
    
    -- 提醒设置
    is_repeated BOOLEAN DEFAULT FALSE,
    repeat_cycle VARCHAR(20),  -- 每年/每月/每周
    
    -- 状态
    status VARCHAR(20) DEFAULT '待执行' CHECK (status IN ('待执行', '已执行', '已过期', '已取消')),
    
    -- 执行结果
    executed_at TIMESTAMPTZ,
    execution_result TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES sys_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES sys_users(id),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 索引设计
-- ============================================================

-- 客户相关索引
CREATE INDEX idx_customers_phone ON customers(phone) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_name ON customers(name) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_id_card ON customers(id_card) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_level ON customers(customer_level);
CREATE INDEX idx_customers_created_at ON customers(created_at DESC);

-- 车辆相关索引
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_vin ON vehicles(vin) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_annual_review ON vehicles(annual_review_expire) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_insurance_expire ON vehicles(commercial_insurance_expire) WHERE is_deleted = FALSE;

-- 保单相关索引
CREATE INDEX idx_car_policies_policy_no ON car_policies(policy_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_customer ON car_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_end_date ON car_policies(end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_agent ON car_policies(agent_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_company ON car_policies(insurance_company) WHERE is_deleted = FALSE;

-- 非车险索引
CREATE INDEX idx_noncar_policies_policy_no ON noncar_policies(policy_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_customer ON noncar_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_end_date ON noncar_policies(end_date) WHERE is_deleted = FALSE;

-- 服务索引
CREATE INDEX idx_vehicle_services_customer ON vehicle_services(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicle_services_vehicle ON vehicle_services(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicle_services_due_date ON vehicle_services(due_date) WHERE is_deleted = FALSE;

-- 后市场索引
CREATE INDEX idx_after_market_orders_customer ON after_market_orders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_after_market_orders_order_no ON after_market_orders(order_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_after_market_orders_created_at ON after_market_orders(created_at DESC);

-- 金融索引
CREATE INDEX idx_finance_contracts_customer ON finance_contracts(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_contracts_contract_no ON finance_contracts(contract_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_schedules_due_date ON repayment_schedules(due_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_schedules_contract ON repayment_schedules(contract_id) WHERE is_deleted = FALSE;

-- 跟进索引
CREATE INDEX idx_followups_customer ON followups(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_followups_next_date ON followups(next_followup_date) WHERE is_deleted = FALSE;

-- 提醒索引
CREATE INDEX idx_reminders_remind_date ON reminders(remind_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_reminders_status ON reminders(status) WHERE is_deleted = FALSE;

-- 审计日志索引
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_record ON audit_logs(record_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- ============================================================
-- 行级安全策略 (RLS)
-- ============================================================

-- 启用RLS
ALTER TABLE sys_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_extensions ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_market_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repayment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 管理员可访问所有数据
-- 员工只能访问自己的数据
-- 只读用户只能查询

-- customers 表策略
CREATE POLICY "sys_users_select" ON customers FOR SELECT TO authenticated USING (
    auth.uid() IN (SELECT id FROM sys_users WHERE is_active = TRUE AND role IN ('admin', 'manager', 'staff', 'readonly'))
);

CREATE POLICY "sys_users_all" ON customers FOR ALL TO authenticated USING (
    auth.uid() IN (SELECT id FROM sys_users WHERE is_active = TRUE AND role IN ('admin', 'manager'))
);

-- 审计日志策略 (所有人可读，管理员可写)
CREATE POLICY "audit_read" ON audit_logs FOR SELECT TO authenticated USING (
    auth.uid() IN (SELECT id FROM sys_users WHERE is_active = TRUE)
);

CREATE POLICY "audit_insert" ON audit_logs FOR INSERT TO authenticated WITH CHECK (TRUE);

-- ============================================================
-- 自动更新触发器
-- ============================================================

-- 审计字段自动更新
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = COALESCE(OLD.version, 0) + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表添加触发器
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_car_policies_updated_at BEFORE UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_noncar_policies_updated_at BEFORE UPDATE ON noncar_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_vehicle_services_updated_at BEFORE UPDATE ON vehicle_services
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_service_providers_updated_at BEFORE UPDATE ON service_providers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_after_market_orders_updated_at BEFORE UPDATE ON after_market_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_finance_contracts_updated_at BEFORE UPDATE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_repayment_schedules_updated_at BEFORE UPDATE ON repayment_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_followups_updated_at BEFORE UPDATE ON followups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_reminders_updated_at BEFORE UPDATE ON reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 初始数据
-- ============================================================

-- 插入管理员账户 (密码: 589842)
INSERT INTO sys_users (username, email, phone, password_hash, real_name, role) VALUES
('admin', '589842@qq.com', '13328185024', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5lWkJFHhKEFVe', '蟹老板', 'admin');

-- 插入系统配置
INSERT INTO sys_config (config_key, config_value, description) VALUES
('system_version', '{"version": "V1.0", "release_date": "2026-04-19", "modules": ["car_insurance", "noncar_insurance", "annual_review", "after_market", "auto_finance"]}', '系统版本信息'),
('renewal_reminder_days', '{"before_90": true, "before_60": true, "before_30": true, "before_7": true}', '续保提醒天数配置'),
('annual_review_reminder_days', '{"before_30": true, "before_7": true}', '年审提醒天数配置'),
('data_backup', '{"auto_backup": true, "backup_time": "10:00", "backup_day": "1", "retain_months": 12}', '数据备份配置');
