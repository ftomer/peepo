#!/bin/zsh
# Store screenshots, at the exact pixel sizes App Store Connect asks for.
#
#   tools/store_shots.sh iphone   -> 2688x1242 (6.5" landscape)
#   tools/store_shots.sh ipad     -> 2752x2064 (13" landscape)
#
# Runs integration_test/store_screenshots_test.dart against the macOS build.
# The rig sizes the window to the matching point size, walks the app through
# each screen and stops on a file handshake; this side captures the window and
# lets it move on. The window is captured by id, so nothing here needs a mouse
# or the app to be in front.
set -e

target=${1:-iphone}
case $target in
  iphone) want=2688x1242 ;;
  ipad)   want=2752x2064 ;;
  *) print "usage: store_shots.sh [iphone|ipad]"; exit 1 ;;
esac
bad=0

root=${0:A:h:h}
shots=$root/store/screenshots/$target
work=$(mktemp -d)
# The app is sandboxed, so its temp directory is inside its container.
handshake=$HOME/Library/Containers/com.glydeo.peepo/Data/tmp/peepo_shots

mkdir -p $shots
rm -rf $handshake
rm -f $shots/*.png(N)

export PATH="$HOME/development/flutter/bin:$PATH"
finder=$work/peepo_window
swiftc -O $root/tools/peepo_window.swift -o $finder
# A window capture always carries an alpha channel, which App Store Connect
# rejects, so every shot goes through this on the way out.
flatten=$work/strip_alpha
swiftc -O $root/tools/strip_alpha.swift -o $flatten

# The iPad window is taller than a laptop screen at its usual scaled
# resolution, so borrow a roomier display mode and hand it back afterwards.
if [[ $target == ipad ]]; then
  modes=$work/display_mode
  swiftc -O $root/tools/display_mode.swift -o $modes
  was=$($modes | awk '/^current/ {print $2}')
  pick=$($modes | awk '$1 != "current" && $2 >= 1400 && $3 >= 1100 {print $1; exit}')
  if [[ $was == -1 ]]; then
    # The live mode is not one CoreGraphics lists, so there is no index to hand
    # back. Borrowing a mode here would strand the screen in it, so don't.
    print "Can't identify the current display mode, leaving it alone."
    print "If the iPad window is clipped, switch to a taller resolution by hand."
  elif [[ -n $pick && $pick != $was ]]; then
    print "Switching the display to a taller mode for the iPad shots"
    trap "print 'Restoring the display mode'; $modes $was" EXIT INT TERM
    $modes $pick
    sleep 2
  fi
fi

print "Capturing $target into $shots"

flutter test integration_test/store_screenshots_test.dart -d macos \
  --dart-define=SHOT_TARGET=$target > $work/test.log 2>&1 &
test_pid=$!

while kill -0 $test_pid 2>/dev/null; do
  if [[ -f $handshake/request ]]; then
    name=$(cat $handshake/request)
    rm -f $handshake/request
    if [[ -z $name ]]; then
      print "  empty capture request - the handshake is out of step"
      bad=1
      print done > $handshake/ack
      sleep 0.2
      continue
    fi
    # Let the window finish the frame it is on before the shutter.
    sleep 0.6
    id=$($finder | awk '{print $1}')
    if [[ -n $id ]]; then
      screencapture -x -o -l$id $work/$name.png
      $flatten $work/$name.png $shots/$name.png
      size=$(sips -g pixelWidth -g pixelHeight $shots/$name.png |
             awk '/pixel/ {print $2}' | paste -sd x -)
      if [[ $size != $want ]]; then
        print "  $name  $size - WRONG SIZE, wanted $want"
        bad=1
      else
        print "  $name  $size"
      fi
    else
      print "  $name - no window found"
      bad=1
    fi
    print done > $handshake/ack
  fi
  sleep 0.2
done

# The rig says when it is finished rather than the exit code saying it. The
# app plays music for as long as it is up, and audioplayers' position updater
# is still ticking when the binding tears the tree down; the framework reports
# that as a failure, differently on different runs, after every shot is already
# captured. So a run is judged on what it produced.
# Caught rather than let through: `set -e` would take the script out here on
# the very failure it is meant to look past. Not `status`, which zsh reserves
# as another name for $?.
rig_status=0
wait $test_pid || rig_status=$?
if [[ ! -f $handshake/finished ]]; then
  print "rig stopped early, see $work/test.log"
  tail -30 $work/test.log
  exit 1
fi
# Written as `if`, not as `(( x )) && ...`: under `set -e` an and-list whose
# test comes out false is a failing last command, and the script would exit
# here - silently, one line short of saying it had done its job.
if (( bad )); then
  print "some shots came out wrong, see above"
  exit 1
fi
if (( rig_status )); then
  print "(the rig exited $rig_status on the way out; every shot was taken)"
fi
print "Done. $shots"
