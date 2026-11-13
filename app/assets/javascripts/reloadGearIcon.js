document.addEventListener('DOMContentLoaded', () => {
	const wrapper = $('.gear-icon-wrapper');
	if (!wrapper.length) return;

	let unfinishedIds = $('.gear-icon').data('unfinished-job-ids') || [];
	let completedSuccessfully = false;

	function reload() {
		if (!$('.gear-icon').data('is-reload-necessary')) return;

		const separatedPath = location.pathname.split('/');
		wrapper.load(`/${separatedPath[1]}/${separatedPath[2]}/jobs/latest_gear_icon`, function (_response, status) {
			if (status === 'error') {
				setTimeout(reload, 3000);
				return;
			}

			const icon = $('.gear-icon');
			const succeededIds = icon.data('succeeded-job-ids') || [];
			completedSuccessfully ||= unfinishedIds.some(id => succeededIds.includes(id));
			unfinishedIds = icon.data('unfinished-job-ids') || [];

			if (icon.data('is-reload-necessary')) {
				setTimeout(reload, 3000);
			} else if (completedSuccessfully && $('.project-docs-list').length) {
				$('.project-docs-list').load(`${location.href} .project-docs-list > *`);
			}
		});
	}

	reload();
});
