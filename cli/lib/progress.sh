# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - running long operations with live progress.
#
# Long-running commands are started in the background while the foreground
# keeps sampling progress, redrawing the user interface and watching for a
# cancellation request.  Progress is measured from the kernel's own I/O
# counters for the target device (/sys/class/block/<dev>/stat), i.e. from the
# bytes that really reached the drive.  That makes it independent of the tool
# doing the writing (dd, cp, mkfs, wimlib, a FUSE file system ...) and keeps
# the bar honest while the page cache is being flushed.
#
#   job_spin CMD...                  no measurable progress (spinner)
#   job_track_write TOTAL CMD...     progress = bytes written to the target
#   job_track_read TOTAL CMD...      progress = bytes read from the target
#   job_track_stdin TOTAL IN OUT CMD CMD reads IN on stdin and writes OUT; progress = offset
#
# CMD may be an external command or a shell function (it then runs in a
# subshell).  Each helper returns the command's exit status, or 130 when the
# operation was cancelled.  Output of CMD goes to the log.
#
# A front end hooks in by setting JOB_UI_HOOK (called on every tick to redraw)
# and JOB_KEY_HOOK (called with the tick length; it must wait at most that
# long for input and may set RC_CANCELLED=1).

[[ -n ${_RC_PROGRESS_LOADED:-} ]] && return 0
_RC_PROGRESS_LOADED=1

JOB_PHASE=''		# title of the current phase (already localized)
JOB_NOTE=''		# detail line, e.g. the file being copied
JOB_PCT=-1		# per-mille (0..1000) of the current operation, -1 = unknown
JOB_DONE=0		# bytes processed by the current operation
JOB_TOTAL=0		# bytes expected for the current operation (0 = unknown)
JOB_RATE=0		# bytes per second, smoothed
JOB_ETA=-1		# seconds left for the current operation, -1 = unknown
JOB_OVERALL=-1		# per-mille of the whole job, -1 = unknown
JOB_STARTED_S=0		# start of the whole job (epoch seconds)
JOB_STEP_BASE=0		# per-mille of the whole job where the current step starts
JOB_STEP_SPAN=0		# per-mille of the whole job the current step is worth
JOB_STAT_DEV=''		# kernel name of the device whose counters are sampled
JOB_UI_HOOK=''		# function redrawing the progress display
JOB_KEY_HOOK=''		# function polling for user input: KEY_HOOK <seconds>
JOB_TICK='0.2'		# seconds between two samples
JOB_NOTE_FILE=''	# file through which background work publishes JOB_NOTE
JOB_LAST_PID=''		# pid of the most recent background command

# job_reset   forget the state of a previous job.
job_reset() {
	JOB_PHASE=''
	JOB_NOTE=''
	JOB_PCT=-1
	JOB_DONE=0
	JOB_TOTAL=0
	JOB_RATE=0
	JOB_ETA=-1
	JOB_OVERALL=-1
	JOB_STEP_BASE=0
	JOB_STEP_SPAN=0
	now_s
	JOB_STARTED_S=$REPLY
	if [[ -z $JOB_NOTE_FILE || ! -e $JOB_NOTE_FILE ]]; then
		if core_mktemp_file note; then
			JOB_NOTE_FILE=$REPLY
		else
			JOB_NOTE_FILE=''
		fi
	fi
	[[ -n $JOB_NOTE_FILE ]] && : >"$JOB_NOTE_FILE"
	return 0
}

# job_phase TITLE   announce a new phase (TITLE is already localized).
job_phase() {
	JOB_PHASE=$1
	JOB_NOTE=''
	JOB_PCT=-1
	JOB_DONE=0
	JOB_TOTAL=0
	JOB_RATE=0
	JOB_ETA=-1
	[[ -n $JOB_NOTE_FILE ]] && : >"$JOB_NOTE_FILE" 2>/dev/null
	log "== $1"
	job_refresh
}

