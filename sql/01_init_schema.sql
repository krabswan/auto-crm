-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema V1.0
-- 创建时间: 2026-04-19
-- 作者: 痞老板
-- ============================================================

-- ============================================================
-- 1. 统一客户中心 (customers)
-- 所有模块的核心，所有数据通过 customer_id 关联
-- ============================================================
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 基本信息
    name TEXT NOT NULL,                          -- 客户姓名
    gender TEXT CHECK(gender IN ('男','女','未知')),  -- 性别
    id_card TEXT,                               -- 身份证号（加密存储）
    phone TEXT NOT NULL,                        -- 手机号（唯一）
    phone2 TEXT,                                 -- 备用手机
    email TEXT,                                  -- 邮箱
    wechat TEXT,                                 -- 微信号
    birthday DATE,                               -- 生日
    occupation TEXT,                             -- 职业
    annual_income NUMERIC(12,2),                -- 年收入（敏感）
    
    -- 地址信息
    province TEXT,                               -- 省
    city TEXT,                                  -- 市
    district TEXT,                               -- 区
    address TEXT,                               -- 详细地址
    postal_code TEXT,                           -- 邮编
    
    -- 车辆信息（主要车辆）
    main_plate TEXT,                            -- 主要车牌
    main_vin TEXT,                              -- 主要VIN码
    main_brand TEXT,                            -- 品牌
    main_model TEXT,                            -- 车型
    main_register_date DATE,                    -- 上牌日期
    main_annual_review_date DATE,               -- 年审日期
    main_insurance_end_date DATE,               -- 保险到期日
    
    -- 客户分类
    customer_type TEXT DEFAULT '个人' 
        CHECK(customer_type IN ('个人','企业','政府','其他')),
    customer_source TEXT,                       -- 客户来源
    customer_level TEXT DEFAULT 'C级'
        CHECK(customer_level IN ('A级','B级','C级','D级')), -- A=高净值 B=稳定 C=普通 D=流失
    tags TEXT[],                                -- 标签数组
    
    -- 归属
    owner_id UUID,                             -- 归属业务员
    owner_name TEXT,                            -- 归属业务员姓名
    org_id TEXT,                                -- 组织ID（未来扩展）
    
    -- 审计字段（所有表统一）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    operate_ip INET,                            -- 操作IP
    
    -- 约束
    UNIQUE(phone)
);

-- 客户表索引
CREATE INDEX IF NOT EXISTS idx_cust_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_cust_main_plate ON customers(main_plate);
CREATE INDEX IF NOT EXISTS idx_cust_owner ON customers(owner_id);
CREATE INDEX IF NOT EXISTS idx_cust_level ON customers(customer_level);
CREATE INDEX IF NOT EXISTS idx_cust_annual_review ON customers(main_annual_review_date);
CREATE INDEX IF NOT EXISTS idx_cust_insurance_end ON customers(main_insurance_end_date);

-- ============================================================
-- 2. 车辆信息表 (vehicles)
-- 一个客户可以有多辆车
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 车辆基本信息
    plate TEXT NOT NULL,                        -- 车牌号
    vin TEXT NOT NULL,                          -- VIN码
    engine_no TEXT,                             -- 发动机号
    brand TEXT,                                 -- 品牌（丰田/大众等）
    series TEXT,                                -- 车系（卡罗拉/帕萨特等）
    model TEXT,                                 -- 车型（具体配置）
    color TEXT,                                 -- 车身颜色
    vehicle_type TEXT DEFAULT '客车'
        CHECK(vehicle_type IN ('客车','货车','客车/货车','其他')),
    use_nature TEXT DEFAULT '家庭自用'
        CHECK(use_nature IN ('家庭自用','企业自用','营运','非营运','出租','其他')),
    
    -- 车辆参数
    register_date DATE,                         -- 注册日期
    annual_review_date DATE,                    -- 年审日期（行驶证）
    compulsory_insurance_date DATE,             -- 交强险有效期
    business_insurance_date DATE,               -- 商业险有效期
    
    -- 其他
    mileage NUMERIC(10,0),                      -- 行驶里程
    accident_record TEXT,                       -- 事故记录
    mortgage_status TEXT DEFAULT '无抵押'
        CHECK(mortgage_status IN ('无抵押','抵押中','已解压')),
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    operate_ip INET,
    
    UNIQUE(plate),
    UNIQUE(vin)
);

