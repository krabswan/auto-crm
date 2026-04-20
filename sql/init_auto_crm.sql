-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本：V1.0 | 日期：2026-04-19
-- ============================================================

-- ============================================================
-- 1. 核心：客户主表 (customers)
-- ============================================================
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 基础信息
    name TEXT NOT NULL,
    gender TEXT CHECK (gender IN ('男', '女', '其他')),
    id_card TEXT,                    -- 身份证号
    phone TEXT NOT NULL,
    phone_2 TEXT,                     -- 第二联系电话
    email TEXT,
    birthday DATE,
    -- 地址信息
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,                     -- 详细地址
    -- 车辆基础信息（第一位车辆）
    first_plate TEXT,
    first_vin TEXT,
    first_brand TEXT,
    first_model TEXT,
    first_color TEXT,
    first_buy_year INTEGER,
    first_engine TEXT,
    -- 职业信息
    occupation TEXT,
    company_name TEXT,
    -- 来源
    source_from TEXT DEFAULT '自然流量',  -- 自然流量/转介绍/网络推广/合作渠道
    -- 归属
    owner_id UUID,                    -- 归属业务员
    -- 标签
    tags TEXT[],                      -- 数组，如 ['vip', '高净值', '频繁理赔']
    -- 备注
    remark TEXT,
    -- 系统字段（审计用）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE customers IS '客户主表 - 所有模块的数据关联中枢';
CREATE INDEX idx_cust_phone ON customers(phone);
CREATE INDEX idx_cust_plate ON customers(first_plate);
CREATE INDEX idx_cust_owner ON customers(owner_id);
CREATE INDEX idx_cust_deleted ON customers(is_deleted);

-- ============================================================
-- 2. 核心：车辆表 (vehicles)
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    plate TEXT NOT NULL,
    vin TEXT UNIQUE,
    brand TEXT,
    model TEXT,
    color TEXT,
    engine_no TEXT,
    register_date DATE,               -- 注册日期
    buy_date DATE,                   -- 购车日期
    annual_review_month INTEGER,      -- 年审月份（1-12）
    annual_review_day INTEGER,        -- 年审日期（可选）
    fuel_type TEXT,                  -- 汽油/柴油/纯电/混动
    plate_color TEXT,                -- 蓝/黄/绿
    plate_city TEXT,                 -- 车牌城市
    mileage INTEGER DEFAULT 0,        -- 当前里程
    last_maintain_mileage INTEGER,
    last_maintain_date DATE,
    next_maintain_mileage INTEGER,
    next_maintain_date DATE,
    car_status TEXT DEFAULT '正常',  -- 正常/报废/转出/抵押
    is_default BOOLEAN DEFAULT FALSE, -- 是否为默认车辆
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE vehicles IS '车辆表 - 支持一个客户多辆车';
CREATE INDEX idx_veh_plate ON vehicles(plate);
CREATE INDEX idx_veh_customer ON vehicles(customer_id);
CREATE INDEX idx_veh_vin ON vehicles(vin);
CREATE INDEX idx_veh_deleted ON vehicles(is_deleted);

-- ============================================================
-- 3. 模块1：车险保单表 (car_insurance)
-- ============================================================
CREATE TABLE IF NOT EXISTS car_insurance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    policy_no TEXT UNIQUE,           -- 保单号
    company TEXT NOT NULL,            -- 承保公司
    -- 商业险
    biz_type TEXT,                   -- 险种：三者险/车损险/盗抢险/自燃险/玻璃险/划痕险/司机险/乘客险/附加险
    biz_coverage NUMERIC,            -- 保额
    biz_premium NUMERIC,             -- 商业险保费
    biz_deductible NUMERIC,          -- 绝对免赔率
    -- 交强险
    force_premium NUMERIC,           -- 交强险保费
    force_start DATE,
    force_end DATE,
    -- 车船税
    tax_premium NUMERIC,
    -- 合计
    total_premium NUMERIC,
    tax_total NUMERIC,
    -- 佣金
    commission_rate NUMERIC,          -- 佣金比例
    commission_amount NUMERIC,        -- 佣金金额
    net_commission NUMERIC,          -- 净佣金（扣除税点后）
    -- 时间
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 状态
    status TEXT DEFAULT 'active',     -- active/policy_lapse/cancelled
    renewal_status TEXT DEFAULT '待跟进', -- 待跟进/已报价/已成交/流失/放弃
    -- 理赔
    claim_count INTEGER DEFAULT 0,
    claim_amount NUMERIC DEFAULT 0,
    -- 关联
    agent_id UUID,
    agent_name TEXT,
    -- 来源
    source_channel TEXT,             -- 来源渠道
    -- 备注
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE car_insurance IS '车险保单表';
CREATE INDEX idx_car_cust ON car_insurance(customer_id);
CREATE INDEX idx_car_plate ON car_insurance(vehicle_id);
CREATE INDEX idx_car_end ON car_insurance(end_date);
CREATE INDEX idx_car_status ON car_insurance(status);
CREATE INDEX idx_car_deleted ON car_insurance(is_deleted);

