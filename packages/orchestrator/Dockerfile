FROM golang:1.24 AS builder

# A simpler approach - use a temporary directory structure to build
WORKDIR /app

# Setup shared module first
WORKDIR /app/shared
COPY .shared/go.mod .shared/go.sum ./
COPY .shared/pkg ./pkg

# Add AWS dependencies
RUN go get github.com/aws/aws-sdk-go-v2@latest
RUN go get github.com/aws/aws-sdk-go-v2/config@latest
RUN go get github.com/aws/aws-sdk-go-v2/service/s3@latest
RUN go get github.com/cenkalti/backoff/v4@latest
RUN go mod tidy

# Setup orchestrator module next
WORKDIR /app/orchestrator
COPY go.mod go.sum ./

# Now create the go.work file at root level
WORKDIR /app
RUN echo 'go 1.23.0\n\nuse (\n\t./shared\n\t./orchestrator\n)' > go.work
RUN go work sync

# Return to orchestrator module to finish the build
WORKDIR /app/orchestrator
COPY main.go Makefile ./
COPY internal/ ./internal/

# Download dependencies before building
RUN go mod download
RUN go mod tidy

ARG COMMIT_SHA
# Build directly instead of using make to avoid issues
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o bin/orchestrator -ldflags "-X=main.commitSHA=${COMMIT_SHA}" .

FROM scratch

COPY --from=builder /app/orchestrator/bin/orchestrator .
