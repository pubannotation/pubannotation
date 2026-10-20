// Loaded with defer only by segments/index, so the DOM is already parsed when this runs.
(() => {
	const dialog = document.getElementById('segment-dialog');

	for (const button of document.querySelectorAll('.edit-segment')) {
		button.addEventListener('click', () => openDialogFor(button));
	}

	document.getElementById('segment-dialog-cancel').addEventListener('click', () => dialog.close());

	// A click outside the dialog lands on the dialog itself (its backdrop), since its content fills it.
	dialog.addEventListener('click', (event) => {
		if (event.target === dialog) dialog.close();
	});

	if (dialog.dataset.openOnLoad === 'true') dialog.showModal();

	// Fills the dialog in with the segment of the clicked Edit button and opens it, so Save updates that one.
	function openDialogFor(button) {
		const form = dialog.querySelector('form');
		const error = document.getElementById('segment-dialog-error');
		const index = document.getElementById('segment-dialog-index');
		const time = document.getElementById('segment-dialog-time');
		const textArea = form.elements['segment[text]'];

		form.action = button.dataset.url;
		error.textContent = '';
		index.textContent = `#${button.dataset.index}`;
		time.textContent = button.dataset.time;
		textArea.value = button.dataset.text;
		dialog.showModal();
	}
})();