-- ============================================================
-- 4. 模块2：非车险保单表 (noncar_insurance)
-- ============================================================
CREATE TABLE IF NOT EXISTS noncar_insurance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    policy_no TEXT UNIQUE,
    insurance_type TEXT NOT NULL,     -- 险种大类
    insurance_subtype TEXT,           -- 险种细分
    company TEXT NOT NULL,
    -- 保障
    coverage_amount NUMERIC,         -- 保额
    premium NUMERIC NOT NULL,        -- 保费
    coverage_period_start DATE,
    coverage_period_end DATE,
    -- 佣金
    commission_rate NUMERIC,
    commission_amount NUMERIC,
    net_commission NUMERIC,
    -- 时间
    sign_date DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- 状态
    status TEXT DEFAULT 'active',
    renewal_status TEXT DEFAULT '待跟进',
    -- 关联
    agent_id UUID,
    agent_name TEXT,
    source_channel TEXT,
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE noncar_insurance IS '非车险保单表 - 意外险/健康险/家财险/责任险等';
CREATE INDEX idx_noncar_cust ON noncar_insurance(customer_id);
CREATE INDEX idx_noncar_type ON noncar_insurance(insurance_type);
CREATE INDEX idx_noncar_end ON noncar_insurance(end_date);
CREATE INDEX idx_noncar_deleted ON noncar_insurance(is_deleted);

-- ============================================================
-- 5. 模块3：年审保养表 (vehicle_services)
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicle_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL,       -- annual_review/年审 | maintain/保养 | repair/维修 | wash/美容 | other/其他
    -- 年审相关
    annual_review_year INTEGER,       -- 年审年份
    annual_review_month INTEGER,
    annual_review_deadline DATE,     -- 年审截止日期
    annual_review_status TEXT DEFAULT '待办理', -- 待办理/办理中/已完成/已过期
    annual_review_result TEXT,        -- 合格/不合格
    annual_review_fee NUMERIC,        -- 年审费用
    annual_review_station TEXT,       -- 年审地点
    annual_review_report TEXT,        -- 年审报告URL
    -- 保养相关
    maintain_type TEXT,              -- 小保养/大保养/专项保养
    maintain_mileage INTEGER,
    maintain_date DATE,
    maintain_fee NUMERIC,
    maintain_items TEXT[],           -- 保养项目数组
    maintain_shop TEXT,              -- 保养商家
    maintain_shop_id UUID,
    next_maintain_mileage INTEGER,
    next_maintain_date DATE,
    -- 维修相关
    repair_type TEXT,                -- 小修/中修/大修/事故维修
    repair_desc TEXT,
    repair_fee NUMERIC,
    repair_start_date DATE,
    repair_end_date DATE,
    repair_status TEXT DEFAULT '待确认',
    repair_shop TEXT,
    repair_shop_id UUID,
    insurance_claim BOOLEAN DEFAULT FALSE,  -- 是否走保险
    insurance_claim_id UUID,
    -- 通用
    status TEXT DEFAULT 'pending',    -- pending/confirmed/in_progress/completed/cancelled
    actual_date DATE,
    actual_fee NUMERIC,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),  -- 评价 1-5星
    rating_remark TEXT,
    -- 关联
    operator_id UUID,
    operator_name TEXT,
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE vehicle_services IS '年审保养表 - 涵盖年审、保养、维修、美容等所有车辆服务';
CREATE INDEX idx_vs_cust ON vehicle_services(customer_id);
CREATE INDEX idx_vs_vehicle ON vehicle_services(vehicle_id);
CREATE INDEX idx_vs_type ON vehicle_services(service_type);
CREATE INDEX idx_vs_status ON vehicle_services(status);
CREATE INDEX idx_vs_deleted ON vehicle_services(is_deleted);