CREATE INDEX IF NOT EXISTS idx_veh_cust ON vehicles(customer_id);
CREATE INDEX IF NOT EXISTS idx_veh_plate ON vehicles(plate);
CREATE INDEX IF NOT EXISTS idx_veh_annual_review ON vehicles(annual_review_date);
CREATE INDEX IF NOT EXISTS idx_veh_insurance_end ON vehicles(compulsory_insurance_date, business_insurance_date);

-- ============================================================
-- 3. 车险保单表 (car_policies)
-- ============================================================
CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 保单基本信息
    policy_no TEXT NOT NULL,                   -- 保单号（唯一）
    company TEXT NOT NULL,                     -- 承保公司
    company_code TEXT,                         -- 公司代码
    policy_type TEXT DEFAULT '商业险'
        CHECK(policy_type IN ('交强险','商业险','全险','单三者','其他')),
    
    -- 车辆信息（快照，关联保单时刻）
    plate TEXT NOT NULL,
    vin TEXT,
    brand TEXT,
    model TEXT,
    
    -- 保费明细
    biz_premium NUMERIC(12,2) DEFAULT 0,       -- 商业险保费
    force_premium NUMERIC(12,2) DEFAULT 0,     -- 交强险保费
    tax_premium NUMERIC(12,2) DEFAULT 0,       -- 车船税
    total_premium NUMERIC(12,2) DEFAULT 0,     -- 总保费
    
    -- 佣金
    commission_rate NUMERIC(5,4),               -- 佣金率
    commission_amount NUMERIC(12,2) DEFAULT 0, -- 佣金金额
    net_income NUMERIC(12,2) DEFAULT 0,        -- 净收入（佣金-税点）
    commission_status TEXT DEFAULT '未结算'
        CHECK(commission_status IN ('未结算','结算中','已结算','拒绝')),
    
    -- 日期
    sign_date DATE NOT NULL,                    -- 签单日期
    start_date DATE NOT NULL,                   -- 生效日期
    end_date DATE NOT NULL,                     -- 到期日期
    pay_date DATE,                              -- 付款日期
    settle_date DATE,                           -- 结算日期
    
    -- 险种明细（JSON格式存储）
    coverage_details JSONB DEFAULT '{}',
    /*
    示例：
    {
      "三者100万": {"premium": 1200, "coverage": 1000000},
      "车损险": {"premium": 2500, "coverage": "发票价"},
      "司机险": {"premium": 150, "coverage": 10000},
      "乘客险": {"premium": 200, "coverage": 10000*4}
    }
    */
    
    -- 状态
    status TEXT DEFAULT 'active'
        CHECK(status IN ('active','expired','cancelled','pending')),
    renewal_status TEXT DEFAULT '未到期'
        CHECK(renewal_status IN ('未到期','待跟进','已报价','已成交','已流失')),
    
    -- 理赔记录
    claim_count INTEGER DEFAULT 0,
    claim_amount NUMERIC(12,2) DEFAULT 0,
    claim_records JSONB DEFAULT '[]',
    
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
    deleted_by UUID,
    operate_ip INET,
    
    UNIQUE(policy_no)
);

CREATE INDEX IF NOT EXISTS idx_car_cust ON car_policies(customer_id);
CREATE INDEX IF NOT EXISTS idx_car_plate ON car_policies(plate);
CREATE INDEX IF NOT EXISTS idx_car_end_date ON car_policies(end_date);
CREATE INDEX IF NOT EXISTS idx_car_renewal ON car_policies(renewal_status);
CREATE INDEX IF NOT EXISTS idx_car_company ON car_policies(company);
CREATE INDEX IF NOT EXISTS idx_car_sign_date ON car_policies(sign_date);
CREATE INDEX IF NOT EXISTS idx_car_status ON car_policies(status);

