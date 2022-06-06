package com.brentvatne.exoplayer.download.trackers

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import com.digimed.drm.video.downloader.services.VideoDownloaderService
import com.google.android.exoplayer2.Format
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.drm.DefaultDrmSessionManager
import com.google.android.exoplayer2.drm.DrmInitData
import com.google.android.exoplayer2.drm.DrmSession.DrmSessionException
import com.google.android.exoplayer2.drm.DrmSessionEventListener
import com.google.android.exoplayer2.drm.OfflineLicenseHelper
import com.google.android.exoplayer2.offline.DownloadHelper
import com.google.android.exoplayer2.offline.DownloadHelper.LiveContentUnsupportedException
import com.google.android.exoplayer2.offline.DownloadRequest
import com.google.android.exoplayer2.offline.DownloadService
import com.google.android.exoplayer2.trackselection.MappingTrackSelector.MappedTrackInfo
import com.google.android.exoplayer2.util.Assertions
import com.google.android.exoplayer2.util.Log
import com.google.android.exoplayer2.util.Util
import java.io.IOException
import java.lang.Exception
import javax.annotation.Nullable

class StartDownloadHelper: DownloadHelper.Callback {
  interface Listener {
    fun onOfflineLicenseFetchFailed(mediaItem: MediaItem?,exception: Exception?)
  }
  companion object {
    const val TAG = "StartDownloadHelper"
  }
  private var mediaItem: MediaItem? = null
  private var downloadHelper: DownloadHelper? = null
  private var context: Context? = null
  private var listener: Listener? = null
  @Nullable private var keySetId: String? = null
  constructor(context: Context?, mediaItem: MediaItem?, downloadHelper: DownloadHelper, listener: Listener){
    this.downloadHelper = downloadHelper
    this.mediaItem = mediaItem
    this.context = context
    this.listener = listener
    this.downloadHelper?.prepare(this)
  }

  override fun onPrepared(helper: DownloadHelper) {
    onDownloadPrepared(helper)
  }


  override fun onPrepareError(helper: DownloadHelper, e: IOException) {
    val isLiveContent = e is LiveContentUnsupportedException
    val logMessage = if (isLiveContent) "Downloading live content unsupported" else "Failed to start download"
    Log.e(StartDownloadHelper.TAG, logMessage, e)
    listener?.onOfflineLicenseFetchFailed(this.mediaItem,e)
  }

  private fun onDownloadPrepared(helper: DownloadHelper) {
    startDownload()
    helper?.release()
  }

  private fun startDownload() {
    var downloadRequest = this.buildDownloadRequest()
    downloadRequest?.let {
      startDownload(it)
    }
  }

  private fun startDownload(downloadRequest: DownloadRequest) {
    context?.let {
      DownloadService.sendAddDownload(it, VideoDownloaderService::class.java, downloadRequest,  /* foreground= */false)
    }
  }

  private fun buildDownloadRequest(): DownloadRequest? {
    val keySetIdBytes = this.keySetId?.toByteArray();
    return downloadHelper?.getDownloadRequest(Util.getUtf8Bytes(Assertions.checkNotNull(mediaItem!!.mediaMetadata.title)))?.copyWithKeySetId(keySetIdBytes)
  }

  fun getKeySetID(): String?{
    return this.keySetId;
  }

  fun  release(){
    this.downloadHelper?.release()
  }

}
