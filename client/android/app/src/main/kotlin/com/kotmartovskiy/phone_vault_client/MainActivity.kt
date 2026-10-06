package com.kotmartovskiy.phone_vault_client

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val permissionRequestCode = 4107

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
