create extension if not exists pgcrypto;

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  owner_name text not null,
  phone text not null default '',
  location text not null,
  business_type text not null,
  created_at timestamptz not null default now()
);

alter table public.shops alter column phone set default '';

-- One row per payment recorded against a layby sale. Kept even after the
-- layby settles so the full payment history is always retrievable.
create table if not exists public.layby_payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  paid_at timestamptz not null default now()
);

create index if not exists layby_payments_sale_idx on public.layby_payments (sale_id, paid_at);
create index if not exists layby_payments_shop_idx on public.layby_payments (shop_id, paid_at desc);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  category text not null,
  sku text not null,
  size text not null default '',
  color text not null default '',
  cost numeric(12, 2) not null check (cost >= 0),
  price numeric(12, 2) not null check (price > 0),
  quantity integer not null check (quantity >= 0),
  created_at timestamptz not null default now(),
  unique (shop_id, sku)
);

alter table public.products
  add column if not exists image_url text not null default '';

-- Supplier recorded against each product for reorders.
alter table public.products
  add column if not exists supplier_name text not null default '';

alter table public.products
  add column if not exists unit_cost numeric(12, 2) not null default 0;

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  contact_name text not null default '',
  phone text not null default '',
  email text not null default '',
  address text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  discount numeric(12, 2) not null default 0 check (discount >= 0),
  total numeric(12, 2) not null check (total >= 0),
  payment_method text not null,
  sold_at timestamptz not null default now(),
  layby_deposit numeric(12, 2) not null default 0 check (layby_deposit >= 0),
  layby_balance numeric(12, 2) not null default 0 check (layby_balance >= 0),
  layby_settled boolean not null default false,
  customer_name text not null default '',
  customer_phone text not null default ''
);

alter table public.sales
  add column if not exists layby_deposit numeric(12, 2) not null default 0,
  add column if not exists layby_balance numeric(12, 2) not null default 0,
  add column if not exists layby_settled boolean not null default false,
  add column if not exists customer_name text not null default '',
  add column if not exists customer_phone text not null default '';

-- Online vs walk-in channel recorded on every sale.
alter table public.sales
  add column if not exists sale_type text not null default 'Walk-in';

alter table public.sales
  add column if not exists sale_channel text not null default 'Walk-in';

-- Operating expenses feeding the net-profit report.
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category text not null,
  amount numeric(12, 2) not null check (amount > 0),
  note text not null default '',
  payment_method text not null default 'Cash Drawer',
  spent_on date not null default current_date,
  created_at timestamptz not null default now()
);

-- Existing installs: add the payment_method column to the expenses table.
alter table public.expenses
  add column if not exists payment_method text not null default 'Cash Drawer';

create index if not exists expenses_shop_period_idx on public.expenses (shop_id, spent_on);

-- Owner vs employee access. Employees get Sales + Daily Sales only.
create table if not exists public.shop_users (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  role text not null default 'employee' check (role in ('owner', 'employee')),
  display_name text not null default '',
  created_at timestamptz not null default now()
);

insert into public.shop_users (shop_id, user_id, role, display_name)
select id, owner_id, 'owner', owner_name from public.shops
on conflict (user_id) do nothing;

create index if not exists sales_open_layby_idx on public.sales (shop_id)
  where layby_balance > 0 and not layby_settled;

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price > 0),
  unit_cost numeric(12, 2) not null check (unit_cost >= 0),
  size text not null default '',
  color text not null default ''
);

-- Make the product reference nullable for existing installs so deleting a
-- product does not violate the FK (sale history keeps product_name, so the
-- record stays readable after the product is gone).
alter table public.sale_items
  alter column product_id drop not null;
alter table public.sale_items
  drop constraint if exists sale_items_product_id_fkey;
alter table public.sale_items
  add constraint sale_items_product_id_fkey
  foreign key (product_id) references public.products(id) on delete set null;

alter table public.sale_items
  add column if not exists unit_cost numeric(12, 2);