-- ============================================================
-- 6. 模块4：后市场订单表 (after_market_orders)
-- ============================================================
CREATE TABLE IF NOT EXISTS after_market_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    order_no TEXT UNIQUE NOT NULL,
    order_type TEXT NOT NULL,         -- traffic_violation/违章 | rescue/救援 | beauty/美容 | parts/配件 | decoration/改装 | parking/停车 | other/其他
    -- 违章相关
    violation_city TEXT,
    violation_plate TEXT,
    violation_date TIMESTAMPTZ,
    violation_type TEXT,             -- 闯红灯/超速/违停/酒驾等
    violation_location TEXT,
    violation_fee NUMERIC,           -- 罚款金额
    violation_score INTEGER,          -- 扣分
    violation_status TEXT DEFAULT '待处理', -- 待处理/处理中/已处理/已缴纳
    -- 救援相关
    rescue_type TEXT,                -- 拖车/搭电/换胎/送油/开锁
    rescue_location TEXT,
    rescue_lat NUMERIC,
    rescue_lng NUMERIC,
    rescue_start_time TIMESTAMPTZ,
    rescue_end_time TIMESTAMPTZ,
    rescue_fee NUMERIC,
    rescue_provider TEXT,
    -- 美容相关
    beauty_items TEXT[],
    beauty_fee NUMERIC,
    beauty_shop TEXT,
    -- 配件相关
    parts_list JSONB,                -- 配件列表 JSON
    parts_fee NUMERIC,
    -- 改装相关
    decoration_items TEXT[],
    decoration_fee NUMERIC,
    -- 订单金额
    total_amount NUMERIC NOT NULL DEFAULT 0,
    discount_amount NUMERIC DEFAULT 0,
    actual_amount NUMERIC NOT NULL,
    payment_status TEXT DEFAULT 'pending', -- pending/paid/part_paid/refunded
    payment_method TEXT,             -- wechat/alipay/cash/transfer/insurance
    -- 状态
    status TEXT DEFAULT 'pending',   -- pending/confirmed/in_progress/completed/cancelled
    completion_date DATE,
    -- 关联
    operator_id UUID,
    operator_name TEXT,
    shop_id UUID,                    -- 合作商家ID
    shop_name TEXT,
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE after_market_orders IS '汽车后市场订单表 - 违章/救援/美容/配件/改装/停车';
CREATE INDEX idx_am_cust ON after_market_orders(customer_id);
CREATE INDEX idx_am_vehicle ON after_market_orders(vehicle_id);
CREATE INDEX idx_am_type ON after_market_orders(order_type);
CREATE INDEX idx_am_status ON after_market_orders(status);
CREATE INDEX idx_am_deleted ON after_market_orders(is_deleted);

