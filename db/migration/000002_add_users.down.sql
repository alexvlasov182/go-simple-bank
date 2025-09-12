-- Drop the foreign key first
ALTER TABLE IF EXISTS "accounts" DROP CONSTRAINT IF EXISTS "fk_owner";

-- Drop other constraints if needed
ALTER TABLE IF EXISTS "accounts" DROP CONSTRAINT IF EXISTS "owner_currency_key";
ALTER TABLE IF EXISTS "accounts" DROP CONSTRAINT IF EXISTS "accounts_owner_key";

-- Now drop dependent tables
DROP TABLE IF EXISTS "users";
