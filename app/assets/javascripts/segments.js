// Loaded with defer only by segments/index, so the DOM is already parsed when this runs.
(() => {
  const dialog = document.getElementById('segment-dialog');
  const form = dialog.querySelector('form');
  const textField = form.elements['segment[text]'];
  const pieceFields = ['piece_begin', 'piece_end', 'piece_text'].map((name) => form.elements[`segment[${name}]`]);
  const piecesTable = document.getElementById('segment-dialog-pieces');
  const textArea = document.getElementById('segment-dialog-text');
  const saveButton = document.getElementById('segment-dialog-save');

  for (const button of document.querySelectorAll('.edit-segment')) {
    button.addEventListener('click', () => openDialogFor(button));
  }

  // Saves whether a line break follows a segment as soon as its checkbox is changed.
  for (const checkbox of document.querySelectorAll('.line-break-form input[type="checkbox"]')) {
    checkbox.addEventListener('change', () => checkbox.form.requestSubmit());
  }

  document.getElementById('segment-dialog-cancel').addEventListener('click', () => dialog.close());

  // A click outside the dialog lands on the dialog itself (its backdrop), since its content fills it.
  dialog.addEventListener('click', (event) => {
    if (event.target === dialog) dialog.close();
  });

  // Rendered open after a failed save: with the pieces of its segment, if any, and the piece being edited, if
  // that was a piece's edit, as the server filled its fields in.
  if (dialog.dataset.openOnLoad === 'true') {
    const pieces = JSON.parse(dialog.dataset.pieces);
    if (pieces.length > 0) showPieces(pieces, !pieceFields[0].disabled);
    dialog.showModal();
  }

  // Fills the dialog in with the segment of the clicked Edit button and opens it, so Save updates that one: its
  // whole text, or, for one with denotations on it, a piece of it chosen from the table.
  function openDialogFor(button) {
    form.action = button.dataset.url;
    document.getElementById('segment-dialog-error').textContent = '';
    document.getElementById('segment-dialog-index').textContent = `#${button.dataset.index}`;
    document.getElementById('segment-dialog-time').textContent = button.dataset.time;

    const pieces = JSON.parse(button.dataset.pieces);
    setPieceFields(null);
    if (pieces.length > 0) {
      showPieces(pieces, false);
    } else {
      piecesTable.hidden = true;
      showTextField(button.dataset.text);
    }
    dialog.showModal();
  }

  // Lists the pieces, each with an Edit button choosing it, with the text field shown only once one is chosen
  // (or, if `editing`, already).
  function showPieces(pieces, editing) {
    piecesTable.tBodies[0].replaceChildren(...pieces.map((piece) => pieceRow(piece)));
    piecesTable.hidden = false;
    textArea.hidden = !editing;
    saveButton.hidden = !editing;
  }

  function pieceRow(piece) {
    const row = document.createElement('tr');
    const text = document.createElement('td');
    text.textContent = piece.text;
    const labels = document.createElement('td');
    labels.textContent = piece.labels.length > 0 ? piece.labels.join(', ') : '-';
    const edit = document.createElement('button');
    edit.type = 'button';
    edit.className = 'button';
    edit.textContent = 'Edit';
    edit.addEventListener('click', () => {
      setPieceFields(piece);
      showTextField(piece.text);
    });
    const action = document.createElement('td');
    action.append(edit);
    row.append(text, labels, action);
    return row;
  }

  // Sends the piece with Save, or, with none, the whole text: the piece's fields are disabled so they aren't sent.
  function setPieceFields(piece) {
    const values = piece ? [piece.begin, piece.end, piece.text] : ['', '', ''];
    pieceFields.forEach((field, index) => {
      field.value = values[index];
      field.disabled = !piece;
    });
  }

  function showTextField(text) {
    textField.value = text;
    textArea.hidden = false;
    saveButton.hidden = false;
    textField.focus();
  }
})();
