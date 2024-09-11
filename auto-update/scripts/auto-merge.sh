DONT_PUBLISH="${DONT_PUBLISH:=0}"

git checkout ${BRANCH_UPDATE}
EXTRA_INFO="$(git log --abbrev-commit --oneline --pretty=format:%s -1 | sed 's,.*\(app version.*\),\1,')"
git checkout ${TARGET_BRANCH}
git pull

glab mr merge ${BRANCH_UPDATE} --remove-source-branch --auto-merge --rebase --message "[MERGE-UPDATE] $BRANCH_UPDATE - $EXTRA_INFO"
RESULT=$(echo $?)
if [ "$(( $RESULT + $DONT_PUBLISH ))" -eq 0 ]; then
  curl -X POST -H 'Content-type: application/json' --data "{'text':'[MERGE-UPDATE] $BRANCH_UPDATE - $EXTRA_INFO ($CLUSTER_NAME)($ENV)'}" "${SLACK_HOOK_URL}" 
fi

exit "${RESULT}"