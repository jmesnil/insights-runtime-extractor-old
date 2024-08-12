.DEFAULT_GOAL = push

build:
	go build -o http-server http-server.go

build-fips:
	GOEXPERIMENT=strictfipsruntime go build  -tags strictfipsruntime -o http-server http-server.go

push:
	./deploy.sh
