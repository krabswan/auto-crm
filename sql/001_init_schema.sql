-- ============================================================
-- 汽车全生态客户管理系统 - 数据库初始化Schema
-- 版本：V1.0 | 日期：2026-04-19 | 作者：痞老板
-- 说明：完整数据库Schema，包含所有模块的表、触发器、函数和RLS策略
-- ============================================================

-- ============================================================
-- 第一部分：枚举类型定义
-- ============================================================

-- 客户类型
CREATE TYPE customer_type AS ENUM (
    '个人',
    '企业',
    '个体工商户'
);

-- 客户来源
CREATE TYPE customer_source AS ENUM (
    '自然增长',
    '转介绍',
    '电话营销',
    '网络推广',
    '合作渠道',
    '老客户复购',
    '其他'
);

-- 客户状态
CREATE TYPE customer_status AS ENUM (
    '潜在',
    '意向',
    '成交',
    '流失',
    '休眠'
);

-- 险种类型
CREATE TYPE insurance_category AS ENUM (
    '交强险',
    '商业险',
    '车上人员险',
    '盗抢险',
    '自燃险',
    '玻璃险',
    '划痕险',
    '不计免赔',
    '第三者责任险',
    '车损险'
);

-- 付款方式
CREATE TYPE payment_method AS ENUM (
    '全额一次性',
    '分期月付',
    '分期季付',
    '分期年付',
    '银行转账',
    '微信支付',
    '支付宝',
    '现金'
);

-- 支付状态
CREATE TYPE payment_status AS ENUM (
    '待支付',
    '部分支付',
    '已支付',
    '已逾期',
    '已退款',
    '已取消'
);

-- 服务状态
CREATE TYPE service_status AS ENUM (
    '待处理',
    '处理中',
    '已完成',
    '已取消',
    '已失败'
);

-- 审批状态
CREATE TYPE approval_status AS ENUM (
    '草稿',
    '待审批',
    '审批中',
    '已通过',
    '已拒绝',
    '已撤回'
);

-- 角色类型
CREATE TYPE user_role AS ENUM (
    '超级管理员',
    '管理员',
    '经理',
    '业务员',
    '客服',
    '财务',
    '查看者'
);

-- 性别
CREATE TYPE gender_type AS ENUM (
    '男',
    '女',
    '未知'
);

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM (
    '正常',
    '年审到期',
    '保险到期',
    '已过户',
    '已报废',
    '已脱保'
);

-- 操作类型（审计日志）
CREATE TYPE audit_action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'SELECT',
    'LOGIN',
    'LOGOUT',
    'EXPORT',
    'IMPORT'
);

-- 服务类型（年审保养）
CREATE TYPE service_type_maintenance AS ENUM (
    '年审',
    '季审',
    '月检',
    '小保养',
    '大保养',
    '轮胎更换',
    '刹车保养',
    '电瓶更换',
    '空调保养',
    '其他'
);

-- 服务类型（后市场）
CREATE TYPE service_type_aftermarket AS ENUM (
    '违章查询',
    '道路救援',
    '美容洗车',
    '贴膜镀晶',
    '改装升级',
    '配件更换',
    '喷漆钣金',
    '其他'
);

-- 金融产品类型
CREATE TYPE finance_product_type AS ENUM (
    '车贷',
    '信用贷',
    '抵押贷',
    '融资租赁',
    '担保服务'
);

-- 贷款状态
CREATE TYPE loan_status AS ENUM (
    '申请中',
    '审批中',
    '已放款',
    '还款中',
    '已结清',
    '已逾期',
    '已坏账'
);

-- ============================================================
-- 第二部分：公共审计字段函数（所有表通用）
-- ============================================================

-- 审计字段注释说明：
-- created_at     创建时间
-- created_by     创建人ID（关联auth.users）
-- updated_at     最后更新时间
-- updated_by     最后更新人ID
-- version        版本号（乐观锁）
-- is_deleted     软删除标记
-- deleted_at     删除时间
-- deleted_by     删除人ID

-- ============================================================
-- 第三部分：用户与权限表
-- ============================================================

-- 用户表（扩展Supabase Auth用户）
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    display_name TEXT NOT NULL,
    phone TEXT UNIQUE,
    email TEXT UNIQUE,
    avatar_url TEXT,
    role user_role NOT NULL DEFAULT '业务员',
    employee_id TEXT UNIQUE,           -- 员工工号
    department TEXT,                    -- 部门
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    CONSTRAINT phone_format CHECK (phone ~ '^[0-9]{11}$'),
    CONSTRAINT username_length CHECK (char_length(username) >= 3)
);

-- 用户登录历史
CREATE TABLE IF NOT EXISTS public.user_login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    login_at TIMESTAMPTZ DEFAULT NOW(),
    login_ip TEXT,
    login_device TEXT,
    login_location TEXT,
    login_status TEXT DEFAULT '成功',
    logout_at TIMESTAMPTZ
);

-- 权限表
CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,          -- 权限代码，如 'car_policy_view'
    name TEXT NOT NULL,                -- 权限名称
    description TEXT,
    module TEXT NOT NULL,              -- 所属模块
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT code_format CHECK (code ~ '^[a-z_]+$')
);

-- 角色权限关联表
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name user_role NOT NULL,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_name, permission_id)
);

-- ============================================================
-- 第四部分：核心客户中心（统一客户表）
-- ============================================================

CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息
    customer_code TEXT UNIQUE NOT NULL,  -- 客户编码（自动生成）
    customer_type customer_type NOT NULL DEFAULT '个人',
    customer_name TEXT NOT NULL,          -- 客户姓名/名称
    gender gender_type DEFAULT '未知',
    id_card TEXT,                         -- 身份证号
    id_card_encrypted TEXT,               -- 加密存储的身份证号
    birth_date DATE,
    age INTEGER GENERATED ALWAYS AS (
        CASE WHEN birth_date IS NOT NULL 
        THEN floor(extract(days from current_date - birth_date) / 365.25)::INTEGER 
        ELSE NULL END
    ) STORED,
    
    -- 联系信息
    phone_primary TEXT NOT NULL,          -- 主手机号
    phone_secondary TEXT,                -- 备用手机号
    wechat_id TEXT,                       -- 微信号
    email TEXT,
    
    -- 地址信息
    province TEXT,
    city TEXT,
    district TEXT,
    address_detail TEXT,                 -- 详细地址
    address_full TEXT GENERATED ALWAYS AS (
        trim(both '' from coalesce(province,'') || coalesce(city,'') || coalesce(district,'') || coalesce(address_detail,''))
    ) STORED,
    
    -- 客户画像
    source customer_source DEFAULT '自然增长',
    source_detail TEXT,                  -- 来源详情
    birthday DATE,                       -- 生日（可能不同于身份证上的出生日期）
    occupation TEXT,                      -- 职业
    annual_income_range TEXT,            -- 年收入区间
    education_level TEXT,                -- 学历
    
    -- 客户价值
    customer_status customer_status DEFAULT '潜在',
    customer_level TEXT DEFAULT 'C级',   -- A/B/C级客户
    total_transaction_amount DECIMAL(15,2) DEFAULT 0,  -- 累计交易金额
    total_transaction_count INTEGER DEFAULT 0,           -- 累计交易次数
    first_transaction_date DATE,         -- 首次交易日期
    last_transaction_date DATE,          -- 最近交易日期
    days_since_last_transaction INTEGER GENERATED ALWAYS AS (
        CASE WHEN last_transaction_date IS NOT NULL 
        THEN (current_date - last_transaction_date)::INTEGER 
        ELSE NULL END
    ) STORED,
    
    -- 客户评分（0-100）
    customer_score INTEGER DEFAULT 50,
    customer_tags TEXT[],                -- 客户标签数组
    
    -- 客户经理
    owner_id UUID REFERENCES public.user_profiles(id),  -- 负责的业务员
    owner_name TEXT,                     -- 冗余字段，方便查询
    
    -- 关联车辆
    has_vehicle BOOLEAN DEFAULT FALSE,   -- 是否有车辆信息
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- 约束
    CONSTRAINT phone_primary_format CHECK (phone_primary ~ '^[0-9]{11}$'),
    CONSTRAINT id_card_length CHECK (char_length(COALESCE(id_card,'')) = 18 OR char_length(COALESCE(id_card,'')) = 0),
    CONSTRAINT customer_score_range CHECK (customer_score >= 0 AND customer_score <= 100)
);

