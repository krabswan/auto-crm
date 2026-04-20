-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本：V1.0 | 日期：2026-04-19
-- 数据库：PostgreSQL (Supabase)
-- ============================================================

-- ============================================================
-- 第1部分：核心表（所有模块共享）
-- ============================================================

-- -------------------------------------------------------
-- 1.1 用户表（系统管理员/业务员）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    real_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    role VARCHAR(20) NOT NULL DEFAULT 'sales' CHECK (role IN ('admin', 'manager', 'sales', 'viewer')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'locked')),
    last_login_at TIMESTAMPTZ,
    last_login_ip VARCHAR(45),
    login_attempts INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON public.users(username) WHERE NOT is_deleted;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone) WHERE NOT is_deleted AND phone IS NOT NULL;

-- -------------------------------------------------------
-- 1.2 客户表（核心主表）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 客户基本信息
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(10) CHECK (gender IN ('男', '女', '其他')),
    id_card VARCHAR(18),
    phone VARCHAR(20) NOT NULL,
    phone_backup VARCHAR(20),
    email VARCHAR(255),
    wechat VARCHAR(100),
    
    -- 地址信息
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address_detail TEXT,
    address_full TEXT,
    
    -- 客户分类
    customer_type VARCHAR(20) DEFAULT 'individual' CHECK (customer_type IN ('individual', 'company', 'vip', 'potential')),
    source_channel VARCHAR(50),  -- 来源渠道
    assigned_user_id UUID REFERENCES public.users(id),
    
    -- 标签系统
    tags TEXT[],  -- 数组格式标签
    remark TEXT,
    
    -- 统计字段（冗余存储，提高查询效率）
    total_policies INTEGER DEFAULT 0,
    total_policies_amount DECIMAL(15,2) DEFAULT 0,
    last_service_at TIMESTAMPTZ,
    lifetime_value DECIMAL(15,2) DEFAULT 0,  -- 客户终身价值
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 唯一约束
    CONSTRAINT uq_customers_phone UNIQUE (phone) WHERE NOT is_deleted,
    CONSTRAINT uq_customers_idcard UNIQUE (id_card) WHERE id_card IS NOT NULL AND NOT is_deleted
);

CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_name ON public.customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_assigned_user ON public.customers(assigned_user_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_customers_type ON public.customers(customer_type) WHERE NOT is_deleted;

-- -------------------------------------------------------
-- 1.3 车辆表（一个客户可以有多辆车）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    
    -- 车辆基本信息
    plate_number VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) CHECK (vehicle_type IN ('私家车', '营运车', '企业用车', '新能源')),
    brand VARCHAR(100),
    model VARCHAR(100),
    model_year INTEGER,
    color VARCHAR(30),
    vin VARCHAR(17),
    engine_number VARCHAR(50),
    register_date DATE,
    
    -- 车辆状态
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'scrapped', 'transferred', 'insured_other')),
    is_new_energy BOOLEAN DEFAULT FALSE,
    mileage INTEGER DEFAULT 0,
    
    -- 年审信息
    annual_review_date DATE,
    annual_review_status VARCHAR(20) DEFAULT 'valid' CHECK (annual_review_status IN ('valid', 'soon_expire', 'expired', 'pending')),
    compulsory_insurance_date DATE,
    commercial_insurance_date DATE,
    
    -- 商业险信息
    last_policy_company VARCHAR(100),
    last_policy_amount DECIMAL(15,2),
    last_policy_expire_date DATE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT uq_vehicles_plate UNIQUE (plate_number) WHERE NOT is_deleted,
    CONSTRAINT uq_vehicles_vin UNIQUE (vin) WHERE vin IS NOT NULL AND NOT is_deleted
);

CREATE INDEX IF NOT EXISTS idx_vehicles_customer ON public.vehicles(customer_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON public.vehicles(plate_number);
CREATE INDEX IF NOT EXISTS idx_vehicles_annual_review ON public.vehicles(annual_review_date) WHERE status = 'active' AND NOT is_deleted;

-- -------------------------------------------------------
-- 1.4 审计日志表（全局可追溯）
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 操作信息
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'SOFT_DELETE', 'RESTORE')),
    
    -- 变更详情（JSON格式）
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    
    -- 操作者信息
    user_id UUID REFERENCES public.users(id),
    user_name VARCHAR(100),
    user_ip VARCHAR(45),
    user_agent TEXT,
    
    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 关联业务（可选）
    module VARCHAR(50),  -- 模块名
    business_id VARCHAR(100),  -- 业务单号
    description TEXT  -- 操作描述
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record ON public.audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.audit_logs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module ON public.audit_logs(module, created_at DESC);

-- -------------------------------------------------------
-- 1.5 系统配置表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    config_type VARCHAR(20) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
    config_group VARCHAR(50),
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,  -- 是否公开（网站展示）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 初始化默认配置
INSERT INTO public.system_config (config_key, config_value, config_type, config_group, description, is_public) VALUES
    ('system_version', 'V1.0', 'string', 'system', '系统版本', FALSE),
    ('company_name', '蟹老板车险工作室', 'string', 'company', '公司名称', TRUE),
    ('contact_phone', '13328185024', 'string', 'company', '联系电话', TRUE),
    ('renewal_reminder_days', '30', 'number', 'insurance', '续保提前提醒天数', FALSE),
    ('annual_review_reminder_days', '30', 'number', 'vehicle', '年审提前提醒天数', FALSE);

-- -------------------------------------------------------
-- 1.6 定时任务记录表
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.scheduled_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(50),
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(20),
    last_run_result TEXT,
    next_run_at TIMESTAMPTZ,
    run_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_next ON public.scheduled_tasks(next_run_at) WHERE next_run_at IS NOT NULL;
