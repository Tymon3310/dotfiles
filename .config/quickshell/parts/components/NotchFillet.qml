// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T C H   F I L L E T                                                │
// │   the concave corner where the notch meets the screen edge               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import "../theme"
import "../../shared" as Shared

Shared.NotchCorner {
    color: Theme.island
    implicitWidth: Theme.radiusNotch * 2
    implicitHeight: Theme.radiusNotch * 2
}
