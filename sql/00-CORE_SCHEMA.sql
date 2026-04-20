-- ============================================================
-- 汽车全生态客户管理系统 - 核心数据库Schema
-- 版本：V1.0 | 日期：2026-04-19 | 作者：痞老板
-- 数据库：Supabase (PostgreSQL)
-- ============================================================

-- ============================================================
-- 基础表结构
-- ============================================================

-- 1. 统一客户表（所有模块的核心）
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 基本信息
    name VARCHAR(100) NOT NULL COMMENT '客户姓名',
    gender VARCHAR(10) COMMENT '性别：男/女',
    birth_date DATE COMMENT '出生日期',
    id_card VARCHAR(18) UNIQUE COMMENT '身份证号',
    phone VARCHAR(20) NOT NULL COMMENT '手机号',
    phone_2 VARCHAR(20) COMMENT '备用手机号',
    email VARCHAR(100) COMMENT '电子邮箱',
    -- 地址信息
    province VARCHAR(50) COMMENT '省份',
    city VARCHAR(50) COMMENT '城市',
    district VARCHAR(50) COMMENT '区县',
    address_detail TEXT COMMENT '详细地址',
    -- 客户分类
    customer_type VARCHAR(20) DEFAULT 'personal' COMMENT '类型：personal-个人/enterprise-企业',
    customer_level VARCHAR(20) DEFAULT 'C' COMMENT '等级：A-重点/B-优质/C-普通',
    source_channel VARCHAR(50) COMMENT '来源渠道',
    -- 关联信息
    assigned_user_id UUID COMMENT '负责业务员',
    family_group_id UUID COMMENT '家庭组ID（同家庭客户关联）',
    -- 标签
    tags TEXT[] DEFAULT '{}' COMMENT '标签数组',
    remark TEXT COMMENT '备注',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 2. 车辆表（汽车全生命周期的核心实体）
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 车辆基础信息
    plate_number VARCHAR(20) NOT NULL COMMENT '车牌号',
    plate_province VARCHAR(20) COMMENT '车牌省份',
    plate_city VARCHAR(20) COMMENT '车牌城市',
    vin VARCHAR(50) UNIQUE COMMENT '车架号VIN',
    engine_no VARCHAR(50) COMMENT '发动机号',
    brand VARCHAR(50) COMMENT '品牌',
    series VARCHAR(50) COMMENT '车系',
    model VARCHAR(100) COMMENT '车型（详细）',
    vehicle_type VARCHAR(20) COMMENT '车辆类型：客车/货车/特种车',
    usage_type VARCHAR(20) DEFAULT 'family' COMMENT '使用性质：family-家庭自用/business-营运',
    color VARCHAR(20) COMMENT '车身颜色',
    -- 车辆参数
    register_date DATE COMMENT '注册日期',
    issue_date DATE COMMENT '发证日期',
    fuel_type VARCHAR(20) COMMENT '燃料类型：gasoline-汽油/diesel-柴油/electric-电动/hybrid-混动',
    engine_displacement DECIMAL(4,2) COMMENT '排量(L)',
    transmission VARCHAR(20) COMMENT '变速箱：auto-自动/manual-手动',
    emission_standard VARCHAR(20) COMMENT '排放标准：国四/国五/国六',
    purchase_price DECIMAL(12,2) COMMENT '购置价格',
    -- 年审信息
    annual_review_month INTEGER COMMENT '年审到期月份(1-12)',
    annual_review_date DATE COMMENT '年审到期日期',
    inspection_expire_date DATE COMMENT '交强险到期日期',
    -- 当前状态
    vehicle_status VARCHAR(20) DEFAULT 'active' COMMENT '状态：active-正常/scrapped-报废/sold-转让/pledged-抵押',
    current_mileage DECIMAL(12,1) COMMENT '当前里程数(km)',
    last_maintenance_date DATE COMMENT '最近保养日期',
    -- 关联客户
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    -- 索引
    UNIQUE(plate_number)
);

-- 3. 系统用户表
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    real_name VARCHAR(50) COMMENT '真实姓名',
    phone VARCHAR(20) COMMENT '手机号',
    email VARCHAR(100) COMMENT '邮箱',
    role VARCHAR(20) DEFAULT 'user' COMMENT '角色：admin-管理员/manager-经理/agent-业务员/user-普通用户',
    department VARCHAR(50) COMMENT '部门',
    is_active BOOLEAN DEFAULT TRUE,
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

-- ============================================================
-- 模块1: 车险管理
-- ============================================================

