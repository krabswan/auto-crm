-- ============================================================
-- 汽车全生态客户管理系统 - 核心数据库Schema
-- 版本：V1.0 | 日期：2026-04-19 | 作者：痞老板
-- 数据库：PostgreSQL 15+ (Supabase托管)
-- ============================================================

-- ============================================================
-- Part 0: 启用UUID扩展
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Part 1: 枚举类型定义
-- ============================================================

-- 客户类型
CREATE TYPE customer_type AS ENUM (
    'individual',   -- 个人
    'corporate'      -- 企业
);

-- 客户状态
CREATE TYPE customer_status AS ENUM (
    'active',        -- 活跃
    'inactive',      -- 不活跃
    'churned'        -- 流失
);

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM (
    'active',        -- 正常
    'scrapped',      -- 报废
    'transferred'    -- 过户
);

-- 业务类型
CREATE TYPE business_type AS ENUM (
    'car_insurance',     -- 车险
    'noncar_insurance',  -- 非车险
    'annual_inspection',  -- 年审
    'maintenance',        -- 保养
    'aftermarket',        -- 后市场
    'financing'          -- 消费金融
);

-- 保单状态
CREATE TYPE policy_status AS ENUM (
    'pending',       -- 待生效
    'active',        -- 生效中
    'expired',       -- 已过期
    'cancelled',     -- 已退保
    'claims'         -- 理赔中
);

-- 支付状态
CREATE TYPE payment_status AS ENUM (
    'unpaid',        -- 未付款
    'paid',          -- 已付款
    'refunded',      -- 已退款
    'overdue'        -- 逾期
);

-- 操作类型（审计日志）
CREATE TYPE audit_action AS ENUM (
    'create',
    'read',
    'update',
    'delete',
    'restore',
    'export',
    'login',
    'logout'
);

-- ============================================================
-- Part 2: 核心客户中心 (customers)
-- ============================================================

CREATE TABLE customers (
    -- 主键和基础信息
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_no VARCHAR(20) UNIQUE NOT NULL,  -- 客户编号（如 C202604190001）
    
    -- 基本信息
    name VARCHAR(100) NOT NULL,               -- 姓名/企业名
    customer_type customer_type DEFAULT 'individual',
    id_card VARCHAR(18),                       -- 身份证号（个人客户）
    id_card_hash VARCHAR(64),                  -- 身份证哈希（用于去重，不存原文）
    phone VARCHAR(20) NOT NULL,               -- 手机号
    phone_hash VARCHAR(64),                    -- 手机号哈希（用于去重）
    
    -- 企业信息
    company_name VARCHAR(200),                 -- 企业名称
    unified_credit_code VARCHAR(18),          -- 统一信用代码
    legal_person VARCHAR(100),                 -- 法人代表
    business_license VARCHAR(100),            -- 营业执照编号
    
    -- 联系信息
    email VARCHAR(100),
    province VARCHAR(50),
    city VARCHAR(50),
    district VARCHAR(50),
    address TEXT,                              -- 详细地址
    
    -- 客户标签（JSON数组，方便统计分析）
    tags JSONB DEFAULT '[]'::jsonb,
    
    -- 客户价值和分层
    customer_level VARCHAR(10) DEFAULT 'C',   -- A/B/C/D 分层
    lifetime_value DECIMAL(12,2) DEFAULT 0,   -- 终身价值
    
    -- 状态
    status customer_status DEFAULT 'active',
    
    -- 来源渠道
    source_channel VARCHAR(50),                -- 客户来源
    source_remark TEXT,                       -- 来源备注
    
    -- 归属业务
    owner_user_id UUID,                       -- 归属业务员
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 约束
    CONSTRAINT phone_format CHECK (phone ~ '^1[3-9]\d{9}$'),
    CONSTRAINT id_card_format CHECK (id_card IS NULL OR id_card ~ '^[1-9]\d{5}(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dX]$')
);

-- 客户号序列
CREATE SEQUENCE customer_no_seq START WITH 1 INCREMENT BY 1;

-- 创建索引
CREATE INDEX idx_customers_phone ON customers(phone_hash) WHERE NOT is_deleted;
CREATE INDEX idx_customers_id_card ON customers(id_card_hash) WHERE id_card_hash IS NOT NULL AND NOT is_deleted;
CREATE INDEX idx_customers_status ON customers(status) WHERE NOT is_deleted;
CREATE INDEX idx_customers_owner ON customers(owner_user_id) WHERE owner_user_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX idx_customers_level ON customers(customer_level) WHERE NOT is_deleted;

