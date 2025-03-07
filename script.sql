-- create database
create database dimas_ecommerce

-- Table users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) UNIQUE NOT NULL, 
    email VARCHAR(255) UNIQUE NOT NULL CHECK (email = LOWER(email)), -- email lowercase
    password TEXT NOT NULL,
    role VARCHAR(50) CHECK (role IN ('CUSTOMER', 'ADMIN')) NOT NULL DEFAULT 'CUSTOMER',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Trigger untuk updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- Insert
INSERT INTO users (id, name, email, password, role)
VALUES 
    (gen_random_uuid(), 'Admin User', 'admin@example.com', '$2a$10$X9w5lHqHqfK9tFmZ5k5QEeFzrfZQqRsHj4T.32/8BaaN6xD14v2iG', 'ADMIN'),
    (gen_random_uuid(), 'Customer One', 'customer1@example.com', '$2a$10$UvuvwevwevweOj9w0KQKROogOeKwOw6k92O.qdeX8ACzQO1E5yGPa', 'CUSTOMER'),
    (gen_random_uuid(), 'Customer Two', 'customer2@example.com', '$2a$10$UvuvwevwevweOj9w0KQKROogOeKwOw6k92O.qdeX8ACzQO1E5yGPa', 'CUSTOMER');


-- Cek hasilnya
SELECT * FROM users;


--------------------------------------------------------------------------------------


-- Table categories
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL CHECK (name = LOWER(name)), --lowercase untuk mencegah duplikasi case-sensitive
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Trigger untuk updated_at
CREATE OR REPLACE FUNCTION update_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_categories_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW
EXECUTE FUNCTION update_categories_updated_at();


-- Insert
INSERT INTO categories (name)
VALUES 
    ('elektronik'), 
    ('fashion'), 
    ('perabotan rumah'), 
    ('makanan & minuman'), 
    ('kesehatan');


-- Cek hasilnya
SELECT * FROM categories;


--------------------------------------------------------------------------------------


-- Table products
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0), -- Stok tidak boleh negatif
    category_id INT,
    status BOOLEAN DEFAULT TRUE, -- TRUE = Aktif, FALSE = Tidak aktif (out of stock)
    image_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- Trigger untuk updated_at
CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_products_updated_at();


-- Trigger status produk otomatis menjadi FALSE jika stok habis
CREATE OR REPLACE FUNCTION update_product_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock <= 0 THEN
        NEW.status = FALSE;
    ELSE
        NEW.status = TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Trigger berjalan saat INSERT dan UPDATE
CREATE TRIGGER trg_update_product_status
BEFORE INSERT OR UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_product_status();


-- Insert
INSERT INTO products (name, description, price, stock, category_id)
VALUES 
    ('Laptop Gaming 3', 'Laptop high-end untuk gaming', 15000000.00, 10, 1),
    ('Kemeja Pria', 'Kemeja formal pria', 250000.00, 20, 2),
    ('Meja Kayu', 'Meja kayu minimalis', 500000.00, 15, 3),
    ('Kopi Arabica', 'Biji kopi Arabica premium', 120000.00, 50, 4),
    ('Masker Medis', 'Masker sekali pakai', 50000.00, 0, 5); -- Stok 0, otomatis status FALSE

-- Update
UPDATE products p 
SET stock = 0
WHERE id = 1;
    
-- Cek hasilnya
SELECT * FROM products;


--------------------------------------------------------------------------------------


-- ENUM untuk status (Opsional, lebih cepat dari VARCHAR + CHECK)
CREATE TYPE order_status AS ENUM ('PENDING', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELED');


-- Table orders
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, 
    status order_status NOT NULL,  -- Menggunakan ENUM
    total_price DECIMAL(14,2) CHECK (total_price >= 0), -- Total tidak boleh negatif
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);


-- Index untuk mempercepat query berdasarkan user_id
CREATE INDEX idx_orders_user_id ON orders(user_id);


-- Trigger untuk update updated_at saat data diperbarui
CREATE OR REPLACE FUNCTION update_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_orders_updated_at();