-- ============================================================
-- 7. 模块5：消费金融表 (finance_contracts)
-- ============================================================
CREATE TABLE IF NOT EXISTS finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    contract_no TEXT UNIQUE NOT NULL,
    finance_type TEXT NOT NULL,       -- car_loan/车贷 | mortgage/抵押贷 | guarantee/担保 | lease/融资租赁 | other/其他
    -- 贷款信息
    loan_amount NUMERIC NOT NULL,     -- 贷款总额
    loan_term INTEGER NOT NULL,       -- 贷款期数（月）
    annual_rate NUMERIC NOT NULL,     -- 年利率（%）
    monthly_payment NUMERIC NOT NULL, -- 月供
    total_interest NUMERIC,           -- 总利息
    total_repayment NUMERIC,          -- 总还款额
    grace_period INTEGER DEFAULT 0,   -- 宽限期天数
    -- 还款计划
    repayment_method TEXT,            -- 等额本息/等额本金/先息后本
    repayment_day INTEGER DEFAULT 20, -- 每月还款日
    remaining_principal NUMERIC,      -- 剩余本金
    remaining_terms INTEGER,          -- 剩余期数
    overdue_count INTEGER DEFAULT 0, -- 逾期次数
    overdue_days INTEGER DEFAULT 0,   -- 累计逾期天数
    -- 状态
    loan_status TEXT DEFAULT 'ongoing', -- pending/ongoing/cleared/overdue/default/cancelled
    -- 放款信息
    disbursement_date DATE,
    disbursement_amount NUMERIC,
    disbursement_bank TEXT,
    first_repayment_date DATE,
    -- 担保信息
    guarantee_type TEXT,              -- 信用/抵押/质押/保证
    collateral_type TEXT,             -- 抵押物类型
    collateral_value NUMERIC,         -- 抵押物估值
    guarantee_fee NUMERIC,            -- 担保费
    -- 合作机构
    finance_company TEXT,             -- 金融机构名称
    agent_id UUID,
    agent_name TEXT,
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE finance_contracts IS '汽车消费金融表 - 车贷/抵押贷/担保/融资租赁';
CREATE INDEX idx_fc_cust ON finance_contracts(customer_id);
CREATE INDEX idx_fc_vehicle ON finance_contracts(vehicle_id);
CREATE INDEX idx_fc_type ON finance_contracts(finance_type);
CREATE INDEX idx_fc_status ON finance_contracts(loan_status);
CREATE INDEX idx_fc_deleted ON finance_contracts(is_deleted);

