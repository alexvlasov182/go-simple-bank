# Stage 1: build
FROM golang:1.23.3-alpine AS builder
WORKDIR /app


RUN apk add --no-cache git ca-certificates


COPY go.mod go.sum ./
RUN go mod download


COPY . .
RUN go build -o main main.go

# Stage 2: minimal runtime image
FROM alpine:3.18
WORKDIR /app


COPY --from=builder /app/main .
COPY app.env .

EXPOSE 8080
CMD ["./main"]
