// Loaded with defer only by segment_splits/edit, so the DOM is already parsed when this runs.
(() => {
	// The segments as split on this page so far; not saved yet.
	const segments = JSON.parse(document.getElementById('split-segments').dataset.segments);
	// Where to split: the index of the segment and the character offset into its text.
	let point = null;

	render();

	// Kept up to date while playing and seeking.
	for (const event of ['timeupdate', 'seeked', 'loadedmetadata']) {
		document.getElementById('media-player').addEventListener(event, showPlaybackTime);
	}

	document.getElementById('split-here').addEventListener('click', splitAtPoint);

	// Splits the pointed segment at the playback time, or shows why it can't.
	function splitAtPoint() {
		const error = splitSegment(point.index, point.offset, currentMs());
		if (error) return showError(error);

		point = null;
		render();
	}

	// Splits the segment at `index` into two at `offset` into its text and at `ms`, the earlier one ending and
	// the later one starting there. Returns why it can't be split, if it can't.
	function splitSegment(index, offset, ms) {
		const segment = segments[index];

		if (offset <= 0 || offset >= segment.text.length) {
			return 'Point inside the text, not at its start or end.';
		}
		if (ms <= segment.start_ms || ms >= segment.end_ms) {
			return `Play the media to between ${formatTime(segment.start_ms)} and ${formatTime(segment.end_ms)}.`;
		}

		segments.splice(index, 1,
			{ ...segment, text: segment.text.slice(0, offset), end_ms: ms },
			{ ...segment, text: segment.text.slice(offset), start_ms: ms });
	}

	function render() {
		document.getElementById('split-segments').replaceChildren(...segments.map(segmentRow));
		showPoint();
		showError('');
	}

	// A segment's times and its text, which can be clicked to point where to split it.
	function segmentRow(segment, index) {
		const time = element('span', 'split-segment-time');
		time.textContent = `${formatTime(segment.start_ms)} - ${formatTime(segment.end_ms)}`;

		const text = element('span', 'split-segment-text');
		// With a mark where it's pointed to be split, if it is.
		if (point?.index === index) {
			text.append(segment.text.slice(0, point.offset), element('span', 'split-mark'), segment.text.slice(point.offset));
		} else {
			text.textContent = segment.text;
		}
		text.addEventListener('click', () => pointAt(text, index));

		const row = element('div', 'split-segment');
		row.append(time, ' ', text);
		return row;
	}

	// Points where to split a segment: the character clicked in its text.
	function pointAt(text, index) {
		const selection = document.getSelection();
		if (!selection.isCollapsed || !text.contains(selection.anchorNode)) return;

		point = { index, offset: offsetInText(text, selection.anchorNode, selection.anchorOffset) };
		render();
	}

	// Counted from the start of the segment's text, which a mark from an earlier click splits up.
	function offsetInText(text, node, offset) {
		const range = document.createRange();
		range.setStart(text, 0);
		range.setEnd(node, offset);
		return range.toString().length;
	}

	// Where it's pointed to split, if it is, enabling Split here.
	function showPoint() {
		document.getElementById('split-here').disabled = !point;
		document.getElementById('split-point').textContent = point
			? `Segment #${point.index}, before character ${point.offset}`
			: "Click in a segment's text to point where to split it.";
	}

	// The playback time Split here would split at.
	function showPlaybackTime() {
		const ms = currentMs();
		document.getElementById('playback-time').textContent = `${formatTime(ms)} (${ms} ms)`;
	}

	function showError(message) {
		document.getElementById('split-error').textContent = message;
	}

	function element(tagName, className) {
		const created = document.createElement(tagName);
		created.className = className;
		return created;
	}

	// The playback time in ms.
	function currentMs() {
		return Math.round(document.getElementById('media-player').currentTime * 1000);
	}

	// Playback time in ms as "m:ss.mmm", as SegmentsHelper#segment_time formats it.
	function formatTime(ms) {
		const total = Math.round(ms);
		const minutes = Math.floor(total / 60000);
		const seconds = Math.floor((total % 60000) / 1000);
		const millis = total % 1000;
		return `${minutes}:${String(seconds).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
	}
})();
