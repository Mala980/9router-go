### Fixed — DNS resolution on Android/Termux (upstream lookups failed with `lookup … on [::1]:53: connection refused`)

- New `internal/netfix` package, installed first in `cmd/9router-go`'s
  `main()`. Android has no `/etc/resolv.conf`, so Go's pure resolver
  silently fell back to the loopback defaults `127.0.0.1:53` /
  `[::1]:53` where nothing listens under Termux — the gateway
  started, but every provider/Telegram/updater lookup failed. (The
  failure was proven live on Termux with the sister go-magic binary,
  whose `pkg/netfix` this is ported from; it depends only on Go's
  resolver behaviour and the missing file.)
- When Android/Termux is detected — or the system resolv.conf is
  missing/loopback-only — the fallback default resolver collects
  nameservers in order: `NINEROUTER_DNS` env override,
  `$PREFIX/etc/resolv.conf`, the well-known Termux resolv.conf path,
  `/etc/resolv.conf`, then public fallbacks `1.1.1.1` / `8.8.8.8`;
  loopback entries are always dropped. Healthy desktops are left
  completely untouched, and one `[netfix]` startup log line names
  the servers in use.
- Every outbound path in the repo resolves through
  `net.DefaultResolver` (verified by audit — the SSRF guards call it
  explicitly), so this single install also fixes the SSRF
  pre-resolution checks, which would otherwise have rejected every
  hostname on Android.
- Verified by unit tests for the resolv.conf parser, detection and
  server collection, plus an end-to-end resolver test against a fake
  DNS server; README Termux section documents the behaviour and the
  override.
