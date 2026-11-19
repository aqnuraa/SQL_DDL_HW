
-- SQL DDL Aknur Zhagypar HW
-- Project: Online Bookstore Management System
-- Database: online_bookstore_db

-- 1. SCHEMA

CREATE SCHEMA IF NOT EXISTS online_bookstore;

SET search_path TO online_bookstore, public;


-- 2. CREATE TABLES
-- Parent tables must be created before child tables.
--
-- Otherwise PostgreSQL may return:
-- ERROR: relation does not exist
-- when a foreign key references a table not yet created.
--
-- Missing foreign keys allow orphan records, for example,
-- an order referring to a customer that does not exist.


-- 2.1 CUSTOMER

CREATE TABLE IF NOT EXISTS customer (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    gender VARCHAR(10) NOT NULL,
    CONSTRAINT chk_customer_gender
        CHECK (gender IN ('Female', 'Male', 'Other'))
);

-- UNIQUE prevents duplicate email addresses.
-- NOT NULL prevents missing essential customer information.
-- CHECK prevents invalid gender values.
-- Without these constraints, inconsistent customer records
-- could be stored.


-- 2.2 AUTHOR

CREATE TABLE IF NOT EXISTS author (
    author_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL
);


-- 2.3 BOOK

CREATE TABLE IF NOT EXISTS book (
    book_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    isbn VARCHAR(20) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    published_date DATE NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_book_published_date
        CHECK (published_date > DATE '2000-01-01'),

    CONSTRAINT chk_book_price
        CHECK (price >= 0),

    CONSTRAINT chk_book_stock
        CHECK (stock_quantity >= 0)
);

-- ISBN is unique to prevent duplicate book identifiers.
-- NUMERIC(10,2) stores monetary values accurately.
-- INTEGER is appropriate for stock quantities.
-- CHECK prevents invalid dates, negative prices and stock.
--
-- Wrong data types can cause:
-- * Lost decimal precision in monetary values.
-- * Invalid date comparisons.
-- * Overflow or incorrect calculations.
-- * Unnecessary storage consumption.


-- 2.4 CUSTOMER_ORDER

CREATE TABLE IF NOT EXISTS customer_order (
    order_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id),

    CONSTRAINT chk_order_date
        CHECK (order_date > DATE '2000-01-01'),

    CONSTRAINT chk_order_status
        CHECK (status IN ('Pending', 'Paid', 'Shipped', 'Cancelled'))
);


-- 2.5 BOOK_AUTHOR

CREATE TABLE IF NOT EXISTS book_author (
    book_id INTEGER NOT NULL,
    author_id INTEGER NOT NULL,

    CONSTRAINT pk_book_author
        PRIMARY KEY (book_id, author_id),

    CONSTRAINT fk_book_author_book
        FOREIGN KEY (book_id)
        REFERENCES book(book_id),

    CONSTRAINT fk_book_author_author
        FOREIGN KEY (author_id)
        REFERENCES author(author_id)
);


-- 2.6 ORDER_ITEM

CREATE TABLE IF NOT EXISTS order_item (
    order_item_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,

    CONSTRAINT fk_order_item_order
        FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id),

    CONSTRAINT fk_order_item_book
        FOREIGN KEY (book_id)
        REFERENCES book(book_id),

    CONSTRAINT uq_order_item
        UNIQUE (order_id, book_id),

    CONSTRAINT chk_order_item_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_order_item_price
        CHECK (unit_price >= 0)
);


-- 2.7 PAYMENT

CREATE TABLE IF NOT EXISTS payment (
    payment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INTEGER NOT NULL,
    payment_reference VARCHAR(50) NOT NULL UNIQUE,
    payment_date DATE NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,

    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id),

    CONSTRAINT chk_payment_date
        CHECK (payment_date > DATE '2000-01-01'),

    CONSTRAINT chk_payment_amount
        CHECK (amount >= 0),

    CONSTRAINT chk_payment_method
        CHECK (payment_method IN ('Card', 'Cash', 'Bank Transfer'))
);


-- 3. ADD RECORD_TS TO EVERY TABLE

ALTER TABLE customer
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE author
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE book
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE book_author
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE customer_order
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE order_item
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE payment
    ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

-- DEFAULT fills record_ts automatically.
-- NOT NULL prevents records without a timestamp.
-- Existing rows receive the current date when the column is added.


-- 4. CREATE INDEXES

CREATE INDEX IF NOT EXISTS idx_order_customer
    ON customer_order(customer_id);

CREATE INDEX IF NOT EXISTS idx_order_item_book
    ON order_item(book_id);

