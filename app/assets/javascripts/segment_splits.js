// Loaded with defer only by segment_splits/edit, so the DOM is already parsed when this runs.
(() => {
	const container = document.getElementById('split-segments');
	const splitPoint = document.getElementById('split-point');

	const segments = JSON.parse(container.dataset.segments);
	// Where to split: the index of the segment and the character offset into its text.
	let point = null;

	render();

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

		splitPoint.textContent = "Click in a segment's text to point where to split it.";
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

	// Playback time in ms as "m:ss.mmm", as SegmentsHelper#segment_time formats it.
	function formatTime(ms) {
		const total = Math.round(ms);
		const minutes = Math.floor(total / 60000);
		const seconds = Math.floor((total % 60000) / 1000);
		const millis = total % 1000;
		return `${minutes}:${String(seconds).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
	}
})();