-- 4. 车险保单表
CREATE TABLE IF NOT EXISTS car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 保单基本信息
    policy_no VARCHAR(50) UNIQUE COMMENT '保单号',
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    -- 承保信息
    insurance_company VARCHAR(100) COMMENT '承保公司',
    insurance_type VARCHAR(20) COMMENT '投保类型：compulsory-交强险/commercial-商业险/both-两者都有',
    -- 商业险详情
    commercial_premium DECIMAL(12,2) COMMENT '商业险保费',
    commercial_coverage_amount DECIMAL(14,2) COMMENT '商业险保额',
    commercial_deductible DECIMAL(10,2) COMMENT '商业险免赔额',
    -- 交强险详情
    compulsory_premium DECIMAL(10,2) COMMENT '交强险保费',
    compulsory_coverage_amount DECIMAL(12,2) COMMENT '交强险保额',
    -- 险种明细（JSON格式存储）
    coverage_details JSONB DEFAULT '{}' COMMENT '险种明细：{"third_party":{amount,premium},...}',
    -- 保险期间
    policy_start_date DATE NOT NULL COMMENT '保单生效日期',
    policy_end_date DATE NOT NULL COMMENT '保单到期日期',
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL COMMENT '总保费',
    actual_premium DECIMAL(12,2) COMMENT '实收保费',
    discount_rate DECIMAL(5,4) COMMENT '折扣率',
    -- 佣金信息
    commission_rate DECIMAL(5,4) COMMENT '佣金比例',
    commission_amount DECIMAL(12,2) COMMENT '佣金金额',
    actual_commission DECIMAL(12,2) COMMENT '实收佣金',
    -- 状态
    policy_status VARCHAR(20) DEFAULT 'active' COMMENT '状态：pending-待生效/active-生效/expired-过期/cancelled-退保',
    renewal_status VARCHAR(20) COMMENT '续保状态：not_due-未到期/remind-待跟进/intent-有意向/confirmed-已确认/lost-流失',
    -- 来源
    source_type VARCHAR(20) DEFAULT 'new' COMMENT '来源：new-新保/renewal-续保/transfer-转入',
    previous_policy_id UUID REFERENCES car_policies(id) COMMENT '上年保单ID',
    -- 时间戳
    effective_date DATE COMMENT '实际生效日期',
    surrender_date DATE COMMENT '退保日期',
    surrender_reason TEXT COMMENT '退保原因',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 5. 车险理赔记录表
