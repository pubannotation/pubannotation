// Loaded with defer only by segment_splits/edit, so the DOM is already parsed when this runs.
class SegmentSplits {
  constructor() {
    // The segments as split on this page so far; not saved yet.
    this.segments = JSON.parse(document.getElementById('split-segments').dataset.segments);
    // Where to split: the index of the segment and the character offset into its text.
    this.point = null;

    this.render();

    // Kept up to date while playing and seeking.
    for (const event of ['timeupdate', 'seeked', 'loadedmetadata']) {
      document.getElementById('media-player').addEventListener(event, () => this.showPlaybackTime());
    }

    document.getElementById('split-here').addEventListener('click', () => this.splitAtPoint());
  }

  // Splits the pointed segment at the playback time, or shows why it can't.
  splitAtPoint() {
    const error = this.splitSegment(this.point.index, this.point.offset, this.currentMs());
    if (error) return this.showError(error);

    this.point = null;
    this.render();
  }

  // Splits the segment at `index` into two at `offset` into its text and at `ms`, the earlier one ending and
  // the later one starting there, a line break after it following the later one. Returns why it can't be
  // split, if it can't.
  splitSegment(index, offset, ms) {
    const segment = this.segments[index];

    if (offset <= 0 || offset >= segment.text.length) {
      return 'Point inside the text, not at its start or end.';
    }
    if (ms <= segment.start_ms || ms >= segment.end_ms) {
      return `Play the media to between ${this.formatTime(segment.start_ms)} and ${this.formatTime(segment.end_ms)}.`;
    }

    this.segments.splice(index, 1,
      { ...segment, text: segment.text.slice(0, offset), end_ms: ms, line_break_after: false },
      { ...segment, text: segment.text.slice(offset), start_ms: ms });
  }

  render() {
    document.getElementById('split-segments').replaceChildren(...this.segments.map((segment, index) => this.segmentRow(segment, index)));
    this.showPoint();
    this.showError('');
  }

  // A segment's times and its text, which can be clicked to point where to split it.
  segmentRow(segment, index) {
    const time = this.element('span', 'split-segment-time');
    time.textContent = `${this.formatTime(segment.start_ms)} - ${this.formatTime(segment.end_ms)}`;

    const text = this.element('span', 'split-segment-text');
    // With a mark where it's pointed to be split, if it is.
    if (this.point?.index === index) {
      text.append(segment.text.slice(0, this.point.offset), this.element('span', 'split-mark'), segment.text.slice(this.point.offset));
    } else {
      text.textContent = segment.text;
    }
    text.addEventListener('click', () => this.pointAt(text, index));

    const row = this.element('div', 'split-segment');
    row.append(time, ' ', text);
    return row;
  }

  // Points where to split a segment: the character clicked in its text.
  pointAt(text, index) {
    const selection = document.getSelection();
    if (!selection.isCollapsed || !text.contains(selection.anchorNode)) return;

    this.point = { index, offset: this.offsetInText(text, selection.anchorNode, selection.anchorOffset) };
    this.render();
  }

  // Counted from the start of the segment's text, which a mark from an earlier click splits up.
  offsetInText(text, node, offset) {
    const range = document.createRange();
    range.setStart(text, 0);
    range.setEnd(node, offset);
    return range.toString().length;
  }

  // Where it's pointed to split, if it is, enabling Split here.
  showPoint() {
    document.getElementById('split-here').disabled = !this.point;
    document.getElementById('split-point').textContent = this.point
      ? `Segment #${this.point.index}, before character ${this.point.offset}`
      : "Click in a segment's text to point where to split it.";
  }

  // The playback time Split here would split at.
  showPlaybackTime() {
    const ms = this.currentMs();
    document.getElementById('playback-time').textContent = `${this.formatTime(ms)} (${ms} ms)`;
  }

  showError(message) {
    document.getElementById('split-error').textContent = message;
  }

  element(tagName, className) {
    const created = document.createElement(tagName);
    created.className = className;
    return created;
  }

  // The playback time in ms.
  currentMs() {
    return Math.round(document.getElementById('media-player').currentTime * 1000);
  }

  // Playback time in ms as "m:ss.mmm", as SegmentsHelper#segment_time formats it.
  formatTime(ms) {
    const total = Math.round(ms);
    const minutes = Math.floor(total / 60000);
    const seconds = Math.floor((total % 60000) / 1000);
    const millis = total % 1000;
    return `${minutes}:${String(seconds).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
  }
}

new SegmentSplits();
