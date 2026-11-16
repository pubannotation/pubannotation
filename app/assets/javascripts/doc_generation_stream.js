function reloadGenerationFrame(id) {
  const frame = document.getElementById(id);
  if (!frame) return;
  if (!frame.getAttribute('src') && frame.dataset.refreshUrl) {
    frame.src = frame.dataset.refreshUrl;
  } else {
    frame.reload();
  }
}

Turbo.StreamActions.reload_media_generation = function () {
  reloadGenerationFrame(this.target);
};

Turbo.StreamActions.reload_media_docs = function () {
  reloadGenerationFrame(this.target);
};

document.addEventListener('DOMContentLoaded', () => {
  const stream = document.querySelector('[data-doc-generation-stream]');
  if (!stream) return;

  // A broadcast can arrive before subscription, or while the connection is down.
  const synchronize = () => {
    if (stream.hasAttribute('connected')) {
      reloadGenerationFrame('doc_generation_status');
      reloadGenerationFrame('media_documents');
    }
  };
  new MutationObserver(synchronize).observe(stream, { attributes: true, attributeFilter: ['connected'] });
  synchronize();
});
