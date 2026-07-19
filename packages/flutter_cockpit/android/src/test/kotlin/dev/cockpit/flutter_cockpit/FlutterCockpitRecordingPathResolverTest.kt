package dev.cockpit.flutter_cockpit

import java.nio.file.Files
import kotlin.io.path.createDirectories
import kotlin.io.path.createTempDirectory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

class FlutterCockpitRecordingPathResolverTest {
    @Test
    fun rejectsBlankPath() {
        assertThrows(IllegalArgumentException::class.java) {
            FlutterCockpitRecordingPathResolver.resolve(
                createTempDirectory().toFile(),
                "  ",
            )
        }
    }

    @Test
    fun rejectsAbsolutePath() {
        val root = createTempDirectory().toFile()
        assertThrows(IllegalArgumentException::class.java) {
            FlutterCockpitRecordingPathResolver.resolve(root, "/tmp/capture.mp4")
        }
    }

    @Test
    fun rejectsDriveQualifiedPath() {
        val root = createTempDirectory().toFile()
        assertThrows(IllegalArgumentException::class.java) {
            FlutterCockpitRecordingPathResolver.resolve(root, "C:capture.mp4")
        }
    }

    @Test
    fun rejectsParentTraversal() {
        val root = createTempDirectory().toFile()
        assertThrows(IllegalArgumentException::class.java) {
            FlutterCockpitRecordingPathResolver.resolve(root, "nested/../capture.mp4")
        }
    }

    @Test
    fun rejectsRecordingRootItself() {
        val root = createTempDirectory().toFile()
        assertThrows(IllegalArgumentException::class.java) {
            FlutterCockpitRecordingPathResolver.resolve(root, ".")
        }
    }

    @Test
    fun rejectsCanonicalSiblingPrefixEscape() {
        val parent = createTempDirectory()
        val root = parent.resolve("flutter_cockpit_recordings").also { it.createDirectories() }
        val sibling = parent.resolve("flutter_cockpit_recordings-escape").also {
            it.createDirectories()
        }
        val link = root.resolve("link")
        try {
            Files.createSymbolicLink(link, sibling)
        } catch (_: UnsupportedOperationException) {
            assumeTrue("Symbolic links are required for the escape test", false)
        } catch (_: java.nio.file.FileSystemException) {
            assumeTrue("Symbolic links are required for the escape test", false)
        }

        assertThrows(IllegalArgumentException::class.java) {
            FlutterCockpitRecordingPathResolver.resolve(parent.toFile(), "link/capture.mp4")
        }
    }

    @Test
    fun resolvesValidNestedPathUnderOwnedRoot() {
        val cacheDirectory = createTempDirectory().toFile()
        val resolved = FlutterCockpitRecordingPathResolver.resolve(
            cacheDirectory,
            "nested/capture.mp4",
        )
        val root = cacheDirectory.resolve("flutter_cockpit_recordings")

        assertEquals(
            root.toPath().resolve("nested/capture.mp4").toFile().canonicalFile,
            resolved,
        )
        assertTrue(resolved.path.startsWith(root.canonicalPath + java.io.File.separator))
    }

    @Test
    fun capabilityRequiresApiActivityAndProjectionManager() {
        assertFalse(
            FlutterCockpitRecordingCapability.isAvailable(
                sdkInt = 28,
                hasActivity = false,
                hasProjectionManager = true,
            ),
        )
        assertFalse(
            FlutterCockpitRecordingCapability.isAvailable(
                sdkInt = 28,
                hasActivity = true,
                hasProjectionManager = false,
            ),
        )
        assertFalse(
            FlutterCockpitRecordingCapability.isAvailable(
                sdkInt = 20,
                hasActivity = true,
                hasProjectionManager = true,
            ),
        )
        assertTrue(
            FlutterCockpitRecordingCapability.isAvailable(
                sdkInt = 21,
                hasActivity = true,
                hasProjectionManager = true,
            ),
        )
    }
}
