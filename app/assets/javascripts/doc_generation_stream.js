function reloadGenerationFrame(id) {
  const frame = document.getElementById(id);
  if (!frame) return;
  if (!frame.getAttribute('src') && frame.dataset.refreshUrl) {
    frame.src = frame.dataset.refreshUrl;
  } else {
    frame.reload();
  }
}

let documentRefreshTimers = [];

function refreshDocuments(id) {
  documentRefreshTimers.forEach(clearTimeout);
  documentRefreshTimers = [];
  reloadGenerationFrame(id);

  const frame = document.getElementById(id);
  if (!frame?.dataset.refreshUrl) return;
  const url = new URL(frame.dataset.refreshUrl, window.location.href);
  if (!url.searchParams.get('keywords')?.trim()) return;

  // Elasticsearch indexes document text and project membership asynchronously.
  documentRefreshTimers = [2000, 5000, 10000].map(delay =>
    setTimeout(() => reloadGenerationFrame(id), delay)
  );
}

Turbo.StreamActions.reload_media_generation = function () {
  reloadGenerationFrame(this.target);
};

Turbo.StreamActions.reload_media_docs = function () {
  refreshDocuments(this.target);
};

document.addEventListener('DOMContentLoaded', () => {
  const stream = document.querySelector('[data-doc-generation-stream]');
  if (!stream) return;

  // A broadcast can arrive before subscription, or while the connection is down.
  const synchronize = () => {
    if (stream.hasAttribute('connected')) {
      reloadGenerationFrame('doc_generation_status');
      refreshDocuments('media_documents');
    }
  };
  new MutationObserver(synchronize).observe(stream, { attributes: true, attributeFilter: ['connected'] });
  synchronize();
});