CREATE TABLE IF NOT EXISTS car_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_no VARCHAR(50) UNIQUE COMMENT '理赔号',
    policy_id UUID NOT NULL REFERENCES car_policies(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    -- 理赔信息
    accident_date TIMESTAMPTZ COMMENT '事故时间',
    accident_location TEXT COMMENT '事故地点',
    accident_type VARCHAR(50) COMMENT '事故类型',
    accident_desc TEXT COMMENT '事故描述',
    -- 损失信息
    damage_desc TEXT COMMENT '损失情况',
    estimated_damage DECIMAL(12,2) COMMENT '预估损失',
    actual_damage DECIMAL(12,2) COMMENT '实际损失',
    -- 理算信息
    claim_amount DECIMAL(12,2) COMMENT '理赔金额',
    deductible_amount DECIMAL(10,2) COMMENT '免赔金额',
    paid_amount DECIMAL(12,2) COMMENT '已付金额',
    -- 状态
    claim_status VARCHAR(20) DEFAULT 'reported' COMMENT '状态：reported-已报案/surveying-查勘中/assessing-定损中/negotiating-协商中/settled-已结案/rejected-拒赔',
    settlement_date DATE COMMENT '结案日期',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 6. 客户跟进记录表（通用）
CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    policy_id UUID REFERENCES car_policies(id),
    -- 跟进信息
    followup_type VARCHAR(30) COMMENT '跟进类型：renewal-续保跟进/claim-理赔跟进/intent-意向跟进/visit-拜访/satisfaction-满意度回访',
    followup_channel VARCHAR(20) COMMENT '跟进方式：phone-电话/wechat-微信/visit-上门/msg-短信',
    followup_purpose VARCHAR(100) COMMENT '跟进目的',
    followup_content TEXT NOT NULL COMMENT '跟进内容',
    followup_result VARCHAR(20) COMMENT '跟进结果：success-成功/deferred-暂缓/failed-失败',
    next_followup_date DATE COMMENT '下次跟进日期',
    next_followup_purpose VARCHAR(100) COMMENT '下次跟进目的',
    -- 附件
    attachments JSONB DEFAULT '[]' COMMENT '附件列表：[{type,url,name}]',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块2: 非车险管理
-- ============================================================

-- 7. 非车险保单表
CREATE TABLE IF NOT EXISTS noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_no VARCHAR(50) UNIQUE COMMENT '保单号',
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 关联车险（交叉销售）
    related_car_policy_id UUID REFERENCES car_policies(id) COMMENT '关联车险保单ID',
    -- 产品信息
    insurance_company VARCHAR(100) COMMENT '承保公司',
    insurance_category VARCHAR(30) COMMENT '险种类别：accident-意外险/health-健康险/property-家财险/liability-责任险/travel-旅行险/special-特种险',
    insurance_product VARCHAR(100) COMMENT '产品名称',
    insurance_subtype VARCHAR(50) COMMENT '子类型',
    -- 保险信息
    insured_name VARCHAR(100) COMMENT '被保险人',
    insured_id_card VARCHAR(18) COMMENT '被保险人身份证',
    insured_phone VARCHAR(20) COMMENT '被保险人电话',
    beneficiary VARCHAR(100) COMMENT '受益人',
    -- 保险期间
    policy_start_date DATE NOT NULL COMMENT '生效日期',
    policy_end_date DATE NOT NULL COMMENT '到期日期',
    -- 保费佣金
    premium DECIMAL(12,2) NOT NULL COMMENT '保费',
    actual_premium DECIMAL(12,2) COMMENT '实收保费',
    coverage_amount DECIMAL(14,2) COMMENT '保额',
    commission_rate DECIMAL(5,4) COMMENT '佣金比例',
    commission_amount DECIMAL(12,2) COMMENT '佣金金额',
    actual_commission DECIMAL(12,2) COMMENT '实收佣金',
    -- 状态
    policy_status VARCHAR(20) DEFAULT 'active' COMMENT '状态：pending-待生效/active-生效/expired-过期/cancelled-退保',
    renewal_status VARCHAR(20) COMMENT '续保状态',
    -- 来源
    source_type VARCHAR(20) DEFAULT 'cross_sell' COMMENT '来源：new-新保/renewal-续保/cross_sell-交叉销售',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块3: 年审保养
-- ============================================================

-- 8. 年审记录表
CREATE TABLE IF NOT EXISTS annual_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 年审信息
    review_year INTEGER NOT NULL COMMENT '年审年份',
    review_month INTEGER COMMENT '年审月份',
    review_date DATE COMMENT '年审日期',
    review_type VARCHAR(20) DEFAULT 'vehicle' COMMENT '类型：vehicle-车辆年审/emission-环保检测/safety-安全检测',
    -- 费用
    review_fee DECIMAL(10,2) COMMENT '年审费用',
    emission_fee DECIMAL(10,2) COMMENT '环检费用',
    total_fee DECIMAL(10,2) COMMENT '总费用',
    -- 检测站
    station_name VARCHAR(100) COMMENT '检测站名称',
    station_address TEXT COMMENT '检测站地址',
    station_phone VARCHAR(20) COMMENT '检测站电话',
    -- 结果
    review_result VARCHAR(20) COMMENT '结果：pass-通过/failed-需复检/rejected-不合格',
    failure_reasons JSONB DEFAULT '[]' COMMENT '不合格原因',
    report_url VARCHAR(500) COMMENT '检测报告URL',
    -- 状态
    status VARCHAR(20) DEFAULT 'pending' COMMENT '状态：pending-待检/scheduled-已预约/ongoing-检测中/completed-已完成/expired-已过期',
    reminder_sent BOOLEAN DEFAULT FALSE COMMENT '是否已发送提醒',
    reminder_dates JSONB DEFAULT '[]' COMMENT '已发送提醒的日期列表',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 9. 保养记录表
CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 保养信息
    maintenance_date DATE NOT NULL COMMENT '保养日期',
    mileage DECIMAL(12,1) COMMENT '保养时里程数',
    maintenance_type VARCHAR(20) COMMENT '保养类型：routine-常规保养/repair-维修/service-其他服务',
    maintenance_category VARCHAR(50) COMMENT '保养类别：oil_change-换机油/tire-轮胎/brake-刹车/battery-电瓶/filter-滤芯/other-其他',
    -- 服务商
    shop_id UUID REFERENCES service_shops(id) COMMENT '服务商ID',
    shop_name VARCHAR(100) COMMENT '服务商名称',
    shop_address TEXT COMMENT '服务商地址',
    technician VARCHAR(50) COMMENT '技师姓名',
    shop_phone VARCHAR(20) COMMENT '服务商电话',
    -- 费用明细
    labor_fee DECIMAL(10,2) COMMENT '工时费',
    parts_fee DECIMAL(10,2) COMMENT '配件费',
    other_fee DECIMAL(10,2) COMMENT '其他费用',
    total_fee DECIMAL(10,2) COMMENT '总费用',
    -- 配件明细
    parts_used JSONB DEFAULT '[]' COMMENT '使用的配件：[{name,qty,price}]',
    -- 下次保养
    next_maintenance_mileage DECIMAL(12,1) COMMENT '下次保养里程',
    next_maintenance_date DATE COMMENT '下次保养日期',
    -- 状态
    warranty_status VARCHAR(20) COMMENT '保修状态：in_warranty-保修期/out_warranty-已过保',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 10. 维修记录表
CREATE TABLE IF NOT EXISTS repair_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 维修信息
    repair_date DATE NOT NULL COMMENT '维修日期',
    repair_type VARCHAR(20) COMMENT '维修类型：accident-事故维修/warranty-保修维修/self_pay-自费维修',
    repair_category VARCHAR(50) COMMENT '维修类别：bodywork-车身/drivetrain-动力系统/brake-制动系统/electrical-电气系统/other-其他',
    fault_desc TEXT COMMENT '故障描述',
    repair_desc TEXT COMMENT '维修描述',
    -- 服务商
    shop_id UUID REFERENCES service_shops(id),
    shop_name VARCHAR(100) COMMENT '维修厂名称',
    technician VARCHAR(50) COMMENT '维修技师',
    -- 费用
    labor_fee DECIMAL(10,2) COMMENT '工时费',
    parts_fee DECIMAL(10,2) COMMENT '配件费',
    paint_fee DECIMAL(10,2) COMMENT '喷漆费',
    other_fee DECIMAL(10,2) COMMENT '其他费用',
    total_fee DECIMAL(10,2) COMMENT '总费用',
    insurance_claim BOOLEAN DEFAULT FALSE COMMENT '是否走保险',
    claim_id UUID REFERENCES car_claims(id) COMMENT '关联理赔ID',
    -- 状态
    status VARCHAR(20) DEFAULT 'completed' COMMENT '状态：diagnosing-诊断中/repairing-维修中/completed-已完成/delivered-已交车',
    delivery_date DATE COMMENT '交车日期',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块4: 汽车后市场服务
-- ============================================================

-- 11. 服务商表
CREATE TABLE IF NOT EXISTS service_shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_name VARCHAR(100) NOT NULL COMMENT '服务商名称',
    shop_type VARCHAR(30) COMMENT '类型：maintenance-保养店/repair-修理厂/dealer-4S店/beauty-美容店/rescue-救援公司/parts-配件商/accessory-改装店',
    business_license VARCHAR(50) COMMENT '营业执照号',
    legal_person VARCHAR(50) COMMENT '法人代表',
    contact_person VARCHAR(50) COMMENT '联系人',
    contact_phone VARCHAR(20) COMMENT '联系电话',
    province VARCHAR(50) COMMENT '省份',
    city VARCHAR(50) COMMENT '城市',
    district VARCHAR(50) COMMENT '区县',
    address_detail TEXT COMMENT '详细地址',
    longitude DECIMAL(11,7) COMMENT '经度',
    latitude DECIMAL(11,7) COMMENT '纬度',
    business_hours VARCHAR(100) COMMENT '营业时间',
    service_brands TEXT[] DEFAULT '{}' COMMENT '服务品牌',
    service_types TEXT[] DEFAULT '{}' COMMENT '服务类型',
    qualification_certificates JSONB DEFAULT '[]' COMMENT '资质证书：[{type,no,expire_date,url}]',
    rating DECIMAL(3,2) COMMENT '评分(0-5)',
    rating_count INTEGER DEFAULT 0 COMMENT '评分次数',
    is_verified BOOLEAN DEFAULT FALSE COMMENT '是否认证',
    is_cooperation BOOLEAN DEFAULT FALSE COMMENT '是否签约合作',
    commission_rate DECIMAL(5,4) COMMENT '佣金比例',
    bank_account VARCHAR(50) COMMENT '银行账户',
    bank_name VARCHAR(50) COMMENT '开户银行',
    remark TEXT COMMENT '备注',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 12. 道路救援记录表
CREATE TABLE IF NOT EXISTS rescue_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    -- 救援信息
    rescue_type VARCHAR(30) COMMENT '救援类型：towing-拖车/flat_tire-换胎/jump_start-搭电/lockout-开锁/fuel_delivery-送油/other-其他',
    accident_date TIMESTAMPTZ COMMENT '事故/故障时间',
    rescue_location TEXT COMMENT '故障地点',
    longitude DECIMAL(11,7) COMMENT '经度',
    latitude DECIMAL(11,7) COMMENT '纬度',
    fault_desc TEXT COMMENT '故障描述',
    -- 处理信息
    shop_id UUID REFERENCES service_shops(id) COMMENT '救援服务商',
    rescue_team VARCHAR(100) COMMENT '救援队伍',
    rescue_phone VARCHAR(20) COMMENT '救援电话',
    dispatch_time TIMESTAMPTZ COMMENT '派单时间',
    arrive_time TIMESTAMPTZ COMMENT '到达时间',
    complete_time TIMESTAMPTZ COMMENT '完成时间',
    -- 费用
    rescue_fee DECIMAL(10,2) COMMENT '救援费用',
    extra_fee DECIMAL(10,2) COMMENT '附加费用（超出基础服务）',
    total_fee DECIMAL(10,2) COMMENT '总费用',
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '支付状态：unpaid-未支付/paid-已支付/refunded-已退款',
    -- 结果
    result VARCHAR(20) COMMENT '结果：success-成功/failed-失败/cancelled-取消',
    customer_feedback TEXT COMMENT '客户反馈',
    rating INTEGER COMMENT '评分(1-5)',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 13. 后市场订单表
CREATE TABLE IF NOT EXISTS aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_no VARCHAR(50) UNIQUE COMMENT '订单号',
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    -- 订单信息
    order_type VARCHAR(30) COMMENT '订单类型：beauty-美容/wash-洗车/accessory-配件/coating-镀晶/tint-贴膜/modify-改装/other-其他',
    order_name VARCHAR(100) COMMENT '服务/商品名称',
    order_desc TEXT COMMENT '订单描述',
    -- 服务商
    shop_id UUID REFERENCES service_shops(id),
    shop_name VARCHAR(100) COMMENT '服务商名称',
    -- 预约信息
    appointment_date TIMESTAMPTZ COMMENT '预约时间',
    appointment_address TEXT COMMENT '预约地址（上门服务）',
    -- 费用
    original_fee DECIMAL(10,2) COMMENT '原价',
    discount_amount DECIMAL(10,2) COMMENT '优惠金额',
    actual_fee DECIMAL(10,2) COMMENT '实付金额',
    payment_method VARCHAR(20) COMMENT '支付方式：cash-现金/wxpay-微信/alipay-支付宝/transfer-转账/card-刷卡',
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '支付状态',
    payment_time TIMESTAMPTZ COMMENT '支付时间',
    -- 状态
    order_status VARCHAR(20) DEFAULT 'pending' COMMENT '订单状态：pending-待支付/paid-已支付/confirmed-已确认/processing-进行中/completed-已完成/cancelled-已取消/refunded-已退款',
    complete_time TIMESTAMPTZ COMMENT '完成时间',
    -- 评价
    rating INTEGER COMMENT '评分(1-5)',
    review_content TEXT COMMENT '评价内容',
    review_time TIMESTAMPTZ COMMENT '评价时间',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 14. 违章记录表
CREATE TABLE IF NOT EXISTS violation_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 违章信息
    violation_no VARCHAR(50) COMMENT '违章编号',
    violation_date TIMESTAMPTZ COMMENT '违章时间',
    violation_location TEXT COMMENT '违章地点',
    violation_type VARCHAR(50) COMMENT '违章类型',
    violation_code VARCHAR(20) COMMENT '违章代码',
    capture_photo_url VARCHAR(500) COMMENT '抓拍图片URL',
    -- 处罚信息
    fines DECIMAL(10,2) COMMENT '罚款金额',
    penalty_points INTEGER COMMENT '扣分',
    detention_days INTEGER COMMENT '拘留天数',
    -- 处理状态
    handled BOOLEAN DEFAULT FALSE COMMENT '是否处理',
    handled_date DATE COMMENT '处理日期',
    handle_shop_id UUID REFERENCES service_shops(id) COMMENT '处理机构',
    -- 来源
    source VARCHAR(20) DEFAULT 'manual' COMMENT '来源：manual-手动/auto-自动同步',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 模块5: 汽车消费金融
-- ============================================================

-- 15. 金融产品表
CREATE TABLE IF NOT EXISTS finance_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_name VARCHAR(100) NOT NULL COMMENT '产品名称',
    product_type VARCHAR(30) COMMENT '产品类型：loan-车贷/lease-融资租赁/ refinance-再抵押/credit-信用贷',
    institution_name VARCHAR(100) COMMENT '金融机构名称',
    institution_type VARCHAR(20) COMMENT '机构类型：bank-银行/finance-金融公司/other-其他',
    -- 利率信息
    min_loan_amount DECIMAL(14,2) COMMENT '最小贷款金额',
    max_loan_amount DECIMAL(14,2) COMMENT '最大贷款金额',
    min_term INTEGER COMMENT '最短期限(月)',
    max_term INTEGER COMMENT '最长期限(月)',
    min_rate DECIMAL(6,4) COMMENT '最低利率(年化)',
    max_rate DECIMAL(6,4) COMMENT '最高利率(年化)',
    -- 费用
    handling_fee_rate DECIMAL(6,4) COMMENT '手续费率',
    handling_fee_fixed DECIMAL(10,2) COMMENT '手续费(固定)',
    early_repayment_penalty DECIMAL(6,4) COMMENT '提前还款违约金率',
    late_payment_penalty DECIMAL(6,4) COMMENT '逾期罚息率',
    -- 条件
    min_down_payment_ratio DECIMAL(5,4) COMMENT '最低首付比例',
    min_credit_score INTEGER COMMENT '最低信用评分',
    collateral_required BOOLEAN DEFAULT TRUE COMMENT '是否需要抵押',
    -- 状态
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否启用',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 16. 金融合同表
CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_no VARCHAR(50) UNIQUE COMMENT '合同编号',
    customer_id UUID NOT NULL REFERENCES customers(id),
    vehicle_id UUID REFERENCES vehicles(id),
    product_id UUID REFERENCES finance_products(id),
    -- 车辆信息（贷款购入）
    vehicle_price DECIMAL(14,2) COMMENT '车辆总价',
    down_payment DECIMAL(14,2) COMMENT '首付金额',
    down_payment_ratio DECIMAL(5,4) COMMENT '首付比例',
    loan_amount DECIMAL(14,2) NOT NULL COMMENT '贷款金额',
    -- 贷款条款
    loan_term INTEGER NOT NULL COMMENT '贷款期限(月)',
    interest_rate DECIMAL(6,4) NOT NULL COMMENT '年利率',
    interest_type VARCHAR(20) DEFAULT 'equal_principal' COMMENT '还款方式：equal_principal-等额本金/equal_payment-等额本息/balloon-气球贷',
    monthly_payment DECIMAL(12,2) COMMENT '月供金额',
    total_interest DECIMAL(12,2) COMMENT '总利息',
    total_repayment DECIMAL(14,2) COMMENT '还款总额',
    -- 费用
    handling_fee DECIMAL(10,2) COMMENT '手续费',
    gps_fee DECIMAL(10,2) COMMENT 'GPS费',
    insurance_premium DECIMAL(10,2) COMMENT '保险押金',
    other_fees DECIMAL(10,2) COMMENT '其他费用',
    -- 放款信息
    disbursement_date DATE COMMENT '放款日期',
    disbursement_amount DECIMAL(14,2) COMMENT '实际放款金额',
    disbursement_account VARCHAR(100) COMMENT '放款账户',
    -- 还款信息
    remaining_principal DECIMAL(14,2) COMMENT '剩余本金',
    remaining_interest DECIMAL(12,2) COMMENT '剩余利息',
    next_payment_date DATE COMMENT '下次还款日期',
    next_payment_amount DECIMAL(12,2) COMMENT '下次还款金额',
    -- 状态
    contract_status VARCHAR(20) DEFAULT 'pending' COMMENT '状态：pending-待审批/approved-已批准/disbursed-已放款/repaying-还款中/settled-已结清/default-违约/rescinded-已撤销',
    -- 担保信息
    collateral_type VARCHAR(20) COMMENT '担保方式：vehicle-车辆抵押/guarantee-担保人/pledge-质押',
    collateral_status VARCHAR(20) COMMENT '抵押状态：pledged-已抵押/released-已解押',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 17. 还款记录表
CREATE TABLE IF NOT EXISTS repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES finance_contracts(id),
    customer_id UUID NOT NULL REFERENCES customers(id),
    -- 期数信息
    period INTEGER NOT NULL COMMENT '期数',
    payment_date DATE NOT NULL COMMENT '应还款日期',
    -- 还款金额
    principal DECIMAL(12,2) NOT NULL COMMENT '本金',
    interest DECIMAL(10,2) NOT NULL COMMENT '利息',
    penalty DECIMAL(10,2) DEFAULT 0 COMMENT '罚息',
    total_amount DECIMAL(12,2) NOT NULL COMMENT '还款总额',
    -- 实际还款
    actual_payment_date DATE COMMENT '实际还款日期',
    actual_amount DECIMAL(12,2) COMMENT '实际还款金额',
    payment_method VARCHAR(20) COMMENT '还款方式',
    -- 状态
    payment_status VARCHAR(20) DEFAULT 'unpaid' COMMENT '状态：unpaid-未还/paid-已还/overdue-逾期/partial-部分还款',
    overdue_days INTEGER DEFAULT 0 COMMENT '逾期天数',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 基础数据表
-- ============================================================

-- 18. 保险产品字典表
CREATE TABLE IF NOT EXISTS insurance_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_code VARCHAR(50) COMMENT '公司代码',
    company_name VARCHAR(100) COMMENT '公司名称',
    product_code VARCHAR(50) COMMENT '产品代码',
    product_name VARCHAR(100) COMMENT '产品名称',
    insurance_type VARCHAR(30) COMMENT '险种类型：车险/意外险/健康险...',
    coverage_items JSONB DEFAULT '[]' COMMENT '保障项目',
    min_premium DECIMAL(10,2) COMMENT '最低保费',
    max_premium DECIMAL(10,2) COMMENT '最高保费',
    commission_rate DECIMAL(5,4) COMMENT '标准佣金率',
    is_active BOOLEAN DEFAULT TRUE,
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 19. 保险机构表
CREATE TABLE IF NOT EXISTS insurance_companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_code VARCHAR(50) UNIQUE COMMENT '公司代码',
    company_name VARCHAR(100) NOT NULL COMMENT '公司名称',
    short_name VARCHAR(50) COMMENT '简称',
    logo_url VARCHAR(500) COMMENT 'Logo URL',
    website VARCHAR(200) COMMENT '官网',
    service_phone VARCHAR(20) COMMENT '客服电话',
    business_scope TEXT[] DEFAULT '{}' COMMENT '业务范围',
    min_premium_discount DECIMAL(5,4) COMMENT '最低保费折扣',
    commission_policy TEXT COMMENT '佣金政策备注',
    is_active BOOLEAN DEFAULT TRUE,
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- 20. 系统参数表
CREATE TABLE IF NOT EXISTS system_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) UNIQUE NOT NULL COMMENT '配置键',
    config_value TEXT COMMENT '配置值(JSON格式)',
    config_type VARCHAR(20) DEFAULT 'string' COMMENT '类型：string/number/boolean/json',
    config_group VARCHAR(50) COMMENT '配置分组',
    config_desc VARCHAR(200) COMMENT '配置描述',
    is_public BOOLEAN DEFAULT FALSE COMMENT '是否公开(网站展示)',
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1
);

