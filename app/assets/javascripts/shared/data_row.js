function bindMetaArrow($row) {
  $row.find('.js-meta-arw').click(function() {
    const $contain = $row.parent('.js-data-row-contain');

    if ($row.hasClass('js-data-row-closed')) {
      $row.addClass('is-hidden');
      $contain.find('.js-data-row-open').removeClass('is-hidden');
    } else {
      $row.addClass('is-hidden');
      $contain.find('.js-data-row-closed').removeClass('is-hidden');
    }
  });
}

function bindMetaArrowsToLoad() {
  $('.js-meta-arw').click(loadRow);
}

function loadRow() {
  const $arrow = $(this) 
      , $row = $arrow.parent('.js-data-row');
      ;

  $arrow.off('click');
  $arrow.removeClass('fa-angle-down');
  $arrow.addClass('fa-spin fa-spinner');
  bindMetaArrow($row);

  $.ajax({
    url: $row.data('showPath'),
    success: function(result) {
      var $result = $(result);
      bindMetaArrow($result);
      $row.addClass('is-hidden');
      $row.after($result);

      $arrow.addClass('fa-angle-down');
      $arrow.removeClass('fa-spin fa-spinner');
    }
  })
}

$(function() {
  bindMetaArrowsToLoad();
});
