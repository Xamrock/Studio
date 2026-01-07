package com.xamrock.testhost

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import com.google.gson.Gson
import com.google.gson.JsonObject
import fi.iki.elonen.NanoHTTPD
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

@RunWith(AndroidJUnit4::class)
class StudioRecorderInstrumentationTest {

    private lateinit var device: UiDevice
    private lateinit var httpServer: StudioHTTPServer
    private lateinit var targetPackage: String
    private var skipAppLaunch: Boolean = false
    private val gson = Gson()

    companion object {
        private const val TAG = "StudioRecorder"
        private const val PORT = 8080
    }

    @Before
    fun setUp() {
        // Get instrumentation arguments
        val arguments = InstrumentationRegistry.getArguments()
        targetPackage = arguments.getString("targetPackage") ?: "com.google.android.apps.maps"
        skipAppLaunch = arguments.getString("skipAppLaunch") == "true"

        Log.d(TAG, "Target package: $targetPackage, Skip launch: $skipAppLaunch")

        // Initialize UiDevice
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

        // Start the HTTP server
        httpServer = StudioHTTPServer(PORT, device, targetPackage)
        httpServer.start()

        Log.d(TAG, "HTTP server started on port $PORT")
    }

    @Test
    fun testRecordingSession() {
        // Launch target app if not skipping
        if (!skipAppLaunch) {
            launchTargetApp()
        }

        // Keep test running until stop command received
        while (!httpServer.shouldStop) {
            Thread.sleep(100)
        }

        Log.d(TAG, "Recording session ended")
    }

    @After
    fun tearDown() {
        httpServer.stop()
    }

