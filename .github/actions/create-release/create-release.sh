#!/bin/sh

set -eu

if [ $# -lt 6 ] || [ $# -gt 7 ]; then
    echo "5 parameters required: OWNER_NAME REPOSITORY_NAME BASE_VERSION DRAFT TARGET"
    exit 1
fi

OWNER_NAME="$1"
REPOSITORY_NAME="$2"
BASE_VERSION="$3"
DRAFT="$4"
TARGET="$5"

new_patch=1
new_build=1

# shellcheck disable=SC2016
release_query='query($owner:String!,$repository:String!,$endCursor:String){repositoryOwner(login: $owner){repository(name:$repository){releases(first:100,after:$endCursor){pageInfo{endCursor}nodes{tagName}}}}}'

process_tag() {

    tag="$1"

    tag_base=$(echo "$tag" | cut -f 1-2 -d '.')
    tag_patch=$(echo "$tag" | cut -f 3 -d '.')

    case "$tag_patch" in

    *-*)
        if [ -n "$PULL_NUMBER" ]; then

            tag_pull_number=$(echo "$tag_patch" | cut -f 3 -d '-')

            if [ "$tag_pull_number" = "$PULL_NUMBER" ]; then

                tag_build=$(echo "$tag_patch" | cut -f 4 -d '-')

                if [ "$tag_build" -ge "$new_build" ]; then

                    new_build=$((tag_build + 1))

                fi
            fi
        fi
        ;;
    *)
        if [ "$tag_base" = "$BASE_VERSION" ] && [ "$tag_patch" -ge "$new_patch" ]; then

            new_patch=$((tag_patch + 1))

        fi
        ;;
    esac
}

process_all_releases() {

    end_cursor="null"

    while [ -n "$end_cursor" ]; do

        releases=$(curl --silent --location --request POST "$GITHUB_GRAPHQL_URL" \
            --header "Authorization: Bearer $GITHUB_TOKEN" \
            --header "Content-Type: application/json" \
            --data-raw "{\"query\": \"$release_query\", \"variables\": {\"owner\":\"$OWNER_NAME\", \"repository\":\"$REPOSITORY_NAME\",\"endCursor\":$end_cursor}}")

        tags=$(echo "$releases" | jq -r '.data.repositoryOwner.repository.releases.nodes[].tagName')

        for tag in $tags; do

            process_tag "$tag"

        done

        # end_cursor needs to include surrounding quotation marks
        end_cursor=$(echo "$releases" | jq '.data.repositoryOwner.repository.releases.pageInfo.endCursor // empty')

    done

}

create_release() {

    version=$1

    curl --silent -o /dev/null --location --request POST "$GITHUB_API_URL/repos/$OWNER_NAME/$REPOSITORY_NAME/releases" \
        --header "Authorization: Bearer $GITHUB_TOKEN" \
        --header "Content-Type: application/json" \
        --data-raw "{\"name\":\"Release $version\",\"tag_name\":\"$version\",\"draft\":$DRAFT,\"target_commitish\":\"$TARGET\",\"generate_release_notes\":true}"
}

process_all_releases

version="$BASE_VERSION.$new_patch"

create_release "$version"

echo "$version"
