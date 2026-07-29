-- Migration: 20260730000000_monetization_schema.sql
-- Purpose: Schema for subscriptions, purchases, founder allocations (1,000 max), lifetime allocations (250 max), registered devices and RLS rules.

BEGIN;

-- 1. Subscription Entitlements Table
CREATE TABLE IF NOT EXISTS public.subscription_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tier VARCHAR(50) NOT NULL DEFAULT 'free',
    source VARCHAR(50) NOT NULL DEFAULT 'free',
    storekit_original_transaction_id VARCHAR(255) UNIQUE,
    storekit_product_id VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT true,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscription_entitlements_user ON public.subscription_entitlements(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_entitlements_active ON public.subscription_entitlements(user_id, is_active);

-- 2. Purchase Transactions Table
CREATE TABLE IF NOT EXISTS public.purchase_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    original_transaction_id VARCHAR(255) UNIQUE NOT NULL,
    transaction_id VARCHAR(255) NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    environment VARCHAR(50) NOT NULL DEFAULT 'Production',
    purchase_date TIMESTAMPTZ NOT NULL,
    expiration_date TIMESTAMPTZ,
    revocation_date TIMESTAMPTZ,
    payload_raw JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_transactions_user ON public.purchase_transactions(user_id);

-- 3. Founder Allocations Table (Max 1,000)
CREATE TABLE IF NOT EXISTS public.founder_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    allocation_number INT NOT NULL UNIQUE CHECK (allocation_number >= 1 AND allocation_number <= 1000),
    original_transaction_id VARCHAR(255) UNIQUE NOT NULL,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_allocations_user ON public.founder_allocations(user_id);

-- 4. Lifetime Allocations Table (Max 250)
CREATE TABLE IF NOT EXISTS public.lifetime_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    allocation_number INT NOT NULL UNIQUE CHECK (allocation_number >= 1 AND allocation_number <= 250),
    original_transaction_id VARCHAR(255) UNIQUE NOT NULL,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lifetime_allocations_user ON public.lifetime_allocations(user_id);

-- 5. Registered Devices Table
CREATE TABLE IF NOT EXISTS public.registered_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL DEFAULT 'iOS',
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_device UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_registered_devices_user ON public.registered_devices(user_id);

-- 6. Transactional Security Functions for Quota Allocation (Idempotent with FOR UPDATE)

CREATE OR REPLACE FUNCTION public.claim_founder_allocation(
    p_user_id UUID,
    p_original_transaction_id TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_number INT;
    v_next_number INT;
BEGIN
    SELECT allocation_number INTO v_existing_number
    FROM public.founder_allocations
    WHERE user_id = p_user_id;

    IF v_existing_number IS NOT NULL THEN
        RETURN v_existing_number;
    END IF;

    SELECT COALESCE(MAX(allocation_number), 0) + 1 INTO v_next_number
    FROM public.founder_allocations
    FOR UPDATE;

    IF v_next_number > 1000 THEN
        RAISE EXCEPTION 'Capacidad máxima de 1.000 cupos Founder alcanzada.' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.founder_allocations (user_id, allocation_number, original_transaction_id)
    VALUES (p_user_id, v_next_number, p_original_transaction_id);

    RETURN v_next_number;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_lifetime_allocation(
    p_user_id UUID,
    p_original_transaction_id TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_number INT;
    v_next_number INT;
BEGIN
    SELECT allocation_number INTO v_existing_number
    FROM public.lifetime_allocations
    WHERE user_id = p_user_id;

    IF v_existing_number IS NOT NULL THEN
        RETURN v_existing_number;
    END IF;

    SELECT COALESCE(MAX(allocation_number), 0) + 1 INTO v_next_number
    FROM public.lifetime_allocations
    FOR UPDATE;

    IF v_next_number > 250 THEN
        RAISE EXCEPTION 'Capacidad máxima de 250 cupos Lifetime alcanzada.' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.lifetime_allocations (user_id, allocation_number, original_transaction_id)
    VALUES (p_user_id, v_next_number, p_original_transaction_id);

    RETURN v_next_number;
END;
$$;

-- 7. Row Level Security (RLS) Policies

ALTER TABLE public.subscription_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lifetime_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registered_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own entitlements"
    ON public.subscription_entitlements FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can read own transactions"
    ON public.purchase_transactions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can read own founder allocation"
    ON public.founder_allocations FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can read own lifetime allocation"
    ON public.lifetime_allocations FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own registered devices"
    ON public.registered_devices FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMIT;
