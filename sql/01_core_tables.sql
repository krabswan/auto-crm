-- ============================================================
-- 汽车全生态客户管理系统 - 数据库Schema
-- 版本：V1.0 | 日期：2026-04-19
-- 作者：痞老板
-- 数据库：Supabase (PostgreSQL)
-- ============================================================

-- ============================================================
-- 第一部分：扩展和基础配置
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 第二部分：枚举类型定义
-- ============================================================

-- 客户类型
CREATE TYPE customer_type AS ENUM ('individual', 'enterprise', 'government');
-- 客户状态
CREATE TYPE customer_status AS ENUM ('active', 'inactive', 'blacklist', 'potential');
-- 客户来源
CREATE TYPE customer_source AS ENUM ('referral', 'walking', 'phone', 'online', 'partner', 'renewal', 'other');
-- 性别
CREATE TYPE gender AS ENUM ('male', 'female', 'unknown');
-- 关系
CREATE TYPE relationship_type AS ENUM ('self', 'spouse', 'parent', 'child', 'sibling', 'colleague', 'friend', 'other');
-- 证件类型
CREATE TYPE id_type AS ENUM ('id_card', 'passport', 'driver_license', 'business_license', 'other');

-- 车辆状态
CREATE TYPE vehicle_status AS ENUM ('active', 'scrapped', 'transferred', 'insurance_expired');
-- 能源类型
CREATE TYPE energy_type AS ENUM ('gasoline', 'diesel', 'hybrid', 'electric', 'natural_gas', 'other');
-- 使用性质
CREATE TYPE vehicle_usage AS ENUM ('family', 'business', 'rental', 'public', 'police', 'other');

-- 保单状态
CREATE TYPE policy_status AS ENUM ('pending', 'effective', 'expired', 'cancelled', 'terminated', 'renewed');
-- 支付状态
CREATE TYPE payment_status AS ENUM ('unpaid', 'paid', 'overdue', 'refunded', 'partial');
-- 支付方式
CREATE TYPE payment_method AS ENUM ('cash', 'transfer', 'wechat', 'alipay', 'card', 'insurance_company');
-- 销售渠道
CREATE TYPE sales_channel AS ENUM ('self', 'agency', 'online', 'phone', 'partner', 'dianping');

-- 险种
CREATE TYPE car_insurance_type AS ENUM ('compulsory', 'commercial', 'third_party', 'driver', 'passenger', 'theft', 'glass', 'scratch', '自然灾害', '不计免赔', 'other');
CREATE TYPE noncar_insurance_type AS ENUM ('accident', 'health', 'life', 'property', 'liability', 'engineering', 'credit', 'other');

-- 理赔状态
CREATE TYPE claim_status AS ENUM ('reported', 'investigating', 'approved', 'rejected', 'paid', 'closed');

-- 服务订单状态
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'completed', 'cancelled', 'refunded');
-- 服务类型
CREATE TYPE service_type AS ENUM ('rescue', 'repair', 'beauty', 'accessories', 'tire', 'car_wash', 'inspection', 'other');

-- 金融合同状态
CREATE TYPE finance_status AS ENUM ('pending', 'approved', 'active', 'completed', 'overdue', 'default', 'cancelled');
-- 贷款类型
CREATE TYPE loan_type AS ENUM ('new_car', 'used_car', 'refinance', 'mortgage', 'other');

-- 员工状态
CREATE TYPE employee_status AS ENUM ('active', 'inactive', 'on_leave', 'terminated');

-- 操作类型（审计日志）
CREATE TYPE operation_type AS ENUM ('create', 'read', 'update', 'delete', 'login', 'logout', 'export', 'import', 'approve', 'reject');

-- ============================================================
-- 第三部分：核心表 - 统一客户中心
-- ============================================================