-- ============================================================
-- 8. 还款记录表 (repayment_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS repayment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    finance_contract_id UUID NOT NULL REFERENCES finance_contracts(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    period_no INTEGER NOT NULL,       -- 期次（第几期）
    due_date DATE NOT NULL,          -- 应还日期
    principal NUMERIC NOT NULL,       -- 本金
    interest NUMERIC NOT NULL,        -- 利息
    amount NUMERIC NOT NULL,          -- 应还金额
    actual_date DATE,                -- 实还日期
    actual_principal NUMERIC,
    actual_interest NUMERIC,
    actual_amount NUMERIC,
    status TEXT DEFAULT 'pending',   -- pending/paid/overdue/part_paid/written_off
    overdue_days INTEGER DEFAULT 0,
    penalty_interest NUMERIC DEFAULT 0,
    payment_method TEXT,
    receipt_no TEXT,
    operator_id UUID,
    operator_name TEXT,
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_rr_contract ON repayment_records(finance_contract_id);
CREATE INDEX idx_rr_due ON repayment_records(due_date);
CREATE INDEX idx_rr_status ON repayment_records(status);

-- ============================================================
-- 9. 合作商家表 (partners)
-- ============================================================
CREATE TABLE IF NOT EXISTS partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_name TEXT NOT NULL,
    partner_type TEXT NOT NULL,       -- garage/维修厂 | gas_station/加油站 | beauty_shop/美容店 | parts_shop/配件店 | rescue/救援公司 | insurance/保险公司 | bank/银行 | finance/金融公司 | other/其他
    contact_person TEXT,
    contact_phone TEXT,
    province TEXT,
    city TEXT,
    district TEXT,
    address TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    rating NUMERIC,
    service_items TEXT[],            -- 服务项目
    business_hours TEXT,
    business_license TEXT,
    contract_start DATE,
    contract_end DATE,
    commission_rate NUMERIC,          -- 返佣比例
    settlement_cycle TEXT,            -- 结算周期
    bank_name TEXT,
    bank_account TEXT,
    status TEXT DEFAULT 'active',    -- active/inactive/suspended
    tags TEXT[],
    remark TEXT,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_partner_type ON partners(partner_type);
CREATE INDEX idx_partner_city ON partners(city, district);
CREATE INDEX idx_partner_status ON partners(status);

-- ============================================================
-- 10. 业务跟进记录表 (followups)
-- ============================================================
CREATE TABLE IF NOT EXISTS followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    related_module TEXT NOT NULL,      -- car_insurance/noncar_insurance/vehicle_service/after_market/finance/customers
    related_id UUID,                  -- 关联记录ID
    followup_type TEXT NOT NULL,     -- call/电话 | visit/拜访 | wechat/微信 | sms/短信 | email/邮件 | other/其他
    followup_purpose TEXT,            -- 跟进目的：quote/报价 | negotiate/洽谈 | claim/理赔 | renewal/续保 | cross_sell/交叉销售
    followup_content TEXT NOT NULL,
    next_followup_date DATE,
    next_followup_purpose TEXT,
    result TEXT,                      -- 跟进结果
    attachment_urls TEXT[],
    -- 状态
    status TEXT DEFAULT 'completed', -- pending/completed/cancelled
    -- 关联
    operator_id UUID NOT NULL,
    operator_name TEXT NOT NULL,
    -- 系统字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_fu_cust ON followups(customer_id);
CREATE INDEX idx_fu_type ON followups(followup_type);
CREATE INDEX idx_fu_date ON followups(next_followup_date);

-- ============================================================
-- 11. 审计日志表 (audit_logs)
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL,          -- INSERT/UPDATE/DELETE/SOFT_DELETE/RESTORE
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],             -- 变更的字段列表
    ip_address TEXT,
    user_agent TEXT,
    -- 操作人
    operator_id UUID,
    operator_name TEXT,
    -- 时间
    operated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_al_table ON audit_logs(table_name);
CREATE INDEX idx_al_record ON audit_logs(record_id);
CREATE INDEX idx_al_operator ON audit_logs(operator_id);
CREATE INDEX idx_al_time ON audit_logs(operated_at DESC);

-- ============================================================
-- 12. 系统配置表 (system_configs)
-- ============================================================
CREATE TABLE IF NOT EXISTS system_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key TEXT UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    config_type TEXT DEFAULT 'string', -- string/number/boolean/json/array
    config_group TEXT,                -- 所属分组
    config_desc TEXT,                 -- 配置说明
    is_public BOOLEAN DEFAULT FALSE,  -- 是否公开（网站展示用）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sc_key ON system_configs(config_key);
CREATE INDEX idx_sc_group ON system_configs(config_group);

-- 初始化默认配置
INSERT INTO system_configs (config_key, config_value, config_group, config_desc, is_public) VALUES
('company_info', '{"name":"蟹老板车险工作室","phone":"13328185024","address":"江苏省常州市金坛区","wechat":"","city":"常州金坛"}', 'business', '公司/工作室基本信息', TRUE),
('annual_review_months', '[3,4,5,9,10,11]', 'business', '年审高峰月份', TRUE),
('tags_config', '{"customer":["vip","高净值","频繁理赔","高意向","沉默客户"],"vehicle":["新能源","豪华车","运营车","二手车"],"service":["好评","投诉","回头客"]}', 'tags', '标签配置', FALSE);

-- ============================================================
-- 13. RLS 策略（行级安全）
-- ============================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_insurance ENABLE ROW LEVEL SECURITY;
ALTER TABLE noncar_insurance ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE after_market_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repayment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;

-- 通用策略：只看未删除的数据
CREATE POLICY "view_own_data" ON customers FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON vehicles FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON car_insurance FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON noncar_insurance FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON vehicle_services FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON after_market_orders FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON finance_contracts FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON repayment_records FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON partners FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_own_data" ON followups FOR SELECT USING (is_deleted = FALSE);
CREATE POLICY "view_all" ON audit_logs FOR SELECT USING (TRUE);

-- ============================================================
-- 14. 自动触发器（更新时间戳 + 审计日志）
-- ============================================================

-- 更新时间戳的函数
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 软删除的函数
CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_deleted = TRUE;
    NEW.deleted_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 审计日志的函数
CREATE OR REPLACE FUNCTION write_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    op_type TEXT;
    old_data JSONB;
    new_data JSONB;
    changed TEXT[];
BEGIN
    IF TG_OP = 'INSERT' THEN
        op_type := 'INSERT';
        old_data := NULL;
        new_data := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        op_type := 'UPDATE';
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
        -- 计算变更字段
        SELECT array_agg(key) INTO changed
        FROM jsonb_object_keys(old_data) AS key
        WHERE old_data->>key IS DISTINCT FROM new_data->>key;
    ELSIF TG_OP = 'DELETE' THEN
        op_type := 'DELETE';
        old_data := to_jsonb(OLD);
        new_data := NULL;
    END IF;

    INSERT INTO audit_logs (table_name, record_id, operation, old_data, new_data, changed_fields, operator_id, operator_name)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        op_type,
        old_data,
        new_data,
        changed,
        COALESCE(NEW.created_by, OLD.created_by),
        NULL
    );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为所有表创建更新时间戳触发器
