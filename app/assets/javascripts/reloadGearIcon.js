document.addEventListener('DOMContentLoaded', () => {
	if ($('.gear-icon')) {
		function getGearIconData() {
			return $('.gear-icon').data('is-reload-necessary');
		}

		function reload() {
			let hasNotFinished = getGearIconData();
			if (hasNotFinished) {
				const separatedPath = location.pathname.split('/');
				$('.gear-icon-wrapper').load(`/${separatedPath[1]}/${separatedPath[2]}/jobs/latest_gear_icon`);

				hasNotFinished = getGearIconData();
				if (hasNotFinished) {
					setTimeout(reload, 3000);
				}
			}
		}

		reload();
	}
});