    private fun launchTargetApp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = context.packageManager.getLaunchIntentForPackage(targetPackage)

        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            context.startActivity(intent)
            device.wait(Until.hasObject(By.pkg(targetPackage).depth(0)), 5000)
            Log.d(TAG, "Launched target app: $targetPackage")
        } else {
            Log.e(TAG, "Could not find launch intent for package: $targetPackage")
        }
    }

    /**
     * HTTP Server implementation using NanoHTTPD
     */
    inner class StudioHTTPServer(
        port: Int,
        private val device: UiDevice,
        private val targetPackage: String
    ) : NanoHTTPD(port) {

        var shouldStop = false

        override fun serve(session: IHTTPSession): Response {
            val uri = session.uri
            val method = session.method

            Log.d(TAG, "Received request: $method $uri")

            return when {
                method == Method.GET && uri == "/health" -> {
                    newFixedLengthResponse(Response.Status.OK, "text/plain", "OK")
                }

                method == Method.POST && uri == "/capture" -> {
                    try {
                        val snapshot = captureHierarchySnapshot()
                        val json = gson.toJson(snapshot)
                        newFixedLengthResponse(Response.Status.OK, "application/json", json)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error capturing snapshot", e)
                        newFixedLengthResponse(
                            Response.Status.INTERNAL_ERROR,
                            "text/plain",
                            "Error: ${e.message}"
                        )
                    }
                }

                method == Method.POST && uri == "/interact" -> {
                    try {
                        // Parse request body
                        val files = HashMap<String, String>()
                        session.parseBody(files)
                        val body = files["postData"] ?: ""

                        val command = gson.fromJson(body, InteractionCommand::class.java)

                        // Execute interaction
                        executeInteraction(command)

                        // Wait for UI to settle
                        Thread.sleep(1000)

                        // Capture new snapshot
                        val snapshot = captureHierarchySnapshot()
                        val json = gson.toJson(snapshot)
                        newFixedLengthResponse(Response.Status.OK, "application/json", json)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error executing interaction", e)
                        newFixedLengthResponse(
                            Response.Status.INTERNAL_ERROR,
                            "text/plain",
                            "Error: ${e.message}"
                        )
                    }
                }

                method == Method.POST && uri == "/stop" -> {
                    shouldStop = true
                    newFixedLengthResponse(Response.Status.OK, "text/plain", "Stopping")
                }

                else -> {
                    newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not Found")
                }
            }
        }

        private fun captureHierarchySnapshot(): HierarchySnapshot {
            // Capture screenshot
            val screenshotFile = java.io.File.createTempFile("screenshot", ".png")
            device.takeScreenshot(screenshotFile)
            val screenshot = android.graphics.BitmapFactory.decodeFile(screenshotFile.absolutePath)
            screenshotFile.delete()
            val screenshotBase64 = bitmapToBase64(screenshot)

            // Get root accessibility node
            val rootNode = InstrumentationRegistry.getInstrumentation()
                .uiAutomation.rootInActiveWindow

            // Serialize hierarchy
            val elements = if (rootNode != null) {
                listOf(serializeNode(rootNode))
            } else {
                emptyList()
            }

            // Get display metrics
            val displayMetrics = ApplicationProvider.getApplicationContext<Context>()
                .resources.displayMetrics

            // Create snapshot
            return HierarchySnapshot(
                timestamp = getCurrentTimestamp(),
                elements = elements,
                screenshot = screenshotBase64,
                appFrame = null,
                screenBounds = SizeData(
                    width = displayMetrics.widthPixels.toDouble(),
                    height = displayMetrics.heightPixels.toDouble()
                ),
                // For Android, displayScale should be 1.0 since element bounds are already in pixels
                // (matching the screenshot coordinate system)
                displayScale = 1.0,
                platform = "android"
            )
        }

        private fun serializeNode(node: AccessibilityNodeInfo): SnapshotElement {
            val bounds = android.graphics.Rect()
            node.getBoundsInScreen(bounds)

            // Get children
            val children = mutableListOf<SnapshotElement>()
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    children.add(serializeNode(child))
                    child.recycle()
                }
            }

            // Map Android elementType to iOS UIElementType (for UI compatibility)
            val className = node.className?.toString() ?: ""
            val elementType = mapAndroidClassToElementType(className)

            // Create platform metadata to preserve Android-specific data
            val platformMetadata = PlatformMetadata(
                androidClassName = className,
                isClickable = node.isClickable,
                isLongClickable = node.isLongClickable,
                isScrollable = node.isScrollable,
                isFocusable = node.isFocusable,
                isCheckable = node.isCheckable,
                isPassword = node.isPassword
            )

            return SnapshotElement(
                elementType = elementType,
                label = node.text?.toString() ?: "",
                title = node.contentDescription?.toString() ?: "",
                value = "",  // Android doesn't have a direct equivalent
                placeholderValue = "",  // Android doesn't have a direct equivalent
                isEnabled = node.isEnabled,
                isSelected = node.isSelected,
                frame = FrameData(
                    x = bounds.left.toDouble(),
                    y = bounds.top.toDouble(),
                    width = (bounds.right - bounds.left).toDouble(),
                    height = (bounds.bottom - bounds.top).toDouble()
                ),
                identifier = node.viewIdResourceName ?: "",
                children = children,
                platformMetadata = platformMetadata
            )
        }

        private fun mapAndroidClassToElementType(className: String): Int {
            // Map Android View classes to iOS UIElementType equivalents
            // https://developer.apple.com/documentation/xctest/xcuielementtype
            return when {
                className.contains("Button") -> 9  // Button
                className.contains("EditText") || className.contains("TextField") -> 49  // TextField
                className.contains("TextView") -> 52  // TextView (static text)
                className.contains("CheckBox") -> 12  // CheckBox
                className.contains("Switch") -> 40  // Switch
                className.contains("ImageView") -> 34  // Image
                className.contains("ScrollView") -> 53  // ScrollView
                className.contains("RecyclerView") || className.contains("ListView") -> 57  // Table
                className.contains("ViewGroup") -> 24  // Group/Other
                else -> 1  // Other (generic element)
            }
        }

        private fun executeInteraction(command: InteractionCommand) {
            Log.d(TAG, "Executing interaction: ${command.type}")

            when (command.type) {
                "tap" -> {
                    val query = command.query ?: throw IllegalArgumentException("Missing query")
                    val element = findElement(query)
                    element.click()
                }

                "doubleTap" -> {
                    val query = command.query ?: throw IllegalArgumentException("Missing query")
                    val element = findElement(query)
                    // Double tap by clicking twice
                    element.click()
                    Thread.sleep(100)
                    element.click()
                }

                "longPress" -> {
                    val query = command.query ?: throw IllegalArgumentException("Missing query")
                    val duration = (command.duration ?: 1.0) * 1000
                    val element = findElement(query)
                    element.click(duration.toLong())
                }

                "swipe" -> {
                    val direction = command.direction ?: throw IllegalArgumentException("Missing direction")
                    if (command.query != null) {
                        val element = findElement(command.query)
                        val bounds = element.visibleBounds
                        val centerX = (bounds.left + bounds.right) / 2
                        val centerY = (bounds.top + bounds.bottom) / 2
                        when (direction) {
                            "up" -> device.swipe(centerX, centerY, centerX, bounds.top, 10)
                            "down" -> device.swipe(centerX, centerY, centerX, bounds.bottom, 10)
                            "left" -> device.swipe(centerX, centerY, bounds.left, centerY, 10)
                            "right" -> device.swipe(centerX, centerY, bounds.right, centerY, 10)
                        }
                    } else {
                        // Swipe on entire screen
                        val displayWidth = device.displayWidth
                        val displayHeight = device.displayHeight
                        when (direction) {
                            "up" -> device.swipe(displayWidth / 2, displayHeight * 3 / 4, displayWidth / 2, displayHeight / 4, 10)
                            "down" -> device.swipe(displayWidth / 2, displayHeight / 4, displayWidth / 2, displayHeight * 3 / 4, 10)
                            "left" -> device.swipe(displayWidth * 3 / 4, displayHeight / 2, displayWidth / 4, displayHeight / 2, 10)
                            "right" -> device.swipe(displayWidth / 4, displayHeight / 2, displayWidth * 3 / 4, displayHeight / 2, 10)
                        }
                    }
                }

                "typeText" -> {
                    val text = command.text ?: throw IllegalArgumentException("Missing text")
                    if (command.query != null) {
                        val element = findElement(command.query)
                        element.click()
                        Thread.sleep(200)
                    }
                    device.findObject(By.focused(true))?.text = text
                }

                "tapCoordinate" -> {
                    val x = command.x ?: throw IllegalArgumentException("Missing x coordinate")
                    val y = command.y ?: throw IllegalArgumentException("Missing y coordinate")
                    device.click(x.toInt(), y.toInt())
                }

                "swipeCoordinate" -> {
                    val x = command.x ?: throw IllegalArgumentException("Missing x coordinate")
                    val y = command.y ?: throw IllegalArgumentException("Missing y coordinate")
                    val direction = command.direction ?: throw IllegalArgumentException("Missing direction")

                    when (direction) {
                        "up" -> device.swipe(x.toInt(), y.toInt(), x.toInt(), (y - 100).toInt(), 10)
                        "down" -> device.swipe(x.toInt(), y.toInt(), x.toInt(), (y + 100).toInt(), 10)
                        "left" -> device.swipe(x.toInt(), y.toInt(), (x - 100).toInt(), y.toInt(), 10)
                        "right" -> device.swipe(x.toInt(), y.toInt(), (x + 100).toInt(), y.toInt(), 10)
                    }
                }

                else -> throw IllegalArgumentException("Unknown command type: ${command.type}")
            }
        }

        private fun findElement(query: ElementQuery): UiObject2 {
            var selector = By.pkg(targetPackage)

            // Build selector based on query parameters
            query.identifier?.let { if (it.isNotEmpty()) selector = By.res(it) }
            query.label?.let { if (it.isNotEmpty()) selector = By.text(it) }
            query.title?.let { if (it.isNotEmpty()) selector = By.desc(it) }

            val element = device.findObject(selector)
                ?: throw IllegalArgumentException("Element not found with query: $query")

            return element
        }

        private fun bitmapToBase64(bitmap: Bitmap): String {
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val bytes = outputStream.toByteArray()
            return Base64.encodeToString(bytes, Base64.NO_WRAP)
        }

        private fun getCurrentTimestamp(): String {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            dateFormat.timeZone = TimeZone.getTimeZone("UTC")
            return dateFormat.format(Date())
        }
    }

    // Data classes for JSON serialization (matching Swift HierarchySnapshot structure)
    data class HierarchySnapshot(
        val timestamp: String,
        val elements: List<SnapshotElement>,
        val screenshot: String?,
        val appFrame: FrameData? = null,
        val screenBounds: SizeData?,
        val displayScale: Double?,
        val platform: String?
    )

    data class SnapshotElement(
        val elementType: Int,
        val label: String,
        val title: String,
        val value: String,
        val placeholderValue: String,
        val isEnabled: Boolean,
        val isSelected: Boolean,
        val frame: FrameData,
        val identifier: String,
        val children: List<SnapshotElement>,
        val platformMetadata: PlatformMetadata?
    )

    data class PlatformMetadata(
        val androidClassName: String? = null,
        val isClickable: Boolean? = null,
        val isLongClickable: Boolean? = null,
        val isScrollable: Boolean? = null,
        val isFocusable: Boolean? = null,
        val isCheckable: Boolean? = null,
        val isPassword: Boolean? = null,
        val iosHittable: Boolean? = null
    )

    data class FrameData(
        val x: Double,
        val y: Double,
        val width: Double,
        val height: Double
    )

    data class SizeData(
        val width: Double,
        val height: Double
    )

    data class InteractionCommand(
        val type: String,
        val query: ElementQuery? = null,
        val duration: Double? = null,
        val direction: String? = null,
        val text: String? = null,
        val x: Double? = null,
        val y: Double? = null
    )

    data class ElementQuery(
        val identifier: String? = null,
        val label: String? = null,
        val title: String? = null,
        val elementType: Int? = null,
        val index: Int? = null
    )
}
