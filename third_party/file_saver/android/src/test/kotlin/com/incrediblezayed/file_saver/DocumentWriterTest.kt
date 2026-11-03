package com.incrediblezayed.file_saver

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import org.junit.Assert.*
import org.junit.Test

class DocumentWriterTest {
    @Test fun writesFlushesAndCloses() {
        var closed = false
        var flushed = false
        val stream = object : ByteArrayOutputStream() {
            override fun close() { closed = true; super.close() }
            override fun flush() { flushed = true; super.flush() }
        }
        writeDocument(stream, byteArrayOf(1, 2, 3))
        assertArrayEquals(byteArrayOf(1, 2, 3), stream.toByteArray())
        assertTrue(closed)
        assertTrue(flushed)
    }
    @Test(expected = IllegalArgumentException::class) fun nullProviderFails() {
        writeDocument(null, byteArrayOf(1))
    }
    @Test fun writeFailurePropagatesAndCloses() {
        var closed = false
        val stream = object : OutputStream() {
            override fun write(b: Int) { throw IOException("full") }
            override fun close() { closed = true }
        }
        try {
            writeDocument(stream, byteArrayOf(1))
            fail("Write failure must propagate")
        } catch (e: IOException) { assertTrue(closed) }
    }
    @Test(expected = IOException::class) fun closeFailurePropagates() {
        writeDocument(object : ByteArrayOutputStream() {
            override fun close() { throw IOException("close failed") }
        }, byteArrayOf(1))
    }
    @Test(expected = IOException::class) fun flushFailurePropagates() {
        writeDocument(object : ByteArrayOutputStream() {
            override fun flush() { throw IOException("flush failed") }
        }, byteArrayOf(1))
    }
}
