// Loaded with defer only by segment_splits/edit, so the DOM is already parsed when this runs.
class SegmentSplits {
  constructor() {
    // The segments as split on this page so far; saved all at once by Save, replacing them all.
    this.segments = JSON.parse(document.getElementById('split-segments').dataset.segments);
    // Whether any is split but not saved yet.
    this.unsaved = false;
    // Where to split: the index of the segment and the character offset into its text.
    this.point = null;

    this.render();

    // Kept up to date while playing and seeking.
    for (const event of ['timeupdate', 'seeked', 'loadedmetadata']) {
      document.getElementById('media-player').addEventListener(event, () => this.showPlaybackTime());
    }

    document.getElementById('split-here').addEventListener('click', () => this.splitAtPoint());
    document.getElementById('merge-with-next').addEventListener('click', () => this.mergeWithNext());
    document.getElementById('split-form').addEventListener('submit', () => this.save());
    // Asks before leaving with splits unsaved, unless leaving by Save.
    window.addEventListener('beforeunload', (event) => {
      if (this.unsaved) event.preventDefault();
    });
  }

  // Puts the segments as split into the form Save submits, and leaves without asking.
  save() {
    document.getElementById('segment_split_segments').value = JSON.stringify(
      this.segments.map(({ text, start_ms, end_ms, line_break_after }) => ({ text, start_ms, end_ms, line_break_after })));
    this.unsaved = false;
  }

  // Splits the pointed segment at the playback time, or shows why it can't.
  splitAtPoint() {
    const error = this.splitSegment(this.point.index, this.point.offset, this.currentMs());
    if (error) return this.showError(error);

    this.point = null;
    this.unsaved = true;
    this.render();
  }

  // Splits the segment at `index` into two at `offset` into its text and at `ms`, the earlier one ending and
  // the later one starting there, a line break after it following the later one. The spaces at the split go,
  // as the segments' boundary stands for them. Returns why it can't be split, if it can't.
  splitSegment(index, offset, ms) {
    const segment = this.segments[index];
    const before = segment.text.slice(0, offset).trimEnd();
    const after = segment.text.slice(offset).trimStart();

    if (before === '' || after === '') {
      return 'Point inside the text, not at its start or end.';
    }
    if (ms <= segment.start_ms || ms >= segment.end_ms) {
      return `Play the media to between ${this.formatTime(segment.start_ms)} and ${this.formatTime(segment.end_ms)}.`;
    }

    this.segments.splice(index, 1,
      { ...segment, text: before, end_ms: ms, line_break_after: false },
      { ...segment, text: after, start_ms: ms });
  }

  // Merges the pointed segment with the next one.
  mergeWithNext() {
    this.mergeSegments(this.point.index);
    this.point = null;
    this.unsaved = true;
    this.render();
  }

  // Merges the segment at `index` with the next one: from its start to the next one's end, their texts joined
  // with a space, as a doc's body joins its segments, and with the line break, if any, after the next one.
  mergeSegments(index) {
    const segment = this.segments[index];
    const next = this.segments[index + 1];

    this.segments.splice(index, 2,
      { ...segment, text: `${segment.text} ${next.text}`, end_ms: next.end_ms, line_break_after: next.line_break_after });
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
    // Selected when pointed in, to be split or merged with the next one.
    row.classList.toggle('selected', this.point?.index === index);
    row.append(time, ' ', text);
    // A blank one has no text to click in, so it's selected by a button instead, to be merged with the next one.
    if (segment.text.trim() === '') {
      const select = this.element('button', 'button');
      select.type = 'button';
      select.textContent = 'Select blank segment';
      select.addEventListener('click', () => {
        this.point = { index, offset: 0 };
        this.render();
      });
      row.append(' ', select);
    }
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

  // Where it's pointed to split, if it is, enabling Split here, and Merge with next unless it's the last one.
  showPoint() {
    document.getElementById('split-here').disabled = !this.point;
    document.getElementById('merge-with-next').disabled = !this.point || this.point.index >= this.segments.length - 1;
    document.getElementById('save-splits').disabled = !this.unsaved;
    document.getElementById('split-point').textContent = this.point
      ? `Segment #${this.point.index}, before character ${this.point.offset}`
      : "Click in a segment's text to point where to split it, or to select it to merge with the next one.";
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
