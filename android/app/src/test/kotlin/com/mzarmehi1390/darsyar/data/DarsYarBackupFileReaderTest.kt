package com.mzarmehi1390.darsyar.data

import java.io.ByteArrayInputStream
import java.io.InputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class DarsYarBackupFileReaderTest {
    @Test
    fun read_decodesUtf8PersianText() {
        val expected = """{"title":"برنامهٔ مطالعه","subject":"ریاضی"}"""

        val actual = DarsYarBackupFileReader.read(
            ByteArrayInputStream(expected.toByteArray(Charsets.UTF_8)),
        )

        assertEquals(expected, actual)
    }

    @Test
    fun read_acceptsInputExactlyAtTenMegabyteLimit() {
        val boundary = ByteArray(DarsYarBackupFileReader.MAX_BACKUP_BYTES) { 'a'.code.toByte() }

        val actual = DarsYarBackupFileReader.read(ByteArrayInputStream(boundary))

        assertEquals(DarsYarBackupFileReader.MAX_BACKUP_BYTES, actual.length)
    }

    @Test
    fun read_acceptsEmptyInput() {
        assertEquals("", DarsYarBackupFileReader.read(ByteArrayInputStream(byteArrayOf())))
    }

    @Test
    fun read_rejectsInputLargerThanTenMegabytes() {
        val oversized = ByteArray(DarsYarBackupFileReader.MAX_BACKUP_BYTES + 1)

        assertThrows(BackupFileTooLargeException::class.java) {
            DarsYarBackupFileReader.read(ByteArrayInputStream(oversized))
        }
    }

    @Test
    fun read_rejectsMalformedUtf8() {
        val malformed = byteArrayOf(0xC3.toByte(), 0x28)

        assertThrows(BackupFileEncodingException::class.java) {
            DarsYarBackupFileReader.read(ByteArrayInputStream(malformed))
        }
    }

    @Test
    fun read_fallsBackWhenBulkReadReturnsZero() {
        val expected = "backup".toByteArray(Charsets.UTF_8)
        val input = object : InputStream() {
            private val delegate = ByteArrayInputStream(expected)
            private var firstBulkRead = true

            override fun read(): Int = delegate.read()

            override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                if (firstBulkRead) {
                    firstBulkRead = false
                    return 0
                }
                return delegate.read(buffer, offset, length)
            }
        }

        assertEquals("backup", DarsYarBackupFileReader.read(input))
    }
}