CREATE INDEX IF NOT EXISTS idx_payment_order
    ON payment(order_id);

CREATE INDEX IF NOT EXISTS idx_book_author_author
    ON book_author(author_id);


-- ============================================================
-- 5. INSERT SAMPLE DATA
-- All relationships are established using SELECT statements.
-- WHERE NOT EXISTS and unique constraints prevent duplicates.
-- ============================================================


-- 5.1 CUSTOMERS

INSERT INTO customer (first_name, last_name, email, phone, gender)
SELECT v.first_name, v.last_name, v.email, v.phone, v.gender
FROM (
    VALUES
        ('Anna', 'Smith', 'anna@example.com', '+77010000001', 'Female'),
        ('John', 'Brown', 'john@example.com', '+77010000002', 'Male'),
        ('Maria', 'Wilson', 'maria@example.com', '+77010000003', 'Female')
) AS v(first_name, last_name, email, phone, gender)
WHERE NOT EXISTS (
    SELECT 1 FROM customer c
    WHERE c.email = v.email
);


-- 5.2 AUTHORS

INSERT INTO author (first_name, last_name)
SELECT v.first_name, v.last_name
FROM (
    VALUES
        ('George', 'Orwell'),
        ('J.K.', 'Rowling'),
        ('Paulo', 'Coelho')
) AS v(first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1 FROM author a
    WHERE LOWER(a.first_name) = LOWER(v.first_name)
      AND LOWER(a.last_name) = LOWER(v.last_name)
);


-- 5.3 BOOKS

INSERT INTO book (
    isbn, title, published_date, price, stock_quantity
)
SELECT
    v.isbn, v.title, v.published_date, v.price, v.stock_quantity
FROM (
    VALUES
        ('9780451524935', '1984', DATE '2000-06-08', 15.99::numeric, 20),
        ('9780747532743', 'Harry Potter', DATE '2001-07-08', 22.50::numeric, 15),
        ('9780061122415', 'The Alchemist', DATE '2002-05-01', 18.00::numeric, 12),
        ('9780141036144', 'Animal Farm', DATE '2003-03-10', 12.99::numeric, 10)
) AS v(isbn, title, published_date, price, stock_quantity)
WHERE NOT EXISTS (
    SELECT 1 FROM book b WHERE b.isbn = v.isbn
);


-- 5.4 BOOK_AUTHOR RELATIONSHIPS

INSERT INTO book_author (book_id, author_id)
SELECT b.book_id, a.author_id
FROM (
    VALUES
        ('9780451524935', 'George', 'Orwell'),
        ('9780141036144', 'George', 'Orwell'),
        ('9780747532743', 'J.K.', 'Rowling'),
        ('9780061122415', 'Paulo', 'Coelho')
) AS v(isbn, first_name, last_name)
JOIN book b ON b.isbn = v.isbn
JOIN author a
    ON LOWER(a.first_name) = LOWER(v.first_name)
   AND LOWER(a.last_name) = LOWER(v.last_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM book_author ba
    WHERE ba.book_id = b.book_id
      AND ba.author_id = a.author_id
);


-- 5.5 CUSTOMER ORDERS

INSERT INTO customer_order (
    order_number, customer_id, order_date, status
)
SELECT
    v.order_number, c.customer_id, v.order_date, v.status
FROM (
    VALUES
        ('ORD-1001', 'anna@example.com', DATE '2024-01-15', 'Paid'),
        ('ORD-1002', 'john@example.com', DATE '2024-02-10', 'Shipped'),
        ('ORD-1003', 'maria@example.com', DATE '2024-03-05', 'Pending')
) AS v(order_number, email, order_date, status)
JOIN customer c ON c.email = v.email
WHERE NOT EXISTS (
    SELECT 1
    FROM customer_order o
    WHERE o.order_number = v.order_number
);


-- 5.6 ORDER ITEMS

INSERT INTO order_item (order_id, book_id, quantity, unit_price)
SELECT o.order_id, b.book_id, v.quantity, b.price
FROM (
    VALUES
        ('ORD-1001', '9780451524935', 2),
        ('ORD-1001', '9780141036144', 1),
        ('ORD-1002', '9780747532743', 1),
        ('ORD-1002', '9780061122415', 2),
        ('ORD-1003', '9780061122415', 1),
        ('ORD-1003', '9780451524935', 1)
) AS v(order_number, isbn, quantity)
JOIN customer_order o ON o.order_number = v.order_number
JOIN book b ON b.isbn = v.isbn
WHERE NOT EXISTS (
    SELECT 1
    FROM order_item oi
    WHERE oi.order_id = o.order_id
      AND oi.book_id = b.book_id
);


