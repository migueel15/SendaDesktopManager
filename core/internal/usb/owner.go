package usb

import (
	"io/fs"
	"syscall"
)

// ownerOf returns the user owning a file, or -1 when it is unknown.
func ownerOf(info fs.FileInfo) int {
	if stat, ok := info.Sys().(*syscall.Stat_t); ok {
		return int(stat.Uid)
	}
	return -1
}