-- 客户主表
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_no VARCHAR(20) UNIQUE NOT NULL,  -- 客户编号 CS-YYYYMMDD-XXXX
    customer_type customer_type NOT NULL DEFAULT 'individual',
    name VARCHAR(100) NOT NULL,               -- 姓名/名称
    gender gender DEFAULT 'unknown',
    id_type id_type DEFAULT 'id_card',
    id_number VARCHAR(50),                      -- 证件号（加密存储）
    id_number_masked VARCHAR(50),             -- 脱敏后证件号
    phone VARCHAR(20),                         -- 主手机号
    phone_masked VARCHAR(20),                  -- 脱敏手机号
    phone_2 VARCHAR(20),                       -- 备用手机
    email VARCHAR(100),
    address_province VARCHAR(20),
    address_city VARCHAR(20),
    address_district VARCHAR(20),
    address_detail VARCHAR(200),
    birthday DATE,
    occupation VARCHAR(100),                   -- 职业
    annual_income DECIMAL(12,2),              -- 年收入（敏感）
    source customer_source DEFAULT 'walking',
    source_detail VARCHAR(100),               -- 来源详情
    referrer_id UUID,                          -- 推荐人ID
    tags TEXT[],                               -- 标签数组
    remark TEXT,                               -- 备注
    status customer_status DEFAULT 'active',
    last_contact_date DATE,                   -- 最后联系日期
    next_contact_date DATE,                   -- 下次联系日期
    lifetime_value DECIMAL(12,2) DEFAULT 0,  -- 客户终身价值
    total_premium DECIMAL(12,2) DEFAULT 0,    -- 累计保费
    total_orders INTEGER DEFAULT 0,            -- 累计订单数
    
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

-- 车辆主表（每个客户可有多辆车）
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_no VARCHAR(30) UNIQUE NOT NULL,   -- 车辆编号 VH-YYYYMMDD-XXXX
    customer_id UUID NOT NULL REFERENCES customers(id),
    plate_number VARCHAR(20) NOT NULL,        -- 车牌号
    plate_number_masked VARCHAR(20),           -- 脱敏车牌
    vin VARCHAR(50) UNIQUE NOT NULL,          -- 车架号
    vin_masked VARCHAR(50),                   -- 脱敏车架号
    engine_no VARCHAR(50),                    -- 发动机号
    brand VARCHAR(50),                        -- 品牌
    series VARCHAR(50),                        -- 车系
    model VARCHAR(100),                       -- 车型
    model_year INTEGER,                        -- 年款
    color VARCHAR(30),                         -- 颜色
    energy_type energy_type DEFAULT 'gasoline',
    vehicle_usage vehicle_usage DEFAULT 'family',
    displacement DECIMAL(3,1),               -- 排量(L)
    purchase_date DATE,                        -- 购车日期
    purchase_price DECIMAL(12,2),            -- 购车价格
    current_value DECIMAL(12,2),             -- 当前估值
    plate_province VARCHAR(20),
    plate_city VARCHAR(20),
    plate_color VARCHAR(10),                  -- 蓝牌/绿牌
    seats INTEGER,                             -- 座位数
    curb_weight DECIMAL(8,2),                 -- 整备质量
    annual_inspection_date DATE,              -- 年审日期
    insurance_expire_date DATE,               -- 保险到期日期
    road_tax_expire_date DATE,                -- 车船税到期
    mileage INTEGER,                          -- 当前里程
    status vehicle_status DEFAULT 'active',
    tags TEXT[],
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

-- 客户关系表（家庭成员、同事等关联）
CREATE TABLE customer_relations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id),
    related_customer_id UUID REFERENCES customers(id),
    related_name VARCHAR(100),                -- 当关联客户不在系统中时
    related_phone VARCHAR(20),
    relationship relationship_type NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,        -- 主要联系人
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