CREATE TRIGGER trg_customers_updated BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_vehicles_updated BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_car_insurance_updated BEFORE UPDATE ON car_insurance FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_noncar_insurance_updated BEFORE UPDATE ON noncar_insurance FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_vehicle_services_updated BEFORE UPDATE ON vehicle_services FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_after_market_updated BEFORE UPDATE ON after_market_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_finance_contracts_updated BEFORE UPDATE ON finance_contracts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_repayment_records_updated BEFORE UPDATE ON repayment_records FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_partners_updated BEFORE UPDATE ON partners FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_followups_updated BEFORE UPDATE ON followups FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 为所有表创建审计日志触发器
CREATE TRIGGER trg_customers_audit AFTER INSERT OR UPDATE OR DELETE ON customers FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_vehicles_audit AFTER INSERT OR UPDATE OR DELETE ON vehicles FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_car_insurance_audit AFTER INSERT OR UPDATE OR DELETE ON car_insurance FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_noncar_insurance_audit AFTER INSERT OR UPDATE OR DELETE ON noncar_insurance FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_vehicle_services_audit AFTER INSERT OR UPDATE OR DELETE ON vehicle_services FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_after_market_audit AFTER INSERT OR UPDATE OR DELETE ON after_market_orders FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_finance_contracts_audit AFTER INSERT OR UPDATE OR DELETE ON finance_contracts FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_repayment_records_audit AFTER INSERT OR UPDATE OR DELETE ON repayment_records FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_partners_audit AFTER INSERT OR UPDATE OR DELETE ON partners FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_followups_audit AFTER INSERT OR UPDATE OR DELETE ON followups FOR EACH ROW EXECUTE FUNCTION write_audit_log();

-- ============================================================
-- 15. 视图：客户360视图（跨模块整合）
-- ============================================================
CREATE OR REPLACE VIEW v_customer_360 AS
SELECT
    c.id,
    c.name,
    c.phone,
    c.first_plate,
    c.first_brand,
    c.first_model,
    c.tags,
    c.source_from,
    c.owner_id,
    -- 车险统计
    COALESCE(ci.total_premium, 0)::NUMERIC as total_car_premium,
    COALESCE(ci.total_commission, 0)::NUMERIC as total_car_commission,
    ci.last_policy_date,
    ci.next_renewal_date,
    ci.policy_count,
    -- 非车险统计
    COALESCE(nci.total_premium, 0)::NUMERIC as total_noncar_premium,
    COALESCE(nci.total_commission, 0)::NUMERIC as total_noncar_commission,
    nci.noncar_policy_count,
    -- 车辆数量
    vc.vehicle_count,
    -- 服务统计
    COALESCE(vs.total_service_fee, 0)::NUMERIC as total_service_fee,
    vs.service_count,
    -- 后市场统计
    COALESCE(am.total_amount, 0)::NUMERIC as total_am_amount,
    am.am_order_count,
    -- 金融统计
    COALESCE(fc.total_loan, 0)::NUMERIC as total_loan,
    fc.loan_count,
    -- 累计贡献
    COALESCE(ci.total_commission, 0) + COALESCE(nci.total_commission, 0) as total_commission,
    c.created_at,
    c.last_followup_at
