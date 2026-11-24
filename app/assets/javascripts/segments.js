// Loaded with defer only by segments/index, so the DOM is already parsed when this runs.
class SegmentDialog {
  constructor() {
    this.dialog = document.getElementById('segment-dialog');
    this.form = this.dialog.querySelector('form');
    this.textField = this.form.elements['segment[text]'];
    this.pieceFields = ['piece_begin', 'piece_end', 'piece_text'].map((name) => this.form.elements[`segment[${name}]`]);
    this.piecesTable = document.getElementById('segment-dialog-pieces');
    this.textArea = document.getElementById('segment-dialog-text');
    this.saveButton = document.getElementById('segment-dialog-save');

    for (const button of document.querySelectorAll('.edit-segment')) {
      button.addEventListener('click', () => this.openFor(button));
    }

    // Saves whether a line break follows a segment as soon as its checkbox is changed.
    for (const checkbox of document.querySelectorAll('.line-break-form input[type="checkbox"]')) {
      checkbox.addEventListener('change', () => checkbox.form.requestSubmit());
    }

    document.getElementById('segment-dialog-cancel').addEventListener('click', () => this.dialog.close());

    // A click outside the dialog lands on the dialog itself (its backdrop), since its content fills it.
    this.dialog.addEventListener('click', (event) => {
      if (event.target === this.dialog) this.dialog.close();
    });

    if (this.dialog.dataset.openOnLoad === 'true') this.reopen();
  }

  // Rendered open after a failed save: with the pieces of its segment, if any, and the piece being edited, if
  // that was a piece's edit, as the server filled its fields in.
  reopen() {
    const pieces = JSON.parse(this.dialog.dataset.pieces);
    if (pieces.length > 0) this.showPieces(pieces, !this.pieceFields[0].disabled);
    this.dialog.showModal();
  }

  // Fills the dialog in with the segment of the clicked Edit button and opens it, so Save updates that one: its
  // whole text, or, for one with denotations on it, a piece of it chosen from the table.
  openFor(button) {
    this.form.action = button.dataset.url;
    document.getElementById('segment-dialog-error').textContent = '';
    document.getElementById('segment-dialog-index').textContent = `#${button.dataset.index}`;
    document.getElementById('segment-dialog-time').textContent = button.dataset.time;

    const pieces = JSON.parse(button.dataset.pieces);
    this.setPieceFields(null);
    if (pieces.length > 0) {
      this.showPieces(pieces, false);
    } else {
      this.piecesTable.hidden = true;
      this.showTextField(button.dataset.text);
    }
    this.dialog.showModal();
  }

  // Lists the pieces, each with an Edit button choosing it, with the text field shown only once one is chosen
  // (or, if `editing`, already).
  showPieces(pieces, editing) {
    this.piecesTable.tBodies[0].replaceChildren(...pieces.map((piece) => this.pieceRow(piece)));
    this.piecesTable.hidden = false;
    this.textArea.hidden = !editing;
    this.saveButton.hidden = !editing;
  }

  pieceRow(piece) {
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
      this.setPieceFields(piece);
      this.showTextField(piece.text);
    });
    const action = document.createElement('td');
    action.append(edit);
    row.append(text, labels, action);
    return row;
  }

  // Sends the piece with Save, or, with none, the whole text: the piece's fields are disabled so they aren't sent.
  setPieceFields(piece) {
    const values = piece ? [piece.begin, piece.end, piece.text] : ['', '', ''];
    this.pieceFields.forEach((field, index) => {
      field.value = values[index];
      field.disabled = !piece;
    });
  }

  showTextField(text) {
    this.textField.value = text;
    this.textArea.hidden = false;
    this.saveButton.hidden = false;
    this.textField.focus();
  }
}

new SegmentDialog();