-- 客户敏感字段加密函数
CREATE OR REPLACE FUNCTION public.encrypt_sensitive_field(text)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(supabase_crypto.encrypt(convert_to($1, 'utf8'), current_setting('app.encryption_key')::bytea, 'aes-256-gcm'), 'base64');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 客户敏感字段解密函数
CREATE OR REPLACE FUNCTION public.decrypt_sensitive_field(text)
RETURNS TEXT AS $$
BEGIN
    RETURN convert_from(supabase_crypto.decrypt(decode($1, 'base64'), current_setting('app.encryption_key')::bytea, 'aes-256-gcm'), 'utf8');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 客户编码自动生成触发器
CREATE OR REPLACE FUNCTION public.generate_customer_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_code IS NULL OR NEW.customer_code = '' THEN
        NEW.customer_code := 'C' || to_char(NOW(), 'YYYYMMDD') || 
                              substr(upper(md5(random()::text)), 1, 6);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_customer_code
    BEFORE INSERT ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.generate_customer_code();

-- ============================================================
-- 第五部分：车辆信息表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    
    -- 车辆基础信息
    plate_number TEXT NOT NULL,          -- 车牌号
    plate_province TEXT,                -- 车牌省份
    plate_city TEXT,                     -- 车牌城市
    vehicle_type TEXT NOT NULL,          -- 车辆类型（轿车/SUV/货车等）
    brand TEXT,                          -- 品牌
    series TEXT,                         -- 车系
    model TEXT,                          -- 车型
    model_year INTEGER,                  -- 年款
    vin TEXT UNIQUE NOT NULL,           -- 车架号（唯一）
    vin_encrypted TEXT,                  -- 加密存储的车架号
    engine_number TEXT,                  -- 发动机号
    engine_number_encrypted TEXT,        -- 加密存储的发动机号
    
    -- 车辆参数
    color TEXT,                          -- 颜色
    fuel_type TEXT,                      -- 燃料类型（汽油/柴油/电动/混动）
    transmission TEXT,                   -- 变速箱（手动/自动）
    displacement DECIMAL(3,1),          -- 排量（L）
    power_kw INTEGER,                   -- 功率（kW）
    emission_standard TEXT,              -- 排放标准
    
    -- 使用信息
    purchase_date DATE,                 -- 购买日期
    registration_date DATE,              -- 注册日期
    manufacture_date DATE,               -- 生产日期
    mileage DECIMAL(12,2) DEFAULT 0,     -- 行驶里程（公里）
    usage_type TEXT,                    -- 使用性质（家用/商用/运营）
    owner_name TEXT,                    -- 车主姓名
    owner_phone TEXT,                   -- 车主电话
    
    -- 状态信息
    vehicle_status vehicle_status DEFAULT '正常',
    insurance_expire_date DATE,         -- 保险到期日期
    inspection_expire_date DATE,        -- 年审到期日期
    
    -- 关联计数（冗余，方便查询）
    policy_count INTEGER DEFAULT 0,
    total_premium DECIMAL(15,2) DEFAULT 0,
    last_policy_date DATE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- 约束
    CONSTRAINT vin_length CHECK (char_length(vin) = 17 OR char_length(vin) = 0)
);