-- 21. 消息模板表
CREATE TABLE IF NOT EXISTS message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code VARCHAR(50) UNIQUE NOT NULL COMMENT '模板编码',
    template_name VARCHAR(100) COMMENT '模板名称',
    template_type VARCHAR(20) COMMENT '类型：sms-短信/wechat-微信/weixin_msg-微信消息/push-推送',
    template_content TEXT NOT NULL COMMENT '模板内容(支持变量占位符 ${name})',
    variables JSONB DEFAULT '[]' COMMENT '变量列表',
    is_active BOOLEAN DEFAULT TRUE,
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

-- ============================================================
-- 审计日志表（数据可追溯的关键）
-- ============================================================

-- 22. 审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 操作信息
    action VARCHAR(20) NOT NULL COMMENT '操作类型：CREATE/UPDATE/DELETE/READ/LOGIN/LOGOUT/EXPORT',
    table_name VARCHAR(50) COMMENT '操作的表名',
    record_id UUID COMMENT '操作的记录ID',
    -- 操作者
    user_id UUID COMMENT '操作人ID',
    user_name VARCHAR(50) COMMENT '操作人姓名',
    user_ip INET COMMENT '操作人IP',
    user_agent TEXT COMMENT '浏览器/客户端信息',
    -- 变更内容
    old_values JSONB DEFAULT '{}' COMMENT '变更前的值',
    new_values JSONB DEFAULT '{}' COMMENT '变更后的值',
    changed_fields TEXT[] DEFAULT '{}' COMMENT '变更的字段列表',
    -- 附加信息
    session_id VARCHAR(100) COMMENT '会话ID',
    request_id VARCHAR(100) COMMENT '请求ID',
    extra_data JSONB DEFAULT '{}' COMMENT '额外数据',
    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 23. 登录日志表