-- 5.7 PAYMENTS

INSERT INTO payment (
    order_id, payment_reference, payment_date,
    amount, payment_method
)
SELECT
    o.order_id,
    v.payment_reference,
    v.payment_date,
    v.amount,
    v.payment_method
FROM (
    VALUES
        ('ORD-1001', 'PAY-1001', DATE '2024-01-15', 44.97::numeric, 'Card'),
        ('ORD-1002', 'PAY-1002', DATE '2024-02-10', 58.50::numeric, 'Cash'),
        ('ORD-1003', 'PAY-1003', DATE '2024-03-05', 33.99::numeric, 'Bank Transfer')
) AS v(order_number, payment_reference, payment_date, amount, payment_method)
JOIN customer_order o ON o.order_number = v.order_number
WHERE NOT EXISTS (
    SELECT 1
    FROM payment p
    WHERE p.payment_reference = v.payment_reference
);


-- 6. VERIFY RECORD_TS

SELECT 'customer' AS table_name, COUNT(*) AS total_rows,
       COUNT(record_ts) AS rows_with_record_ts
FROM customer
UNION ALL
SELECT 'author', COUNT(*), COUNT(record_ts) FROM author
UNION ALL
SELECT 'book', COUNT(*), COUNT(record_ts) FROM book
UNION ALL
SELECT 'book_author', COUNT(*), COUNT(record_ts) FROM book_author
UNION ALL
SELECT 'customer_order', COUNT(*), COUNT(record_ts) FROM customer_order
UNION ALL
SELECT 'order_item', COUNT(*), COUNT(record_ts) FROM order_item
UNION ALL
SELECT 'payment', COUNT(*), COUNT(record_ts) FROM payment;


-- 7. FINAL DATA VERIFICATION

SELECT * FROM customer ORDER BY customer_id;
SELECT * FROM author ORDER BY author_id;
SELECT * FROM book ORDER BY book_id;

SELECT
    b.title,
    a.first_name,
    a.last_name
FROM book_author ba
JOIN book b USING (book_id)
JOIN author a USING (author_id)
ORDER BY b.title;

SELECT
    o.order_number,
    c.first_name,
    c.last_name,
    o.order_date,
    o.status
FROM customer_order o
JOIN customer c USING (customer_id)
ORDER BY o.order_number;

SELECT
    o.order_number,
    b.title,
    oi.quantity,
    oi.unit_price
FROM order_item oi
JOIN customer_order o USING (order_id)
JOIN book b USING (book_id)
ORDER BY o.order_number, b.title;

SELECT
    o.order_number,
    p.payment_reference,
    p.payment_date,
    p.amount,
    p.payment_method
FROM payment p
JOIN customer_order o USING (order_id)
ORDER BY o.order_number;


-- DESIGN NOTES
--
-- 1. NORMALIZATION:
--    The model separates customers, authors, books, orders,
--    order items and payments. The many-to-many book-author
--    relationship is resolved through book_author.
--
-- 2. DATA TYPES:
--    VARCHAR is used for variable-length text, DATE for dates,
--    NUMERIC for monetary amounts, INTEGER for quantities and IDs.
--    Incorrect types can cause precision loss, invalid values,
--    overflow and unnecessary storage consumption.
--
-- 3. CONSTRAINTS:
--    CHECK prevents invalid dates, negative amounts and invalid
--    gender, status and payment method values.
--    UNIQUE prevents duplicate emails, ISBNs, order numbers
--    and payment references.
--    NOT NULL prevents missing required information.
--    Without these constraints, invalid or duplicate data
--    could enter the database.
--
-- 4. FOREIGN KEYS:
--    Foreign keys prevent references to nonexistent customers,
--    books, authors and orders. Without them, orphan records
--    and inconsistent relationships could occur.
--
-- 5. DDL ORDER:
--    Parent tables are created before child tables.
--    Incorrect ordering can cause foreign-key creation errors
--    because the referenced relation does not yet exist.
--
-- 6. DATA CONSISTENCY:
--    INSERT INTO SELECT retrieves IDs from existing records.
--    WHERE NOT EXISTS and UNIQUE constraints prevent duplicates.
--    Foreign keys preserve relationships between records.
--
-- 7. RECORD_TS:
--    Every table has a NOT NULL record_ts column with a
--    CURRENT_DATE default. Existing rows receive a date
--    when the column is added.
--
-- 8. RERUNNING:
--    IF NOT EXISTS, unique constraints and WHERE NOT EXISTS
--    make the creation and sample data sections reusable.