-- ============================================================
-- 4. 非车险保单表 (noncar_policies)
-- ============================================================
CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 保单信息
    policy_no TEXT NOT NULL,
    company TEXT NOT NULL,
    insurance_type TEXT NOT NULL,
    /*
    类型包括：
    - 意外险（驾乘意外险/人身意外险）
    - 健康险（医疗险/重疾险）
    - 家财险
    - 责任险（雇主责任/公众责任）
    - 信用保证险
    - 财产险
    - 船舶险
    - 工程险
    - 其他
    */
    insurance_subtype TEXT,                    -- 子类型
    
    -- 被保险人
    insured_name TEXT,
    insured_id_card TEXT,
    insured_phone TEXT,
    
    -- 保费与佣金
    premium NUMERIC(12,2) NOT NULL,
    commission_rate NUMERIC(5,4),
    commission_amount NUMERIC(12,2) DEFAULT 0,
    net_income NUMERIC(12,2) DEFAULT 0,
    commission_status TEXT DEFAULT '未结算'
        CHECK(commission_status IN ('未结算','结算中','已结算','拒绝')),
    
    -- 日期
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    pay_date DATE,
    settle_date DATE,
    
    -- 保障内容
    coverage_amount NUMERIC(14,2),              -- 保额
    coverage_details JSONB DEFAULT '{}',        -- 详细保障内容
    
    -- 关联车险（如果有）
    linked_car_policy_id UUID REFERENCES car_policies(id),
    
    -- 状态
    status TEXT DEFAULT 'active'
        CHECK(status IN ('active','expired','cancelled','pending')),
    renewal_status TEXT DEFAULT '未到期'
        CHECK(renewal_status IN ('未到期','待跟进','已报价','已成交','已流失')),
    
    -- 理赔
    claim_count INTEGER DEFAULT 0,
    claim_amount NUMERIC(12,2) DEFAULT 0,
    
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
    deleted_by UUID,
    operate_ip INET,
    
    UNIQUE(policy_no)
);

CREATE INDEX IF NOT EXISTS idx_noncar_cust ON noncar_policies(customer_id);
CREATE INDEX IF NOT EXISTS idx_noncar_type ON noncar_policies(insurance_type);
CREATE INDEX IF NOT EXISTS idx_noncar_end_date ON noncar_policies(end_date);
CREATE INDEX IF NOT EXISTS idx_noncar_sign_date ON noncar_policies(sign_date);
CREATE INDEX IF NOT EXISTS idx_noncar_renewal ON noncar_policies(renewal_status);

-- ============================================================
-- 5. 年审保养记录表 (vehicle_services)
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicle_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    plate TEXT,                                 -- 车牌（快照）
    
    service_type TEXT NOT NULL,
    /*
    类型包括：
    - annual_review: 年审
    - inspection: 检测（上线检测/安全检测）
    - maintenance: 保养（小保/大保/换油/轮胎等）
    - repair: 维修
    - beauty: 美容（洗车/打蜡/镀晶/贴膜）
    - modification: 改装
    - insurance_claim: 出险维修
    */
    
    -- 服务详情
    service_name TEXT NOT NULL,                 -- 服务名称
    description TEXT,                           -- 描述
    mileage NUMERIC(10,0),                      -- 当时里程
    cost NUMERIC(12,2),                         -- 成本
    price NUMERIC(12,2),                        -- 收费
    profit NUMERIC(12,2),                       -- 利润
    
    -- 服务商
    provider_name TEXT,                         -- 服务商名称
    provider_phone TEXT,                        -- 服务商电话
    provider_address TEXT,                       -- 服务商地址
    
    -- 推荐费（如果服务商给返佣）
    referral_fee NUMERIC(12,2) DEFAULT 0,       -- 推荐费
    referral_status TEXT DEFAULT '未结算'
        CHECK(referral_status IN ('未结算','已结算')),
    
    -- 日期
    service_date DATE NOT NULL,
    next_service_date DATE,                     -- 下次服务日期
    next_service_mileage NUMERIC(10,0),        -- 下次服务里程
    
    -- 提醒设置
    need_remind BOOLEAN DEFAULT TRUE,
    remind_days INTEGER DEFAULT 30,             -- 提前多少天提醒
    
    -- 状态
    status TEXT DEFAULT 'completed'
        CHECK(status IN ('scheduled','in_progress','completed','cancelled')),
    
    -- 评价
    rating INTEGER CHECK(rating BETWEEN 1 AND 5),
    review TEXT,
    review_date TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    operate_ip INET
);