-- Insert
INSERT INTO orders (user_id, status, total_price)
VALUES 
    ('6395ad7b-8707-4534-baed-c56a63968feb', 'PENDING', 150000.00),
    ('649efad0-e309-4714-9a3b-598481b021af', 'PAID', 250000.00),
    ('a1b290a2-3534-4c16-8e55-9ee3d1dff775', 'CANCELED', 0.00);

-- Cek hasilnya
SELECT * FROM orders;


--------------------------------------------------------------------------------------


-- Table order_items
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL,
    product_id SERIAL NOT NULL, 
    quantity INT NOT NULL CHECK (quantity > 0), -- Tidak boleh kurang dari 1
    price DECIMAL(14,2) NOT NULL CHECK (price >= 0), -- Tidak boleh harga negatif
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);


-- Index untuk mempercepat query
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);


-- Insert
INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES 
    ('0082f541-c969-4a98-89d2-ef2a77e3ed1a', '30', 2, 250000.00),
    ('0082f541-c969-4a98-89d2-ef2a77e3ed1a', '23', 2, 250000.00);

-- Cek hasilnya
SELECT * FROM order_items;


--------------------------------------------------------------------------------------


-- Table order_history
CREATE TABLE order_history (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL,
    status order_status NOT NULL, -- Menggunakan ENUM dari tabel orders
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP CHECK (changed_at <= NOW()), -- Tidak boleh di masa depan
    changed_by UUID NOT NULL, -- Pengguna yang mengubah status order
    CONSTRAINT fk_order_history_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_order_history_user FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL
);


-- Index untuk mempercepat pencarian berdasarkan order_id
CREATE INDEX idx_order_history_order_id ON order_history(order_id);


-- Insert
INSERT INTO order_history (order_id, status, changed_by)
VALUES 
    ('0082f541-c969-4a98-89d2-ef2a77e3ed1a', 'PENDING', '6395ad7b-8707-4534-baed-c56a63968feb'),
    ('0082f541-c969-4a98-89d2-ef2a77e3ed1a', 'PAID', '6395ad7b-8707-4534-baed-c56a63968feb'),
    ('0082f541-c969-4a98-89d2-ef2a77e3ed1a', 'SHIPPED', '6395ad7b-8707-4534-baed-c56a63968feb');


-- Cek hasilnya
SELECT * FROM order_history;


--------------------------------------------------------------------------------------


-- Table cart
CREATE TABLE cart (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL, 
    product_id SERIAL NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),  -- Minimal 1 item
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cart_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

ALTER TABLE cart ADD CONSTRAINT unique_cart_user_product UNIQUE (user_id, product_id);

-- Index untuk mempercepat query pencarian keranjang per user
CREATE INDEX idx_cart_user_id ON cart(user_id);
CREATE INDEX idx_cart_product_id ON cart(product_id);


CREATE OR REPLACE FUNCTION update_cart_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_cart_updated_at
BEFORE UPDATE ON cart
FOR EACH ROW
EXECUTE FUNCTION update_cart_updated_at();


-- Insert
INSERT INTO cart (user_id, product_id, quantity)
VALUES 
    ('a1b290a2-3534-4c16-8e55-9ee3d1dff775', 1, 2),  
    ('a1b290a2-3534-4c16-8e55-9ee3d1dff775', 2, 1),  
    ('649efad0-e309-4714-9a3b-598481b021af', 3, 3);

    
-- Cek isi cart
SELECT * FROM cart;


SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders' AND column_name = 'status';

ALTER TABLE order_history ALTER COLUMN status TYPE TEXT;


ALTER TABLE order_history DROP CONSTRAINT fk_order_history_user;
ALTER TABLE order_history ADD CONSTRAINT fk_order_history_user FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE order_history ALTER COLUMN changed_at SET DEFAULT CURRENT_TIMESTAMP;



SELECT p.id, p.name, p.description, p.price, p.stock, p.status, p.image_path, c.name AS category_name
FROM products p
JOIN categories c ON p.category_id = c.id
WHERE p.category_id = 2 AND p.status = TRUE;



SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_name = 'order_items' AND column_name = 'price';