FROM customers c
LEFT JOIN (
    SELECT customer_id,
           SUM(total_premium) as total_premium,
           SUM(commission_amount) as total_commission,
           MAX(end_date) as next_renewal_date,
           MAX(sign_date) as last_policy_date,
           COUNT(*) as policy_count
    FROM car_insurance
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) ci ON ci.customer_id = c.id
LEFT JOIN (
    SELECT customer_id,
           SUM(premium) as total_premium,
           SUM(commission_amount) as total_commission,
           COUNT(*) as noncar_policy_count
    FROM noncar_insurance
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) nci ON nci.customer_id = c.id
LEFT JOIN (
    SELECT customer_id,
           COUNT(*) as vehicle_count
    FROM vehicles
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) vc ON vc.customer_id = c.id
LEFT JOIN (
    SELECT customer_id,
           SUM(actual_fee) as total_service_fee,
           COUNT(*) as service_count
    FROM vehicle_services
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) vs ON vs.customer_id = c.id
LEFT JOIN (
    SELECT customer_id,
           SUM(actual_amount) as total_amount,
           COUNT(*) as am_order_count
    FROM after_market_orders
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) am ON am.customer_id = c.id
LEFT JOIN (
    SELECT customer_id,
           SUM(loan_amount) as total_loan,
           COUNT(*) as loan_count
    FROM finance_contracts
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) fc ON fc.customer_id = c.id
LEFT JOIN (
    SELECT customer_id,
           MAX(created_at) as last_followup_at
    FROM followups
    WHERE is_deleted = FALSE
    GROUP BY customer_id
) fu ON fu.customer_id = c.id
WHERE c.is_deleted = FALSE;

-- ============================================================
-- 16. 视图：待办事项汇总（所有模块待办）
-- ============================================================
CREATE OR REPLACE VIEW v_all_todos AS
-- 车险续保待办
SELECT 'car_renewal' as todo_type, '车险续保' as module, c.name, c.phone,
       v.plate, ci.end_date as due_date,
       '车险将于 ' || ci.end_date || ' 到期，请及时跟进' as todo_desc,
       ci.renewal_status as status, ci.id as related_id
FROM car_insurance ci
JOIN customers c ON c.id = ci.customer_id
JOIN vehicles v ON v.id = ci.vehicle_id
WHERE ci.is_deleted = FALSE AND ci.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'

UNION ALL

-- 年审待办
SELECT 'annual_review', '年审保养', c.name, c.phone,
       vs.plate, vs.annual_review_deadline,
       '年审将于 ' || vs.annual_review_deadline || ' 到期' as todo_desc,
       vs.annual_review_status, vs.id
FROM vehicle_services vs
JOIN customers c ON c.id = vs.customer_id
WHERE vs.is_deleted = FALSE AND vs.service_type = 'annual_review'
  AND vs.annual_review_deadline BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'

UNION ALL

-- 保养待办
SELECT 'maintain', '年审保养', c.name, c.phone,
       vs.plate, vs.next_maintain_date,
       '建议保养日期 ' || vs.next_maintain_date as todo_desc,
       vs.status, vs.id
FROM vehicle_services vs
JOIN customers c ON c.id = vs.customer_id
WHERE vs.is_deleted = FALSE AND vs.service_type = 'maintain'
  AND vs.next_maintain_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'

UNION ALL

-- 跟进待办
SELECT 'followup', '客户跟进', c.name, c.phone,
       NULL as plate, fu.next_followup_date,
       '计划跟进：' || fu.next_followup_purpose as todo_desc,
       fu.status, fu.id
FROM followups fu
JOIN customers c ON c.id = fu.customer_id
WHERE fu.is_deleted = FALSE AND fu.next_followup_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'

UNION ALL

-- 非车险续保待办
SELECT 'noncar_renewal', '非车险续保', c.name, c.phone,
       NULL as plate, ni.end_date,
       '非车险（' || ni.insurance_type || '）将于 ' || ni.end_date || ' 到期' as todo_desc,
       ni.renewal_status, ni.id
FROM noncar_insurance ni
JOIN customers c ON c.id = ni.customer_id
WHERE ni.is_deleted = FALSE AND ni.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'

UNION ALL

-- 车贷还款待办
SELECT 'loan_repayment', '汽车金融', c.name, c.phone,
       NULL as plate, rr.due_date,
       '车贷第 ' || rr.period_no || ' 期还款，月供 ' || rr.amount || ' 元' as todo_desc,
       rr.status, rr.id
FROM repayment_records rr
JOIN customers c ON c.id = rr.customer_id
WHERE rr.is_deleted = FALSE AND rr.status = 'pending'
  AND rr.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'

ORDER BY due_date;
