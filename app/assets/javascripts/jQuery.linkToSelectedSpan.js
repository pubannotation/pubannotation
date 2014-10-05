(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
(function($) {
  var toLength = function(node) {
      return node.nodeName === "#text" ? node.length :
        node.nodeName === "BR" ? 1 :
        0;
    },
    getPrevNodesOffset = function(node) {
      var pos = 0,
        brotherNodes = node.parentElement.childNodes;
      for (var i = 0; brotherNodes[i] !== node; i++) {
        pos += toLength(brotherNodes[i]);
      }
      return pos;
    },
    getPosition = function(selection, name) {
      return getPrevNodesOffset(selection[name + 'Node']) +
        selection[name + 'Offset'];
    },
    toBeginEnd = function(apos, fpos) {
      return {
        begin: apos < fpos ? apos : fpos,
        end: apos < fpos ? fpos : apos
      };
    },
    getSelectedPosition = function(selection) {
      var apos = getPosition(selection, 'anchor'),
        fpos = getPosition(selection, 'focus');

      return toBeginEnd(apos, fpos);
    },
    toSelectString = function(select) {
      return select.begin + '-' + select.end;
    },
    triggerSelect = function(event) {
      var selection = window.getSelection();

      if (selection.isCollapsed) return;
      if (selection.anchorNode.nodeName !== '#text') return;
      if (selection.focusNode.nodeName !== '#text') return;

      $(event.target)
        .trigger('select', toSelectString(getSelectedPosition(selection)));
    },
    createLinkSpaceContent = function($target) {
      return $target
        .append(
          $('<span>')
          .addClass('range')
        )
        .append(
          $('<a>')
          .addClass('link')
        );
    },
    updateLinkSpaceContent = function($target, select, url) {
      return $target.find('.range')
        .text(select)
        .end()
        .find('.link')
        .text('<' + url + '>')
        .attr('href', url);
    },
    Selected = function($linkSpace) {
      return function(event, select) {
        var url = require('./pathJoin')(location.href, 'spans/' + select);
        updateLinkSpaceContent($linkSpace, select, url);
      };
    },
    bindEvent = function($target, $linkSpace) {
      $target
        .on('click', triggerSelect)
        .on('select', new Selected($linkSpace));
    },
    linkToSelectedSpan = function(selector) {
      var $linkSpace = $(selector);
      if ($linkSpace.length === 0) {
        console.warn('no element is found. selector: ', selector);
        return;
      }

      createLinkSpaceContent($linkSpace);
      bindEvent(this, $linkSpace);

      console.log('start to observe element.');
      return this;
    },
    main = function() {
      $.fn.linkToSelectedSpan = linkToSelectedSpan;
    };

  main();
})(jQuery);

},{"./pathJoin":2}],2:[function(require,module,exports){
module.exports = function(path, lowPath) {
  path = path.substr(-1) === '/' ? path : path + '/';
  return path + lowPath;
};

},{}]},{},[1]);
