podman machine start

Set-Alias -Name docker -Value podman

$IFXMETRICS_BUILD_VER = "2.1.0-$(Get-Date -Format 'yyyyMMdd')-$(git rev-parse --short HEAD)"

docker pull x1unix/go-mingw:1.20

# Compile x64 Windows DLL
docker run --rm -it -v ${PWD}/extension/IFXMetrics:/go/work -w /go/work -e GOARCH=amd64 -e CGO_ENABLED=1 x1unix/go-mingw:1.20  go build -o ./dist/ifxmetrics_x64.dll -buildmode=c-shared -ldflags "-w -s -X main.EXTENSION_VERSION=$IFXMETRICS_BUILD_VER" ./cmd

Move-Item -Path ./extension/IFXMetrics/dist/ifxmetrics_x64.dll -Destination ./ifxmetrics_x64.dll -Force

# Compile x86 Windows DLL
docker run --rm -it -v ${PWD}/extension/IFXMetrics:/go/work -w /go/work -e GOARCH=386 -e CGO_ENABLED=1 x1unix/go-mingw:1.20 go build -o ./dist/ifxmetrics.dll -buildmode=c-shared -ldflags "-w -s -X main.EXTENSION_VERSION=$IFXMETRICS_BUILD_VER" ./cmd

Move-Item -Path ./extension/IFXMetrics/dist/ifxmetrics.dll -Destination ./ifxmetrics.dll -Force

# Compile x64 Windows EXE
docker run --rm -it -v ${PWD}/extension/IFXMetrics:/go/work -w /go/work -e GOARCH=amd64 -e CGO_ENABLED=1 x1unix/go-mingw:1.20 go build -o ./dist/ifxmetrics_x64.exe -ldflags "-w -s -X main.EXTENSION_VERSION=$IFXMETRICS_BUILD_VER" ./cmd

Move-Item -Path ./extension/IFXMetrics/dist/ifxmetrics_x64.exe -Destination ./ifxmetrics_x64.exe -Force

docker build -t indifox926/build-a3go:linux-so -f ./build/Dockerfile.build .

# Compile x64 Linux .so
docker run --rm -it -v ${PWD}/extension/IFXMetrics:/app -e GOOS=linux -e GOARCH=amd64 -e CGO_ENABLED=1 indifox926/build-a3go:linux-so go build -o ./dist/ifxmetrics_x64.so -linkshared -ldflags "-w -s -X main.EXTENSION_VERSION=${IFXMETRICS_BUILD_VER}" ./cmd

Move-Item -Path ./extension/IFXMetrics/dist/ifxmetrics_x64.so -Destination ./ifxmetrics_x64.so -Force

# Compile x86 Linux .so
docker run --rm -it -v ${PWD}/extension/IFXMetrics:/app -e GOOS=linux -e GOARCH=386 -e CGO_ENABLED=1 indifox926/build-a3go:linux-so go build -o ./dist/ifxmetrics.so -linkshared -ldflags "-w -s -X main.EXTENSION_VERSION=${IFXMETRICS_BUILD_VER}" ./cmd

Move-Item -Path ./extension/IFXMetrics/dist/ifxmetrics.so -Destination ./ifxmetrics.so -Force

hemtt release