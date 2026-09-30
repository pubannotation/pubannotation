// Loaded with defer only by docs/_content, so the DOM is already parsed when this runs.
(() => {
	$('#body').linkToSelectedSpan('#linkSpace');

	highlightCurrentSpeechSegment();
	focusHighlightedSpan();

	// Highlight the latest speech segment to have started, keeping it highlighted through the gap
	// until the next one starts, and clear it once playback ends.
	function highlightCurrentSpeechSegment() {
		const mediaPlayer = document.getElementById('media-player');
		const speechSegments = document.querySelectorAll('#body .speech-segment');
		if (!mediaPlayer || speechSegments.length === 0) return;

		mediaPlayer.addEventListener('timeupdate', () => {
			const currentMs = mediaPlayer.currentTime * 1000;
			let previousSegment = null;

			// Segments are in chronological order: once a segment hasn't started yet, the one before it is
			// the one playing (or the last one, once all have started; none, before the first one starts).
			for (const segment of speechSegments) {
				if (currentMs < Number(segment.dataset.startMs)) break;
				previousSegment = segment;
			}

			if (previousSegment) {
				setCurrentlyPlaying(previousSegment);
			} else {
				clearCurrentlyPlaying();
			}
		});

		mediaPlayer.addEventListener('ended', clearCurrentlyPlaying);

		function setCurrentlyPlaying(segment) {
			if (segment.classList.contains('now-playing')) return;

			clearCurrentlyPlaying();
			segment.classList.add('now-playing');
		}

		function clearCurrentlyPlaying() {
			document.querySelector('#body .now-playing')?.classList.remove('now-playing');
		}
	}

	// Scroll to and focus on the highlighted span
	function focusHighlightedSpan() {
		const highlightedSpan = document.querySelector('#body .highlight');
		if (!highlightedSpan) return;

		// Make the span focusable by adding tabindex
		highlightedSpan.setAttribute('tabindex', '-1');
		// Scroll to the element
		highlightedSpan.scrollIntoView({ behavior: 'smooth', block: 'center' });
		// Focus on the element, leaving the scrolling to scrollIntoView above
		highlightedSpan.focus({ preventScroll: true });
	}
})();
