// Loaded with defer only by segment_splits/edit, so the DOM is already parsed when this runs.
(() => {
	const container = document.getElementById('split-segments');

	const segments = JSON.parse(container.dataset.segments);

	render();

	// One row per segment: its times and its text.
	function render() {
		container.replaceChildren(...segments.map((segment) => {
			const row = document.createElement('div');
			row.className = 'split-segment';

			const time = document.createElement('span');
			time.className = 'split-segment-time';
			time.textContent = `${formatTime(segment.start_ms)} - ${formatTime(segment.end_ms)}`;

			const text = document.createElement('span');
			text.className = 'split-segment-text';
			text.textContent = segment.text;

			row.append(time, ' ', text);
			return row;
		}));
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
