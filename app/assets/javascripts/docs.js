// Loaded with defer only by docs/_content, so the DOM is already parsed when this runs.
(function() {
	$('#body').linkToSelectedSpan('#linkSpace');

	highlightCurrentSpeechSegment();
	focusHighlightedSpan();

	// Highlight the latest speech segment to have started, keeping it highlighted through the gap
	// until the next one starts, and clear it once playback ends.
	function highlightCurrentSpeechSegment() {
		const mediaPlayer = document.getElementById('media-player');
		const speechSegments = document.querySelectorAll('#body .speech-segment');
		if (!mediaPlayer || speechSegments.length === 0) return;

		let currentlyPlaying = null;

		function setCurrentlyPlaying(segment) {
			if (segment === currentlyPlaying) return;
			if (currentlyPlaying) currentlyPlaying.classList.remove('now-playing');
			if (segment) segment.classList.add('now-playing');
			currentlyPlaying = segment;
		}

		mediaPlayer.addEventListener('timeupdate', function() {
			const currentMs = mediaPlayer.currentTime * 1000;
			let active = null;

			// Segments are in chronological order, so the last one that has started is the current one.
			for (let i = 0; i < speechSegments.length; i++) {
				if (currentMs < Number(speechSegments[i].dataset.startMs)) break;
				active = speechSegments[i];
			}

			setCurrentlyPlaying(active);
		});

		mediaPlayer.addEventListener('ended', function() {
			setCurrentlyPlaying(null);
		});
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
