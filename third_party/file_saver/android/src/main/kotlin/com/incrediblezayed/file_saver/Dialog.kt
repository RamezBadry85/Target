package com.incrediblezayed.file_saver

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.text.TextUtils
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.OutputStream


private const val SAVE_FILE = 886325063

class Dialog(private val activity: Activity) : PluginRegistry.ActivityResultListener {
    private var result: MethodChannel.Result? = null
    private var bytes: ByteArray? = null
    private var fileName: String? = null
    private val TAG = "Dialog Activity"

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_FILE) {
            return false
        }

        if (resultCode == Activity.RESULT_OK && data?.data != null) {
            Log.d(TAG, "Starting file operation")
            completeFileOperation(data.data!!)
        } else {
            Log.d(TAG, "Activity result was null")
            result?.success(null)
            result = null
        }

        return true
    }

    fun openFileManager(
        fileName: String?,
        ext: String?,
        bytes: ByteArray?,
        type: String?,
        result: MethodChannel.Result
    ) {
        Log.d(TAG, "Opening File Manager")
        if (this.result != null) {
            result.error("SAVE_IN_PROGRESS", "A save dialog is already open", null)
            return
        }
        this.result = result
        this.bytes = bytes
        this.fileName = fileName
        val intent =
            Intent(Intent.ACTION_CREATE_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.putExtra(Intent.EXTRA_TITLE, "$fileName.${ext.orEmpty().removePrefix(".")}")
        intent.putExtra(
            DocumentsContract.EXTRA_INITIAL_URI,
            Environment.getExternalStorageDirectory().path
        )
        intent.type = type
        try {
            activity.startActivityForResult(intent, SAVE_FILE)
        } catch (e: Exception) {
            this.result = null
            this.bytes = null
            throw e  // Plugin completes the channel error; next save may retry.
        }
    }

    private fun completeFileOperation(uri: Uri) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                withContext(Dispatchers.IO) {
                    writeDocument(activity.contentResolver.openOutputStream(uri),
                        requireNotNull(bytes) { "No document bytes supplied" })
                }
                // SAF providers need not expose a filesystem path. The URI is
                // the successful destination, not a nullable path lookup.
                result?.success(uri.toString())
                result = null
                //result?.success(getRealPathFromUri(activity, uri))
            } catch (e: SecurityException) {
                Log.d(TAG, "Security Exception while saving file" + e.message)

                result?.error("Security Exception", e.localizedMessage, null)
                result = null
            } catch (e: Exception) {
                Log.d(TAG, "Exception while saving file" + e.message)
                result?.error("Error", e.localizedMessage, null)
                result = null
            }
        }
    }

}