-- 员工表
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_no VARCHAR(20) UNIQUE NOT NULL, -- 员工编号 EP-YYYYMMDD-XXXX
    name VARCHAR(50) NOT NULL,
    gender gender DEFAULT 'unknown',
    phone VARCHAR(20),
    email VARCHAR(100),
    department VARCHAR(50),
    position VARCHAR(50),
    id_number VARCHAR(50),
    hire_date DATE,
    status employee_status DEFAULT 'active',
    is_salesman BOOLEAN DEFAULT FALSE,        -- 是否业务员
    commission_rate DECIMAL(5,4),            -- 默认佣金比例
    manager_id UUID,                          -- 上级ID
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

-- 角色表
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_code VARCHAR(50) UNIQUE NOT NULL,
    role_name VARCHAR(50) NOT NULL,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,         -- 系统内置角色
    permissions JSONB DEFAULT '[]',          -- 权限列表
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 员工角色关联表
CREATE TABLE employee_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    role_id UUID NOT NULL REFERENCES roles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 审计日志表（所有操作的完整记录）
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    operation operation_type NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changes JSONB,                            -- 变更字段明细
    ip_address INET,
    user_agent TEXT,
    employee_id UUID,
    employee_name VARCHAR(50),
    remark TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 系统配置表
CREATE TABLE system_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(20),                 -- string, number, boolean, json
    description TEXT,
    category VARCHAR(50),                    -- 模块分类
    is_encrypted BOOLEAN DEFAULT FALSE,       -- 是否加密存储
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID
);

-- ============================================================
-- 索引
-- ============================================================

CREATE INDEX idx_customers_phone ON customers(phone) WHERE NOT is_deleted;
CREATE INDEX idx_customers_id_number ON customers(id_number) WHERE NOT is_deleted AND id_number IS NOT NULL;
CREATE INDEX idx_customers_name ON customers(name) WHERE NOT is_deleted;
CREATE INDEX idx_customers_status ON customers(status) WHERE NOT is_deleted;
CREATE INDEX idx_customers_source ON customers(source) WHERE NOT is_deleted;
CREATE INDEX idx_customers_created_at ON customers(created_at DESC) WHERE NOT is_deleted;

CREATE INDEX idx_vehicles_plate ON vehicles(plate_number) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_vin ON vehicles(vin) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_customer ON vehicles(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_annual_inspection ON vehicles(annual_inspection_date) WHERE NOT is_deleted;
CREATE INDEX idx_vehicles_insurance_expire ON vehicles(insurance_expire_date) WHERE NOT is_deleted;

CREATE INDEX idx_customer_relations_customer ON customer_relations(customer_id) WHERE NOT is_deleted;
CREATE INDEX idx_customer_relations_related ON customer_relations(related_customer_id) WHERE NOT is_deleted;

CREATE INDEX idx_employees_phone ON employees(phone) WHERE NOT is_deleted;
CREATE INDEX idx_employees_status ON employees(status) WHERE NOT is_deleted;

CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_employee ON audit_logs(employee_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_operation ON audit_logs(operation);

CREATE INDEX idx_system_configs_key ON system_configs(config_key);

-- ============================================================
-- RLS 策略
-- ============================================================

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;

-- 默认策略：只读自己的数据（后续按需细化）
CREATE POLICY "Users can view all customers" ON customers FOR SELECT USING (true);
CREATE POLICY "Users can insert customers" ON customers FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update customers" ON customers FOR UPDATE USING (true);
CREATE POLICY "Users can delete customers" ON customers FOR DELETE USING (true);

CREATE POLICY "Users can view all vehicles" ON vehicles FOR SELECT USING (true);
CREATE POLICY "Users can insert vehicles" ON vehicles FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update vehicles" ON vehicles FOR UPDATE USING (true);
CREATE POLICY "Users can delete vehicles" ON vehicles FOR DELETE USING (true);

-- audit_logs 只允许插入，不允许直接读取/修改/删除
CREATE POLICY "Users can insert audit logs" ON audit_logs FOR INSERT WITH CHECK (true);
