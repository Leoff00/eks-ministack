FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /hello-eks .

FROM alpine:3.21
COPY --from=build /hello-eks /hello-eks
USER 10001:10001
EXPOSE 5001
ENTRYPOINT ["/hello-eks"]
