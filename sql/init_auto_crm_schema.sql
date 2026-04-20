-- =============================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本：V1.0 | 日期：2026-04-19
-- 数据库：PostgreSQL 15+ (Supabase托管)
-- =============================================================

-- =============================================================
-- 第一部分：核心基础设施表（必须先创建）
-- =============================================================

-- 1. 组织架构表（支持多业务员）
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    short_name TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    address TEXT,
    logo_url TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);

-- 2. 用户表（业务员/管理员）
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    real_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'agent',  -- admin/super_admin/agent
    status TEXT DEFAULT 'active',
    last_login_at TIMESTAMPTZ,
    last_login_ip TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 3. 客户主表（核心，统一ID）
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_no TEXT UNIQUE NOT NULL,  -- 客户编号，格式：CUST-YYYYMMDD-XXXX
    real_name TEXT NOT NULL,
    id_card TEXT,
    id_card_hash TEXT,  -- 脱敏用，仅存储hash
    phone TEXT NOT NULL,
    phone_secondary TEXT,  -- 备用电话
    wechat TEXT,
    wechat_nickname TEXT,
    qq TEXT,
    email TEXT,
    gender TEXT,  -- 男/女
    birth_date DATE,
    birthday_reminder BOOLEAN DEFAULT TRUE,
    address_home TEXT,
    address_work TEXT,
    occupation TEXT,  -- 职业
    annual_income_range TEXT,  -- 年收入区间
    marital_status TEXT,  -- 未婚/已婚/离异/丧偶
    family_members_count INTEGER,  -- 家庭成员数
    risk_level TEXT DEFAULT 'normal',  -- normal/caution/high
    customer_source TEXT,  -- customer_self/walk_in/referral/online/agent_referral
    source_agent_id UUID REFERENCES users(id),  -- 来源业务员
    vip_level TEXT DEFAULT 'normal',  -- normal/silver/gold/diamond
    tags TEXT[],  -- 标签数组
    photo_url TEXT,
    id_card_front_url TEXT,
    id_card_back_url TEXT,
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 4. 车辆主表（一个客户可有多辆车）
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_no TEXT UNIQUE NOT NULL,  -- 车辆编号
    plate TEXT NOT NULL,  -- 车牌号
    plate_province TEXT,  -- 省份
    plate_city TEXT,  -- 城市
    vin TEXT NOT NULL,  -- 车架号
    engine_no TEXT,  -- 发动机号
    brand TEXT NOT NULL,  -- 品牌（大众/丰田/宝马等）
    series TEXT,  -- 车系（朗逸/卡罗拉/3系等）
    car_model TEXT,  -- 具体车型（2022款 1.5L 自动舒适版）
    vehicle_type TEXT,  -- 轿车/SUV/MPV/皮卡/面包车
    use_type TEXT DEFAULT 'family',  -- family/private/commercial/rental
    fuel_type TEXT,  -- 汽油/柴油/纯电/混动/增程
    displacement TEXT,  -- 排量
    transmission TEXT,  -- 手动/自动/CVT/DCT
    color TEXT,  -- 车身颜色
    purchase_date DATE,  -- 购车日期
    purchase_price NUMERIC,  -- 购车价格
    current_value NUMERIC,  -- 当前估值
    annual_mileage INTEGER,  -- 年行驶里程(公里)
    has_remote_start BOOLEAN DEFAULT FALSE,
    has_auto_park BOOLEAN DEFAULT FALSE,
    insurance_company TEXT,  -- 投保公司偏好
    maintenance_shop TEXT,  -- 保养地点偏好
    inspection_due_date DATE,  -- 年检到期日期
    inspection_status TEXT DEFAULT 'valid',  -- valid/pending/expired
    emission_standard TEXT,  -- 排放标准（国六/国六B等）
    energy_type TEXT,  -- 能源类型（纯电动/插电混动/增程式等）
    battery_capacity NUMERIC,  -- 电池容量(kWh)
    battery_brand TEXT,  -- 电池品牌
    warranty_expire_date DATE,  -- 质保到期
    plate_front_url TEXT,
    plate_back_url TEXT,
    vehicle_photo_url TEXT,
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 5. 审计日志表（核心可追溯性）
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL,  -- INSERT/UPDATE/DELETE
    operation_type TEXT,  -- business operation type
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    ip_address TEXT,
    user_agent TEXT,
    user_id UUID,
    user_name TEXT,
    organization_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_table_record ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit_logs(created_at DESC);

-- =============================================================
-- 第二部分：模块1 - 车险管理
-- =============================================================

