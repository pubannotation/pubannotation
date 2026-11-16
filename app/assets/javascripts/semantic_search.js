document.addEventListener('change', (event) => {
  if (!event.target.matches('.search-bar input[name="semantic"][type="checkbox"]')) return;

  const fallback = event.target.form.querySelector('#semantic_fallback');
  if (fallback) fallback.disabled = event.target.checked;
});