# job_step BASE SPAN   position the current step within the whole job
# (both in per-mille); the overall figure then follows the step's progress.
job_step() {
	JOB_STEP_BASE=$1
	JOB_STEP_SPAN=$2
	JOB_OVERALL=$1
}

# job_note TEXT   publish a detail line.  Safe to call from background
# subshells: the text travels through a file that the foreground polls.
job_note() {
	JOB_NOTE=$1
	if [[ -n $JOB_NOTE_FILE ]]; then
		printf '%s\n' "$1" >"$JOB_NOTE_FILE" 2>/dev/null
	fi
	return 0
}

# job_refresh   redraw now (used between steps).
job_refresh() {
	if [[ -n $JOB_UI_HOOK ]]; then
		"$JOB_UI_HOOK"
	fi
	return 0
}

# job_cancelled   true once cancellation was requested.
job_cancelled() { ((RC_CANCELLED)); }

# job_poll   let the front end process pending input without waiting.
job_poll() {
	if [[ -n $JOB_KEY_HOOK ]]; then
		"$JOB_KEY_HOOK" 0
	fi
	return 0
}

# --- sampling ---------------------------------------------------------------

# _job_sample MODE [PID]   -> REPLY (bytes), or fails when unavailable
_job_sample() {
	local mode=$1 pid=${2:-} line
	local -a f
	case $mode in
		write | read)
			[[ -n $JOB_STAT_DEV && -r /sys/class/block/$JOB_STAT_DEV/stat ]] || return 1
			read -r -a f <"/sys/class/block/$JOB_STAT_DEV/stat" || return 1
			# Fields: 0 reads completed, 2 sectors read, 4 writes completed,
			# 6 sectors written.  The unit is always 512 bytes.
			if [[ $mode == write ]]; then
				REPLY=$((${f[6]:-0} * 512))
			else
				REPLY=$((${f[2]:-0} * 512))
			fi
			;;
		stdin)
			[[ -n $pid && -r /proc/$pid/fdinfo/0 ]] || return 1
			while read -r line; do
				if [[ $line == pos:* ]]; then
					REPLY=${line#pos:}
					REPLY=${REPLY//[!0-9]/}
					[[ -n $REPLY ]] || return 1
					return 0
				fi
			done <"/proc/$pid/fdinfo/0"
			return 1
			;;
		*) return 1 ;;
	esac
}

