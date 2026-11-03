package com.incrediblezayed.file_saver

import java.io.OutputStream

// Return only after write/flush/close succeeds; propagate failures to the channel.
internal fun writeDocument(output: OutputStream?, bytes: ByteArray) {
    requireNotNull(output) { "Document provider returned no output stream" }.use {
        it.write(bytes)
        it.flush()
    }
}
