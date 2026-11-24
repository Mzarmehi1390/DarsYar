package com.mzarmehi1390.darsyar.data

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * Reads untrusted backup input with a strict byte limit before JSON parsing.
 *
 * The limit is measured in encoded bytes (not UTF-16 characters), so a file
 * cannot force an unbounded allocation through a document provider.
 */
internal object DarsYarBackupFileReader {
    const val MAX_BACKUP_BYTES: Int = 10 * 1024 * 1024
    private const val BUFFER_SIZE = 8 * 1024

    fun read(input: InputStream): String {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(BUFFER_SIZE)
        var totalBytes = 0

        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (count == 0) {
                // InputStream implementations may legally return zero for a
                // non-empty buffer request. Fall back to a single-byte read
                // so a non-conforming provider cannot cause a busy loop.
                val singleByte = input.read()
                if (singleByte < 0) break
                totalBytes++
                if (totalBytes > MAX_BACKUP_BYTES) {
                    throw BackupFileTooLargeException(MAX_BACKUP_BYTES)
                }
                output.write(singleByte)
                continue
            }

            totalBytes += count
            if (totalBytes > MAX_BACKUP_BYTES) {
                throw BackupFileTooLargeException(MAX_BACKUP_BYTES)
            }
            output.write(buffer, 0, count)
        }

        return try {
            StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(output.toByteArray()))
                .toString()
        } catch (exception: CharacterCodingException) {
            throw BackupFileEncodingException(exception)
        }
    }
}

class BackupFileTooLargeException(maxBytes: Int) :
    IllegalArgumentException("Backup file exceeds the maximum size of $maxBytes bytes.")

class BackupFileEncodingException(cause: Throwable) :
    IllegalArgumentException("Backup file is not valid UTF-8.", cause)
