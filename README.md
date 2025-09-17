# Go Simple Bank

A simple banking API built with **Golang**, following clean architecture and best practices.  
The project is inspired by the TechSchool course and includes **database migrations, REST APIs, unit tests, authentication, and mocking**.

---

## Features

- User management (create accounts, authentication, password hashing)
- Bank accounts and balance tracking
- Secure transactions (transfer money between accounts)
- JWT authentication & middleware
- Database migrations with `golang-migrate`
- Unit tests with `gomock` & `testify`
- Clean architecture: separation of API, DB, and utilities

---

## Tech Stack

- **Backend**: Golang (Gin, sqlc, gomock, testify)
- **Database**: PostgreSQL
- **Migration**: golang-migrate
- **Auth**: JWT, bcrypt
- **Containerization**: Docker, Docker Compose

---

## Getting Started

### 1. Clone repo
```bash
git clone https://github.com/yourusername/go-simple-bank.git
cd go-simple-bank

## Run Postgres with Docker
```bash
make postgres
```

## Run migrations

```bash
make migrateup
```

## Start the server

```bash
make server
```
Server will start at: http://localhost:8080

## Testing

Run unit tests:
```bash
make test
```

## Project Structure
```bash
.
├── api/          # Gin HTTP handlers
├── db/           # SQLC generated queries & migrations
├── util/         # Utility functions (config, password, tokens)
├── main.go       # Entry point
└── Makefile      # Helpful commands
```

## Useful Commands
```bash
make postgres     # Start PostgreSQL with Docker
make createdb     # Create DB
make dropdb       # Drop DB
make migrateup    # Apply migrations
make migratedown  # Rollback migrations
make server       # Run API server
make test         # Run unit tests
```