-- 车牌号自动格式化触发器
CREATE OR REPLACE FUNCTION public.format_plate_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.plate_number := upper(replace(NEW.plate_number, ' ', ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_format_plate_number
    BEFORE INSERT OR UPDATE ON public.vehicles
    FOR EACH ROW EXECUTE FUNCTION public.format_plate_number();

-- VIN码自动格式化触发器
CREATE OR REPLACE FUNCTION public.format_vin()
RETURNS TRIGGER AS $$
BEGIN
    NEW.vin := upper(replace(replace(NEW.vin, ' ', ''), 'O', '0'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_format_vin
    BEFORE INSERT OR UPDATE ON public.vehicles
    FOR EACH ROW EXECUTE FUNCTION public.format_vin();

-- 客户-车辆关联触发器
CREATE OR REPLACE FUNCTION public.update_customer_vehicle_flag()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.customers 
    SET has_vehicle = TRUE,
        updated_at = NOW()
    WHERE id = NEW.customer_id AND has_vehicle = FALSE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_customer_vehicle_flag
    AFTER INSERT ON public.vehicles
    FOR EACH ROW EXECUTE FUNCTION public.update_customer_vehicle_flag();

-- ============================================================
-- 第六部分：车险保单表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.car_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_number TEXT UNIQUE NOT NULL,  -- 保单号
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES public.user_profiles(id),  -- 业务员
    
    -- 承保信息
    insurance_company TEXT NOT NULL,     -- 保险公司
    insurance_company_code TEXT,         -- 保险公司代码
    product_name TEXT,                   -- 产品名称
    policy_type TEXT,                    -- 保单类型（续保/新保/转保）
    
    -- 保险期间
    start_date DATE NOT NULL,           -- 生效日期
    end_date DATE NOT NULL,             -- 到期日期
    insurance_period INTEGER GENERATED ALWAYS AS (
        (end_date - start_date)::INTEGER
    ) STORED,
    
    -- 险种信息（JSONB存储多险种）
    coverage_details JSONB DEFAULT '[]'::jsonb,
    -- 示例: [{"category": "交强险", "premium": 950, "coverage": 122000}, ...]
    
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL,
    compulsory_premium DECIMAL(10,2),   -- 交强险保费
    commercial_premium DECIMAL(10,2),   -- 商业险保费
    tax_amount DECIMAL(10,2),          -- 车船税
    
    -- 佣金信息
    commission_rate DECIMAL(5,4),       -- 佣金比例
    commission_amount DECIMAL(12,2),   -- 佣金金额
    commission_received DECIMAL(12,2) DEFAULT 0,  -- 已收佣金
    commission_status TEXT DEFAULT '待结算',  -- 待结算/已结算/部分结算
    
    -- 付款信息
    payment_method payment_method,
    payment_status payment_status DEFAULT '待支付',
    payment_due_date DATE,
    paid_amount DECIMAL(12,2) DEFAULT 0,
    paid_at TIMESTAMPTZ,
    
    -- 状态
    is_renewal BOOLEAN DEFAULT FALSE,   -- 是否续保
    previous_policy_id UUID,            -- 上年保单ID
    renewal_source TEXT,                -- 续保来源
    
    -- 归属
    company_branch TEXT,                -- 支公司/营业部
    agent_name TEXT,                   -- 代理人姓名
    
    -- 备注
    remarks TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- 约束
    CONSTRAINT end_after_start CHECK (end_date > start_date),
    CONSTRAINT positive_premium CHECK (total_premium >= 0)
);

-- 保单号自动生成触发器
CREATE OR REPLACE FUNCTION public.generate_policy_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.policy_number IS NULL OR NEW.policy_number = '' THEN
        NEW.policy_number := 'C' || to_char(NOW(), 'YYYY') || 
                             lpad(random_between(10000000, 99999999)::text, 8, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.random_between(min_val INTEGER, max_val INTEGER)
RETURNS INTEGER AS $$
BEGIN
    RETURN floor(random() * (max_val - min_val + 1) + min_val)::INTEGER;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_policy_number
    BEFORE INSERT ON public.car_policies
    FOR EACH ROW EXECUTE FUNCTION public.generate_policy_number();

-- 车辆保单统计触发器
CREATE OR REPLACE FUNCTION public.update_vehicle_policy_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.vehicles SET
            policy_count = policy_count + 1,
            total_premium = total_premium + NEW.total_premium,
            last_policy_date = NEW.start_date,
            updated_at = NOW()
        WHERE id = NEW.vehicle_id;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE public.vehicles SET
            total_premium = total_premium - OLD.total_premium + NEW.total_premium,
            updated_at = NOW()
        WHERE id = NEW.vehicle_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.vehicles SET
            policy_count = GREATEST(0, policy_count - 1),
            total_premium = GREATEST(0, total_premium - OLD.total_premium),
            updated_at = NOW()
        WHERE id = OLD.vehicle_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_vehicle_policy_stats
    AFTER INSERT OR UPDATE OR DELETE ON public.car_policies
    FOR EACH ROW EXECUTE FUNCTION public.update_vehicle_policy_stats();

-- 客户交易统计触发器
CREATE OR REPLACE FUNCTION public.update_customer_transaction_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.payment_status = '已支付' THEN
        UPDATE public.customers SET
            total_transaction_amount = total_transaction_amount + NEW.total_premium,
            total_transaction_count = total_transaction_count + 1,
            last_transaction_date = COALESCE(NEW.paid_at, NOW())::date,
            first_transaction_date = COALESCE(first_transaction_date, NEW.paid_at::date),
            updated_at = NOW()
        WHERE id = NEW.customer_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_customer_transaction_stats
    AFTER INSERT ON public.car_policies
    FOR EACH ROW EXECUTE FUNCTION public.update_customer_transaction_stats();

-- ============================================================
-- 第七部分：非车险保单表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.noncar_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_number TEXT UNIQUE NOT NULL,
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    related_car_policy_id UUID REFERENCES public.car_policies(id) ON DELETE SET NULL,  -- 关联车险保单（交叉销售）
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 承保信息
    insurance_company TEXT NOT NULL,
    insurance_type TEXT NOT NULL,       -- 非车险类型（意外险/健康险/家财险/责任险等）
    insurance_type_code TEXT,          -- 险种代码
    product_name TEXT,
    policy_type TEXT DEFAULT '新保',
    
    -- 投保人/被保险人信息
    policy_holder_name TEXT,           -- 投保人姓名
    policy_holder_phone TEXT,
    policy_holder_id_card TEXT,
    insured_name TEXT,                 -- 被保险人姓名
    insured_phone TEXT,
    insured_id_card TEXT,
    
    -- 保险期间
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- 保费信息
    total_premium DECIMAL(12,2) NOT NULL,
    sum_insured DECIMAL(15,2),         -- 保额
    
    -- 佣金
    commission_rate DECIMAL(5,4),
    commission_amount DECIMAL(12,2),
    commission_received DECIMAL(12,2) DEFAULT 0,
    commission_status TEXT DEFAULT '待结算',
    
    -- 付款
    payment_method payment_method,
    payment_status payment_status DEFAULT '待支付',
    payment_due_date DATE,
    paid_amount DECIMAL(12,2) DEFAULT 0,
    paid_at TIMESTAMPTZ,
    
    -- 保单详情（JSONB）
    policy_details JSONB DEFAULT '{}'::jsonb,
    
    -- 备注
    remarks TEXT,
    
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

CREATE TRIGGER trg_generate_noncar_policy_number
    BEFORE INSERT ON public.noncar_policies
    FOR EACH ROW EXECUTE FUNCTION public.generate_policy_number();

-- ============================================================
-- 第八部分：年审保养表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_number TEXT UNIQUE NOT NULL,
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 服务类型
    service_type service_type_maintenance NOT NULL,
    service_type_detail TEXT,           -- 服务类型详情
    
    -- 服务信息
    service_provider TEXT,              -- 服务商/维修厂
    service_provider_phone TEXT,        -- 服务商电话
    service_provider_address TEXT,      -- 服务商地址
    
    -- 服务时间
    service_date DATE NOT NULL,
    service_time TIME,
    next_service_date DATE,            -- 下次服务日期
    next_service_mileage DECIMAL(12,2), -- 下次服务里程
    
    -- 服务内容（JSONB）
    service_items JSONB DEFAULT '[]'::jsonb,
    -- 示例: [{"name": "更换机油", "quantity": 1, "price": 300}, ...]
    
    -- 费用信息
    total_amount DECIMAL(10,2) NOT NULL,
    material_cost DECIMAL(10,2) DEFAULT 0,
    labor_cost DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    actual_paid DECIMAL(10,2),
    
    -- 付款
    payment_method payment_method,
    payment_status payment_status DEFAULT '待支付',
    paid_amount DECIMAL(10,2) DEFAULT 0,
    paid_at TIMESTAMPTZ,
    
    -- 车辆状态（服务后）
    mileage_at_service DECIMAL(12,2),  -- 服务时里程
    overall_condition TEXT,             -- 整体车况描述
    
    -- 备注
    remarks TEXT,
    
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

-- 服务记录号自动生成
CREATE OR REPLACE FUNCTION public.generate_maintenance_record_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.record_number IS NULL OR NEW.record_number = '' THEN
        NEW.record_number := 'M' || to_char(NOW(), 'YYYYMM') || 
                              lpad(random_between(10000, 99999)::text, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_maintenance_record_number
    BEFORE INSERT ON public.maintenance_records
    FOR EACH ROW EXECUTE FUNCTION public.generate_maintenance_record_number();

-- ============================================================
-- 第九部分：年审到期提醒表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.inspection_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 年审信息
    inspection_type TEXT NOT NULL,     -- 年审类型（上线/年审/环保）
    inspection_date DATE NOT NULL,      -- 年审日期
    inspection_deadline DATE,          -- 最晚上检日期
    
    -- 提醒状态
    reminder_status TEXT DEFAULT '待提醒',  -- 待提醒/已提醒/已完成/已过期
    reminder_count INTEGER DEFAULT 0,   -- 提醒次数
    last_reminder_at TIMESTAMPTZ,
    
    -- 年审结果
    inspection_result TEXT,            -- 通过/未通过/需要复检
    inspection_certificate_no TEXT,    -- 检验合格证编号
    next_inspection_date DATE,         -- 下次年审日期
    
    -- 办理信息
    handling_status TEXT DEFAULT '未办理',
    handling_deadline DATE,
    handling_fee DECIMAL(10,2),
    handling_location TEXT,
    
    -- 备注
    remarks TEXT,
    
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

-- ============================================================
-- 第十部分：汽车后市场服务表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.aftermarket_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT UNIQUE NOT NULL,
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 订单信息
    service_type service_type_aftermarket NOT NULL,
    service_items JSONB DEFAULT '[]'::jsonb,
    
    -- 服务商
    service_provider TEXT,
    service_provider_phone TEXT,
    service_provider_address TEXT,
    
    -- 时间
    order_date TIMESTAMPTZ DEFAULT NOW(),
    service_date DATE,
    service_time TIME,
    completion_date TIMESTAMPTZ,
    
    -- 费用
    total_amount DECIMAL(10,2) NOT NULL,
    material_cost DECIMAL(10,2) DEFAULT 0,
    service_cost DECIMAL(10,2) DEFAULT 0,
    platform_fee DECIMAL(10,2) DEFAULT 0,  -- 平台服务费
    discount_amount DECIMAL(10,2) DEFAULT 0,
    actual_paid DECIMAL(10,2),
    
    -- 付款
    payment_method payment_method,
    payment_status payment_status DEFAULT '待支付',
    paid_amount DECIMAL(10,2) DEFAULT 0,
    paid_at TIMESTAMPTZ,
    
    -- 状态
    order_status service_status DEFAULT '待处理',
    fulfillment_status TEXT,
    
    -- 评价
    rating INTEGER,                    -- 1-5星
    rating_comment TEXT,
    rating_at TIMESTAMPTZ,
    
    -- 备注
    remarks TEXT,
    
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

-- 订单号自动生成
CREATE OR REPLACE FUNCTION public.generate_aftermarket_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
        NEW.order_number := 'A' || to_char(NOW(), 'YYYYMMDD') || 
                             lpad(random_between(10000, 99999)::text, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_aftermarket_order_number
    BEFORE INSERT ON public.aftermarket_orders
    FOR EACH ROW EXECUTE FUNCTION public.generate_aftermarket_order_number();

-- ============================================================
-- 第十一部分：违章记录表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.violation_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 违章信息
    violation_code TEXT NOT NULL,       -- 违章代码
    violation_type TEXT,                -- 违章类型
    violation_description TEXT,         -- 违章描述
    violation_location TEXT NOT NULL,   -- 违章地点
    violation_date TIMESTAMPTZ NOT NULL, -- 违章时间
    
    -- 处罚信息
    fine_amount DECIMAL(10,2),         -- 罚款金额
    penalty_points INTEGER DEFAULT 0,  -- 扣分
    detention_days INTEGER,            -- 拘留天数
    other_penalty TEXT,                -- 其他处罚
    
    -- 处理状态
    handling_status TEXT DEFAULT '未处理',  -- 未处理/处理中/已处理/已缴费/已过期
    handling_date DATE,
    handling_location TEXT,
    receipt_number TEXT,               -- 处理单号
    
    -- 费用分摊
    total_cost DECIMAL(10,2),          -- 总费用（含手续费）
    platform_fee DECIMAL(10,2),        -- 平台服务费
    actual_cost DECIMAL(10,2),         -- 实际费用
    
    -- 来源
    data_source TEXT,                  -- 数据来源（交管/第三方）
    source_update_at TIMESTAMPTZ,      -- 数据更新时间
    
    -- 备注
    remarks TEXT,
    
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

-- ============================================================
-- 第十二部分：汽车消费金融表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.finance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_number TEXT UNIQUE NOT NULL,
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 金融产品
    product_type finance_product_type NOT NULL,
    product_name TEXT,
    lender_name TEXT NOT NULL,         -- 出借方/金融机构
    lender_type TEXT,                   -- 银行/消费金融公司/担保公司
    
    -- 合同信息
    contract_date DATE NOT NULL,
    contract_amount DECIMAL(15,2) NOT NULL,  -- 合同金额
    loan_amount DECIMAL(15,2) NOT NULL,       -- 贷款金额
    down_payment DECIMAL(15,2) NOT NULL,      -- 首付款
    down_payment_rate DECIMAL(5,4),           -- 首付比例
    
    -- 还款信息
    loan_term INTEGER NOT NULL,         -- 贷款期限（月）
    interest_rate DECIMAL(7,4) NOT NULL, -- 年利率
    monthly_payment DECIMAL(12,2) NOT NULL,  -- 月还款额
    total_interest DECIMAL(15,2),       -- 总利息
    total_repayment DECIMAL(15,2),     -- 总还款额
    
    -- 贷款状态
    loan_status loan_status DEFAULT '申请中',
    start_date DATE,                   -- 开始还款日期
    end_date DATE,                     -- 结束还款日期
    
    -- 还款计划（JSONB）
    repayment_schedule JSONB DEFAULT '[]'::jsonb,
    -- 示例: [{"period": 1, "due_date": "2026-05-01", "principal": 5000, "interest": 500, "balance": 450000}, ...]
    
    -- 逾期信息
    overdue_count INTEGER DEFAULT 0,   -- 逾期次数
    overdue_days INTEGER DEFAULT 0,    -- 当前逾期天数
    overdue_amount DECIMAL(12,2) DEFAULT 0,  -- 逾期金额
    
    -- 担保信息
    collateral_type TEXT,              -- 抵押物类型
    collateral_value DECIMAL(15,2),    -- 抵押物价值
    guarantor_name TEXT,              -- 担保人
    guarantor_phone TEXT,             -- 担保人电话
    guarantor_id_card TEXT,           -- 担保人身份证
    
    -- GPS信息
    has_gps BOOLEAN DEFAULT FALSE,
    gps_device_no TEXT,
    gps_provider TEXT,
    gps_install_date DATE,
    
    -- 提前还款
    early_repayment_allowed BOOLEAN DEFAULT TRUE,
    early_repayment_fee DECIMAL(10,2), -- 提前还款违约金
    early_repayment_date DATE,
    early_repayment_amount DECIMAL(15,2),
    
    -- 合同附件（JSONB存储文件URL）
    attachments JSONB DEFAULT '[]'::jsonb,
    
    -- 备注
    remarks TEXT,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- 约束
    CONSTRAINT positive_loan CHECK (loan_amount > 0),
    CONSTRAINT positive_term CHECK (loan_term > 0),
    CONSTRAINT positive_rate CHECK (interest_rate >= 0)
);

-- 合同号自动生成
CREATE OR REPLACE FUNCTION public.generate_finance_contract_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.contract_number IS NULL OR NEW.contract_number = '' THEN
        NEW.contract_number := 'F' || to_char(NOW(), 'YYYYMM') || 
                                lpad(random_between(100000, 999999)::text, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_finance_contract_number
    BEFORE INSERT ON public.finance_contracts
    FOR EACH ROW EXECUTE FUNCTION public.generate_finance_contract_number();

-- ============================================================
-- 第十三部分：还款记录表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.loan_repayments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 关联信息
    finance_contract_id UUID NOT NULL REFERENCES public.finance_contracts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    owner_id UUID REFERENCES public.user_profiles(id),
    
    -- 期次信息
    period INTEGER NOT NULL,           -- 期次
    due_date DATE NOT NULL,            -- 应还日期
    payment_date DATE,                 -- 实还日期
    
    -- 金额
    principal_due DECIMAL(15,2) NOT NULL,    -- 应还本金
    interest_due DECIMAL(15,2) NOT NULL,     -- 应还利息
    total_due DECIMAL(15,2) GENERATED ALWAYS AS (principal_due + interest_due) STORED,
    principal_paid DECIMAL(15,2) DEFAULT 0,
    interest_paid DECIMAL(15,2) DEFAULT 0,
    total_paid DECIMAL(15,2) DEFAULT 0,
    penalty_interest DECIMAL(12,2) DEFAULT 0,  -- 罚息
    
    -- 状态
    payment_status TEXT DEFAULT '待还',  -- 待还/部分还/已还/逾期
    is_overdue BOOLEAN DEFAULT FALSE,
    overdue_days INTEGER DEFAULT 0,
    
    -- 还款方式
    payment_method payment_method,
    transaction_no TEXT,               -- 交易流水号
    
    -- 备注
    remarks TEXT,
    
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

-- ============================================================
-- 第十四部分：客户跟进记录表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    followup_number TEXT UNIQUE NOT NULL,
    
    -- 关联信息
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    related_policy_id UUID,             -- 关联保单（车险或非车险）
    owner_id UUID NOT NULL REFERENCES public.user_profiles(id),
    
    -- 跟进信息
    followup_type TEXT NOT NULL,       -- 跟进类型（电话/微信/面谈/短信/其他）
    followup_purpose TEXT,             -- 跟进目的
    followup_content TEXT NOT NULL,    -- 跟进内容
    followup_result TEXT,              -- 跟进结果
    
    -- 意向评估
    customer_intent TEXT DEFAULT '待评估',  -- 高/中/低/无意向
    next_followup_date DATE,           -- 下次跟进日期
    next_followup_purpose TEXT,        -- 下次跟进目的
    
    -- 状态
    followup_status TEXT DEFAULT '进行中',  -- 进行中/已成交/已流失/待定
    
    -- 来源
    source_module TEXT,                -- 来源模块（car_policy/noncar/maintenance/aftermarket/finance）
    
    -- 附件（JSONB存储附件URL）
    attachments JSONB DEFAULT '[]'::jsonb,
    
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

-- 跟进号自动生成
CREATE OR REPLACE FUNCTION public.generate_followup_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.followup_number IS NULL OR NEW.followup_number = '' THEN
        NEW.followup_number := 'F' || to_char(NOW(), 'YYYYMMDD') || 
                                lpad(random_between(10000, 99999)::text, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_followup_number
    BEFORE INSERT ON public.followups
    FOR EACH ROW EXECUTE FUNCTION public.generate_followup_number();

-- ============================================================
-- 第十五部分：审计日志表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 操作信息
    action audit_action NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID,
    record_ids UUID[],                 -- 批量操作时的ID数组
    
    -- 操作详情
    old_values JSONB,                  -- 变更前的值
    new_values JSONB,                  -- 变更后的值
    changed_fields TEXT[],             -- 变更的字段列表
    change_summary TEXT,               -- 变更摘要
    
    -- 操作人
    user_id UUID REFERENCES public.user_profiles(id),
    user_name TEXT,
    user_ip TEXT,
    user_agent TEXT,
    
    -- 操作环境
    session_id TEXT,
    request_id TEXT,
    operation_source TEXT,             -- 操作来源（web/app/api/cron）
    
    -- 时间
    operation_time TIMESTAMPTZ DEFAULT NOW(),
    
    -- 执行时长（毫秒）
    execution_time_ms INTEGER
);

-- 全局审计日志触发器生成函数
CREATE OR REPLACE FUNCTION public.create_audit_trigger(table_name TEXT)
RETURNS void AS $$
BEGIN
    EXECUTE format(
        'CREATE OR REPLACE TRIGGER trg_audit_%I
         AFTER INSERT OR UPDATE OR DELETE ON %I
         FOR EACH ROW EXECUTE FUNCTION public.log_audit_event()',
        table_name, table_name
    );
END;
$$ LANGUAGE plpgsql;

-- 通用审计日志记录函数
CREATE OR REPLACE FUNCTION public.log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    audit_record public.audit_logs%ROWTYPE;
BEGIN
    audit_record.id := gen_random_uuid();
    audit_record.table_name := TG_TABLE_NAME;
    audit_record.record_id := COALESCE(NEW.id, OLD.id);
    
    IF TG_OP = 'INSERT' THEN
        audit_record.action := 'INSERT';
        audit_record.new_values := to_jsonb(NEW);
        audit_record.old_values := NULL;
        audit_record.change_summary := '新增记录';
    ELSIF TG_OP = 'UPDATE' THEN
        audit_record.action := 'UPDATE';
        audit_record.new_values := to_jsonb(NEW);
        audit_record.old_values := to_jsonb(OLD);
        audit_record.changed_fields := ARRAY(
            SELECT key
            FROM jsonb_each_text(audit_record.new_values - audit_record.old_values::jsonb)
            WHERE key NOT IN ('updated_at', 'version', 'updated_by')
        );
        audit_record.change_summary := '更新字段: ' || array_to_string(audit_record.changed_fields, ', ');
    ELSIF TG_OP = 'DELETE' THEN
        audit_record.action := 'DELETE';
        audit_record.new_values := NULL;
        audit_record.old_values := to_jsonb(OLD);
        audit_record.change_summary := '删除记录';
    END IF;
    
    audit_record.user_id := COALESCE(current_setting('app.current_user_id', TRUE), auth.uid());
    audit_record.operation_time := NOW();
    audit_record.operation_source := COALESCE(current_setting('app.operation_source', TRUE), 'web');
    
    INSERT INTO public.audit_logs VALUES (audit_record.*);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 第十六部分：系统配置表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.system_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key TEXT UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_type TEXT DEFAULT 'string',  -- string/number/boolean/json
    config_group TEXT NOT NULL,         -- 分组
    description TEXT,
    is_encrypted BOOLEAN DEFAULT FALSE, -- 是否加密存储
    is_public BOOLEAN DEFAULT FALSE,    -- 是否公开配置
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- 初始化系统配置
INSERT INTO public.system_configs (config_key, config_value, config_type, config_group, description, is_public) VALUES
    ('system_version', 'V1.0.0', 'string', 'system', '系统版本', TRUE),
    ('company_name', '蟹老板车险工作室', 'string', 'system', '公司名称', TRUE),
    ('contact_phone', '13328185024', 'string', 'system', '联系电话', TRUE),
    ('renewal_reminder_days', '30', 'number', 'insurance', '续保提前提醒天数', TRUE),
    ('inspection_reminder_days', '15', 'number', 'insurance', '年审提前提醒天数', TRUE),
    ('default_commission_rate', '0.15', 'number', 'commission', '默认佣金比例', FALSE),
    ('backup_email', '589842@qq.com', 'string', 'backup', '备份接收邮箱', FALSE),
    ('data_retention_days', '3650', 'number', 'backup', '数据保留天数(10年)', FALSE)
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================
-- 第十七部分：索引创建
-- ============================================================

-- 客户表索引
CREATE INDEX idx_customers_phone ON public.customers(phone_primary);
CREATE INDEX idx_customers_name ON public.customers(customer_name);
CREATE INDEX idx_customers_owner ON public.customers(owner_id) WHERE NOT is_deleted;
CREATE INDEX idx_customers_status ON public.customers(customer_status) WHERE NOT is_deleted;
CREATE INDEX idx_customers_created ON public.customers(created_at DESC);
CREATE INDEX idx_customers_last_transaction ON public.customers(last_transaction_date DESC) WHERE last_transaction_date IS NOT NULL;

-- 车辆表索引
CREATE INDEX idx_vehicles_plate ON public.vehicles(plate_number) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_vin ON public.vehicles(vin) WHERE NOT is_deleted AND vin != '';
CREATE INDEX idx_vehicles_customer ON public.vehicles(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_insurance_expire ON public.vehicles(insurance_expire_date) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_inspection_expire ON public.vehicles(inspection_expire_date) WHERE NOT is_deleted;

-- 车险保单表索引
CREATE INDEX idx_car_policies_number ON public.car_policies(policy_number) WHERE NOT is_deleted;
CREATE INDEX idx_car_policies_customer ON public.car_policies(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_car_policies_vehicle ON public.car_policies(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX idx_car_policies_company ON public.car_policies(insurance_company) WHERE NOT is_deleted;
CREATE INDEX idx_car_policies_dates ON public.car_policies(start_date, end_date) WHERE NOT is_deleted;
CREATE INDEX idx_car_policies_expiring ON public.car_policies(end_date) WHERE NOT is_deleted AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days';
CREATE INDEX idx_car_policies_owner ON public.car_policies(owner_id) WHERE NOT is_deleted;
CREATE INDEX idx_car_policies_payment ON public.car_policies(payment_status) WHERE NOT is_deleted;

-- 非车险保单表索引
CREATE INDEX idx_noncar_policies_customer ON public.noncar_policies(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_noncar_policies_type ON public.noncar_policies(insurance_type) WHERE NOT is_deleted;
CREATE INDEX idx_noncar_policies_expiring ON public.noncar_policies(end_date) WHERE NOT is_deleted AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days';

-- 年审保养表索引
CREATE INDEX idx_maintenance_customer ON public.maintenance_records(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_maintenance_vehicle ON public.maintenance_records(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX idx_maintenance_date ON public.maintenance_records(service_date DESC) WHERE NOT is_deleted;
CREATE INDEX idx_maintenance_next ON public.maintenance_records(next_service_date) WHERE NOT is_deleted AND next_service_date IS NOT NULL;

-- 年审提醒表索引
CREATE INDEX idx_inspection_reminder_vehicle ON public.inspection_reminders(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX idx_inspection_reminder_date ON public.inspection_reminders(inspection_date) WHERE NOT is_deleted;
CREATE INDEX idx_inspection_reminder_status ON public.inspection_reminders(reminder_status) WHERE NOT is_deleted;

-- 后市场订单表索引
CREATE INDEX idx_aftermarket_customer ON public.aftermarket_orders(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_aftermarket_vehicle ON public.aftermarket_orders(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX idx_aftermarket_service_type ON public.aftermarket_orders(service_type) WHERE NOT is_deleted;
CREATE INDEX idx_aftermarket_date ON public.aftermarket_orders(order_date DESC) WHERE NOT is_deleted;

-- 违章记录表索引
CREATE INDEX idx_violation_vehicle ON public.violation_records(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX idx_violation_customer ON public.violation_records(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_violation_status ON public.violation_records(handling_status) WHERE NOT is_deleted;

-- 金融合同表索引
CREATE INDEX idx_finance_customer ON public.finance_contracts(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_finance_vehicle ON public.finance_contracts(vehicle_id) WHERE NOT is_deleted;
CREATE INDEX idx_finance_status ON public.finance_contracts(loan_status) WHERE NOT is_deleted;
CREATE INDEX idx_finance_next_payment ON public.finance_contracts(id) WHERE NOT is_deleted;

-- 还款记录表索引
CREATE INDEX idx_repayment_contract ON public.loan_repayments(finance_contract_id) WHERE NOT is_deleted;
CREATE INDEX idx_repayment_customer ON public.loan_repayments(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_repayment_due ON public.loan_repayments(due_date) WHERE NOT is_deleted;
CREATE INDEX idx_repayment_status ON public.loan_repayments(payment_status) WHERE NOT is_deleted;

-- 跟进记录表索引
CREATE INDEX idx_followup_customer ON public.followups(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_followup_owner ON public.followups(owner_id) WHERE NOT is_deleted;
CREATE INDEX idx_followup_date ON public.followups(created_at DESC) WHERE NOT is_deleted;
CREATE INDEX idx_followup_next ON public.followups(next_followup_date) WHERE NOT is_deleted AND next_followup_date IS NOT NULL;

-- 审计日志表索引
CREATE INDEX idx_audit_table ON public.audit_logs(table_name);
CREATE INDEX idx_audit_record ON public.audit_logs(record_id) WHERE record_id IS NOT NULL;
CREATE INDEX idx_audit_user ON public.audit_logs(user_id);
CREATE INDEX idx_audit_time ON public.audit_logs(operation_time DESC);
CREATE INDEX idx_audit_action ON public.audit_logs(action);

-- 用户表索引
CREATE INDEX idx_users_phone ON public.user_profiles(phone) WHERE NOT is_deleted;
CREATE INDEX idx_users_email ON public.user_profiles(email) WHERE NOT is_deleted;
CREATE INDEX idx_users_role ON public.user_profiles(role) WHERE NOT is_deleted;

-- ============================================================
-- 第十八部分：RLS行级安全策略
-- ============================================================

-- 启用RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noncar_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aftermarket_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.violation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_repayments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_configs ENABLE ROW LEVEL SECURITY;

-- 用户表策略
CREATE POLICY "用户查看自己的信息" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id OR EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员')
    ));

CREATE POLICY "管理员可管理所有用户" ON public.user_profiles
    FOR ALL USING (EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员')
    ));

-- 客户表策略
CREATE POLICY "用户可查看自己负责的客户" ON public.customers
    FOR SELECT USING (
        owner_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理'))
    );

CREATE POLICY "用户可创建客户" ON public.customers
    FOR INSERT WITH CHECK (owner_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员')
    ));

CREATE POLICY "用户可更新自己负责的客户" ON public.customers
    FOR UPDATE USING (
        owner_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理'))
    );

CREATE POLICY "管理员可删除客户" ON public.customers
    FOR DELETE USING (EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员')
    ));

-- 车辆表策略（跟随客户权限）
CREATE POLICY "车辆权限跟随客户" ON public.vehicles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = vehicles.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 车险保单策略
CREATE POLICY "保单权限跟随客户" ON public.car_policies
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = car_policies.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 非车险保单策略
CREATE POLICY "非车险权限跟随客户" ON public.noncar_policies
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = noncar_policies.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 年审保养策略
CREATE POLICY "保养权限跟随客户" ON public.maintenance_records
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = maintenance_records.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 年审提醒策略
CREATE POLICY "年审提醒权限跟随客户" ON public.inspection_reminders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = inspection_reminders.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 后市场订单策略
CREATE POLICY "后市场权限跟随客户" ON public.aftermarket_orders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = aftermarket_orders.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 违章记录策略
CREATE POLICY "违章权限跟随客户" ON public.violation_records
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = violation_records.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 金融合同策略
CREATE POLICY "金融权限跟随客户" ON public.finance_contracts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = finance_contracts.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 还款记录策略
CREATE POLICY "还款权限跟随客户" ON public.loan_repayments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = loan_repayments.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 跟进记录策略
CREATE POLICY "跟进权限跟随客户" ON public.followups
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.customers 
            WHERE customers.id = followups.customer_id 
            AND (customers.owner_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员', '经理')
            ))
        )
    );

-- 审计日志策略（只允许管理员查看）
CREATE POLICY "管理员可查看审计日志" ON public.audit_logs
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员')
    ));

-- 系统配置策略
CREATE POLICY "公开配置可被所有人查看" ON public.system_configs
    FOR SELECT USING (is_public = TRUE);

CREATE POLICY "管理员可管理配置" ON public.system_configs
    FOR ALL USING (EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('管理员', '超级管理员')
    ));

-- ============================================================
-- 第十九部分：自动更新updated_at触发器
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    IF NEW.updated_by IS NULL THEN
        NEW.updated_by = auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表添加updated_at触发器
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON public.vehicles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_car_policies_updated_at BEFORE UPDATE ON public.car_policies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_noncar_policies_updated_at BEFORE UPDATE ON public.noncar_policies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_maintenance_updated_at BEFORE UPDATE ON public.maintenance_records
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_inspection_reminders_updated_at BEFORE UPDATE ON public.inspection_reminders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_aftermarket_updated_at BEFORE UPDATE ON public.aftermarket_orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_violation_updated_at BEFORE UPDATE ON public.violation_records
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_finance_updated_at BEFORE UPDATE ON public.finance_contracts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_repayment_updated_at BEFORE UPDATE ON public.loan_repayments
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_followups_updated_at BEFORE UPDATE ON public.followups
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_system_configs_updated_at BEFORE UPDATE ON public.system_configs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 第二十部分：常用视图
-- ============================================================

-- 客户360视图（包含车辆、保单汇总）
CREATE OR REPLACE VIEW public.v_customer_360 AS
SELECT 
    c.id as customer_id,
    c.customer_code,
    c.customer_name,
    c.phone_primary,
    c.province,
    c.city,
    c.district,
    c.source,
    c.customer_status,
    c.customer_level,
    c.total_transaction_amount,
    c.total_transaction_count,
    c.days_since_last_transaction,
    c.owner_id,
    c.owner_name,
    c.created_at,
    -- 车辆信息
    COALESCE(v.vehicle_count, 0) as vehicle_count,
    COALESCE(v.latest_plate, '') as latest_plate,
    COALESCE(v.latest_vin, '') as latest_vin,
    COALESCE(v.vehicle_brand, '') as vehicle_brand,
    COALESCE(v.vehicle_model, '') as vehicle_model,
    -- 保险信息
    COALESCE(p.policy_count, 0) as policy_count,
    COALESCE(p.total_premium, 0) as total_premium,
    COALESCE(p.latest_policy_date, NULL) as latest_policy_date,
    COALESCE(p.expiring_policy_count, 0) as expiring_policy_count,
    -- 其他服务
    COALESCE(m.maintenance_count, 0) as maintenance_count,
    COALESCE(m.latest_maintenance_date, NULL) as latest_maintenance_date,
    COALESCE(m.total_maintenance_amount, 0) as total_maintenance_amount,
    -- 待跟进
    COALESCE(f.followup_count, 0) as followup_pending_count,
    COALESCE(f.next_followup_date, NULL) as next_followup_date
FROM public.customers c
LEFT JOIN (
    SELECT 
        customer_id,
        count(*) as vehicle_count,
        array_agg(plate_number ORDER BY created_at DESC)[1] as latest_plate,
        array_agg(vin ORDER BY created_at DESC)[1] as latest_vin,
        array_agg(brand ORDER BY created_at DESC)[1] as vehicle_brand,
        array_agg(model ORDER BY created_at DESC)[1] as vehicle_model
    FROM public.vehicles WHERE NOT is_deleted
    GROUP BY customer_id
) v ON c.id = v.customer_id
LEFT JOIN (
    SELECT 
        customer_id,
        count(*) as policy_count,
        sum(total_premium) as total_premium,
        max(start_date) as latest_policy_date,
        count(*) FILTER (WHERE end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days') as expiring_policy_count
    FROM public.car_policies WHERE NOT is_deleted
    GROUP BY customer_id
) p ON c.id = p.customer_id
LEFT JOIN (
    SELECT 
        customer_id,
        count(*) as maintenance_count,
        max(service_date) as latest_maintenance_date,
        sum(actual_paid) as total_maintenance_amount
    FROM public.maintenance_records WHERE NOT is_deleted
    GROUP BY customer_id
) m ON c.id = m.customer_id
LEFT JOIN (
    SELECT 
        customer_id,
        count(*) FILTER (WHERE followup_status = '进行中') as followup_count,
        min(next_followup_date) as next_followup_date
    FROM public.followups WHERE NOT is_deleted AND next_followup_date >= CURRENT_DATE
    GROUP BY customer_id
) f ON c.id = f.customer_id
WHERE NOT c.is_deleted;

-- 保险到期视图
CREATE OR REPLACE VIEW public.v_policy_expiring AS
SELECT 
    p.id as policy_id,
    p.policy_number,
    p.customer_id,
    c.customer_name,
    c.phone_primary,
    c.owner_id,
    c.owner_name,
    p.vehicle_id,
    v.plate_number,
    v.vin,
    v.brand,
    v.model,
    p.insurance_company,
    p.start_date,
    p.end_date,
    p.total_premium,
    p.commission_amount,
    p.payment_status,
    p.commission_status,
    (p.end_date - CURRENT_DATE)::integer as days_to_expire,
    CASE 
        WHEN p.end_date - CURRENT_DATE <= 7 THEN '紧急'
        WHEN p.end_date - CURRENT_DATE <= 15 THEN '即将到期'
        WHEN p.end_date - CURRENT_DATE <= 30 THEN '提前续保'
        ELSE '正常'
    END as expire_level
FROM public.car_policies p
JOIN public.customers c ON p.customer_id = c.id
LEFT JOIN public.vehicles v ON p.vehicle_id = v.id
WHERE NOT p.is_deleted 
    AND NOT c.is_deleted
    AND p.end_date >= CURRENT_DATE
    AND p.end_date <= CURRENT_DATE + INTERVAL '90 days'
ORDER BY (p.end_date - CURRENT_DATE) ASC;

-- 业务员业绩视图
CREATE OR REPLACE VIEW public.v_sales_performance AS
SELECT 
    u.id as user_id,
    u.display_name as user_name,
    u.employee_id,
    u.department,
    -- 车险业绩
    COALESCE(policy_stats.policy_count, 0) as total_policies,
    COALESCE(policy_stats.new_policies, 0) as new_policies,
    COALESCE(policy_stats.renewal_policies, 0) as renewal_policies,
    COALESCE(policy_stats.total_premium, 0) as total_premium,
    COALESCE(policy_stats.total_commission, 0) as total_commission,
    COALESCE(policy_stats.received_commission, 0) as received_commission,
    -- 客户数量
    COALESCE(customer_stats.total_customers, 0) as total_customers,
    COALESCE(customer_stats.active_customers, 0) as active_customers,
    -- 其他服务
    COALESCE(service_stats.total_services, 0) as total_services,
    COALESCE(service_stats.total_service_amount, 0) as total_service_amount,
    -- 本月数据
    COALESCE(month_stats.policy_count_month, 0) as month_policies,
    COALESCE(month_stats.premium_month, 0) as month_premium
FROM public.user_profiles u
LEFT JOIN (
    SELECT 
        owner_id,
        count(*) as policy_count,
        count(*) FILTER (WHERE policy_type = '新保') as new_policies,
        count(*) FILTER (WHERE is_renewal = TRUE) as renewal_policies,
        sum(total_premium) as total_premium,
        sum(commission_amount) as total_commission,
        sum(commission_received) as received_commission
    FROM public.car_policies 
    WHERE NOT is_deleted AND start_date >= CURRENT_DATE - INTERVAL '1 year'
    GROUP BY owner_id
) policy_stats ON u.id = policy_stats.owner_id
LEFT JOIN (
    SELECT 
        owner_id,
        count(*) as total_customers,
        count(*) FILTER (WHERE customer_status = '成交') as active_customers
    FROM public.customers
    WHERE NOT is_deleted
    GROUP BY owner_id
) customer_stats ON u.id = customer_stats.owner_id
LEFT JOIN (
    SELECT 
        owner_id,
        count(*) as total_services,
        sum(actual_paid) as total_service_amount
    FROM public.maintenance_records
    WHERE NOT is_deleted
    GROUP BY owner_id
) service_stats ON u.id = service_stats.owner_id
LEFT JOIN (
    SELECT 
        owner_id,
        count(*) as policy_count_month,
        sum(total_premium) as premium_month
    FROM public.car_policies
    WHERE NOT is_deleted 
        AND start_date >= date_trunc('month', CURRENT_DATE)
        AND start_date < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
    GROUP BY owner_id
) month_stats ON u.id = month_stats.owner_id
WHERE NOT u.is_deleted
ORDER BY total_premium DESC;

-- ============================================================
-- 第二十一部分：系统函数
-- ============================================================

-- 获取客户完整档案
CREATE OR REPLACE FUNCTION public.fn_get_customer_full档案(customer_uuid UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'customer', (SELECT row_to_json(c) FROM public.customers c WHERE id = customer_uuid),
        'vehicles', (SELECT jsonb_agg(row_to_json(v)) FROM public.vehicles v WHERE customer_id = customer_uuid AND NOT v.is_deleted),
        'car_policies', (SELECT jsonb_agg(row_to_json(p)) FROM public.car_policies p WHERE customer_id = customer_uuid AND NOT p.is_deleted),
        'noncar_policies', (SELECT jsonb_agg(row_to_json(n)) FROM public.noncar_policies n WHERE customer_id = customer_uuid AND NOT n.is_deleted),
        'maintenance', (SELECT jsonb_agg(row_to_json(m)) FROM public.maintenance_records m WHERE customer_id = customer_uuid AND NOT m.is_deleted),
        'aftermarket', (SELECT jsonb_agg(row_to_json(a)) FROM public aftermarket_orders a WHERE customer_id = customer_uuid AND NOT a.is_deleted),
        'finance', (SELECT jsonb_agg(row_to_json(f)) FROM public.finance_contracts f WHERE customer_id = customer_uuid AND NOT f.is_deleted),
        'followups', (SELECT jsonb_agg(row_to_json(fu)) FROM public.followups fu WHERE customer_id = customer_uuid AND NOT fu.is_deleted ORDER BY fu.created_at DESC LIMIT 20)
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取即将到期的保单列表
CREATE OR REPLACE FUNCTION public.fn_get_expiring_policies(days INTEGER DEFAULT 30)
RETURNS TABLE (
    policy_id UUID,
    policy_number TEXT,
    customer_name TEXT,
    phone TEXT,
    plate_number TEXT,
    insurance_company TEXT,
    end_date DATE,
    days_left INTEGER,
    total_premium DECIMAL,
    owner_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as policy_id,
        p.policy_number,
        c.customer_name,
        c.phone_primary,
        v.plate_number,
        p.insurance_company,
        p.end_date,
        (p.end_date - CURRENT_DATE)::integer as days_left,
        p.total_premium,
        c.owner_name
    FROM public.car_policies p
    JOIN public.customers c ON p.customer_id = c.id
    LEFT JOIN public.vehicles v ON p.vehicle_id = v.id
    WHERE NOT p.is_deleted
        AND NOT c.is_deleted
        AND p.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (days || ' days')::interval
    ORDER BY (p.end_date - CURRENT_DATE) ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 计算续保率
CREATE OR REPLACE FUNCTION public.fn_calculate_renewal_rate(start_date DATE, end_date DATE)
RETURNS DECIMAL AS $$
DECLARE
    total_policies INTEGER;
    renewed_policies INTEGER;
    rate DECIMAL;
BEGIN
    -- 统计这段时间内到期的保单数量
    SELECT count(*) INTO total_policies
    FROM public.car_policies
    WHERE NOT is_deleted
        AND end_date BETWEEN start_date AND end_date;
    
    -- 统计这些保单中续保的数量
    SELECT count(*) INTO renewed_policies
    FROM public.car_policies p1
    WHERE NOT p1.is_deleted
        AND p1.end_date BETWEEN start_date AND end_date
        AND p1.is_renewal = TRUE;
    
    -- 计算续保率
    IF total_policies > 0 THEN
        rate := (renewed_policies::decimal / total_policies::decimal) * 100;
    ELSE
        rate := 0;
    END IF;
    
    RETURN rate;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 第二十二部分：数据一致性检查函数
-- ============================================================

-- 每日数据一致性检查
CREATE OR REPLACE FUNCTION public.fn_check_data_consistency()
RETURNS TABLE (
    check_name TEXT,
    check_result TEXT,
    affected_rows BIGINT,
    check_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    -- 检查1: 客户总数与车辆总数的关系
    SELECT 
        '客户车辆关联检查' as check_name,
        CASE 
            WHEN v.count > 0 THEN '警告: 有' || v.count || '个客户标记为无车辆但实际有车辆'
            ELSE '正常'
        END as check_result,
        v.count as affected_rows,
        NOW() as check_time
    FROM (
        SELECT count(*) as count
        FROM public.customers c
        WHERE c.has_vehicle = FALSE
            AND EXISTS (SELECT 1 FROM public.vehicles v WHERE v.customer_id = c.id AND NOT v.is_deleted)
    ) v
    UNION ALL
    -- 检查2: 保单客户是否存在
    SELECT 
        '保单客户关联检查' as check_name,
        CASE 
            WHEN p.count > 0 THEN '警告: 有' || p.count || '个保单关联了已删除的客户'
            ELSE '正常'
        END as check_result,
        p.count as affected_rows,
        NOW() as check_time
    FROM (
        SELECT count(*) as count
        FROM public.car_policies p
        WHERE NOT p.is_deleted
            AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE c.id = p.customer_id AND NOT c.is_deleted)
    ) p
    UNION ALL
    -- 检查3: 车辆客户是否存在
    SELECT 
        '车辆客户关联检查' as check_name,
        CASE 
            WHEN v.count > 0 THEN '警告: 有' || v.count || '个车辆关联了已删除的客户'
            ELSE '正常'
        END as check_result,
        v.count as affected_rows,
        NOW() as check_time
    FROM (
        SELECT count(*) as count
        FROM public.vehicles v
        WHERE NOT v.is_deleted
            AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE c.id = v.customer_id AND NOT c.is_deleted)
    ) v
    UNION ALL
    -- 检查4: 保单佣金计算检查
    SELECT 
        '保单佣金计算检查' as check_name,
        CASE 
            WHEN p.count > 0 THEN '警告: 有' || p.count || '个保单佣金计算有误'
            ELSE '正常'
        END as check_result,
        p.count as affected_rows,
        NOW() as check_time
    FROM (
        SELECT count(*) as count
        FROM public.car_policies p
        WHERE NOT p.is_deleted
            AND p.commission_amount IS NOT NULL
            AND p.total_premium IS NOT NULL
            AND p.commission_rate IS NOT NULL
            AND abs(p.commission_amount - p.total_premium * p.commission_rate) > 0.01
    ) p;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 第二十三部分：定期清理任务
-- ============================================================

-- 清理30天前的登录历史（保留最近30天）
CREATE OR REPLACE FUNCTION public.fn_cleanup_login_history(retention_days INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.user_login_history
    WHERE login_at < NOW() - (retention_days || ' days')::interval;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 清理90天前的审计日志（保留最近90天，但保留所有DELETE操作的日志）
CREATE OR REPLACE FUNCTION public.fn_cleanup_audit_logs(retention_days INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.audit_logs
    WHERE operation_time < NOW() - (retention_days || ' days')::interval
        AND action != 'DELETE';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 第二十四部分：Grant权限（确保服务角色有权限）
-- ============================================================

-- 启用服务密钥访问（允许anon key访问公开数据）
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 允许服务角色执行函数
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- ============================================================
-- 完成标记
-- ============================================================

-- 添加版本记录
COMMENT ON SCHEMA public IS '汽车全生态客户管理系统 V1.0 | 创建日期: 2026-04-19 | 作者: 痞老板';
