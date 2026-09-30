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
			let active = null;

			// Segments are in chronological order, so the last one that has started is the current one.
			for (const segment of speechSegments) {
				if (currentMs < Number(segment.dataset.startMs)) break;
				active = segment;
			}

			if (active) {
				setCurrentlyPlaying(active);
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
		const highlightedSpan = $('#body .highlight');
		if (highlightedSpan.length === 0) return;

		// Make the span focusable by adding tabindex
		highlightedSpan.attr('tabindex', '-1');
		// Scroll to the element
		highlightedSpan[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
		// Focus on the element
		highlightedSpan.focus();
	}
})();
