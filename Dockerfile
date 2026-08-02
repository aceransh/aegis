FROM golang:1.27rc2-alpine3.24 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG APP_NAME
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/app ./cmd/${APP_NAME}

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /bin/app .

ENTRYPOINT [ "./app" ]