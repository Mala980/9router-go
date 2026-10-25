//go:build linux || android

package clientconfig

import "golang.org/x/sys/unix"

// Linux answers termios through the generic TCGETS/TCSETS pair. The BSDs use
// the older TIOC* names for the same operation; the constants cannot be shared
// because their values differ. Android (bionic) uses the same TCGETS/TCSETS
// values as Linux, so it shares this file — as connect_termios_linux.go the
// filename constraint alone would have excluded it from android builds and
// left the password prompt with no termios implementation at all.
const (
	termiosGetReq = unix.TCGETS
	termiosSetReq = unix.TCSETS
)
