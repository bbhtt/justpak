_get_manifest app_id:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f "{{app_id}}.json" ]; then
        echo "{{app_id}}.json"
    elif [ -f "{{app_id}}.yaml" ]; then
        echo "{{app_id}}.yaml"
    elif [ -f "{{app_id}}.yml" ]; then
        echo "{{app_id}}.yml"
    else
        echo "Error: No manifest file found for {{app_id}}" >&2
        exit 1
    fi

_get_build_subject:
    #!/usr/bin/env bash
    set -euo pipefail
    commit_msg=$(git log -1 --pretty=%s)
    commit_hash=$(git rev-parse --short=12 HEAD)
    echo "$commit_msg ($commit_hash)"

checkout repo ref:
    #!/usr/bin/env bash
    set -euo pipefail
    git clone --depth 1 --recurse-submodules --shallow-submodules -b {{ref}} {{repo}} .

prepare-env:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak remote-add --user --if-not-exists flathub-beta https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo
    flatpak install --install-or-update --user flathub org.flatpak.Builder --noninteractive

validate-manifest app_id:
    #!/usr/bin/env bash
    set -euo pipefail
    manifest=$(just _get_manifest {{app_id}})
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "$manifest"

build app_id branch="stable":
    #!/usr/bin/env bash
    set -euo pipefail
    
    manifest=$(just _get_manifest {{app_id}})
    subject=$(just _get_subject)
    
    # Setup dependencies arguments
    deps_args="--install-deps-from=flathub"
    if [ "{{branch}}" = "beta" ] || [ "{{branch}}" = "test" ]; then
        deps_args="$deps_args --install-deps-from=flathub-beta"
    fi

    dbus-run-session flatpak run org.flatpak.Builder -v \
        --force-clean --sandbox --delete-build-dirs \
        --user $deps_args \
        --mirror-screenshots-url=https://dl.flathub.org/media \
        --repo repo \
        --extra-sources=./downloads \
        --default-branch "{{branch}}" \
        --subject "${subject}" \
        builddir "$manifest"

commit-screenshots:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p builddir/files/share/app-info/media
    ostree commit --repo=repo --canonical-permissions --branch=screenshots/{{arch()}} builddir/files/share/app-info/media

validate-build:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder --exceptions repo repo

generate-deltas:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak build-update-repo --generate-static-deltas --static-delta-ignore-ref=*.Debug --static-delta-ignore-ref=*.Sources repo

upload url:
    #!/usr/bin/env bash
    set -euo pipefail
    flatpak run --command=flat-manager-client org.flatpak.Builder push "{{url}}" repo
