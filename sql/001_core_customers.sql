-- ============================================================================
-- 汽车全生态CRM - 核心客户表
-- 版本: V1.0 | 日期: 2026-04-19
-- 说明: 所有模块的根表，通过customer_id关联各业务模块
-- ============================================================================

-- 客户主表（核心表，所有模块的根）
CREATE TABLE IF NOT EXISTS core_customers (
    -- 主键和基础字段
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_no VARCHAR(20) UNIQUE NOT NULL,  -- 客户编号，格式: C + 年份 + 6位序号，如 C2026000001
    
    -- 基础信息
    name VARCHAR(100) NOT NULL,                 -- 姓名
    id_card VARCHAR(18),                        -- 身份证号（加密存储）
    id_card_hash VARCHAR(64),                   -- 身份证号哈希（用于快速查重）
    phone VARCHAR(20) NOT NULL,                 -- 手机号
    phone_hash VARCHAR(64),                     -- 手机号哈希
    phone_2 VARCHAR(20),                       -- 备用手机号
    email VARCHAR(100),                        -- 邮箱
    
    -- 地址信息
    province VARCHAR(50),                      -- 省份
    city VARCHAR(50),                          -- 城市
    district VARCHAR(50),                      -- 区/县
    address_detail VARCHAR(200),                -- 详细地址
    
    -- 客户分类
    customer_type VARCHAR(20) DEFAULT 'personal',  -- personal/personal/business/enterprise
    customer_source VARCHAR(50),                -- 客户来源：车险/转介绍/网络/其他
    
    -- 客户画像（JSON字段，灵活扩展）
    profile JSONB DEFAULT '{}',                 -- {
                                               --   birthday: 生日,
                                               --   gender: 性别,
                                               --   occupation: 职业,
                                               --   annual_income: 年收入,
                                               --   family_members: 家庭成员数,
                                               --   tags: [标签数组],
                                               --   notes: 备注
                                               -- }
    
    -- 车辆信息（主要车辆，与vehicles表一对多）
    primary_vehicle_id UUID,                   -- 主车辆ID，关联vehicles表
    
    -- 归属和营销
    owner_id UUID,                             -- 归属业务员ID，关联staff表
    owner_name VARCHAR(100),                    -- 归属业务员姓名（冗余字段，加速查询）
    channel VARCHAR(50),                       -- 渠道来源
    campaign VARCHAR(100),                      -- 营销活动
    
    -- 价值评估
    customer_level VARCHAR(10) DEFAULT 'C',     -- A/B/C/D 客户等级
    lifetime_value DECIMAL(12,2) DEFAULT 0,    -- 终身价值预估
    total_premium DECIMAL(12,2) DEFAULT 0,     -- 历史总保费
    total_orders DECIMAL(12,2) DEFAULT 0,      -- 历史总订单金额
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active',       -- active/inactive/blacklist
    last_contact_date DATE,                    -- 最后联系日期
    next_followup_date DATE,                   -- 下次跟进日期
    
    -- 审计字段（所有表统一）
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    delete_reason VARCHAR(200),
    
    -- 约束
    CONSTRAINT customer_no_format CHECK (customer_no ~ '^C[0-9]{10}$'),
    CONSTRAINT phone_format CHECK (phone ~ '^[0-9]{7,20}$'),
    CONSTRAINT id_card_format CHECK (id_card IS NULL OR id_card ~ '^[0-9]{17}[0-9X]$')
);

-- 创建索引
CREATE INDEX idx_customers_phone ON core_customers(phone_hash);
CREATE INDEX idx_customers_id_card ON core_customers(id_card_hash);
CREATE INDEX idx_customers_owner ON core_customers(owner_id);
CREATE INDEX idx_customers_status ON core_customers(status);
CREATE INDEX idx_customers_type ON core_customers(customer_type);
CREATE INDEX idx_customers_created ON core_customers(created_at DESC);

COMMENT ON TABLE core_customers IS '客户主表 - 所有业务模块的根表';
COMMENT ON COLUMN core_customers.customer_no IS '客户编号，格式C2026000001，唯一不重复';
COMMENT ON COLUMN core_customers.profile IS 'JSON字段，存储客户画像数据，灵活扩展';
COMMENT ON COLUMN core_customers.lifetime_value IS '客户终身价值预估，单位元';