CREATE INDEX IF NOT EXISTS idx_svc_cust ON vehicle_services(customer_id);
CREATE INDEX IF NOT EXISTS idx_svc_vehicle ON vehicle_services(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_svc_type ON vehicle_services(service_type);
CREATE INDEX IF NOT EXISTS idx_svc_date ON vehicle_services(service_date);
CREATE INDEX IF NOT EXISTS idx_svc_next_date ON vehicle_services(next_service_date);
CREATE INDEX IF NOT EXISTS idx_svc_annual_review ON vehicle_services(service_type, next_service_date) 
    WHERE service_type = 'annual_review' AND is_deleted = FALSE;

-- ============================================================
-- 6. 后市场订单表 (after_market_orders)
-- ============================================================
CREATE TABLE IF NOT EXISTS after_market_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    plate TEXT,
    
    -- 订单类型
    order_type TEXT NOT NULL,
    /*
    - traffic_violation: 违章处理
    - roadside_rescue: 道路救援
    - beauty: 美容服务
    - modification: 改装服务
    - parts: 配件销售
    - rental: 租车服务
    - parking: 停车服务
    - charging: 充电服务
    - fuel: 加油服务
    - other: 其他
    */
    
    -- 订单信息
    order_no TEXT UNIQUE,
    title TEXT NOT NULL,                        -- 订单标题
    description TEXT,
    
    -- 金额
    amount NUMERIC(12,2) NOT NULL,              -- 订单金额
    cost NUMERIC(12,2),                         -- 成本
    profit NUMERIC(12,2),                       -- 利润
    
    -- 第三方服务（如违章）
    third_party TEXT,                           -- 第三方平台
    third_party_fee NUMERIC(12,2),              -- 第三方手续费
    official_fee NUMERIC(12,2),                 -- 官方费用（罚款等）
    handling_fee NUMERIC(12,2),                 -- 代办手续费
    
    -- 服务商
    provider_name TEXT,
    provider_phone TEXT,
    
    -- 支付
    payment_status TEXT DEFAULT 'unpaid'
        CHECK(payment_status IN ('unpaid','paid','refunded','cancelled')),
    payment_method TEXT
        CHECK(payment_method IN ('微信','支付宝','银行转账','现金','其他')),
    payment_date DATE,
    
    -- 日期
    order_date DATE NOT NULL,
    service_date DATE,
    complete_date DATE,
    
    -- 状态
    status TEXT DEFAULT 'pending'
        CHECK(status IN ('pending','processing','completed','cancelled','refunded')),
    
    -- 评价
    rating INTEGER CHECK(rating BETWEEN 1 AND 5),
    review TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    operate_ip INET
);

CREATE INDEX IF NOT EXISTS idx_am_cust ON after_market_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_am_type ON after_market_orders(order_type);
CREATE INDEX IF NOT EXISTS idx_am_status ON after_market_orders(status);
CREATE INDEX IF NOT EXISTS idx_am_date ON after_market_orders(order_date);

