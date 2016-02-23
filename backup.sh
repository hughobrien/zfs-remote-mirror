#!/bin/sh
# Hugh O'Brien 2016 - obrien.hugh@gmail.com

# pipe-viewer isn't technically needed, but it is nice for progress info
[ -z $(which pv) ] && echo "pv not found" && exit

last_sent_file=~/.knox-last-sent
[ ! -f "$last_sent_file" ] && touch "$last_sent_file"

latest_remote="$(cat "$last_sent_file")"
[ -z "$latest_remote" ] && echo "remote state unknown. Set it in "$last_sent_file""

# This is split out as we need to recalculate it if we make a new snapshot
update_latest_local() {
	latest_local="$(zfs list -H -d1 -t snapshot \
		| grep -e '-[0-9][0-9]T[0-9][0-9]:' \
		| cut -f1 \
		| sort \
		| tail -n 1)"
}
update_latest_local

# pv will only take integer size arguments, so convert them here
calculate_size() {
	size=$(zfs send -RevnI "$latest_remote" "$latest_local"  2>&1 \
		| tail -n 1 \
		| sed -E 's/.* ([0-9]*)/\1/')

	unit=$(echo "$size" | sed -E 's/.*([A-Z,a-z])/\1/')
	unitless_size=$(echo "$size" | tr -d "$unit")

	case "$unit" in
		(K) exponent=10 ;;
		(M) exponent=20 ;;
		(G) exponent=30 ;;
		(T) exponent=40 ;;
	esac

	integer_size=$(echo "$unitless_size * 2^$exponent" | bc)
	truncated_integer_size=$(echo "$integer_size" \
		| sed -E 's/([0-9].*)\..*/\1/')

	# last test to make sure the data is good, else pv will fail
	case "$truncated_integer_size" in
		''|*[!0-9]*) truncated_integer_size=0 ;;
	esac

}

print_size() {
	calculate_size
	echo "Estimated Size: $size"
}

snapshot() {
	zfs snapshot -r "wd@$(date -u '+%FT%TZ')"
	update_latest_local
}

send_incremental_snapshot() {
	calculate_size
	ssh -q knox-fifo < ~/.ssh/knox-geli-key &
	sleep 3
	zfs send -ReI "$latest_remote" "$latest_local" \
	| pv --size "$truncated_integer_size" \
	| ssh -q knox-send
}

preview() {
	zfs diff "$latest_remote" "$latest_local" | less
}

backup() {
	send_incremental_snapshot && echo "$latest_local" > "$last_sent_file"
}

case "$1" in
	backup)	print_size; backup ;;
	preview)	preview ;;
	snapshot)	snapshot; print_size ;;
	snapback)	snapshot; print_size; backup ;;
	*)	echo "Latest Local:   "$latest_local""
		echo "Latest Remote:  "$latest_remote""
		print_size; echo
		echo "Commands are: snapshot, preview, backup, snapback"
esac
