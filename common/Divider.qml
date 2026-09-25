// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
import QtQuick
Rectangle {
    required property var pal
    implicitWidth: 1
    implicitHeight: Math.round(pal.thickness * 0.46)
    color: pal.out
}