-- ============================================================
-- 7. 汽车消费金融表 (finance_contracts)
-- ============================================================
CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- 合同信息
    contract_no TEXT UNIQUE,
    contract_type TEXT NOT NULL,
    /*
    - car_loan: 车贷（银行贷款/汽车金融）
    - installment: 分期付款
    - lease: 融资租赁
    - guarantee: 担保服务
    */
    
    -- 关联金融机构
    institution_name TEXT,                       -- 金融机构名称
    institution_type TEXT                       -- 银行/汽车金融/小贷/其他
    
    -- 贷款信息
    loan_amount NUMERIC(14,2) NOT NULL,         -- 贷款金额
    loan_term INTEGER,                          -- 贷款期数（月）
    interest_rate NUMERIC(8,4),                 -- 年利率
    monthly_payment NUMERIC(12,2),              -- 月供
    total_interest NUMERIC(12,2),              -- 总利息
    total_repayment NUMERIC(14,2),             -- 总还款
    
    -- 已还情况
    repaid_term INTEGER DEFAULT 0,              -- 已还期数
    repaid_amount NUMERIC(14,2) DEFAULT 0,      -- 已还本金
    repaid_interest NUMERIC(12,2) DEFAULT 0,  -- 已还利息
    remaining_amount NUMERIC(14,2),             -- 剩余本金
    remaining_term INTEGER,                      -- 剩余期数
    
    -- 费用
    handling_fee NUMERIC(12,2) DEFAULT 0,       -- 手续费
    guarantee_fee NUMERIC(12,2) DEFAULT 0,     -- 担保费
    insurance_premium NUMERIC(12,2) DEFAULT 0, -- 担保保险费
    
    -- 担保信息（如果蟹老板做担保）
    is_guarantee BOOLEAN DEFAULT FALSE,         -- 是否蟹老板担保
    guarantee_fee_rate NUMERIC(5,4),            -- 担保费率
    guarantee_fee_received NUMERIC(12,2) DEFAULT 0, -- 已收担保费
    guarantee_risk_level TEXT DEFAULT '正常'
        CHECK(guarantee_risk_level IN ('正常','关注','可疑','损失')),
    
    -- 日期
    sign_date DATE NOT NULL,
    start_date DATE,
    end_date DATE,
    complete_date DATE,                         -- 结清日期
    
    -- 还款
    repayment_method TEXT
        CHECK(repayment_method IN ('等额本息','等额本金','先息后本','等比递增','其他')),
    repayment_account TEXT,                     -- 还款账户
    repayment_day INTEGER DEFAULT 15,            -- 每月还款日
    first_repayment_date DATE,
    overdue_count INTEGER DEFAULT 0,            -- 逾期次数
    overdue_days INTEGER DEFAULT 0,              -- 累计逾期天数
    max_overdue_days INTEGER DEFAULT 0,         -- 最长逾期天数
    
    -- 状态
    status TEXT DEFAULT 'ongoing'
        CHECK(status IN ('pending','ongoing','overdue','completed','cancelled','default')),
    
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
    deleted_by UUID,
    operate_ip INET
);