CREATE TABLE IF NOT EXISTS login_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    username VARCHAR(50),
    login_time TIMESTAMPTZ DEFAULT NOW(),
    login_ip INET,
    login_device VARCHAR(100),
    login_browser VARCHAR(100),
    login_os VARCHAR(100),
    login_result VARCHAR(20) DEFAULT 'success' COMMENT 'success-成功/failed-失败/locked-锁定',
    fail_reason VARCHAR(100) COMMENT '失败原因',
    logout_time TIMESTAMPTZ COMMENT '登出时间',
    session_duration INTEGER COMMENT '会话时长(秒)'
);

-- ============================================================
-- 索引创建
-- ============================================================

-- 客户表索引
CREATE INDEX idx_customers_phone ON customers(phone) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_name ON customers(name) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_id_card ON customers(id_card) WHERE is_deleted = FALSE;
CREATE INDEX idx_customers_assigned_user ON customers(assigned_user_id) WHERE is_deleted = FALSE;

-- 车辆表索引
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_vin ON vehicles(vin) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_annual_review ON vehicles(annual_review_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_vehicles_status ON vehicles(vehicle_status, is_deleted);

-- 车险保单索引
CREATE INDEX idx_car_policies_customer ON car_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_vehicle ON car_policies(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_policy_no ON car_policies(policy_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_end_date ON car_policies(policy_end_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_status ON car_policies(policy_status, renewal_status) WHERE is_deleted = FALSE;
CREATE INDEX idx_car_policies_company ON car_policies(insurance_company) WHERE is_deleted = FALSE;

-- 非车险索引
CREATE INDEX idx_noncar_policies_customer ON noncar_policies(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_policy_no ON noncar_policies(policy_no) WHERE is_deleted = FALSE;
CREATE INDEX idx_noncar_policies_category ON noncar_policies(insurance_category) WHERE is_deleted = FALSE;

-- 年审保养索引
CREATE INDEX idx_annual_reviews_vehicle ON annual_reviews(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_annual_reviews_date ON annual_reviews(review_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_vehicle ON maintenance_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_maintenance_date ON maintenance_records(maintenance_date) WHERE is_deleted = FALSE;

-- 后市场索引
CREATE INDEX idx_rescue_vehicle ON rescue_records(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_orders_customer ON aftermarket_orders(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_orders_status ON aftermarket_orders(order_status) WHERE is_deleted = FALSE;
CREATE INDEX idx_violation_vehicle ON violation_records(vehicle_id) WHERE is_deleted = FALSE;

-- 金融索引
CREATE INDEX idx_finance_contracts_customer ON finance_contracts(customer_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_contracts_vehicle ON finance_contracts(vehicle_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_contracts_status ON finance_contracts(contract_status) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_contract ON repayment_records(contract_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_date ON repayment_records(payment_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_repayment_status ON repayment_records(payment_status) WHERE is_deleted = FALSE;

-- 审计日志索引（特别重要）
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at);
CREATE INDEX idx_audit_logs_time ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action, table_name);

-- 登录日志索引
CREATE INDEX idx_login_logs_user ON login_logs(user_id, login_time DESC);
CREATE INDEX idx_login_logs_ip ON login_logs(login_ip, login_time DESC);

-- ============================================================
-- RLS 策略（行级安全）
-- ============================================================

-- 启用RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE annual_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE rescue_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE aftermarket_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE violation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repayment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_logs ENABLE ROW LEVEL SECURITY;

-- 用户策略（基于角色）
CREATE POLICY "Users can view all customers" ON customers
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert own records" ON customers
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update assigned records" ON customers
    FOR UPDATE USING (assigned_user_id = auth.uid() OR auth.role() = 'admin');

-- 车险保单策略
CREATE POLICY "Users can view own policies" ON car_policies
    FOR SELECT USING (created_by = auth.uid() OR auth.role() = 'admin');

CREATE POLICY "Users can insert own policies" ON car_policies
    FOR INSERT WITH CHECK (created_by = auth.uid() OR auth.role() = 'admin');

-- 审计日志只允许管理员访问
CREATE POLICY "Only admin can view audit logs" ON audit_logs
    FOR SELECT USING (auth.role() = 'admin');

CREATE POLICY "Only admin can insert audit logs" ON audit_logs
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

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

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_policies_updated_at BEFORE UPDATE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_claims_updated_at BEFORE UPDATE ON car_claims
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_followups_updated_at BEFORE UPDATE ON followups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_noncar_policies_updated_at BEFORE UPDATE ON noncar_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_annual_reviews_updated_at BEFORE UPDATE ON annual_reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_maintenance_records_updated_at BEFORE UPDATE ON maintenance_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_repair_records_updated_at BEFORE UPDATE ON repair_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_service_shops_updated_at BEFORE UPDATE ON service_shops
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rescue_records_updated_at BEFORE UPDATE ON rescue_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_aftermarket_orders_updated_at BEFORE UPDATE ON aftermarket_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_violation_records_updated_at BEFORE UPDATE ON violation_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_finance_products_updated_at BEFORE UPDATE ON finance_products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_finance_contracts_updated_at BEFORE UPDATE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_repayment_records_updated_at BEFORE UPDATE ON repayment_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 审计日志触发器（记录所有变更）
-- ============================================================

CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
DECLARE
    audit_action VARCHAR(20);
    old_data JSONB;
    new_data JSONB;
    changed_fields TEXT[];
    field_key TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        audit_action := 'CREATE';
        old_data := '{}';
        new_data := to_jsonb(NEW);
        changed_fields := ARRAY(SELECT jsonb_object_keys(to_jsonb(NEW)));
    ELSIF TG_OP = 'UPDATE' THEN
        audit_action := 'UPDATE';
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
        -- 计算变更的字段
        changed_fields := ARRAY(
            SELECT key
            FROM jsonb_object_keys(old_data) AS key
            WHERE old_data->key IS DISTINCT FROM new_data->key
        );
        IF changed_fields IS NULL THEN
            changed_fields := '{}';
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        audit_action := 'DELETE';
        old_data := to_jsonb(OLD);
        new_data := '{}';
        changed_fields := ARRAY(SELECT jsonb_object_keys(to_jsonb(OLD)));
    END IF;

    INSERT INTO audit_logs (
        action, table_name, record_id, user_id, user_name,
        old_values, new_values, changed_fields, user_ip, user_agent
    ) VALUES (
        audit_action,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        auth.uid(),
        (SELECT username FROM users WHERE id = auth.uid()),
        old_data,
        new_data,
        changed_fields,
        (SELECT last_value FROM pg_catalog.pg_get_last_result_error_info())::inet,
        current_setting('request.user_agent', true)
    );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为关键表创建审计触发器
CREATE TRIGGER audit_customers_changes
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER audit_vehicles_changes
    AFTER INSERT OR UPDATE OR DELETE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER audit_car_policies_changes
    AFTER INSERT OR UPDATE OR DELETE ON car_policies
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER audit_finance_contracts_changes
    AFTER INSERT OR UPDATE OR DELETE ON finance_contracts
    FOR EACH ROW EXECUTE FUNCTION log_changes();

-- ============================================================
-- 种子数据
-- ============================================================

-- 创建管理员账户（密码：admin123，后续需修改）
INSERT INTO users (username, password_hash, real_name, phone, role, is_active)
VALUES (
    'admin',
    -- bcrypt hash of 'admin123' (需要Supabase Edge Function来正确哈希)
    '$2a$10$abcdefghijklmnopqrstuv',
    '系统管理员',
    '13328185024',
    'admin',
    TRUE
) ON CONFLICT (username) DO NOTHING;

-- 初始化系统配置
INSERT INTO system_config (config_key, config_value, config_type, config_group, config_desc, is_public) VALUES
    ('system_name', '"汽车全生态客户管理系统"', 'string', 'basic', '系统名称', TRUE),
    ('system_version', '"V1.0"', 'string', 'basic', '系统版本', TRUE),
    ('company_name', '"蟹老板车险工作室"', 'string', 'basic', '公司名称', TRUE),
    ('contact_phone', '"13328185024"', 'string', 'basic', '联系电话', TRUE),
    ('backup_email', '"589842@qq.com"', 'string', 'backup', '备份接收邮箱', FALSE),
    ('renewal_reminder_days', '[30, 15, 7, 3, 1]', 'json', 'reminder', '续保提醒天数', FALSE),
    ('annual_review_reminder_days', '[30, 15, 7, 3, 1]', 'json', 'reminder', '年审提醒天数', FALSE),
    ('data_retention_days', '365', 'number', 'backup', '数据保留天数', FALSE),
    ('max_upload_size', '5242880', 'number', 'system', '最大上传文件大小(字节)', FALSE)
ON CONFLICT (config_key) DO NOTHING;

-- 初始化保险机构
INSERT INTO insurance_companies (company_code, company_name, short_name, business_scope) VALUES
    ('PICC', '中国人民财产保险股份有限公司', '人保', ARRAY['车险', '非车险']),
    ('CPIC', '中国太平洋财产保险股份有限公司', '太平洋', ARRAY['车险', '非车险']),
    ('平安财险', '平安财产保险股份有限公司', '平安', ARRAY['车险', '非车险']),
    ('国寿财', '中国人寿财产保险股份有限公司', '国寿财', ARRAY['车险', '非车险']),
    ('中华联合', '中华联合财产保险股份有限公司', '中华联合', ARRAY['车险', '非车险']),
    ('阳光财险', '阳光财产保险股份有限公司', '阳光', ARRAY['车险', '非车险']),
    ('大地保险', '大地财产保险股份有限公司', '大地', ARRAY['车险', '非车险']),
    ('太平财险', '太平财产保险股份有限公司', '太平', ARRAY['车险', '非车险'])
ON CONFLICT (company_code) DO NOTHING;

-- 初始化消息模板
INSERT INTO message_templates (template_code, template_name, template_type, template_content) VALUES
    ('renewal_reminder_30', '续保提醒-30天', 'wechat_msg', '尊敬的${customer_name}您好！您的${vehicle_plate}车辆保险将于${policy_end_date}到期，请提前办理续保，如有疑问请联系${agent_name}。'),
    ('renewal_reminder_7', '续保提醒-7天', 'wechat_msg', '【重要提醒】尊敬的${customer_name}，您的${vehicle_plate}车险仅剩${days}天到期！为避免脱保，请尽快联系办理续保。'),
    ('annual_review_reminder', '年审提醒', 'wechat_msg', '尊敬的${customer_name}，您的${vehicle_plate}车辆年审将于${review_date}到期，请提前办理年审业务。'),
    ('payment_success', '支付成功通知', 'wechat_msg', '您好，您的${order_name}已支付成功，金额${amount}元，如有疑问请联系客服。')
ON CONFLICT (template_code) DO NOTHING;
