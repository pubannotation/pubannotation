(() => {
	if (window.jobsTableReloadInstalled) return;
	window.jobsTableReloadInstalled = true;

	let timer;

	function scheduleReload() {
		clearTimeout(timer);
		const frame = document.getElementById('jobs_table');
		if (!frame || frame.querySelector('.jobs-table')?.dataset.isReloadNecessary !== 'true') return;

		timer = setTimeout(async () => {
			if (!frame.isConnected) return;
			try {
				if (frame.src) {
					await frame.reload();
				} else {
					frame.src = frame.dataset.refreshUrl;
					await frame.loaded;
				}
			} catch (error) {
				console.error("Could not reload jobs table", error);
			} finally {
				if (frame.isConnected) scheduleReload();
			}
		}, 3000);
	}

	document.addEventListener('turbo:load', scheduleReload);
	document.addEventListener('turbo:before-cache', () => clearTimeout(timer));
	document.addEventListener('DOMContentLoaded', scheduleReload);
	scheduleReload();
})();