CREATE INDEX IF NOT EXISTS idx_fin_cust ON finance_contracts(customer_id);
CREATE INDEX IF NOT EXISTS idx_fin_vehicle ON finance_contracts(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_fin_status ON finance_contracts(status);
CREATE INDEX IF NOT EXISTS idx_fin_type ON finance_contracts(contract_type);
CREATE INDEX IF NOT EXISTS idx_fin_sign_date ON finance_contracts(sign_date);

-- ============================================================
-- 8. 还款记录表 (repayment_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES finance_contracts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- 期数信息
    term_no INTEGER NOT NULL,                    -- 期数
    due_date DATE NOT NULL,                     -- 应还日期
    due_principal NUMERIC(12,2) NOT NULL,      -- 应还本金
    due_interest NUMERIC(12,2) NOT NULL,       -- 应还利息
    due_amount NUMERIC(12,2) NOT NULL,         -- 应还总额
    due_penalty NUMERIC(12,2) DEFAULT 0,       -- 应付罚息
    
    -- 实际还款
    actual_date DATE,                           -- 实还日期
    actual_principal NUMERIC(12,2),            -- 实还本金
    actual_interest NUMERIC(12,2),             -- 实还利息
    actual_amount NUMERIC(12,2),               -- 实还总额
    actual_penalty NUMERIC(12,2) DEFAULT 0,    -- 实还罚息
    is_on_time BOOLEAN,                        -- 是否按时
    overdue_days INTEGER DEFAULT 0,             -- 逾期天数
    
    -- 状态
    status TEXT DEFAULT 'pending'
        CHECK(status IN ('pending','paid','overdue','waived')),
    
    -- 还款方式
    payment_method TEXT,
    
    -- 备注
    remark TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    operate_ip INET
);

CREATE INDEX IF NOT EXISTS idx_rep_contract ON repayment_records(contract_id);
CREATE INDEX IF NOT EXISTS idx_rep_due_date ON repayment_records(due_date);
CREATE INDEX IF NOT EXISTS idx_rep_status ON repayment_records(status);

-- ============================================================
-- 9. 审计日志表 (audit_logs)
-- 全量记录所有数据的增删改操作
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 操作类型
    action TEXT NOT NULL CHECK(action IN ('INSERT','UPDATE','DELETE','SELECT','EXPORT','LOGIN','LOGOUT')),
    table_name TEXT NOT NULL,
    record_id UUID,
    
    -- 操作者
    operator_id UUID,
    operator_name TEXT,
    operator_ip INET,
    user_agent TEXT,
    
    -- 变更内容
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],                     -- 变更的字段名数组
    
    -- 上下文
    session_id TEXT,
    request_id TEXT,
    app_module TEXT,                           -- 操作来自哪个模块
    remark TEXT,
    
    -- 时间
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_logs(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_operator ON audit_logs(operator_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_module ON audit_logs(app_module);

-- ============================================================
-- 10. 跟进记录表 (followups)
-- ============================================================
CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    related_type TEXT,
    /* 
    - car_policy: 车险
    - noncar_policy: 非车险
    - vehicle_service: 年审保养
    - after_market: 后市场
    - finance: 消费金融
    - general: 综合跟进
    */
    related_id UUID,
    
    -- 跟进信息
    followup_type TEXT NOT NULL,
    /*
    - 报价: 发送报价
    - 跟进: 日常跟进
    - 成交: 签单成交
    - 流失: 客户流失
    - 投诉: 客户投诉
    - 回访: 服务回访
    - 提醒: 系统提醒
    - 其他: 其他
    */
    content TEXT NOT NULL,
    
    -- 跟进结果
    result TEXT,
    next_followup_date DATE,
    next_followup_content TEXT,
    
    -- 渠道
    channel TEXT DEFAULT '系统'
        CHECK(channel IN ('系统','电话','微信','短信','面谈','其他')),
    
    -- 状态
    status TEXT DEFAULT 'completed'
        CHECK(status IN ('scheduled','completed','cancelled')),
    
    -- 附件
    attachments JSONB DEFAULT '[]',
    /* 
    [{type: 'image', url: '...'}, {type: 'file', url: '...', name: 'xxx.pdf'}]
    */
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    created_name TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    operate_ip INET
);

CREATE INDEX IF NOT EXISTS idx_fu_cust ON followups(customer_id);
CREATE INDEX IF NOT EXISTS idx_fu_type ON followups(followup_type);
CREATE INDEX IF NOT EXISTS idx_fu_date ON followups(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fu_next ON followups(next_followup_date) WHERE status = 'scheduled';

-- ============================================================
-- 11. 提醒任务表 (reminders)
-- ============================================================
CREATE TABLE IF NOT EXISTS reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    related_type TEXT,
    related_id UUID,
    
    -- 提醒内容
    title TEXT NOT NULL,
    content TEXT,
    reminder_type TEXT NOT NULL,
    /*
    - renewal: 续保提醒
    - annual_review: 年审提醒
    - maintenance: 保养到期
    - payment: 还款提醒
    - followup: 跟进提醒
    - birthday: 生日提醒
    - custom: 自定义
    */
    
    -- 提醒时间
    remind_at TIMESTAMPTZ NOT NULL,
    remind_days_before INTEGER,                -- 提前多少天
    
    -- 关联车辆
    plate TEXT,
    vehicle_id UUID,
    
    -- 状态
    status TEXT DEFAULT 'pending'
        CHECK(status IN ('pending','sent','completed','cancelled')),
    sent_at TIMESTAMPTZ,
    sent_result TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    operate_ip INET
);

CREATE INDEX IF NOT EXISTS idx_rem_cust ON reminders(customer_id);
CREATE INDEX IF NOT EXISTS idx_rem_type ON reminders(reminder_type);
CREATE INDEX IF NOT EXISTS idx_rem_time ON reminders(remind_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_rem_plate ON reminders(plate) WHERE plate IS NOT NULL;

-- ============================================================
-- 12. 字典表/配置表 (sys_config)
-- ============================================================
CREATE TABLE IF NOT EXISTS sys_config (
    id TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- 初始配置数据
INSERT INTO sys_config (id, category, value, description) VALUES
('insurance_companies', '车险', 
 '{"options": [{"code": "人保", "name": "中国人保"}, {"code": "平安", "name": "平安保险"}, {"code": "太平洋", "name": "太平洋保险"}, {"code": "国寿", "name": "中国人寿"}, {"code": "中华联合", "name": "中华联合保险"}, {"code": "阳光", "name": "阳光保险"}, {"code": "大地", "name": "大地保险"}, {"code": "太平", "name": "太平保险"}], "remark": "支持的保险公司列表"}', 
 '车险公司列表'),
('noncar_types', '非车险',
 '{"options": [{"code": "驾乘意外", "name": "驾乘意外险"}, {"code": "人身意外", "name": "人身意外险"}, {"code": "医疗险", "name": "医疗保险"}, {"code": "重疾险", "name": "重疾险"}, {"code": "家财险", "name": "家庭财产险"}, {"code": "雇主责任", "name": "雇主责任险"}, {"code": "公众责任", "name": "公众责任险"}, {"code": "信用保证", "name": "信用保证险"}, {"code": "财产险", "name": "财产险"}, {"code": "其他", "name": "其他险种"}], "remark": "非车险类型"}',
 '非车险类型'),
('service_types', '服务',
 '{"options": [{"code": "annual_review", "name": "年审"}, {"code": "inspection", "name": "检测"}, {"code": "maintenance", "name": "保养"}, {"code": "repair", "name": "维修"}, {"code": "beauty", "name": "美容"}, {"code": "modification", "name": "改装"}], "remark": "年审保养服务类型"}',
 '服务类型'),
('customer_levels', '客户',
 '{"options": [{"code": "A级", "name": "高净值客户", "color": "#10b981"}, {"code": "B级", "name": "稳定客户", "color": "#3b82f6"}, {"code": "C级", "name": "普通客户", "color": "#f59e0b"}, {"code": "D级", "name": "流失风险", "color": "#ef4444"}], "remark": "客户分级标准"}',
 '客户分级配置'),
('reminder_templates', '提醒',
 '{"templates": [{"type": "renewal", "title": "续保提醒", "content": "您的车辆 {plate} 保险将于 {end_date} 到期，请及时续保。"}, {"type": "annual_review", "title": "年审提醒", "content": "您的车辆 {plate} 年审将于 {annual_review_date} 到期，请及时办理。"}, {"type": "maintenance", "title": "保养提醒", "content": "您的车辆 {plate} 保养已超过 {mileage} 公里，请及时保养。"}], "remark": "提醒模板"}',
 '提醒模板配置')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 13. 附件表 (attachments)
-- 统一管理所有上传的附件
-- ============================================================
CREATE TABLE IF NOT EXISTS attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    file_type TEXT,
    mime_type TEXT,
    
    -- 关联信息
    ref_type TEXT NOT NULL,
    ref_id UUID NOT NULL,
    
    -- 上传信息
    uploaded_by UUID,
    uploaded_by_name TEXT,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 元数据
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    storage_type TEXT DEFAULT 'supabase'
        CHECK(storage_type IN ('supabase', 'local', 'github', 'email'))
);

CREATE INDEX IF NOT EXISTS idx_att_ref ON attachments(ref_type, ref_id);

-- ============================================================
-- 触发器：自动更新 updated_at 和版本号
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = COALESCE(OLD.version, 0) + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有业务表创建触发器
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_policies_updated_at BEFORE UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_noncar_policies_updated_at BEFORE UPDATE ON noncar_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicle_services_updated_at BEFORE UPDATE ON vehicle_services
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_after_market_orders_updated_at BEFORE UPDATE ON after_market_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_finance_contracts_updated_at BEFORE UPDATE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_followups_updated_at BEFORE UPDATE ON followups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 触发器：软删除
-- ============================================================
CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_deleted = TRUE;
    NEW.deleted_at = NOW();
    NEW.deleted_by = COALESCE(NEW.deleted_by, auth.uid());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- RLS 策略（行级安全）
-- ============================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_market_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sys_config ENABLE ROW LEVEL SECURITY;

-- 所有人可以查看自己创建的数据（基于 owner_id 或 created_by）
-- 对于超级管理员可以查看所有数据
CREATE POLICY "Users can view own records" ON customers
    FOR SELECT USING (owner_id = auth.uid() OR created_by = auth.uid());

CREATE POLICY "Users can update own records" ON customers
    FOR UPDATE USING (owner_id = auth.uid() OR created_by = auth.uid());

-- 更多RLS策略根据需要添加...

-- ============================================================
-- 完成
-- ============================================================
