APP_NAME=senda
ENTRY=./cmd/senda

build:
	./scripts/build.sh

run:
	go run $(ENTRY)

clean:
	rm -rf dist bin

test:
	go test ./...