-- ============================================================
-- Part 3: 车辆信息表 (vehicles)
-- ============================================================

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_no VARCHAR(20) UNIQUE NOT NULL,   -- 车辆编号
    
    -- 客户关联（外键）
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    
    -- 车辆基本信息
    plate_number VARCHAR(20) NOT NULL,         -- 车牌号（如苏D983P）
    plate_province VARCHAR(10),                 -- 车牌省份
    plate_city VARCHAR(10),                     -- 车牌城市
    vin VARCHAR(17) NOT NULL,                   -- 车架号/VIN
    vin_hash VARCHAR(64),                       -- VIN哈希（用于去重）
    engine_number VARCHAR(30),                   -- 发动机号
    engine_number_hash VARCHAR(64),
    
    -- 车辆属性
    brand VARCHAR(50) NOT NULL,                 -- 品牌（如 东风）
    series VARCHAR(50),                         -- 车系（如 景逸X3）
    model VARCHAR(100),                         -- 车型全称
    vehicle_type VARCHAR(20),                   -- 车辆类型（轿车/SUV/货车等）
    vehicle_color VARCHAR(20),                  -- 颜色
    
    -- 使用信息
    register_date DATE,                         -- 注册日期
    plate_date DATE,                            -- 上牌日期
    mileage INTEGER DEFAULT 0,                   -- 当前里程（公里）
    usage_type VARCHAR(20),                     -- 使用性质（家用/营运/非营运）
    
    -- 车辆状态
    status vehicle_status DEFAULT 'active',
    
    -- 保险信息
    last_insurance_company VARCHAR(100),        -- 上次承保公司
    last_insurance_expire DATE,                -- 上次保险到期日
    
    -- 年审信息
    annual_inspection_expire DATE,             -- 年审到期日
    next_annual_inspection DATE,                -- 下次年审日期
    environmental_standard VARCHAR(10),         -- 排放标准（国四/国五/国六）
    
    -- 最新里程更新时间
    mileage_updated_at TIMESTAMPTZ,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- 约束
    CONSTRAINT vin_format CHECK (vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),  -- VIN格式
    CONSTRAINT plate_format CHECK (plate_number ~ '^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-Z][A-Z0-9]{4,5}[A-Z0-9挂学警港澳]$')
);

-- VIN去重索引
CREATE UNIQUE INDEX idx_vehicles_vin ON vehicles(vin_hash) WHERE NOT is_deleted;

-- 创建索引
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_insurance_expire ON vehicles(last_insurance_expire) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_annual_expire ON vehicles(annual_inspection_expire) WHERE NOT is_deleted;

-- ============================================================
-- Part 4: 用户表 (users)
-- ============================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    
    -- 密码（Supabase Auth处理，但保留本地备份）
    password_hash VARCHAR(255),
    
    -- 个人信息
    real_name VARCHAR(50) NOT NULL,
    avatar_url TEXT,
    id_card VARCHAR(18),
    
    -- 角色和权限
    role VARCHAR(20) DEFAULT 'user',           -- admin/super_admin/user/viewer
    permissions JSONB DEFAULT '[]'::jsonb,      -- 细粒度权限
    
    -- 业务员信息（如果是业务员角色）
    employee_no VARCHAR(20),                    -- 员工编号
    department VARCHAR(100),                    -- 部门
    position VARCHAR(50),                      -- 职位
    
    -- 工作状态
    is_active BOOLEAN DEFAULT TRUE,
    
    -- 审计字段
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ
);

-- ============================================================
-- Part 5: 车辆表 (vehicles) - 续
-- ============================================================

-- 补充：为已有车辆表添加车辆与客户关系视图
CREATE OR REPLACE VIEW v_customer_vehicles AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.phone,
    v.id AS vehicle_id,
    v.plate_number,
    v.brand,
    v.series,
    v.vin,
    v.register_date,
    v.mileage,
    v.usage_type,
    v.status,
    v.last_insurance_expire,
    v.annual_inspection_expire
FROM customers c
INNER JOIN vehicles v ON c.id = v.customer_id
WHERE c.is_deleted = FALSE AND v.is_deleted = FALSE;

