THISDIR = $(shell pwd)

XRAY_VERSION := 26.3.27
XRAY_URL := https://github.com/XTLS/Xray-core/archive/refs/tags/v$(XRAY_VERSION).tar.gz

export GO111MODULE=on
export GOPROXY=https://goproxy.io,direct

all: download_test extract_test build_xray

download_test:
	( if [ ! -f $(THISDIR)/xray-core-$(XRAY_VERSION).tar.gz ]; then \
		wget -t5 --timeout=60 --no-check-certificate -O xray-core-$(XRAY_VERSION).tar.gz $(XRAY_URL); \
	fi )

extract_test:
	( if [ ! -d $(THISDIR)/src ]; then \
		tar xzf xray-core-$(XRAY_VERSION).tar.gz && \
		mv Xray-core-$(XRAY_VERSION) $(THISDIR)/src ; \
	fi )

build_xray:
	( mkdir -p $(THISDIR)/bin ; \
	cd $(THISDIR)/src ; \
	CGO_ENABLED=0 GOOS=linux GOARCH=mipsle GOMIPS=softfloat \
	go build -trimpath -ldflags "-s -w" -o $(THISDIR)/bin/xray ./main ; \
	)

clean:
	rm -rf $(THISDIR)/src
	rm -rf $(THISDIR)/bin

romfs:
	$(ROMFSINST) -p +x $(THISDIR)/bin/xray /usr/bin/xray
