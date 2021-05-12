//= require traits/data_viz/sankey
//= require traits/data_viz/assoc
//= require traits/data_viz/taxon_summary
window.TraitDataViz = (function(exports) {
  const BAR_COLORS = ['#b3d7ff', '#e6f2ff'];

  const typesToFns = {
    bar: buildBarChart,
    hist: buildHistogram,
    sankey: Sankey.build,
    assoc: AssocViz.build,
    taxon_summary: TaxonSummaryViz.build
  }

  function buildBarChart($contain) {
    var $elmt = $contain.find('.js-taxon-bar-chart')
      , width = 750
      , hPad = 5
      , innerWidth = width - (hPad * 2)
      , barHeight = 20
      , barSpace = 8
      , labelY = 15 
      , labelX = 10
      , keyHeight = 40
      , data = $elmt.data('results')
      , maxCount = data.reduce((curMax, d) => {
          return Math.max(d.count, curMax) 
        }, 0)
      , remainder = maxCount % 10
      , height = data.length * (barHeight + barSpace) - barSpace + keyHeight
      , barColors = BAR_COLORS
      ;

    if (remainder > 0) {
      maxCount += (10 - remainder);
    }

    data.forEach((d) => {
      pctWidth = (d.count / maxCount);
      d.width =  pctWidth * innerWidth;
      d.label = pctWidth <= .25 || pctWidth >= .75 ?
        d.label_long :
        d.label_short;
      d.prompt_text = pctWidth <= .25 || pctWidth >= .75 ?
        d.prompt_long :
        d.prompt_short;
    });

    var svg = d3.select($elmt[0])
          .append('svg')
            .attr('width', width)
            .attr('height', height)
            .style('width', width)
            .style('height', height)
            .style('display', 'block')
            .style('margin', '0 auto');

    var gKey = svg.append('g')
    buildTick(gKey, 'start', 0);
    buildTick(gKey, 'middle', maxCount / 2);
    buildTick(gKey, 'end', maxCount);

    var gBar = svg.append('g')
      .attr('transform', `translate(${hPad}, ${keyHeight})`);


    var barsEnter = gBar
      .selectAll('.bar')
      .data(data)
      .enter()
      .append('g')
      .attr('class', 'bar')
      .attr('transform', (d, i) => `translate(0, ${i * (barHeight + barSpace)})`)
      .style('cursor', (d) => d.search_path ? 'pointer' : 'default')
      .on('mouseenter', (e, d) => {
        d3.select(e.target).select('text').text(d.prompt_text); 
      })
      .on('mouseleave', (e, d) => {
        d3.select(e.target).select('text').text(d.label);
      })
      .on('click', (e, d) => { 
        if (d.search_path) {
          window.location = d.search_path;
        }
      });


    barsEnter
      .append('rect')
      .attr('width', d => d.width)
      .attr('height', barHeight)
      .attr('fill', (d, i) => barColors[i % barColors.length])
    barsEnter
      .append('text')
      .text(d => d.label)
      .style('line-height', barHeight)
      .attr('x', (d) => { 
        if (widthGtHalf(d)) {
          return d.width - labelX;
        } else {
          return d.width + labelX;
        }
      })
      .attr('text-anchor', (d) => {
        if (widthGtHalf(d)) {
          return 'end';
        } else {
          return 'start';
        }
      })
      .attr('y', labelY)

    function widthGtHalf(d) {
      return d.count > maxCount / 2;
    }

    function buildTick(group, textAnchor, number) {
      var x = (number / maxCount) * innerWidth + hPad
        , textX = 0
        , gTick = group.append('g')
            .attr('transform', `translate(${x}, 0)`)
        ;

      if (textAnchor == 'start') {
        textX = -3;
      } else if (textAnchor == 'end') {
        textX = 3;
      }

      gTick.append('text')
        .text(number)
        .attr('x', textX)
        .attr('y', 12)
        .attr('text-anchor', textAnchor)

      gTick.append('line')
        .attr('stroke', 'black')
        .style('stroke-width', '1px')
        .attr('x1', 0)
        .attr('x2', 0)
        .attr('y1', 15)
        .attr('y2', 30);
    }
  }

  function buildHistogram($contain) {
    var $elmt = $contain.find('.js-value-hist')
      , data = $elmt.data('json')
      , width = 850 
      , height = 530
      , barWidth = 35
      , xAxisY = height - 60 
      , xAxisWidth = (data.buckets.length) * barWidth
      , xAxisX1 = (width - xAxisWidth) / 2 // Y axis needs some room
      , xTicks // populated below
      , yLineHeight = 400
      , tickLength = 8
      , tickTextOffsetX = 25 
      , tickTextOffsetY = -16
      , xAxisLabelOffset = 50 
      , yAxisLabelOffset = -40 
      , yAxisOffsetVert = 20
      , yAxisOffsetHoriz = 20
      , numYTicks = data.maxCount < 10 ? data.maxCount + 1 : 10
      , yTickIncr = Math.ceil(data.maxCount / (numYTicks - 1))
      , yTicks = new Array(numYTicks)
          .fill(null)
          .map((_, i) => i * yTickIncr)
      , yTickDist = yLineHeight / (numYTicks - 1)
      , promptY = 20
      , labelAllTicksCharLimit = 5
      ;

    xTicks = data.buckets.map(b => b.min)
    xTicks.push(data.buckets[data.buckets.length - 1].limit)

    var svg = d3.select('.js-value-hist')
          .append('svg')
          .attr('width', width)
          .attr('height', 400)
          .style('width', width)
          .style('height', height)
          .style('margin', '0 auto')
          .style('display', 'block');

    // x axis
    var gX = svg.append('g')
      .attr('transform', `translate(${xAxisX1}, ${xAxisY})`);

    buildAxis(
      gX, 
      xAxisWidth, 
      data.valueLabel,
      xAxisLabelOffset,
      xTicks,
      barWidth,
      tickLength,
      tickTextOffsetX
    );

    // y axis
    var gY = svg.append('g')
      .attr('transform', `translate(${xAxisX1 - yAxisOffsetHoriz}, ${xAxisY - yAxisOffsetVert}) rotate(270, 0, 0)`)

    buildAxis(
      gY,
      yLineHeight,
      data.yAxisLabel,
      yAxisLabelOffset,
      yTicks,
      yTickDist,
      -1 * tickLength,
      tickTextOffsetY
    );

    // bars
    var bar = svg.append('g')
      .attr('transform', `translate(${xAxisX1}, ${xAxisY - yAxisOffsetVert})`)
      .selectAll('bar')
        .data(data.buckets)
        .enter() 
        .append('g')
          .attr('stroke', 'black')
          .attr('stroke-width', 1)
          .attr('transform', (_, i) => `translate(${i * barWidth}, 0)`)
          .style('cursor', 'pointer')
          .on('click', (e, d) => window.location = d.queryPath)
        
    bar.append('rect')
      .attr('x', 0)
      .attr('y', (d) => -1 * d.count * yTickDist / yTickIncr )
      .attr('width', barWidth)
      .attr('height', (d) => d.count * yTickDist / yTickIncr)
      .attr('stroke', '#4287f5')
      .attr('fill', (_, i) => BAR_COLORS[i % BAR_COLORS.length])

    var prompt = svg.append('text')
      .attr('y', promptY)
      .attr('x', width / 2)
      .attr('text-anchor', 'middle');

    bar.on('mouseenter', (e, d) => prompt.text(d.promptText));
    bar.on('mouseleave', (e, d) => prompt.text(''));

    function buildAxis(g, width, axisLabelText, axisLabelY, ticks, tickDist, tickLength, tickLabelY) { 
      g.append('line')
        .attr('stroke', 'black')
        .attr('stroke-width', 1)
        .attr('x1', 0)
        .attr('x2', width)
        .attr('y1', 0)
        .attr('y2', 0);

      // todo: i18n
      g.append('text')
        .attr('x', width / 2)
        .attr('y', axisLabelY)
        .attr('text-anchor', 'middle')
        .attr('font-size', 15)
        .text(axisLabelText)

      var gTick = g.selectAll('.tick')
        .data(ticks)
        .enter()
        .append('g')
          .attr('class', 'tick')
          .attr('transform', (d, i) => `translate(${tickDist * i}, 0)`);

      gTick
        .append('line')
          .attr('x1', 0)
          .attr('x2', 0)
          .attr('y1', 0)
          .attr('y2', tickLength)
          .attr('stroke', 'black')
          .attr('stroke-width', 1);

      gTick
        .append('text')
        .attr('text-anchor', 'middle')
        .attr('y', tickLabelY)
        .text((d, i) => tickLabel(i, d, ticks));
    }

    function tickLabel(i, label, ticks) {
      if (
        label.toString().length < labelAllTicksCharLimit ||
        (
          i === 0 ||
          i === ticks.length - 1 ||
          (
            i !== 1 && 
            i !== ticks.length - 2 &&
            i % 2 === 0
          )
        )
      ) {
        return label;
      } else {
        return null;
      }
    }
  }

  function loadViz($contain, loadFallbackIfPresent) {
    function replaceWithFallback(jqXHR, textStatus) {
      if (textStatus == 'nocontent') {
        const $fallbackContain = $('.js-fallback-viz-contain');

        if ($fallbackContain.length) {
          $contain.replaceWith($fallbackContain); 
          $fallbackContain.removeClass('uk-hidden');
          loadViz($fallbackContain, false);
        }
      }
    }

    const success = loadFallbackIfPresent ? loadFallbackViz : null
        , complete = loadFallbackIfPresent ? replaceWithFallback : null
        ;

    function error(jqXHR, textStatus, errorThrown) {
      $contain.empty();
    }

    loadVizHelper($contain, success, error, complete);
  }

  function loadFallbackViz($contain) {
    const $parent = $contain.closest('.js-viz-with-fallback')
        ;

    if ($parent.length) {
      const $fallbackContain = $parent.find('.js-fallback-viz-contain')
          , $toggle = $parent.find('.js-viz-toggle')
          , $toggleSpinner = $toggle.find('.js-viz-toggle-spin')
          ;

      function success() {
        $toggleSpinner.remove();
        $toggleLink = $toggle.find('.js-viz-toggle-link');
        $toggleLink.html($fallbackContain.data('toggleText')); 
        $toggleLink.click(toggleViz);
      }

      function error() {
        $toggle.remove();
        $fallbackContain.remove();
      }

      if ($fallbackContain.length) {
        $toggleSpinner.show();
        $contain.addClass('js-viz-cur');
        $fallbackContain.addClass('js-viz-alt');
        loadVizHelper($fallbackContain, success, error, null);
      }
    }
  }

  function toggleViz() {
    const $this = $(this)
        , $parent = $this.closest('.js-viz-with-fallback')
        , $cur = $parent.find('.js-viz-cur')
        , $alt = $parent.find('.js-viz-alt')
        ;

    $this.html($cur.data('toggleText'));
    $cur.addClass('uk-hidden');
    $cur.removeClass('js-viz-cur');
    $cur.addClass('js-viz-alt');
    $alt.removeClass('uk-hidden');
    $alt.removeClass('js-viz-alt');
    $alt.addClass('js-viz-cur');
  }


  function loadVizHelper($contain, success, error, complete) {
    const ready = typesToFns[$contain.data('type')];

    $.ajax($contain.data('loadPath'), {
      success: (result) => {
        $contain.find('.js-viz-spinner').remove();

        if (result) {
          $contain.append(result);
          $contain.find('.js-viz-text').removeClass('uk-hidden');
          ready($contain);
          
          if (success) {
            success($contain);
          }
        }
      },
      error: error,
      complete: complete
    });
  }

  function loadAll() {
    const $contain = $('.js-viz-contain');

    $contain.each(function() {
      const $this = $(this);

      if (!$this.hasClass('js-fallback-viz-contain')) {
        loadViz($this, true);
      }
    });
  }

  exports.loadAll = loadAll;

  return exports;
})({});

$(TraitDataViz.loadAll);

