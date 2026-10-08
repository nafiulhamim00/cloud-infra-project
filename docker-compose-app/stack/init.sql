CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO messages (content) VALUES
    ('Welcome to the DAT515 stack!'),
    ('This data is persisted in MySQL'),
    ('Redis is handling the page-view counter');
