# Offline Home dev tasks. Run from the repo root.
FLUTTER ?= flutter
DART    ?= dart
PYTHON  ?= python3
APP     := app
SIMS    ?= wiz
IOS_DEVICE ?= ios
APK     := $(APP)/build/app/outputs/flutter-apk/app-release.apk

.PHONY: help deps fmt fmt-check analyze codegen codegen-check flutter-test sim-test test sim run-android run-ios apk install-apk ios-device doctor clean

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

deps: ## fetch Flutter + Python dev deps
	cd $(APP) && $(FLUTTER) pub get
	$(PYTHON) -m pip install -q -r sim/requirements-dev.txt

fmt: ## format Dart code
	cd $(APP) && $(DART) format .

fmt-check: ## fail if Dart code is not formatted (CI)
	cd $(APP) && $(DART) format --output=none --set-exit-if-changed .

analyze: ## static analysis
	cd $(APP) && $(FLUTTER) analyze --fatal-infos

codegen: ## run build_runner (freezed, json_serializable, drift)
	cd $(APP) && $(DART) run build_runner build --delete-conflicting-outputs

codegen-check: codegen ## fail if committed generated code is stale (CI)
	cd $(APP) && $(DART) format lib test >/dev/null
	@out=$$(git status --porcelain -- $(APP)/lib $(APP)/test); if [ -n "$$out" ]; then echo "Generated code is stale or uncommitted:"; echo "$$out"; git diff --stat -- $(APP); exit 1; fi

flutter-test: ## Flutter unit + widget tests
	cd $(APP) && OH_PYTHON=$$(command -v $(PYTHON)) $(FLUTTER) test

sim-test: ## simulator self-tests
	$(PYTHON) -m pytest -q sim

test: analyze flutter-test sim-test ## analyze + flutter test + pytest

sim: ## start simulators on localhost (SIMS=wiz,tuya33:key=...)
	$(PYTHON) sim/run.py --devices $(SIMS) --no-stdin-watch

run-android: ## run on a connected Android phone
	cd $(APP) && $(FLUTTER) run -d android

run-ios: ## run on a connected iPhone (free Apple ID signing expires after 7 days)
	cd $(APP) && $(FLUTTER) run -d ios

apk: ## release APK for your own phone (signed with the debug key: fine for sideloading)
	cd $(APP) && $(FLUTTER) build apk --release
	@echo "APK: $(APK)  (copy to the phone, or: make install-apk)"

install-apk: apk ## build + install the release APK on the USB-connected Android phone
	adb install -r $(APK)

ios-device: ## release build on the USB-connected iPhone (free Apple ID: re-run every 7 days)
	cd $(APP) && $(FLUTTER) run --release -d $(IOS_DEVICE)

doctor: ## check the local Flutter / Android / Xcode setup
	$(FLUTTER) doctor -v

clean: ## remove build outputs
	cd $(APP) && $(FLUTTER) clean