-- ============================================================
-- Part 6: 审计日志表 (audit_logs)
-- ============================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 操作信息
    action audit_action NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,                             -- 被操作的记录ID
    record_no VARCHAR(50),                      -- 被操作的记录编号
    
    -- 操作详情
    old_data JSONB,                             -- 修改前的数据
    new_data JSONB,                             -- 修改后的数据
    change_summary TEXT,                        -- 变更摘要（如 "将状态从active改为inactive"）
    
    -- 操作上下文
    user_id UUID,
    user_name VARCHAR(100),
    user_ip INET,
    user_agent TEXT,
    request_id VARCHAR(100),                    -- 请求追踪ID
    
    -- 业务关联
    business_type business_type,                -- 关联业务类型
    customer_id UUID,                          -- 关联客户（方便查询）
    vehicle_id UUID,                           -- 关联车辆（方便查询）
    
    -- 时间
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_audit_table ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_customer ON audit_logs(customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX idx_audit_vehicle ON audit_logs(vehicle_id) WHERE vehicle_id IS NOT NULL;
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_action ON audit_logs(action, created_at DESC);

-- ============================================================
-- Part 7: 键值存储表 (kv_store)
-- ============================================================

CREATE TABLE kv_store (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    category VARCHAR(50),                       -- 分类
    description TEXT,
    expires_at TIMESTAMPTZ,                     -- 过期时间（可选）
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_kv_category ON kv_store(category) WHERE category IS NOT NULL;
CREATE INDEX idx_kv_expires ON kv_store(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================================
-- Part 8: 系统配置表 (system_configs)
-- ============================================================

CREATE TABLE system_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    config_type VARCHAR(20) DEFAULT 'string',   -- string/number/boolean/json/array
    category VARCHAR(50),
    description TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- 初始化系统配置
INSERT INTO system_configs (config_key, config_value, config_type, category, description) VALUES
('system_version', '"V1.0.0"', 'string', 'system', '系统版本'),
('system_name', '"汽车全生态客户管理系统"', 'string', 'system', '系统名称'),
('customer_no_prefix', '"C"', 'string', 'business', '客户编号前缀'),
('vehicle_no_prefix', '"V"', 'string', 'business', '车辆编号前缀'),
('renewal_reminder_days', '[30, 15, 7, 3, 1]', 'array', 'business', '续保提醒天数'),
('annual_inspection_reminder_days', '[30, 15, 7, 1]', 'array', 'business', '年审提醒天数');

-- ============================================================
-- Part 9: 触发器函数
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

-- 为各表添加触发器
CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at
    BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 自动生成客户编号
CREATE OR REPLACE FUNCTION generate_customer_no()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.customer_no IS NULL OR NEW.customer_no = '' THEN
        NEW.customer_no = 'C' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEXTVAL('customer_no_seq')::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_customer_no
    BEFORE INSERT ON customers
    FOR EACH ROW EXECUTE FUNCTION generate_customer_no();

-- 审计日志触发器函数
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    audit_action audit_action;
    old_data JSONB;
    new_data JSONB;
BEGIN
    -- 判断操作类型
    IF TG_OP = 'INSERT' THEN
        audit_action = 'create'::audit_action;
        old_data = NULL;
        new_data = row_to_json(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        audit_action = 'update'::audit_action;
        old_data = row_to_json(OLD);
        new_data = row_to_json(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        audit_action = 'delete'::audit_action;
        old_data = row_to_json(OLD);
        new_data = NULL;
    END IF;
    
    -- 插入审计日志（不包含自身表，避免循环）
    IF TG_TABLE_NAME != 'audit_logs' THEN
        INSERT INTO audit_logs (
            action, table_name, record_id, record_no,
            old_data, new_data, user_id, business_type
        ) VALUES (
            audit_action, TG_TABLE_NAME, 
            COALESCE(NEW.id, OLD.id),
            COALESCE(NEW.customer_no, NEW.vehicle_no, NEW.policy_no, OLD.customer_no, OLD.vehicle_no, OLD.policy_no),
            old_data, new_data,
            COALESCE(NEW.created_by, NEW.updated_by, auth.uid()),
            NULL
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为核心表添加审计触发器
CREATE TRIGGER audit_customers
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_vehicles
    AFTER INSERT OR UPDATE OR DELETE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- ============================================================
-- Part 10: RLS行级安全策略
-- ============================================================

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE kv_store ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;

-- 客户表RLS策略：用户只能看到自己的客户（owner是自己）和管理员可以看到所有
CREATE POLICY "users_select_customers" ON customers
    FOR SELECT USING (
        owner_user_id = auth.uid() 
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

CREATE POLICY "users_insert_customers" ON customers
    FOR INSERT WITH CHECK (
        created_by = auth.uid() OR auth.uid() IS NOT NULL
    );

CREATE POLICY "users_update_customers" ON customers
    FOR UPDATE USING (
        owner_user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

-- 车辆表RLS策略：只能看到所属客户的车辆
CREATE POLICY "users_select_vehicles" ON vehicles
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM customers WHERE owner_user_id = auth.uid()
        )
        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

CREATE POLICY "users_insert_vehicles" ON vehicles
    FOR INSERT WITH CHECK (
        customer_id IN (SELECT id FROM customers WHERE owner_user_id = auth.uid())
        OR auth.uid() IS NOT NULL
    );

-- 审计日志：只有管理员可看
CREATE POLICY "admin_only_audit" ON audit_logs
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

-- ============================================================
-- 完成
-- ============================================================
