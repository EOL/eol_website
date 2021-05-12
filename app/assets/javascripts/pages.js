//= require shared/data_row
//= require shared/slideshow
//= require trophic_web
//= require traits/data_viz

(function() {
  function setupMenus() {
    EOL.enableDropdowns();

    $('.js-menus a').on('ajax:success', function(e, data, status, xhr) {
      $('.js-content').replaceWith(data);
      setupMenus();
      bindLoadArrows(); // No-op for media, but needed for data
    });
  }

  function setupBreadcrumbs() {
    var $summary = $('.js-hier-summary')
      , $full = $('.js-hier-full')
      ;

    $('.js-show-full-hier').click(function() { 
      $summary.addClass('is-hidden');
      $full.removeClass('is-hidden');
    })

    $('.js-show-summary-hier').click(function() {
      $full.addClass('is-hidden');
      $summary.removeClass('is-hidden');
    })
  }

  function scrollToRecord() {
    var hashParams = EOL.parseHashParams();
    
    if ('trait_id' in hashParams) {
      var $row = $('.js-data-row[data-id="' + hashParams.trait_id + '"]')
        , $nav = $('.l-nav')
        , $tabs = $('.l-tabs')
        , $filters = $('.js-menus')
        ;

      if ($row.length) {
        setTimeout(function() {
          $(document).scrollTop($row.offset().top - $nav.height() - $tabs.height() - $filters.height());
          $row.find('.js-meta-arw').click();
        }, 1000);
      }
    }
  }

  function setupNames() {
    $('.js-name-card-open').click(function() {
      $(this)
        .closest('.js-name-card-body')
        .find('.js-name-card-item')
        .removeClass('uk-hidden');
      $(this).addClass('uk-hidden');
      $(this).siblings('.js-name-card-close').removeClass('uk-hidden');
      updateGridLayout($(this).closest('.js-name-vern-grid'))
    });

    $('.js-name-card-close').click(function() {
      $(this)
        .closest('.js-name-card-body')
        .find('.js-name-card-item[data-hide-on-close]')
        .addClass('uk-hidden');
      $(this).addClass('uk-hidden');
      $(this).siblings('.js-name-card-open').removeClass('uk-hidden');
      updateGridLayout($(this).closest('.js-name-vern-grid'))
    });

    $('.js-name-more-vern').click(function() {
      $('.js-name-card-vern').removeClass('uk-hidden');
      $(this).addClass('uk-hidden');
      $(this).siblings('.js-name-less-vern').removeClass('uk-hidden');
      updateGridLayout($('.js-name-vern-grid'));
    });

    $('.js-name-less-vern').click(function() {
      $('.js-name-card-vern[data-hide]').addClass('uk-hidden');
      $(this).addClass('uk-hidden');
      $(this).siblings('.js-name-more-vern').removeClass('uk-hidden');
      updateGridLayout($('.js-name-vern-grid'));
    });
  }
  
  function updateGridLayout($grid) {
    if ($grid.length) {
      UIkit.grid($grid).$emit(); 
    }
  }
    

  $(function() {
    setupMenus();
    setupBreadcrumbs();
    setupNames();
    scrollToRecord();
  });
})();
