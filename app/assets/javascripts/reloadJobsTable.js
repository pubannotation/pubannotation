document.addEventListener('DOMContentLoaded', () => {
	if ($('.jobs-table')) {
		function getJobsTableData() {
			return $('.jobs-table').data('is-reload-necessary');
		}

		function reload() {
			let hasNotFinished = getJobsTableData();
			if (hasNotFinished) {
				$('.jobs-table-wrapper').load(`${location.pathname}/latest_jobs_table`);

				hasNotFinished = getJobsTableData();
				if (hasNotFinished) {
					setTimeout(reload, 3000);
				}
			}
		}

		reload();
	}
});