update public.sale_items as items
set unit_cost = products.cost
from public.products as products
where items.product_id = products.id and items.unit_cost is null;

update public.sale_items set unit_cost = 0 where unit_cost is null;

alter table public.sale_items
  alter column unit_cost set default 0,
  alter column unit_cost set not null;

alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.suppliers enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.layby_payments enable row level security;
alter table public.expenses enable row level security;
alter table public.shop_users enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update on public.shops to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.suppliers to authenticated;
grant select, insert, update, delete on public.sales, public.sale_items to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
grant select, insert on public.layby_payments to authenticated;

-- Owner-only management happens through the service role via the API;
-- employees need read on shop_users to know their own role.
grant select on public.shop_users to authenticated;

drop policy if exists "Shop owners manage layby payments" on public.layby_payments;
create policy "Shop owners manage layby payments" on public.layby_payments
  for all to authenticated
  using (
    exists (
      select 1 from public.shops
      where shops.id = layby_payments.shop_id and shops.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.shops
      where shops.id = layby_payments.shop_id and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners read their shop" on public.shops;
create policy "Shop owners read their shop" on public.shops
  for select to authenticated using (owner_id = auth.uid());
drop policy if exists "Shop owners create their shop" on public.shops;
create policy "Shop owners create their shop" on public.shops
  for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists "Shop owners update their shop" on public.shops;
create policy "Shop owners update their shop" on public.shops
  for update to authenticated using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "Shop owners read their products" on public.products;
create policy "Shop owners read their products" on public.products
  for select to authenticated using (
    exists (
      select 1 from public.shops
      where shops.id = products.shop_id and shops.owner_id = auth.uid()
    )
  );
drop policy if exists "Shop owners add their products" on public.products;
create policy "Shop owners add their products" on public.products
  for insert to authenticated with check (
    exists (
      select 1 from public.shops
      where shops.id = products.shop_id and shops.owner_id = auth.uid()
    )
  );
drop policy if exists "Shop owners update their products" on public.products;
create policy "Shop owners update their products" on public.products
  for update to authenticated using (
    exists (
      select 1 from public.shops
      where shops.id = products.shop_id and shops.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.shops
      where shops.id = products.shop_id and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners delete their products" on public.products;
create policy "Shop owners delete their products" on public.products
  for delete to authenticated using (
    exists (
      select 1 from public.shops
      where shops.id = products.shop_id and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners manage their suppliers" on public.suppliers;
create policy "Shop owners manage their suppliers" on public.suppliers
  for all to authenticated
  using (
    exists (
      select 1 from public.shops
      where shops.id = suppliers.shop_id and shops.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.shops
      where shops.id = suppliers.shop_id and shops.owner_id = auth.uid()
    )
  );

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

-- ---------------- Expense policies (owner-only via the shops owner link) ----
drop policy if exists "Shop owners manage expenses" on public.expenses;
create policy "Shop owners manage expenses" on public.expenses
  for all to authenticated
  using (
    exists (
      select 1 from public.shops
      where shops.id = expenses.shop_id and shops.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.shops
      where shops.id = expenses.shop_id and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners read product images" on storage.objects;
create policy "Shop owners read product images" on storage.objects
  for select to authenticated using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.shops
      where shops.id::text = split_part(name, '/', 1)
        and shops.owner_id = auth.uid()
    )
  );
drop policy if exists "Shop owners upload product images" on storage.objects;
create policy "Shop owners upload product images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.shops
      where shops.id::text = split_part(name, '/', 1)
        and shops.owner_id = auth.uid()
    )
  );
drop policy if exists "Shop owners update product images" on storage.objects;
create policy "Shop owners update product images" on storage.objects
  for update to authenticated using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.shops
      where shops.id::text = split_part(name, '/', 1)
        and shops.owner_id = auth.uid()
    )
  ) with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.shops
      where shops.id::text = split_part(name, '/', 1)
        and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners read their sales" on public.sales;
create policy "Shop owners read their sales" on public.sales
  for select to authenticated using (
    exists (
      select 1 from public.shops
      where shops.id = sales.shop_id and shops.owner_id = auth.uid()
    )
  );
drop policy if exists "Shop owners create their sales" on public.sales;
create policy "Shop owners create their sales" on public.sales
  for insert to authenticated with check (
    exists (
      select 1 from public.shops
      where shops.id = sales.shop_id and shops.owner_id = auth.uid()
    )
  );

-- Required by the pay_layby() security-invoker function: without an UPDATE
-- policy, RLS rejects the row update even with the UPDATE privilege granted.
drop policy if exists "Shop owners update their sales" on public.sales;
create policy "Shop owners update their sales" on public.sales
  for update to authenticated
  using (
    exists (
      select 1 from public.shops
      where shops.id = sales.shop_id and shops.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.shops
      where shops.id = sales.shop_id and shops.owner_id = auth.uid()
    )
  );

-- Owners can void / delete mistaken sales entirely.
drop policy if exists "Shop owners delete their sales" on public.sales;
create policy "Shop owners delete their sales" on public.sales
  for delete to authenticated using (
    exists (
      select 1 from public.shops
      where shops.id = sales.shop_id and shops.owner_id = auth.uid()
    )
  );

-- Cascading a sale delete removes its sale_items rows; RLS still applies to
-- the cascaded DELETE, so without this policy the sale delete itself fails.
drop policy if exists "Shop owners delete their sale items" on public.sale_items;
create policy "Shop owners delete their sale items" on public.sale_items
  for delete to authenticated using (
    exists (
      select 1 from public.sales
      join public.shops on shops.id = sales.shop_id
      where sales.id = sale_items.sale_id and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners read their sale items" on public.sale_items;
create policy "Shop owners read their sale items" on public.sale_items
  for select to authenticated using (
    exists (
      select 1 from public.sales
      join public.shops on shops.id = sales.shop_id
      where sales.id = sale_items.sale_id and shops.owner_id = auth.uid()
    )
  );
drop policy if exists "Shop owners create their sale items" on public.sale_items;
create policy "Shop owners create their sale items" on public.sale_items
  for insert to authenticated with check (
    exists (
      select 1 from public.sales
      join public.shops on shops.id = sales.shop_id
      where sales.id = sale_items.sale_id and shops.owner_id = auth.uid()
    )
  );

-- Employees (linked in shop_users) can read their shop's products and sales,
-- and create sales, but not manage inventory or suppliers.
-- Shop members read products and sales through their own shop_users rows.
-- Reading the shops row itself is owner-only (owner_id = auth.uid()).
-- A shops policy that references shop_users recurses with the shop_users
-- policy that references shops, causing "infinite recursion detected".
drop policy if exists "Shop members read their shop" on public.shops;

drop policy if exists "Shop members read products" on public.products;
create policy "Shop members read products" on public.products
  for select to authenticated using (
    exists (
      select 1 from public.shop_users
      where shop_users.shop_id = products.shop_id and shop_users.user_id = auth.uid()
    )
  );

drop policy if exists "Shop members read sales" on public.sales;
create policy "Shop members read sales" on public.sales
  for select to authenticated using (
    exists (
      select 1 from public.shop_users
      where shop_users.shop_id = sales.shop_id and shop_users.user_id = auth.uid()
    )
  );

drop policy if exists "Shop members create sales" on public.sales;
create policy "Shop members create sales" on public.sales
  for insert to authenticated with check (
    exists (
      select 1 from public.shop_users
      where shop_users.shop_id = sales.shop_id and shop_users.user_id = auth.uid()
    )
  );

drop policy if exists "Shop members read sale items" on public.sale_items;
create policy "Shop members read sale items" on public.sale_items
  for select to authenticated using (
    exists (
      select 1 from public.sales
      join public.shop_users on shop_users.shop_id = sales.shop_id
      where sales.id = sale_items.sale_id and shop_users.user_id = auth.uid()
    )
  );

drop policy if exists "Shop members create sale items" on public.sale_items;
create policy "Shop members create sale items" on public.sale_items
  for insert to authenticated with check (
    exists (
      select 1 from public.sales
      join public.shop_users on shop_users.shop_id = sales.shop_id
      where sales.id = sale_items.sale_id and shop_users.user_id = auth.uid()
    )
  );

drop policy if exists "Shop members read shop_users" on public.shop_users;
create policy "Shop members read shop_users" on public.shop_users
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.shops
      where shops.id = shop_users.shop_id and shops.owner_id = auth.uid()
    )
  );

drop policy if exists "Shop owners manage shop_users" on public.shop_users;
create policy "Shop owners manage shop_users" on public.shop_users
  for all to authenticated
  using (
    exists (
      select 1 from public.shops
      where shops.id = shop_users.shop_id and shops.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.shops
      where shops.id = shop_users.shop_id and shops.owner_id = auth.uid()
    )
  );

-- If an earlier version of this function exists with a different signature,
-- 'create or replace' would ADD an overload instead of replacing it, and
-- PostgREST would then fail every sale with PGRST203 ("Could not choose the
-- best candidate function"). Drop any stale overload first.
drop function if exists public.create_shop_sale(
  uuid, numeric, text, jsonb
);
drop function if exists public.create_shop_sale(
  uuid, numeric, text, jsonb, numeric, text, text
);
drop function if exists public.create_shop_sale(
  uuid, numeric, text, jsonb, numeric, text, text, text
);
drop function if exists public.create_shop_sale(
  uuid, numeric, text, jsonb, numeric, text, text, numeric, text
);
drop function if exists public.create_shop_sale(
  uuid, numeric, text, jsonb, numeric, text, text, text, numeric
);

create or replace function public.create_shop_sale(
  p_shop_id uuid,
  p_discount_percent numeric,
  p_payment_method text,
  p_items jsonb,
  p_layby_deposit numeric default 0,
  p_customer_name text default '',
  p_customer_phone text default '',
  p_discount_type text default 'percent',
  p_discount_value numeric default 0,
  p_sale_type text default 'Walk-in'
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_item jsonb;
  v_product public.products%rowtype;
  v_sale public.sales%rowtype;
  v_quantity integer;
  v_subtotal numeric(12, 2) := 0;
  v_discount numeric(12, 2);
  v_sale_type text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.shops where id = p_shop_id and owner_id = auth.uid()
  ) and not exists (
    select 1 from public.shop_users
    where shop_users.shop_id = p_shop_id and shop_users.user_id = auth.uid()
  ) then
    raise exception 'Shop not found for the signed-in user.';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A sale must contain at least one item.';
  end if;
  if p_discount_percent < 0 or p_discount_percent > 100 then
    raise exception 'Discount must be between zero and one hundred percent.';
  end if;
  if coalesce(trim(p_payment_method), '') = '' then
    raise exception 'Payment method is required.';
  end if;
  v_sale_type := case
    when lower(coalesce(p_sale_type, '')) like 'online%' then 'Online'
    else 'Walk-in'
  end;

  for v_product in
    select products.*
    from public.products
    where products.shop_id = p_shop_id
      and products.id in (
        select distinct (entry.item->>'product_id')::uuid
        from jsonb_array_elements(p_items) as entry(item)
      )
    order by products.id
    for update
  loop
    select coalesce(sum((item->>'quantity')::integer), 0)
      into v_quantity
      from jsonb_array_elements(p_items) as entry(item)
      where (entry.item->>'product_id')::uuid = v_product.id;
    if v_quantity <= 0 then
      raise exception 'Item quantity must be greater than zero.';
    end if;
    if v_product.quantity < v_quantity then
      raise exception 'Insufficient stock for product %.', v_product.name;
    end if;
    v_subtotal := v_subtotal + v_product.price * v_quantity;
  end loop;

  if exists (
    select 1
    from jsonb_array_elements(p_items) as entry(item)
    where not exists (
      select 1 from public.products
      where id = (entry.item->>'product_id')::uuid and shop_id = p_shop_id
    )
  ) then
    raise exception 'Product not found in this shop.';
  end if;

  if p_discount_type = 'value' then
    v_discount := least(round(greatest(p_discount_value, 0), 2), v_subtotal);
  else
    v_discount := round(v_subtotal * p_discount_percent / 100, 2);
  end if;
  insert into public.sales (
    shop_id, subtotal, discount, total, payment_method, sale_type,
    layby_deposit, layby_balance, layby_settled,
    customer_name, customer_phone
  )
  values (
    p_shop_id, v_subtotal, v_discount, v_subtotal - v_discount, p_payment_method, v_sale_type,
    round(greatest(p_layby_deposit, 0), 2),
    case
      when lower(p_payment_method) = 'layby'
      then greatest(round(v_subtotal - v_discount, 2) - round(greatest(p_layby_deposit, 0), 2), 0)
      else 0
    end,
    false,
    coalesce(trim(p_customer_name), ''),
    coalesce(trim(p_customer_phone), '')
  )
  returning * into v_sale;

  for v_item in select entry.item from jsonb_array_elements(p_items) as entry(item)
  loop
    v_quantity := (v_item->>'quantity')::integer;
    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and shop_id = p_shop_id;
    insert into public.sale_items (
      sale_id, product_id, product_name, quantity, unit_price, unit_cost, size, color
    ) values (
      v_sale.id, v_product.id, v_product.name, v_quantity, v_product.price,
      v_product.cost, coalesce(v_item->>'size', v_product.size),
      coalesce(v_item->>'color', v_product.color)
    );
  end loop;

  update public.products as products
  set quantity = products.quantity - items.quantity
  from (
    select (entry.item->>'product_id')::uuid as product_id,
      sum((entry.item->>'quantity')::integer)::integer as quantity
    from jsonb_array_elements(p_items) as entry(item)
    group by (entry.item->>'product_id')::uuid
  ) as items
  where products.id = items.product_id and products.shop_id = p_shop_id;

  return to_jsonb(v_sale);
end;
$$;

revoke all on function public.create_shop_sale(uuid, numeric, text, jsonb, numeric, text, text, text, numeric, text)
  from public, anon;
grant execute on function public.create_shop_sale(uuid, numeric, text, jsonb, numeric, text, text, text, numeric, text)
  to authenticated;

-- Records a payment against an open layby sale, appends a row to
-- layby_payments so the history survives after settlement, and closes the
-- layby when the balance reaches zero. Returns the updated sale row.
create or replace function public.pay_layby(
  p_sale_id uuid,
  p_amount numeric
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_sale public.sales%rowtype;
  v_amount numeric(12, 2);
begin
  if auth.uid() is null or not exists (
    select 1 from public.shops
    where id = (select shop_id from public.sales where id = p_sale_id)
      and owner_id = auth.uid()
  ) then
    raise exception 'Sale not found for the signed-in user.';
  end if;

  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then
    raise exception 'Sale not found.';
  end if;
  if v_sale.layby_balance <= 0 or v_sale.layby_settled then
    raise exception 'This sale is not an open layby.';
  end if;

  v_amount := round(p_amount, 2);
  if v_amount <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  update public.sales
  set layby_deposit = layby_deposit + v_amount,
    layby_balance = greatest(layby_balance - v_amount, 0),
    layby_settled = (layby_balance - v_amount) <= 0
  where id = p_sale_id
  returning * into v_sale;

  insert into public.layby_payments (sale_id, shop_id, amount)
  values (p_sale_id, v_sale.shop_id, v_amount);

  return to_jsonb(v_sale);
end;
$$;

revoke all on function public.pay_layby(uuid, numeric) from public, anon;
grant execute on function public.pay_layby(uuid, numeric) to authenticated;
