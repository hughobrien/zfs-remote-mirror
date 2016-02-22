#!/bin/sh

last_sent_file=~/.knox-last-sent
[ ! -f "$last_sent_file" ] && touch "$last_sent_file"

latest_remote="$(cat "$last_sent_file")"
[ -z $latest_remote ] && echo "remote state unknown. Set it in $last_sent_file"

latest_local="$(zfs list -H -d1 -t snapshot\
	| grep -e '-[0-9][0-9]T[0-9][0-9]:' \
	| cut -f1 \
	| sort \
	| tail -n 1)"

snapshot() {
	zfs snapshot -r "wd@$(date -u '+%FT%TZ')"
}

send_incremental_snapshot() {
	ssh knox-fifo < ~/.ssh/knox-geli-key &
	sleep 3
	zfs send -RevI "$latest_remote" "$latest_local" \
	| ssh knox-send
}

preview() {
	zfs diff "$latest_remote" "$latest_local" | less
}

backup() {
	send_incremental_snapshot && echo "$latest_remote" > "$last_sent_file"
}

case "$1" in
	backup) backup ;;
	preview) preview ;;
	snapshot) snapshot ;;
	snapback) snapshot; backup ;;
	*) echo "Commands are: snapshot, backup, preview, snapback"
esac
