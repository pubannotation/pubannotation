// Loaded with defer only by segment_splits/edit, so the DOM is already parsed when this runs.
(() => {
	const mediaPlayer = document.getElementById('media-player');
	const container = document.getElementById('split-segments');
	const splitPoint = document.getElementById('split-point');
	const splitHere = document.getElementById('split-here');
	const mergeWithNext = document.getElementById('merge-with-next');
	const splitError = document.getElementById('split-error');
	const playbackTime = document.getElementById('playback-time');

	// The segments as split on this page so far; not saved yet.
	const segments = JSON.parse(container.dataset.segments);
	// Where to split: the index of the segment and the character offset into its text.
	let point = null;

	render();

	// Shows the playback time Split here would split at, kept up to date while playing and seeking.
	for (const event of ['timeupdate', 'seeked', 'loadedmetadata']) {
		mediaPlayer.addEventListener(event, () => {
			const ms = Math.round(mediaPlayer.currentTime * 1000);
			playbackTime.textContent = `${formatTime(ms)} (${ms} ms)`;
		});
	}

	splitHere.addEventListener('click', () => {
		const segment = segments[point.index];
		const ms = Math.round(mediaPlayer.currentTime * 1000);

		// Spaces at the split go, as the segments' boundary stands for them.
		const before = segment.text.slice(0, point.offset).trimEnd();
		const after = segment.text.slice(point.offset).trimStart();

		if (before === '' || after === '') {
			return showError('Point inside the text, not at its start or end.');
		}
		if (ms <= segment.start_ms || ms >= segment.end_ms) {
			return showError(`Play the media to between ${formatTime(segment.start_ms)} and ${formatTime(segment.end_ms)}.`);
		}

		segments.splice(point.index, 1,
			{ ...segment, text: before, end_ms: ms },
			{ ...segment, text: after, start_ms: ms });
		point = null;
		render();
	});

	// Merges the selected segment with the next one: from its start to the next one's end, their texts
	// joined with a space, as a doc's body joins its segments.
	mergeWithNext.addEventListener('click', () => {
		const segment = segments[point.index];
		const next = segments[point.index + 1];

		segments.splice(point.index, 2,
			{ ...segment, text: `${segment.text} ${next.text}`, end_ms: next.end_ms });
		point = null;
		render();
	});

	// One row per segment: its times and its text, which can be clicked to point where to split it.
	function render() {
		container.replaceChildren(...segments.map((segment, index) => {
			const row = document.createElement('div');
			row.className = 'split-segment';

			const time = document.createElement('span');
			time.className = 'split-segment-time';
			time.textContent = `${formatTime(segment.start_ms)} - ${formatTime(segment.end_ms)}`;

			const text = document.createElement('span');
			text.className = 'split-segment-text';
			text.textContent = segment.text;
			text.addEventListener('click', () => pointAt(text, index));

			row.append(time, ' ', text);
			return row;
		}));

		splitHere.disabled = !point;
		mergeWithNext.disabled = true;
		splitPoint.textContent = "Click in a segment's text to point where to split it, or to select it to merge with the next one.";
		showError('');
	}

	// Points where to split a segment: the character clicked in its text.
	function pointAt(text, index) {
		const selection = document.getSelection();
		if (!selection.isCollapsed || !text.contains(selection.anchorNode)) return;

		// Counted from the start of the segment's text, which a mark from an earlier click splits up.
		const range = document.createRange();
		range.setStart(text, 0);
		range.setEnd(selection.anchorNode, selection.anchorOffset);
		const offset = range.toString().length;

		render();
		point = { index, offset };
		splitHere.disabled = false;
		mergeWithNext.disabled = index >= segments.length - 1;
		container.children[index].classList.add('selected');
		markPoint(container.children[index].querySelector('.split-segment-text'), offset);
		splitPoint.textContent = `Segment #${index}, before character ${offset}`;
	}

	// Shows the pointed position as a mark between the characters on either side of it.
	function markPoint(text, offset) {
		const characters = text.textContent;
		const mark = document.createElement('span');
		mark.className = 'split-mark';
		text.replaceChildren(characters.slice(0, offset), mark, characters.slice(offset));
	}

	function showError(message) {
		splitError.textContent = message;
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
