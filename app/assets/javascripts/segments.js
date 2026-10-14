// Loaded with defer only by segments/index, so the DOM is already parsed when this runs.
(() => {
	const dialog = document.getElementById('segment-dialog');
	const form = dialog.querySelector('form');
	const error = document.getElementById('segment-dialog-error');
	const time = document.getElementById('segment-dialog-time');
	const textArea = form.querySelector('textarea');

	// Fills the dialog in with the clicked segment, so Save updates that one.
	for (const button of document.querySelectorAll('.edit-segment')) {
		button.addEventListener('click', () => {
			form.action = button.dataset.url;
			error.textContent = '';
			time.textContent = button.dataset.time;
			textArea.value = button.dataset.text;
			dialog.showModal();
		});
	}

	document.getElementById('segment-dialog-cancel').addEventListener('click', () => dialog.close());

	// A click outside the dialog lands on the dialog itself (its backdrop), since its content fills it.
	dialog.addEventListener('click', (event) => {
		if (event.target === dialog) dialog.close();
	});

	if (dialog.dataset.openOnLoad === 'true') dialog.showModal();
})();
