FROM golang:1.27.4-alpine3.24 AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/donation-service .

FROM gcr.io/distroless/static-debian13:nonroot

COPY --from=builder /out/donation-service /donation-service

EXPOSE 8082
ENTRYPOINT ["/donation-service"]
