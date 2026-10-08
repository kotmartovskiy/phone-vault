[Reading 178 lines from start (total: 178 lines, 0 remaining)]

package com.kotmartovskiy.phone_vault_client

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import android.util.Base64
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val permissionRequestCode = 4107
    private val secureChannel = "phone_vault/secure_storage"
    private val keyAlias = "phone_vault_token_key"

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            permissionResult = null
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "phone_vault/file_index").setMethodCallHandler { call, result ->
            if (call.method == "requestPermission") {
                val permissions = if (Build.VERSION.SDK_INT >= 33) {
                    arrayOf(
                        Manifest.permission.READ_MEDIA_IMAGES,
                        Manifest.permission.READ_MEDIA_VIDEO,
                        Manifest.permission.READ_MEDIA_AUDIO
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
                } else {
                    emptyArray()
                }
                val missing = permissions.filter {
                    checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
                }
                if (missing.isNotEmpty()) {
                    permissionResult = result
                    requestPermissions(missing.toTypedArray(), permissionRequestCode)
                } else {
                    result.success(true)
                }
            } else if (call.method == "listFiles") {
                result.success(indexFiles())
            } else result.notImplemented()
        }

        MethodChannel(engine.dartExecutor.binaryMessenger, "phone_vault/nsd").setMethodCallHandler { call, result ->
            if (call.method != "discover") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val serviceType = call.argument<String>("serviceType") ?: "_phone-vault._tcp"
            val timeoutMs = (call.argument<Number>("timeoutMs")?.toLong() ?: 2000L).coerceIn(500L, 10000L)
            discoverNsd(serviceType, timeoutMs, result)
        }

        MethodChannel(engine.dartExecutor.binaryMessenger, secureChannel).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "writeToken" -> {
                        val token = call.argument<String>("token")
                        require(!token.isNullOrEmpty()) { "token is empty" }
                        getSharedSecret().let { key ->
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.ENCRYPT_MODE, key)
                            val ciphertext = cipher.doFinal(token.toByteArray(StandardCharsets.UTF_8))
                            val encoded = Base64.encodeToString(cipher.iv + ciphertext, Base64.NO_WRAP)
                            getPreferences(MODE_PRIVATE).edit().putString("secure_token", encoded).apply()
                        }
                        result.success(true)
                    }
                    "readToken" -> {
                        val encoded = getPreferences(MODE_PRIVATE).getString("secure_token", null)
                        if (encoded == null) {
                            result.success(null)
                        } else {
                            val raw = Base64.decode(encoded, Base64.DEFAULT)
                            require(raw.size > 12) { "invalid secure token" }
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.DECRYPT_MODE, getSharedSecret(), GCMParameterSpec(128, raw.copyOfRange(0, 12)))
                            val token = cipher.doFinal(raw.copyOfRange(12, raw.size)).toString(StandardCharsets.UTF_8)
                            result.success(token)
                        }
                    }
                    "deleteToken" -> {
                        getPreferences(MODE_PRIVATE).edit().remove("secure_token").apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SECURE_STORAGE", e.message, null)
            }
        }
    }

    private fun discoverNsd(serviceType: String, timeoutMs: Long, result: MethodChannel.Result) {
        val nsd = getSystemService(NSD_SERVICE) as android.net.nsd.NsdManager
        val results = mutableListOf<Map<String, Any>>()
        val lock = Any()
        var finished = false
        val handler = android.os.Handler(mainLooper)
        lateinit var listener: android.net.nsd.NsdManager.DiscoveryListener
        val finish = Runnable {
            synchronized(lock) {
                if (finished) return@Runnable
                finished = true
            }
            try { nsd.stopServiceDiscovery(listener) } catch (_: Exception) {}
            result.success(results.toList())
        }
        listener = object : android.net.nsd.NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {}
            override fun onServiceFound(serviceInfo: android.net.nsd.NsdServiceInfo) {
                if (serviceInfo.serviceType != serviceType) return
                nsd.resolveService(serviceInfo, object : android.net.nsd.NsdManager.ResolveListener {
                    override fun onResolveFailed(info: android.net.nsd.NsdServiceInfo, errorCode: Int) {}
                    override fun onServiceResolved(info: android.net.nsd.NsdServiceInfo) {
                        val host = info.host?.hostAddress ?: return
                        val port = info.port
                        synchronized(lock) {
                            if (!finished && port > 0 && results.none { it["host"] == host && it["port"] == port }) {
                                results.add(mapOf("host" to host, "port" to port))
                            }
                        }
                    }
                })
            }
            override fun onServiceLost(serviceInfo: android.net.nsd.NsdServiceInfo) {}
            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { handler.post(finish) }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
        }
        handler.postDelayed(finish, timeoutMs)
        try {
            nsd.discoverServices(serviceType, android.net.nsd.NsdManager.PROTOCOL_DNS_SD, listener)
        } catch (e: Exception) {
            handler.removeCallbacks(finish)
            result.error("NSD", e.message, null)
        }
    }

    private fun getSharedSecret(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(keyAlias, null)
        if (existing is SecretKey) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build()
        )
        return generator.generateKey()
    }

    private fun indexFiles(): List<Map<String, Any>> {
        val root = Environment.getExternalStorageDirectory()
        val roots = linkedMapOf(
            "Downloads" to File(root, "Download"),
            "Photos" to File(root, "DCIM"),
            "Pictures" to File(root, "Pictures"),
            "Videos" to File(root, "Movies"),
            "Music" to File(root, "Music"),
            "Documents" to File(root, "Documents"),
            "WhatsApp" to File(root, "Android/media/com.whatsapp/WhatsApp/Media"),
            "Telegram" to File(root, "Android/media/org.telegram.messenger/Telegram"),
            "Viber" to File(root, "Android/media/com.viber.voip/Viber")
        )
        val out = ArrayList<Map<String, Any>>()
        val seen = HashSet<String>()
        for ((label, dir) in roots) {
            if (dir.isDirectory) scan(dir, label, 0, seen, out)
            if (out.size >= 5000) break
        }
        out.sortByDescending { it["modified"] as Long }
        return out.take(5000)
    }

    private fun scan(dir: File, label: String, depth: Int, seen: MutableSet<String>, out: MutableList<Map<String, Any>>) {
        if (depth > 5 || out.size >= 5000) return
        val children = try { dir.listFiles() ?: return } catch (_: Exception) { return }
        for (f in children) {
            if (f.isDirectory) scan(f, label, depth + 1, seen, out)
            else if (f.isFile && f.length() > 0 && seen.add(f.absolutePath)) {
                val cat = category(f.name)
                out.add(mapOf("path" to f.absolutePath, "name" to f.name, "category" to cat,
                    "folder" to label, "mime" to mime(cat), "size" to f.length(), "modified" to f.lastModified()))
            }
            if (out.size >= 5000) return
        }
    }

    private fun category(name: String): String {
        val e = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
        return when (e) {
            "jpg","jpeg","png","webp","gif","bmp","heic","heif","avif" -> "Images"
            "mp4","mkv","mov","avi","webm","3gp","m4v" -> "Video"
            "mp3","m4a","aac","flac","wav","ogg","opus","amr" -> "Audio"
            "zip","rar","7z","tar","gz","bz2","xz" -> "Archives"
            "pdf","txt","doc","docx","xls","xlsx","ppt","pptx","csv","rtf","epub" -> "Documents"
            else -> "Other"
        }
    }

    private fun mime(category: String) = when (category) {
        "Images" -> "image/*"
        "Video" -> "video/*"
        "Audio" -> "audio/*"
        else -> "application/octet-stream"
    }
}

[executed on device: Lenovo (398cfb14-e310-4397-bd2d-83bbd22b1d3b)]