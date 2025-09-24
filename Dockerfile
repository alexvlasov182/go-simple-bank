# Stage 1: build
FROM golang:1.23.3-alpine AS builder
WORKDIR /app

# Install curl, git, ca-certificates and tar
RUN apk add --no-cache git ca-certificates curl tar

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o main main.go

# Download migrate directly in /app
RUN curl -L https://github.com/golang-migrate/migrate/releases/download/v4.19.0/migrate.linux-amd64.tar.gz \
    | tar xvz -C /app

# Stage 2: minimal runtime image
FROM alpine:3.18
WORKDIR /app

# Installing bash and nc (for wait-for-it.sh)
RUN apk add --no-cache bash netcat-openbsd

COPY --from=builder /app/main .
COPY --from=builder /app/migrate ./migrate
COPY start.sh .
COPY wait-for-it.sh .
COPY app.env .
COPY db/migration ./migration

RUN chmod +x ./start.sh ./wait-for-it.sh ./migrate

EXPOSE 8080
ENTRYPOINT ["/app/start.sh"]
CMD ["./main"]