-- 6. 车险保单表
CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_no TEXT UNIQUE NOT NULL,  -- 保单号
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    insurance_company TEXT NOT NULL,  -- 承保公司
    company_code TEXT,  -- 保险公司代码
    
    -- 保费明细
    biz_premium NUMERIC NOT NULL DEFAULT 0,  -- 商业险保费
    biz_coverage_amount NUMERIC,  -- 商业险保额
    force_premium NUMERIC NOT NULL DEFAULT 0,  -- 交强险保费
    tax_premium NUMERIC NOT NULL DEFAULT 0,  -- 车船税
    total_premium NUMERIC NOT NULL,  -- 总保费
    discount_rate NUMERIC,  -- 折扣率
    discount_amount NUMERIC,  -- 优惠金额
    
    -- 佣金
    commission_rate NUMERIC,  -- 佣金比例
    commission_amount NUMERIC,  -- 佣金金额
    net_commission NUMERIC,  -- 净佣金（扣除税后）
    
    -- 险种明细（JSON存储复杂结构）
    coverage_details JSONB,  -- 险种配置：{"三者200万": true, "车损": true, "司机险50万": false...}
    third_party_amount NUMERIC,  -- 三者险额度
    driver_insurance_amount NUMERIC,  -- 司机险额度
    passenger_insurance_amount NUMERIC,  -- 乘客险额度
    
    -- 日期
    sign_date DATE NOT NULL,  -- 签单日期
    start_date DATE NOT NULL,  -- 生效日期
    end_date DATE NOT NULL,  -- 到期日期
    grace_period_days INTEGER DEFAULT 15,  -- 宽限期天数
    
    -- 状态
    status TEXT DEFAULT 'active',  -- active/pending/cancelled/expired/renewed
    payment_status TEXT DEFAULT 'unpaid',  -- unpaid/paid/part_paid
    payment_method TEXT,  -- wechat/alipay/bank_transfer/cash
    payment_time TIMESTAMPTZ,
    
    -- 来源
    source_channel TEXT,  -- 线下/线上/电销/转介绍
    source_remark TEXT,
    referring_customer_id UUID REFERENCES customers(id),  -- 转介绍客户
    
    -- 关联
    previous_policy_id UUID REFERENCES car_policies(id),  -- 上一期保单
    renewed_policy_id UUID REFERENCES car_policies(id),  -- 续保保单
    
    -- 业务员
    agent_id UUID REFERENCES users(id),
    agent_name TEXT,
    
    -- 附件
    policy_pdf_url TEXT,
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_car_policy_customer ON car_policies(customer_id);
CREATE INDEX IF NOT EXISTS idx_car_policy_vehicle ON car_policies(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_car_policy_end_date ON car_policies(end_date);
CREATE INDEX IF NOT EXISTS idx_car_policy_status ON car_policies(status);
CREATE INDEX IF NOT EXISTS idx_car_policy_agent ON car_policies(agent_id);
CREATE INDEX IF NOT EXISTS idx_car_policy_company ON car_policies(insurance_company);

-- 7. 车险理赔记录表
CREATE TABLE IF NOT EXISTS car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_no TEXT UNIQUE NOT NULL,  -- 理赔案号
    policy_id UUID REFERENCES car_policies(id),
    customer_id UUID REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 理赔信息
    claim_type TEXT NOT NULL,  -- collision/glass/water/fire/theft/natural/triple/other
    claim_type_desc TEXT,  -- 理赔类型描述
    accident_date DATE NOT NULL,  -- 出险日期
    accident_location TEXT,  -- 出险地点
    accident_description TEXT,  -- 出险经过
    claim_amount NUMERIC NOT NULL,  -- 报案金额
    assessed_amount NUMERIC,  -- 定损金额
    paid_amount NUMERIC,  -- 实付金额
    deductible NUMERIC,  -- 免赔额
    
    -- 时间节点
    report_date TIMESTAMPTZ,  -- 报案时间
    survey_date TIMESTAMPTZ,  -- 查勘时间
    assess_date TIMESTAMPTZ,  -- 定损时间
    settlement_date TIMESTAMPTZ,  -- 结案时间
    payment_date TIMESTAMPTZ,  -- 支付时间
    
    -- 状态
    status TEXT DEFAULT 'reported',  -- reported/surveying/assessing/negotiating/settled/rejected
    settlement_type TEXT,  -- 协议理赔/快速理赔
    
    -- 涉及方
    third_party_name TEXT,  -- 第三方姓名
    third_party_plate TEXT,  -- 第三方车牌
    third_party_phone TEXT,  -- 第三方电话
    third_party_insurance_company TEXT,  -- 第三方保险公司
    
    -- 修理信息
    repair_shop TEXT,  -- 修理厂
    repair_shop_contact TEXT,  -- 修理厂联系方式
    repair_start_date DATE,  -- 维修开始日期
    repair_end_date DATE,  -- 维修结束日期
    repair_cost NUMERIC,  -- 维修费用
    repair_invoice_url TEXT,  -- 维修发票
    claim_invoice_url TEXT,  -- 理赔发票
    
    -- 附件
    accident_photo_urls TEXT[],  -- 出险照片URL数组
    survey_report_url TEXT,  -- 查勘报告URL
    
    -- 业务员
    handler_id UUID REFERENCES users(id),
    handler_name TEXT,
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_car_claim_policy ON car_claims(policy_id);
CREATE INDEX IF NOT EXISTS idx_car_claim_customer ON car_claims(customer_id);
CREATE INDEX IF NOT EXISTS idx_car_claim_status ON car_claims(status);
CREATE INDEX IF NOT EXISTS idx_car_claim_accident_date ON car_claims(accident_date);

-- 8. 续保跟进记录表
CREATE TABLE IF NOT EXISTS car_renewal_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID REFERENCES car_policies(id),
    customer_id UUID REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 到期信息
    due_date DATE NOT NULL,  -- 到期日期
    days_before_due INTEGER,  -- 距离到期天数
    
    -- 跟进状态
    status TEXT DEFAULT 'pending',  -- pending/contacted/quoted/renewed/not_renewed
    priority TEXT DEFAULT 'normal',  -- low/normal/high/urgent
    
    -- 联系记录
    contact_date TIMESTAMPTZ,  -- 联系时间
    contact_method TEXT,  -- 电话/微信/短信/上门
    contact_result TEXT,  -- 接通/未接/拒绝/有意向
    customer_response TEXT,  -- 客户反馈
    next_followup_date DATE,  -- 下次跟进日期
    
    -- 报价信息
    quoted_amount NUMERIC,  -- 报价金额
    competitor_quoted_amount NUMERIC,  -- 竞品报价
    competitor_company TEXT,  -- 竞品公司
    price_difference NUMERIC,  -- 价格差
    
    -- 决策信息
    decision TEXT,  -- renewal_decided/not_renewed_decided/pending_decision
    decision_reason TEXT,  -- 决策原因
    decision_date DATE,  -- 决策日期
    
    -- 业务员
    agent_id UUID REFERENCES users(id),
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_car_renewal_policy ON car_renewal_followups(policy_id);
CREATE INDEX IF NOT EXISTS idx_car_renewal_due_date ON car_renewal_followups(due_date);
CREATE INDEX IF NOT EXISTS idx_car_renewal_status ON car_renewal_followups(status);
CREATE INDEX IF NOT EXISTS idx_car_renewal_agent ON car_renewal_followups(agent_id);

-- =============================================================
-- 第三部分：模块2 - 非车险管理
-- =============================================================

-- 9. 非车险保单表
CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_no TEXT UNIQUE NOT NULL,  -- 保单号
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    -- 险种分类
    insurance_category TEXT NOT NULL,  -- 意外险/健康险/家财险/责任险/信用险/货运险/其他
    insurance_type TEXT NOT NULL,  -- 具体险种：驾乘险/雇主责任险/团体意外险/家财险等
    
    -- 承保公司
    insurance_company TEXT NOT NULL,
    company_code TEXT,
    
    -- 保费与佣金
    premium NUMERIC NOT NULL,  -- 保费
    coverage_amount NUMERIC,  -- 保额
    commission_rate NUMERIC,  -- 佣金比例
    commission_amount NUMERIC,  -- 佣金金额
    
    -- 被保险人信息
    insured_name TEXT,
    insured_id_card TEXT,
    insured_phone TEXT,
    insured_relationship TEXT,  -- 与投保人关系
    
    -- 保险标的
    insured_object_type TEXT,  -- 标的类型：人/财产/责任/信用
    insured_object_desc TEXT,  -- 标的描述
    
    -- 日期
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 状态
    status TEXT DEFAULT 'active',
    payment_status TEXT DEFAULT 'unpaid',
    payment_time TIMESTAMPTZ,
    
    -- 关联车险
    related_car_policy_id UUID REFERENCES car_policies(id),  -- 关联的车险保单
    cross_sell BOOLEAN DEFAULT FALSE,  -- 是否交叉销售
    
    -- 来源
    source_channel TEXT,
    
    -- 业务员
    agent_id UUID REFERENCES users(id),
    agent_name TEXT,
    
    -- 附件
    policy_pdf_url TEXT,
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_noncar_policy_customer ON noncar_policies(customer_id);
CREATE INDEX IF NOT EXISTS idx_noncar_policy_category ON noncar_policies(insurance_category);
CREATE INDEX IF NOT EXISTS idx_noncar_policy_type ON noncar_policies(insurance_type);
CREATE INDEX IF NOT EXISTS idx_noncar_policy_end_date ON noncar_policies(end_date);
CREATE INDEX IF NOT EXISTS idx_noncar_policy_status ON noncar_policies(status);
CREATE INDEX IF NOT EXISTS idx_noncar_policy_agent ON noncar_policies(agent_id);

-- =============================================================
-- 第四部分：模块3 - 年审保养管理
-- =============================================================

-- 10. 年审记录表
CREATE TABLE IF NOT EXISTS vehicle_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID REFERENCES customers(id),
    inspection_no TEXT UNIQUE,  -- 年检标编号
    
    -- 年审信息
    inspection_type TEXT NOT NULL,  -- initial/annual/transfer/change/label_replace
    inspection_year INTEGER NOT NULL,  -- 年审年份
    inspection_month INTEGER,  -- 年审月份
    
    -- 日期
    apply_date DATE,  -- 申请日期
    inspection_date DATE,  -- 年检日期
    due_date DATE NOT NULL,  -- 到期日期
    valid_from DATE,  -- 有效期起
    valid_to DATE,  -- 有效期至
    
    -- 费用
    inspection_fee NUMERIC,  -- 年检费用
    service_fee NUMERIC,  -- 服务费
    total_fee NUMERIC,  -- 费用合计
    
    -- 结果
    result TEXT,  -- pass/fail/pending
    fail_reason TEXT,  -- 不合格原因
    
    -- 检验机构
    inspection_station TEXT,
    inspector_name TEXT,
    
    -- 处理方式
    handling_type TEXT,  -- self_handled/agent_assisted/agency_full
    handling_shop_id UUID,  -- 代办修理厂ID
    
    -- 附件
    certificate_front_url TEXT,  -- 年检标正面
    certificate_back_url TEXT,  -- 年检标背面
    emission_test_report_url TEXT,  -- 排放检测报告
    inspection_record_url TEXT,  -- 年检记录单
    
    -- 提醒设置
    reminder_30_days BOOLEAN DEFAULT TRUE,  -- 提前30天提醒
    reminder_15_days BOOLEAN DEFAULT TRUE,  -- 提前15天提醒
    reminder_7_days BOOLEAN DEFAULT TRUE,  -- 提前7天提醒
    
    -- 状态
    status TEXT DEFAULT 'pending',  -- pending/due/handling/completed/expired
    reminder_sent_count INTEGER DEFAULT 0,  -- 已发送提醒次数
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_inspection_vehicle ON vehicle_inspections(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_inspection_due_date ON vehicle_inspections(due_date);
CREATE INDEX IF NOT EXISTS idx_inspection_status ON vehicle_inspections(status);
CREATE INDEX IF NOT EXISTS idx_inspection_year ON vehicle_inspections(inspection_year);

-- 11. 保养记录表
CREATE TABLE IF NOT EXISTS vehicle_maintenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID REFERENCES customers(id),
    
    -- 保养信息
    maintenance_no TEXT UNIQUE NOT NULL,  -- 保养单号
    maintenance_type TEXT NOT NULL,  -- routine/repair/warranty/inspection/prepurchase
    
    -- 日期
    service_date DATE NOT NULL,
    next_service_date DATE,  -- 下次保养日期
    next_service_mileage INTEGER,  -- 下次保养里程
    
    -- 里程
    current_mileage INTEGER NOT NULL,  -- 当前里程
    
    -- 修理厂
    shop_id UUID,  -- 修理厂ID
    shop_name TEXT,
    shop_address TEXT,
    shop_phone TEXT,
    technician_name TEXT,  -- 技师姓名
    
    -- 保养项目
    maintenance_items JSONB,  -- 保养项目数组
    -- 示例：[{"item": "更换机油", "brand": "壳牌", "spec": "5W-40", "qty": 1, "price": 200},
    --        {"item": "更换机滤", "brand": "马勒", "spec": "OL123", "qty": 1, "price": 50}]
    
    -- 配件
    parts_used JSONB,  -- 使用的配件
    -- 示例：[{"part": "刹车片前", "brand": "博世", "spec": "D...", "qty": 2, "price": 150}]
    
    -- 费用
    labor_fee NUMERIC DEFAULT 0,  -- 工时费
    parts_fee NUMERIC DEFAULT 0,  -- 配件费
    total_fee NUMERIC NOT NULL,  -- 总费用
    discount_amount NUMERIC DEFAULT 0,  -- 优惠金额
    final_fee NUMERIC,  -- 实付金额
    
    -- 支付
    payment_method TEXT,  -- wechat/alipay/cash/bank_transfer
    payment_status TEXT DEFAULT 'unpaid',  -- unpaid/paid
    
    -- 状态
    quality_warranty_days INTEGER DEFAULT 30,  -- 质量保修天数
    quality_status TEXT DEFAULT 'normal',  -- normal/claiming/resolved
    
    -- 附件
    invoice_url TEXT,
    photo_urls TEXT[],
    
    -- 来源
    source TEXT,  -- walk_in/referral/insurance_claim/customer_call
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON vehicle_maintenance(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_date ON vehicle_maintenance(service_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_shop ON vehicle_maintenance(shop_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_type ON vehicle_maintenance(maintenance_type);

-- 12. 修理厂/服务商表
CREATE TABLE IF NOT EXISTS service_shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_no TEXT UNIQUE NOT NULL,  -- 商家编号
    
    -- 基本信息
    shop_name TEXT NOT NULL,
    shop_type TEXT NOT NULL,  -- 4s店/修理厂/养护店/改装店/美容店/钣金喷漆/年检站
    business_license_no TEXT,  -- 营业执照号
    legal_person TEXT,  -- 法人
    contact_person TEXT,
    contact_phone TEXT NOT NULL,
    contact_phone_secondary TEXT,
    
    -- 地址
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT NOT NULL,
    longitude NUMERIC,
    latitude NUMERIC,
    
    -- 评分
    rating NUMERIC DEFAULT 0,  -- 评分(1-5)
    rating_count INTEGER DEFAULT 0,  -- 评分次数
    
    -- 营业信息
    business_hours TEXT,  -- 营业时间
    has_pickup_service BOOLEAN DEFAULT FALSE,  -- 是否提供取送车服务
    has_waiting_area BOOLEAN DEFAULT FALSE,  -- 是否有休息区
    has_car_wash BOOLEAN DEFAULT FALSE,  -- 是否有洗车服务
    
    -- 资质
    has_maintenance_qualification BOOLEAN DEFAULT FALSE,  -- 维修资质
    has_insurance_qualification BOOLEAN DEFAULT FALSE,  -- 保险资质
    quality_certifications TEXT[],  -- 质量认证
    insurance_brand_authorizations TEXT[],  -- 授权品牌
    
    -- 合作信息
    is_partner BOOLEAN DEFAULT FALSE,  -- 是否合作伙伴
    commission_rate NUMERIC,  -- 佣金比例
    cooperation_start_date DATE,
    settlement_type TEXT,  -- 月结/次结/实时
    
    -- 附件
    license_photo_url TEXT,
    shop_photo_urls TEXT[],
    
    -- 状态
    status TEXT DEFAULT 'active',  -- active/inactive/blacklist
    priority_level TEXT DEFAULT 'normal',  -- low/normal/high/preferred
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_shop_type ON service_shops(shop_type);
CREATE INDEX IF NOT EXISTS idx_shop_city ON service_shops(city, district);
CREATE INDEX IF NOT EXISTS idx_shop_status ON service_shops(status);
CREATE INDEX IF NOT EXISTS idx_shop_partner ON service_shops(is_partner);

-- =============================================================
-- 第五部分：模块4 - 汽车后市场服务
-- =============================================================

-- 13. 后市场服务订单表
CREATE TABLE IF NOT EXISTS aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_no TEXT UNIQUE NOT NULL,  -- 订单号
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 订单类型
    order_type TEXT NOT NULL,  -- violation/query/towing/beauty/modify/parts/accessory/other
    order_type_name TEXT,  -- 类型名称：违章查询/道路救援/美容装潢/改装升级/配件销售/其他
    
    -- 服务信息
    service_item TEXT NOT NULL,  -- 具体服务项目
    service_provider_id UUID REFERENCES service_shops(id),  -- 服务商
    service_provider_name TEXT,
    
    -- 金额
    original_price NUMERIC,  -- 原价
    discounted_price NUMERIC,  -- 折后价
    service_fee NUMERIC DEFAULT 0,  -- 服务费
    platform_fee NUMERIC DEFAULT 0,  -- 平台费
    total_amount NUMERIC NOT NULL,  -- 总金额
    
    -- 支付
    payment_status TEXT DEFAULT 'unpaid',  -- unpaid/paid/refunded/part_refunded
    payment_method TEXT,
    payment_time TIMESTAMPTZ,
    refund_amount NUMERIC DEFAULT 0,  -- 退款金额
    refund_time TIMESTAMPTZ,
    refund_reason TEXT,
    
    -- 状态
    status TEXT DEFAULT 'pending',  -- pending/confirmed/processing/completed/cancelled/refunded
    status_updated_at TIMESTAMPTZ,
    
    -- 违章查询专用
    violation_count INTEGER,  -- 违章数量
    violation_penalty_amount NUMERIC,  -- 罚款金额
    violation_points INTEGER,  -- 扣分
    violation_processed BOOLEAN DEFAULT FALSE,  -- 是否已处理
    
    -- 道路救援专用
    rescue_location TEXT,  -- 救援地点
    rescue_destination TEXT,  -- 目的地
    rescue_reason TEXT,  -- 救援原因
    rescue_arrival_time TIMESTAMPTZ,  -- 到达时间
    rescue_complete_time TIMESTAMPTZ,  -- 完成时间
    rescue_distance NUMERIC,  -- 拖车距离(公里)
    
    -- 时间
    service_request_date TIMESTAMPTZ,  -- 申请时间
    service_schedule_date DATE,  -- 预约服务日期
    service_schedule_time TIME,  -- 预约服务时间
    service_complete_date TIMESTAMPTZ,  -- 完成时间
    
    -- 评价
    has_review BOOLEAN DEFAULT FALSE,
    review_rating INTEGER,  -- 评分1-5
    review_content TEXT,
    review_date TIMESTAMPTZ,
    
    -- 附件
    photos_before TEXT[],  -- 服务前照片
    photos_after TEXT[],  -- 服务后照片
    invoice_url TEXT,
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_aftermarket_order_customer ON aftermarket_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_aftermarket_order_vehicle ON aftermarket_orders(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_aftermarket_order_type ON aftermarket_orders(order_type);
CREATE INDEX IF NOT EXISTS idx_aftermarket_order_status ON aftermarket_orders(status);
CREATE INDEX IF NOT EXISTS idx_aftermarket_order_date ON aftermarket_orders(service_request_date);

-- 14. 配件/商品表
CREATE TABLE IF NOT EXISTS parts_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_no TEXT UNIQUE NOT NULL,  -- 商品编号
    
    -- 基本信息
    product_name TEXT NOT NULL,  -- 商品名称
    brand TEXT,  -- 品牌
    series TEXT,  -- 系列
    specification TEXT,  -- 规格
    model_code TEXT,  -- 型号代码
    
    -- 分类
    category TEXT NOT NULL,  -- 机油/滤芯/刹车片/雨刷/电池/轮胎/车衣/行车记录仪/脚垫/香水/其他
    sub_category TEXT,  -- 子分类
    
    -- 适用车型（兼容多个）
    applicable_brands TEXT[],  -- 适用品牌：["大众","丰田","宝马"]
    applicable_models TEXT[],  -- 适用车型：["朗逸","卡罗拉","3系"]
    applicable_years TEXT[],  -- 适用年份：["2020","2021","2022"]
    
    -- 库存
    stock_quantity INTEGER DEFAULT 0,  -- 库存数量
    reserved_quantity INTEGER DEFAULT 0,  -- 预留数量
    available_quantity INTEGER GENERATED ALWAYS AS (stock_quantity - reserved_quantity) STORED,
    min_stock_level INTEGER DEFAULT 0,  -- 最低库存
    low_stock_alert BOOLEAN DEFAULT FALSE,  -- 低库存预警
    
    -- 价格
    cost_price NUMERIC NOT NULL,  -- 成本价
    retail_price NUMERIC NOT NULL,  -- 零售价
    member_price NUMERIC,  -- 会员价
    vip_price NUMERIC,  -- VIP价
    wholesale_price NUMERIC,  -- 批发价
    
    -- 供应商
    supplier_id UUID,  -- 供应商ID
    supplier_name TEXT,
    
    -- 图片
    main_image_url TEXT,
    image_urls TEXT[],
    
    -- 状态
    status TEXT DEFAULT 'active',  -- active/out_of_stock/discontinued
    is_featured BOOLEAN DEFAULT FALSE,  -- 是否推荐
    is_new BOOLEAN DEFAULT FALSE,  -- 是否新品
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOolean DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_parts_category ON parts_products(category);
CREATE INDEX IF NOT EXISTS idx_parts_brand ON parts_products(brand);
CREATE INDEX IF NOT EXISTS idx_parts_status ON parts_products(status);
CREATE INDEX IF NOT EXISTS idx_parts_stock ON parts_products(stock_quantity);

-- =============================================================
-- 第六部分：模块5 - 汽车消费金融
-- =============================================================

-- 15. 车贷申请表
CREATE TABLE IF NOT EXISTS auto_loan_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_no TEXT UNIQUE NOT NULL,  -- 申请编号
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID,  -- 意向车型
    
    -- 贷款信息
    loan_type TEXT NOT NULL,  -- new_car_loan/used_car_loan/refinance/upgrade_loan
    loan_purpose TEXT,  -- 贷款用途描述
    
    -- 金额
    vehicle_price NUMERIC NOT NULL,  -- 车辆价格
    down_payment_amount NUMERIC NOT NULL,  -- 首付款
    down_payment_rate NUMERIC,  -- 首付比例
    loan_amount NUMERIC NOT NULL,  -- 贷款金额
    loan_term_months INTEGER NOT NULL,  -- 贷款期数（月）
    interest_rate_annual NUMERIC NOT NULL,  -- 年利率（%）
    interest_rate_monthly NUMERIC,  -- 月利率
    base_interest_rate NUMERIC,  -- 基准利率
    floating_rate NUMERIC,  -- 浮动利率
    total_interest NUMERIC,  -- 总利息
    total_payment NUMERIC,  -- 还款总额
    monthly_payment NUMERIC,  -- 月供
    first_payment_date DATE,  -- 首次还款日
    
    -- 贷款机构
    lender_type TEXT,  -- bank/financial_company/dealer_financing/other
    lender_name TEXT NOT NULL,  -- 贷款机构名称
    lender_branch TEXT,  -- 分支机构
    
    -- 共同借款人
    has_co_borrower BOOLEAN DEFAULT FALSE,
    co_borrower_name TEXT,
    co_borrower_phone TEXT,
    co_borrower_id_card TEXT,
    co_borrower_relationship TEXT,  -- 与申请人关系
    
    -- 担保方式
    guarantee_type TEXT,  --信用/抵押/质押/保证
    collateral_type TEXT,  -- 抵押物类型：车辆/房产/其他
    collateral_value NUMERIC,  -- 抵押物估值
    has_guarantor BOOLEAN DEFAULT FALSE,  -- 是否有担保人
    guarantor_name TEXT,
    guarantor_phone TEXT,
    guarantor_id_card TEXT,
    
    -- 保险要求
    required_insurance_types TEXT[],  -- 要求购买的险种
    insurance_company_requirement TEXT,  -- 指定保险公司
    
    -- 申请状态
    status TEXT DEFAULT 'pending',  -- pending/approved/rejected/contract_signed/loan_disbursed/rejected
    status_reason TEXT,  -- 状态原因
    
    -- 审批信息
    approval_date TIMESTAMPTZ,
    approver_name TEXT,
    approval_limit_amount NUMERIC,  -- 审批额度
    approval_interest_rate NUMERIC,  -- 审批利率
    approval_remarks TEXT,
    
    -- 日期
    application_date TIMESTAMPTZ DEFAULT NOW(),
    interview_date TIMESTAMPTZ,
    review_date TIMESTAMPTZ,
    approval_date TIMESTAMPTZ,
    contract_sign_date DATE,
    disbursement_date DATE,
    
    -- 附件
    id_card_front_url TEXT,
    id_card_back_url TEXT,
    income_proof_url TEXT,  -- 收入证明
    bank_statement_url TEXT,  -- 银行流水
    vehicle_photo_url TEXT,  -- 车辆照片
    contract_pdf_url TEXT,  -- 合同PDF
    
    -- 业务员
    agent_id UUID REFERENCES users(id),
    agent_name TEXT,
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_loan_application_customer ON auto_loan_applications(customer_id);
CREATE INDEX IF NOT EXISTS idx_loan_application_status ON auto_loan_applications(status);
CREATE INDEX IF NOT EXISTS idx_loan_application_date ON auto_loan_applications(application_date);
CREATE INDEX IF NOT EXISTS idx_loan_application_lender ON auto_loan_applications(lender_name);

-- 16. 车贷还款计划表
CREATE TABLE IF NOT EXISTS loan_repayment_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES auto_loan_applications(id),
    
    -- 期次信息
    installment_no INTEGER NOT NULL,  -- 期次号
    due_date DATE NOT NULL,  -- 应还日期
    
    -- 金额
    principal_amount NUMERIC NOT NULL,  -- 本金
    interest_amount NUMERIC NOT NULL,  -- 利息
    total_payment NUMERIC NOT NULL,  -- 应还总额
    remaining_principal NUMERIC,  -- 剩余本金
    
    -- 还款状态
    status TEXT DEFAULT 'pending',  -- pending/paid/overdue/partially_paid/waived
    actual_payment_date DATE,  -- 实际还款日
    actual_principal NUMERIC,  -- 实还本金
    actual_interest NUMERIC,  -- 实还利息
    actual_total NUMERIC,  -- 实还总额
    overdue_days INTEGER DEFAULT 0,  -- 逾期天数
    overdue_penalty NUMERIC DEFAULT 0,  -- 逾期罚息
    
    -- 扣款
    auto_deduct BOOLEAN DEFAULT FALSE,  -- 是否自动扣款
    autopay_bank_card TEXT,  -- 自动扣款卡号
    autopay_status TEXT,  -- pending/success/failed
    
    -- 通知
    reminder_sent BOOLEAN DEFAULT FALSE,  -- 还款提醒已发送
    reminder_date TIMESTAMPTZ,  -- 提醒发送时间
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_repayment_application ON loan_repayment_schedules(application_id);
CREATE INDEX IF NOT EXISTS idx_repayment_due_date ON loan_repayment_schedules(due_date);
CREATE INDEX IF NOT EXISTS idx_repayment_status ON loan_repayment_schedules(status);

-- =============================================================
-- 第七部分：营销与跟进管理
-- =============================================================

-- 17. 客户跟进记录表（统一）
CREATE TABLE IF NOT EXISTS customer_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    
    -- 跟进类型
    followup_type TEXT NOT NULL,  -- car_insurance_renewal/noncar_marketing/inspection_reminder/maintenance_reminder/loan_followup/general_service/complaint/thanks
    followup_category TEXT,  -- 子类别
    
    -- 跟进内容
    contact_method TEXT NOT NULL,  -- 电话/微信/短信/上门/邮件
    contact_date TIMESTAMPTZ NOT NULL,  -- 联系时间
    contact_duration_seconds INTEGER,  -- 通话时长（秒）
    
    -- 联系结果
    contact_result TEXT NOT NULL,  -- 成功联系/未接听/号码错误/拒接/空号
    customer_feedback TEXT,  -- 客户反馈内容
    customer_intent_level TEXT,  -- 意向程度：none/low/medium/high/confirmed
    next_action TEXT,  -- 下一步动作
    next_followup_date DATE,  -- 下次跟进日期
    
    -- 关联业务
    related_policy_id UUID,  -- 关联保单
    related_order_id UUID,  -- 关联订单
    related_claim_id UUID,  -- 关联理赔
    
    -- 统计
    call_count INTEGER DEFAULT 1,  -- 本次联系次数
    
    -- 业务员
    agent_id UUID REFERENCES users(id),
    agent_name TEXT,
    
    -- 附件
    recording_url TEXT,  -- 通话录音
    chat_screenshot_urls TEXT[],  -- 聊天截图
    photos TEXT[],
    
    -- 系统生成
    is_system_generated BOOLEAN DEFAULT FALSE,  -- 是否系统自动生成
    auto_followup_reason TEXT,  -- 自动跟进原因
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_followup_customer ON customer_followups(customer_id);
CREATE INDEX IF NOT EXISTS idx_followup_type ON customer_followups(followup_type);
CREATE INDEX IF NOT EXISTS idx_followup_date ON customer_followups(contact_date);
CREATE INDEX IF NOT EXISTS idx_followup_agent ON customer_followups(agent_id);
CREATE INDEX IF NOT EXISTS idx_followup_next_date ON customer_followups(next_followup_date);

-- 18. 营销活动表
CREATE TABLE IF NOT EXISTS marketing_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_no TEXT UNIQUE NOT NULL,  -- 活动编号
    campaign_name TEXT NOT NULL,  -- 活动名称
    
    -- 活动类型
    campaign_type TEXT NOT NULL,  -- renewal_discount/holiday_promotion/new_customer/seasonal_service/loan_promotion/insurance_package/other
    target_audience TEXT,  -- 目标受众：all/customers_expiring/customers_new/specific_group
    
    -- 时间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- 内容
    description TEXT,  -- 活动描述
    promotion_details JSONB,  -- 促销详情
    
    -- 优惠
    discount_type TEXT,  -- percentage/fixed_amount/gift/service_package
    discount_value NUMERIC,  -- 优惠值
    min_purchase_amount NUMERIC,  -- 最低消费
    max_discount_amount NUMERIC,  -- 最高优惠
    
    -- 目标
    target_customer_count INTEGER,  -- 目标客户数
    actual_customer_count INTEGER DEFAULT 0,  -- 实际参与数
    
    -- 统计
    total_sent INTEGER DEFAULT 0,  -- 发送数量
    total_views INTEGER DEFAULT 0,  -- 查看数量
    total_responses INTEGER DEFAULT 0,  -- 响应数量
    conversion_rate NUMERIC,  -- 转化率
    
    -- 创建人
    created_by UUID,
    
    status TEXT DEFAULT 'draft',  -- draft/active/paused/completed/cancelled
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 19. 短信/通知模板表
CREATE TABLE IF NOT EXISTS message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code TEXT UNIQUE NOT NULL,  -- 模板编码
    template_name TEXT NOT NULL,  -- 模板名称
    
    -- 模板类型
    template_type TEXT NOT NULL,  -- sms/wechat/template_message/email
    
    -- 适用场景
    applicable_scenarios TEXT[],  -- renewal_reminder/accident_notice/payment_reminder/service_complete/birthday/policy_expiry
    trigger_event TEXT,  -- 触发事件
    
    -- 内容
    template_content TEXT NOT NULL,  -- 模板内容（支持变量占位符）
    -- 示例：尊敬的{customer_name}，您的{plate}将于{due_date}到期，请及时续保！
    
    -- 变量说明
    variables JSONB,  -- 可用变量列表
    -- 示例：[{"name": "customer_name", "desc": "客户姓名"}, {"name": "plate", "desc": "车牌号"}]
    
    -- 状态
    is_active BOOLEAN DEFAULT TRUE,
    is_system BOOLEAN DEFAULT FALSE,  -- 系统模板，不可删除
    
    -- 统计
    total_sent INTEGER DEFAULT 0,  -- 总发送数
    total_delivered INTEGER DEFAULT 0,  -- 总送达数
    total_failed INTEGER DEFAULT 0,  -- 总失败数
    
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- =============================================================
-- 第八部分：数据统计与报表
-- =============================================================

-- 20. 日统计表（每日自动生成）
CREATE TABLE IF NOT EXISTS daily_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stat_date DATE NOT NULL,
    agent_id UUID REFERENCES users(id),
    
    -- 车险统计
    car_policy_new_count INTEGER DEFAULT 0,
    car_policy_new_premium NUMERIC DEFAULT 0,
    car_policy_renewal_count INTEGER DEFAULT 0,
    car_policy_renewal_premium NUMERIC DEFAULT 0,
    car_policy_cancelled_count INTEGER DEFAULT 0,
    car_claim_count INTEGER DEFAULT 0,
    car_claim_amount NUMERIC DEFAULT 0,
    car_commission_amount NUMERIC DEFAULT 0,
    
    -- 非车险统计
    noncar_policy_count INTEGER DEFAULT 0,
    noncar_premium NUMERIC DEFAULT 0,
    noncar_commission_amount NUMERIC DEFAULT 0,
    
    -- 后市场统计
    aftermarket_order_count INTEGER DEFAULT 0,
    aftermarket_order_amount NUMERIC DEFAULT 0,
    
    -- 保养统计
    maintenance_count INTEGER DEFAULT 0,
    maintenance_amount NUMERIC DEFAULT 0,
    
    -- 贷款统计
    loan_application_count INTEGER DEFAULT 0,
    loan_application_amount NUMERIC DEFAULT 0,
    loan_disbursed_count INTEGER DEFAULT 0,
    loan_disbursed_amount NUMERIC DEFAULT 0,
    
    -- 跟进统计
    followup_count INTEGER DEFAULT 0,
    successful_contact_count INTEGER DEFAULT 0,
    new_customer_count INTEGER DEFAULT 0,
    
    -- 转化统计
    renewal_lead_count INTEGER DEFAULT 0,
    renewal_success_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(stat_date, agent_id)
);

CREATE INDEX IF NOT EXISTS idx_daily_stat_date ON daily_statistics(stat_date);
CREATE INDEX IF NOT EXISTS idx_daily_stat_agent ON daily_statistics(agent_id);

-- =============================================================
-- 第九部分：系统配置表
-- =============================================================

-- 21. 保险公司字典表
CREATE TABLE IF NOT EXISTS insurance_companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_code TEXT UNIQUE NOT NULL,
    company_name TEXT NOT NULL,
    short_name TEXT,
    logo_url TEXT,
    website TEXT,
    service_phone TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- 22. 字典表（通用）
CREATE TABLE IF NOT EXISTS system_dict (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dict_type TEXT NOT NULL,  -- dict_type/dict_type2
    dict_value TEXT NOT NULL,
    dict_label TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    parent_value TEXT,  -- 父级值（用于树形结构）
    css_class TEXT,  -- 前端样式
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(dict_type, dict_value)
);

CREATE INDEX IF NOT EXISTS idx_dict_type ON system_dict(dict_type);

-- 预设字典类型
-- dict_type='vehicle_type': 车辆类型
-- dict_type='fuel_type': 能源类型
-- dict_type='use_type': 使用性质
-- dict_type='insurance_category': 险种类别
-- dict_type='coverage_type': 险种
-- dict_type='claim_type': 理赔类型
-- dict_type='order_type': 订单类型
-- dict_type='maintenance_type': 保养类型
-- dict_type='loan_type': 贷款类型
-- dict_type='payment_method': 支付方式
-- dict_type='contact_result': 联系结果
-- dict_type='intent_level': 意向程度

-- =============================================================
-- 第十部分：云端存储配置
-- =============================================================

-- 23. 文件上传记录表
CREATE TABLE IF NOT EXISTS file_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_no TEXT UNIQUE NOT NULL,  -- 文件编号
    original_name TEXT NOT NULL,  -- 原始文件名
    stored_name TEXT NOT NULL,  -- 存储文件名
    file_path TEXT NOT NULL,  -- 存储路径
    file_url TEXT NOT NULL,  -- 访问URL
    file_type TEXT,  -- 文件类型
    mime_type TEXT,
    file_size BIGINT,  -- 文件大小（字节）
    file_hash TEXT,  -- 文件哈希（防篡改）
    
    -- 关联
    related_table TEXT,  -- 关联表名
    related_id UUID,  -- 关联记录ID
    
    -- 上传者
    uploader_id UUID REFERENCES users(id),
    uploader_name TEXT,
    
    -- 安全
    access_level TEXT DEFAULT 'private',  -- private/internal/public
    download_count INTEGER DEFAULT 0,
    last_access_at TIMESTAMPTZ,
    last_access_ip TEXT,
    
    status TEXT DEFAULT 'active',  -- active/deleted
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_file_related ON file_uploads(related_table, related_id);
CREATE INDEX IF NOT EXISTS idx_file_uploader ON file_uploads(uploader_id);

-- =============================================================
-- 触发器：自动生成审计日志
-- =============================================================

-- 创建审计日志触发器函数
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    audit_row audit_logs%ROWTYPE;
    old_vals JSONB;
    new_vals JSONB;
    changed_cols TEXT[];
    col_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        old_vals = NULL;
        new_vals = to_jsonb(NEW);
        audit_row.operation = 'INSERT';
    ELSIF TG_OP = 'UPDATE' THEN
        old_vals = to_jsonb(OLD);
        new_vals = to_jsonb(NEW);
        
        -- 计算变更字段
        changed_cols = ARRAY[]::TEXT[];
        FOR col_name IN SELECT jsonb_object_keys(old_vals)
        LOOP
            IF old_vals->col_name IS DISTINCT FROM new_vals->col_name THEN
                changed_cols = array_append(changed_cols, col_name);
            END IF;
        END LOOP;
        
        audit_row.operation = 'UPDATE';
    ELSIF TG_OP = 'DELETE' THEN
        old_vals = to_jsonb(OLD);
        new_vals = NULL;
        audit_row.operation = 'DELETE';
    END IF;
    
    INSERT INTO audit_logs (
        table_name,
        record_id,
        operation,
        old_values,
        new_values,
        changed_fields,
        user_id
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id::TEXT, OLD.id::TEXT),
        audit_row.operation,
        old_vals,
        new_vals,
        changed_cols,
        current_setting('app.current_user_id', TRUE)::UUID
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 为所有核心表创建触发器
-- 注意：需要 Supabase 超级用户权限才能创建触发器
-- 如果没有权限，需要使用 Edge Function 来实现审计功能

/*
-- 示例：为 customers 表创建触发器
DROP TRIGGER IF EXISTS trg_customers_audit ON customers;
CREATE TRIGGER trg_customers_audit
    BEFORE INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();
*/

-- =============================================================
-- 初始化数据
-- =============================================================

-- 插入保险公司数据
INSERT INTO insurance_companies (company_code, company_name, short_name, service_phone, is_active) VALUES
('PICC', '中国人民财产保险股份有限公司', '人保财险', '95518', TRUE),
('CPIC', '中国太平洋财产保险股份有限公司', '太平洋财险', '95500', TRUE),
('CIC', '中国平安财产保险股份有限公司', '平安财险', '95511', TRUE),
('CCIC', '中华联合财产保险股份有限公司', '中华联合', '95585', TRUE),
('THI', '太平财产保险有限公司', '太平财险', '95589', TRUE),
('CITIC', '中银财产保险有限公司', '中银保险', '95566', TRUE),
('AXA', '安盛天平财产保险有限公司', '安盛天平', '95550', TRUE),
('ALLIANZ', '安联财产保险（中国）有限公司', '安联保险', '400-800-2020', TRUE),
('AIG', '美亚财产保险有限公司', '美亚保险', '400-820-5911', TRUE),
('SUNLIFE', '阳光财产保险股份有限公司', '阳光财险', '95510', TRUE)
ON CONFLICT (company_code) DO NOTHING;

-- 插入系统字典数据
INSERT INTO system_dict (dict_type, dict_value, dict_label, sort_order, is_active) VALUES
-- 车辆类型
('vehicle_type', 'sedan', '轿车', 1, TRUE),
('vehicle_type', 'suv', 'SUV', 2, TRUE),
('vehicle_type', 'mpv', 'MPV', 3, TRUE),
('vehicle_type', 'pickup', '皮卡', 4, TRUE),
('vehicle_type', 'van', '面包车', 5, TRUE),
('vehicle_type', 'hatchback', '两厢车', 6, TRUE),
('vehicle_type', 'wagon', '旅行车', 7, TRUE),
-- 能源类型
('fuel_type', 'gasoline', '汽油', 1, TRUE),
('fuel_type', 'diesel', '柴油', 2, TRUE),
('fuel_type', 'electric', '纯电动', 3, TRUE),
('fuel_type', 'hybrid', '混合动力', 4, TRUE),
('fuel_type', 'plug_in_hybrid', '插电式混合动力', 5, TRUE),
('fuel_type', 'range_extender', '增程式', 6, TRUE),
-- 使用性质
('use_type', 'family', '家用', 1, TRUE),
('use_type', 'private', '非营业私人', 2, TRUE),
('use_type', 'commercial', '营业', 3, TRUE),
('use_type', 'rental', '租赁', 4, TRUE),
-- 险种类别
('insurance_category', 'accident', '意外险', 1, TRUE),
('insurance_category', 'health', '健康险', 2, TRUE),
('insurance_category', 'property', '家财险', 3, TRUE),
('insurance_category', 'liability', '责任险', 4, TRUE),
('insurance_category', 'credit', '信用险', 5, TRUE),
('insurance_category', 'freight', '货运险', 6, TRUE),
('insurance_category', 'other', '其他险', 7, TRUE),
-- 订单类型
('order_type', 'violation', '违章查询', 1, TRUE),
('order_type', 'towing', '道路救援', 2, TRUE),
('order_type', 'beauty', '美容装潢', 3, TRUE),
('order_type', 'modify', '改装升级', 4, TRUE),
('order_type', 'parts', '配件销售', 5, TRUE),
('order_type', 'accessory', '汽车用品', 6, TRUE),
('order_type', 'other', '其他服务', 7, TRUE),
-- 贷款类型
('loan_type', 'new_car', '新车贷款', 1, TRUE),
('loan_type', 'used_car', '二手车贷款', 2, TRUE),
('loan_type', 'refinance', '贷款续期', 3, TRUE),
('loan_type', 'upgrade', '贷款升级', 4, TRUE),
-- 支付方式
('payment_method', 'wechat', '微信支付', 1, TRUE),
('payment_method', 'alipay', '支付宝', 2, TRUE),
('payment_method', 'bank_transfer', '银行转账', 3, TRUE),
('payment_method', 'cash', '现金', 4, TRUE),
('payment_method', 'pos', 'POS机', 5, TRUE)
ON CONFLICT (dict_type, dict_value) DO NOTHING;

-- =============================================================
-- 视图：方便前端查询
-- =============================================================

-- 客户车辆关联视图
CREATE OR REPLACE VIEW v_customer_vehicles AS
SELECT 
    c.id AS customer_id,
    c.real_name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate,
    v.brand,
    v.series,
    v.car_model,
    v.vin,
    v.vehicle_type,
    v.fuel_type,
    v.inspection_due_date,
    v.purchase_date
FROM customers c
LEFT JOIN vehicles v ON c.id = v.customer_id AND NOT v.is_deleted
WHERE NOT c.is_deleted;

-- 客户保险汇总视图
CREATE OR REPLACE VIEW v_customer_insurance_summary AS
SELECT 
    c.id AS customer_id,
    c.real_name AS customer_name,
    c.phone,
    COUNT(cp.id) AS car_policy_count,
    COALESCE(SUM(cp.total_premium), 0) AS car_total_premium,
    COALESCE(SUM(cp.commission_amount), 0) AS car_total_commission,
    COUNT(np.id) AS noncar_policy_count,
    COALESCE(SUM(np.premium), 0) AS noncar_total_premium,
    COALESCE(SUM(np.commission_amount), 0) AS noncar_total_commission,
    COUNT(cp.id) FILTER (WHERE cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days') AS car_policy_expiring_soon
FROM customers c
LEFT JOIN car_policies cp ON c.id = cp.customer_id AND NOT cp.is_deleted
LEFT JOIN noncar_policies np ON c.id = np.customer_id AND NOT np.is_deleted
WHERE NOT c.is_deleted
GROUP BY c.id, c.real_name, c.phone;

-- 到期提醒视图（30天内）
CREATE OR REPLACE VIEW v_expiring_policies AS
SELECT 
    cp.id AS policy_id,
    cp.policy_no,
    c.id AS customer_id,
    c.real_name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate,
    cp.end_date,
    cp.total_premium,
    cp.insurance_company,
    (cp.end_date - CURRENT_DATE) AS days_to_expire,
    CASE 
        WHEN (cp.end_date - CURRENT_DATE) <= 7 THEN 'urgent'
        WHEN (cp.end_date - CURRENT_DATE) <= 15 THEN 'high'
        ELSE 'normal'
    END AS urgency_level
FROM car_policies cp
JOIN customers c ON cp.customer_id = c.id
LEFT JOIN vehicles v ON cp.vehicle_id = v.id
WHERE NOT cp.is_deleted 
    AND NOT c.is_deleted
    AND cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
    AND cp.status IN ('active', 'pending')
ORDER BY days_to_expire;

-- 年审到期提醒视图
CREATE OR REPLACE VIEW v_expiring_inspections AS
SELECT 
    vi.id AS inspection_id,
    c.id AS customer_id,
    c.real_name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate,
    vi.due_date,
    (vi.due_date - CURRENT_DATE) AS days_to_due,
    vi.status AS inspection_status,
    CASE 
        WHEN (vi.due_date - CURRENT_DATE) <= 7 THEN 'urgent'
        WHEN (vi.due_date - CURRENT_DATE) <= 15 THEN 'high'
        ELSE 'normal'
    END AS urgency_level
FROM vehicle_inspections vi
JOIN vehicles v ON vi.vehicle_id = v.id
JOIN customers c ON v.customer_id = c.id
WHERE NOT vi.is_deleted
    AND NOT v.is_deleted
    AND NOT c.is_deleted
    AND vi.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
    AND vi.status IN ('pending', 'due')
ORDER BY days_to_due;

-- =============================================================
-- 结束
-- =============================================================