# _job_wait PID MODE TOTAL   foreground loop: sample, redraw, watch for cancel.
_job_wait() {
	local pid=$1 mode=$2 total=$3
	local base=0 have_base=0 cur=0 rc=0 cancelled=0
	local now t0 dt i n
	local -a win_t=() win_b=()

	JOB_TOTAL=$total
	JOB_DONE=0
	JOB_RATE=0
	JOB_ETA=-1
	if [[ $mode == none || $total -le 0 ]]; then JOB_PCT=-1; else JOB_PCT=0; fi

	if [[ $mode == stdin ]]; then
		# A stream position is absolute: it starts at zero by definition.
		base=0
		have_base=1
	elif [[ $mode != none ]] && _job_sample "$mode" "$pid"; then
		base=$REPLY
		have_base=1
	fi
	now_ms
	t0=$REPLY

	while kill -0 "$pid" 2>/dev/null; do
		if ((RC_CANCELLED)); then
			cancelled=1
			log "cancelling pid $pid"
			core_kill_tree "$pid" TERM
			# Give it a few seconds to go, then insist.
			for ((i = 0; i < 25; i++)); do
				kill -0 "$pid" 2>/dev/null || break
				rc_sleep 0.2
			done
			if kill -0 "$pid" 2>/dev/null; then
				core_kill_tree "$pid" KILL
			fi
			break
		fi

		if [[ $mode != none ]] && _job_sample "$mode" "$pid"; then
			if ((!have_base)); then
				base=$REPLY
				have_base=1
			fi
			cur=$((REPLY - base))
			((cur < 0)) && cur=0
			JOB_DONE=$cur
			now_ms
			now=$REPLY
			# Sliding window of about three seconds for the transfer rate.
			win_t+=("$now")
			win_b+=("$cur")
			n=${#win_t[@]}
			while ((n > 2 && now - win_t[0] > 3000)); do
				win_t=("${win_t[@]:1}")
				win_b=("${win_b[@]:1}")
				n=${#win_t[@]}
			done
			dt=$((now - win_t[0]))
			if ((dt >= 500)); then
				JOB_RATE=$(((cur - win_b[0]) * 1000 / dt))
			elif ((now - t0 >= 500)); then
				JOB_RATE=$((cur * 1000 / (now - t0)))
			fi
			if ((total > 0)); then
				JOB_PCT=$((cur * 1000 / total))
				# Never claim completion before the command has returned.
				((JOB_PCT > 999)) && JOB_PCT=999
				if ((JOB_RATE > 0 && cur < total)); then
					JOB_ETA=$(((total - cur) / JOB_RATE))
				else
					JOB_ETA=-1
				fi
				JOB_OVERALL=$((JOB_STEP_BASE + JOB_STEP_SPAN * JOB_PCT / 1000))
			fi
		fi

		if [[ -n $JOB_NOTE_FILE && -s $JOB_NOTE_FILE ]]; then
			IFS= read -r JOB_NOTE <"$JOB_NOTE_FILE" 2>/dev/null || true
		fi
		[[ -n $JOB_UI_HOOK ]] && "$JOB_UI_HOOK"
		if [[ -n $JOB_KEY_HOOK ]]; then
			"$JOB_KEY_HOOK" "$JOB_TICK"
		else
			rc_sleep "$JOB_TICK"
		fi
	done

	wait "$pid" 2>/dev/null || rc=$?
	if ((cancelled || RC_CANCELLED)); then
		log "operation cancelled"
		return 130
	fi
	if ((rc == 0)); then
		if ((total > 0)); then
			JOB_PCT=1000
			JOB_DONE=$total
			JOB_ETA=0
			JOB_OVERALL=$((JOB_STEP_BASE + JOB_STEP_SPAN))
		fi
	else
		log "  -> exit status $rc"
	fi
	[[ -n $JOB_UI_HOOK ]] && "$JOB_UI_HOOK"
	return "$rc"
}

# --- public runners ---------------------------------------------------------

job_spin() {
	((RC_CANCELLED)) && return 130
	log_cmd "$@"
	"$@" >>"${LOG_FILE:-/dev/null}" 2>&1 </dev/null &
	JOB_LAST_PID=$!
	_job_wait "$JOB_LAST_PID" none 0
}

job_track_write() {
	local total=$1
	shift
	((RC_CANCELLED)) && return 130
	is_uint "$total" || total=0
	log_cmd "$@"
	"$@" >>"${LOG_FILE:-/dev/null}" 2>&1 </dev/null &
	JOB_LAST_PID=$!
	_job_wait "$JOB_LAST_PID" write "$total"
}

job_track_read() {
	local total=$1
	shift
	((RC_CANCELLED)) && return 130
	is_uint "$total" || total=0
	log_cmd "$@"
	"$@" >>"${LOG_FILE:-/dev/null}" 2>&1 </dev/null &
	JOB_LAST_PID=$!
	_job_wait "$JOB_LAST_PID" read "$total"
}

# job_track_stdin TOTAL INFILE OUTFILE CMD...
# CMD reads INFILE on its standard input; progress is the read offset in it.
# CMD's standard output is written to OUTFILE ("-" sends it to the log).
job_track_stdin() {
	local total=$1 infile=$2 outfile=$3
	shift 3
	((RC_CANCELLED)) && return 130
	is_uint "$total" || total=0
	log_cmd "$@"
	if [[ $outfile == - ]]; then
		"$@" >>"${LOG_FILE:-/dev/null}" 2>&1 <"$infile" &
	else
		"$@" >"$outfile" 2>>"${LOG_FILE:-/dev/null}" <"$infile" &
	fi
	JOB_LAST_PID=$!
	_job_wait "$JOB_LAST_PID" stdin "$total"
}
