-- Auto-CRM 云端数据库建表 SQL
-- 在 Supabase Dashboard → SQL Editor 中粘贴执行

-- customers 客户表
CREATE TABLE IF NOT EXISTS public.customers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT,
  phone TEXT,
  id_card TEXT,
  address TEXT,
  remark TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- car_policies 车险保单表
CREATE TABLE IF NOT EXISTS public.car_policies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  vehicle_id TEXT,
  company TEXT,
  commercial_premium NUMERIC,
  compulsory_premium NUMERIC,
  vehicle_tax NUMERIC,
  total_premium NUMERIC,
  commission NUMERIC,
  start_date DATE,
  end_date DATE,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- followups 跟进记录表
CREATE TABLE IF NOT EXISTS public.followups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  content TEXT,
  next_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- noncar_policies 非车险表
CREATE TABLE IF NOT EXISTS public.noncar_policies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  type TEXT,
  company TEXT,
  premium NUMERIC,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 禁用 RLS（方便直接读写）
ALTER TABLE public.customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_policies DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.followups DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.noncar_policies DISABLE ROW LEVEL SECURITY;