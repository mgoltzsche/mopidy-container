##@ Interactive Testing

.PHONY: run-mopidy
run-mopidy: SKAFFOLD_OPTS=-t dev
run-mopidy: image ## Run mopidy container simply using docker.
	mkdir -p data
	docker run --rm --network=host -u `id -u`:`id -g` \
		-e MOPIDY_NO_CHMOD=true \
		-v "`pwd`/data:/var/lib/mopidy" \
		-v /run:/host/run \
		-e PULSE_SERVER=unix:/host/run/user/`id -u`/pulse/native \
		--mount "type=bind,src=$$HOME/.config/pulse,dst=/var/lib/mopidy/.config/pulse" \
                -e HOME=/var/lib/mopidy \
		-e MOPIDY_BEETS_ENABLED=true \
		ghcr.io/mgoltzsche/mopidy:dev

.PHONY: clean-data
clean-data: ## Delete temporary mopidy data.
	docker run --rm -v "`pwd`:/src" -w /src alpine:3.18 rm -rf data

