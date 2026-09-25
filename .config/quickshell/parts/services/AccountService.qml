pragma Singleton

import QtQuick
import Quickshell

import "."

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string home: Quickshell.env("HOME") || "/home/" + root.user

    readonly property string name: SettingsService.userName !== ""
        ? SettingsService.userName
        : (root.user.charAt(0).toUpperCase() + root.user.slice(1))

    readonly property string avatar: {
        if (SettingsService.userAvatar !== "")
            return SettingsService.userAvatar
        return ""
    }

    readonly property string initials: {
        const words = root.name.trim().split(/\s+/).filter(word => word !== "")
        if (words.length === 0)
            return "?"
        if (words.length === 1)
            return words[0].slice(0, 1).toUpperCase()
        return (words[0].slice(0, 1) + words[words.length - 1].slice(0, 1)).toUpperCase()
    }
}
