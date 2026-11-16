Turbo.StreamActions.reload_media_generation = function () {
  document.getElementById(this.target)?.reload();
};

document.addEventListener('DOMContentLoaded', () => {
  const stream = document.querySelector('[data-doc-generation-stream]');
  if (!stream) return;

  // A broadcast can arrive before subscription, or while the connection is down.
  const synchronize = () => {
    if (stream.hasAttribute('connected')) {
      document.getElementById('doc_generation_status')?.reload();
    }
  };
  new MutationObserver(synchronize).observe(stream, { attributes: true, attributeFilter: ['connected'] });
  synchronize();
});
