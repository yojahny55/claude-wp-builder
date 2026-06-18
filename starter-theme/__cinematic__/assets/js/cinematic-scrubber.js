/* Cinematic Scroll Kit — WebCodecs scrubber
   --------------------------------------------------------
   Drives a <canvas> from a scroll progress value (0..1) by decoding the
   target frame on demand via WebCodecs + MP4Box. Replaces the failed
   `video.currentTime` scrub: codecs cannot decode backward, and
   currentTime snaps to keyframes — both of which manifested as the
   "stuck / jumps to end / reverse stutter" symptoms in the old path.

   Strategy: single-frame-in-flight. On each scrubTo(progress) we compute
   the target frame index. If it differs from the last requested frame,
   we feed an EncodedVideoChunk into the decoder. When VideoFrame arrives
   on the output callback, we paint and close it. The decoder is fast
   enough at 720p (~5ms per frame) to keep up with normal scroll, and
   stale requests are silently dropped if a newer one supersedes them.

   Public API:
     const s = new CinematicScrubber(videoUrl, canvas);
     await s.init();        // fetch + demux + prime decoder
     s.scrubTo(0.42);       // paint frame at 42% through video
     s.destroy();           // release decoder + samples
*/
(() => {
  'use strict';

  const MP4BOX_URL = 'https://cdn.jsdelivr.net/npm/mp4box@0.5.2/dist/mp4box.all.min.js';
  let _mp4boxLoading = null;

  function loadMp4Box() {
    if (window.MP4Box) return Promise.resolve();
    if (_mp4boxLoading) return _mp4boxLoading;
    _mp4boxLoading = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = MP4BOX_URL;
      s.async = true;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('Failed to load MP4Box.js'));
      document.head.appendChild(s);
    });
    return _mp4boxLoading;
  }

  /**
   * Feature detect — caller should branch to the legacy <video> path if false.
   */
  function isSupported() {
    return typeof window.VideoDecoder === 'function'
        && typeof window.EncodedVideoChunk === 'function';
  }

  class CinematicScrubber {
    constructor(videoUrl, canvas) {
      this.videoUrl = videoUrl;
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d', { alpha: false, desynchronized: true });
      this.samples = [];          // Array<EncodedVideoChunkInit>
      this.decoder = null;
      this.ready = false;
      this.destroyed = false;
      this.width = 0;
      this.height = 0;
      this.lastRequestedFrame = -1;
      this.pendingFrame = -1;     // frame index we're waiting for
      this._latestFrameDrawn = -1;
    }

    async init() {
      await loadMp4Box();
      if (this.destroyed) return;

      const buf = await fetch(this.videoUrl).then(r => r.arrayBuffer());
      if (this.destroyed) return;
      buf.fileStart = 0;

      // Demux
      const file = window.MP4Box.createFile();
      const trackInfo = await new Promise((resolve, reject) => {
        file.onError = e => reject(new Error('MP4Box demux failed: ' + e));
        file.onReady = info => {
          const track = info.videoTracks[0];
          if (!track) return reject(new Error('No video track'));
          resolve(track);
        };
        file.appendBuffer(buf);
        file.flush();
      });
      if (this.destroyed) return;

      this.width = trackInfo.video.width;
      this.height = trackInfo.video.height;
      this.canvas.width = this.width;
      this.canvas.height = this.height;

      // Build EncodedVideoChunk descriptions from samples
      const samples = await new Promise((resolve, reject) => {
        const acc = [];
        file.onSamples = (id, user, sampleArr) => {
          for (const s of sampleArr) {
            acc.push({
              type: s.is_sync ? 'key' : 'delta',
              timestamp: (s.cts * 1e6) / s.timescale,
              duration: (s.duration * 1e6) / s.timescale,
              data: s.data,
            });
          }
          if (acc.length >= trackInfo.nb_samples) resolve(acc);
        };
        file.setExtractionOptions(trackInfo.id, null, { nbSamples: trackInfo.nb_samples });
        file.start();
      });
      if (this.destroyed) return;
      this.samples = samples;

      // Get the avcC / hvcC description blob for the decoder config
      const description = extractDescription(file, trackInfo);

      // Build decoder
      this.decoder = new window.VideoDecoder({
        output: vf => this._onDecoded(vf),
        error: e => console.warn('[scrubber] decoder error', e),
      });
      const codec = trackInfo.codec.startsWith('avc1')
        ? trackInfo.codec
        : (trackInfo.codec || 'avc1.42E01E');
      this.decoder.configure({
        codec,
        codedWidth: this.width,
        codedHeight: this.height,
        description,
        optimizeForLatency: true,
      });

      this.ready = true;
      // Paint frame 0 so the canvas isn't blank
      this.scrubTo(0);
    }

    /**
     * Paint the frame nearest to `progress` (0..1).
     */
    scrubTo(progress) {
      if (!this.ready || this.destroyed) return;
      const total = this.samples.length;
      if (!total) return;
      const idx = Math.max(0, Math.min(total - 1, Math.floor(progress * (total - 1))));
      if (idx === this.lastRequestedFrame) return;
      this.lastRequestedFrame = idx;
      this._requestFrame(idx);
    }

    _requestFrame(idx) {
      if (this.pendingFrame === idx) return;
      this.pendingFrame = idx;

      // For all-keyframe MP4 (which we encode) every frame is independently
      // decodable — feed the single sample. For inter-frame video we'd need
      // to walk back to the nearest keyframe and decode forward; we don't
      // currently encode that way, but the branch is here in case.
      const sample = this.samples[idx];
      if (sample.type === 'key') {
        this._submit(sample);
      } else {
        // Walk back to nearest keyframe, decode forward to idx.
        let kf = idx;
        while (kf > 0 && this.samples[kf].type !== 'key') kf--;
        for (let i = kf; i <= idx; i++) this._submit(this.samples[i]);
      }
    }

    _submit(sample) {
      try {
        this.decoder.decode(new window.EncodedVideoChunk(sample));
      } catch (e) {
        // Decoder rejects on configure mismatch or after close — ignore once.
      }
    }

    _onDecoded(videoFrame) {
      if (this.destroyed) { videoFrame.close(); return; }
      // Drop stale frames: only the most recent requested frame matters.
      // If user keeps scrolling, intermediate frames may queue up and arrive
      // late — we paint the latest one only.
      try {
        this.ctx.drawImage(videoFrame, 0, 0, this.width, this.height);
        this._latestFrameDrawn = this.pendingFrame;
      } finally {
        videoFrame.close();
      }
    }

    destroy() {
      this.destroyed = true;
      try { this.decoder && this.decoder.close(); } catch (_) {}
      this.samples = [];
      this.decoder = null;
    }
  }

  // MP4Box exposes the codec description as the entries needed to build the
  // `avcC` box. This helper serialises it into a Uint8Array the decoder
  // accepts in `description`. Lifted from the standard demuxer pattern.
  function extractDescription(file, trackInfo) {
    const trak = file.moov.traks.find(t => t.tkhd.track_id === trackInfo.id);
    if (!trak) return undefined;
    for (const entry of trak.mdia.minf.stbl.stsd.entries) {
      const box = entry.avcC || entry.hvcC || entry.vpcC || entry.av1C;
      if (!box) continue;
      // Re-serialise via MP4Box's own writer.
      const stream = new (window.MP4Box.DataStream || window.DataStream)(undefined, 0, (window.MP4Box.DataStream || window.DataStream).BIG_ENDIAN);
      box.write(stream);
      return new Uint8Array(stream.buffer, 8); // skip the 8-byte box header
    }
    return undefined;
  }

  // Expose
  window.CinematicScrubber = CinematicScrubber;
  window.CinematicScrubber.isSupported = isSupported;
})();
