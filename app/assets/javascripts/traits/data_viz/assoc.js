// Based on https://observablehq.com/@d3/hierarchical-edge-bundling
window.AssocViz = (function(exports) {
  function populateLinks(root) {
    const nodesById = new Map(root.leaves().map(d => [d.data.pageId, d]))

    root.leaves().forEach((l) => {
      const subjLinks = [];

      l.data.objPageIds.forEach((id) => {
        const o = nodesById.get(id)
            , link = { subj: l, obj: o }
            ;

        subjLinks.push(link);

        if (!o.objLinks) {
          o.objLinks = []
        }

        o.objLinks.push(link);
      });

      l.subjLinks = subjLinks;

      if (!l.objLinks) {
        l.objLinks = [];
      }
    });

    return root;
  }

  exports.build = function($container) {
    const radius = 350
        , width = 850
        , colorNone = '#ccc'
        , colorIn = '#4c2c92'
        , colorOut = '#2e8540'
        ;

    const data = $container.find('.js-assoc').data('json')
        , allowClicks = data.allowClicks
        , root = d3.cluster().size([2 * Math.PI, radius - 50])(populateLinks(d3.hierarchy(data.rootNode)))
              .sort((a, b) => d3.ascending(a.height, b.height) || d3.ascending(a.data.name, b.data.name))
        , links = root.leaves().flatMap(d => d.subjLinks)
        , line = d3.lineRadial()
            .curve(d3.curveBundle.beta(0.85))
            .radius(d => d.y)
            .angle(d => d.x)
        , svg = d3.select('.js-assoc')
          .append('svg')
            .style('max-width', width)
            .style('max-height', width)
            .style('display', 'block')
            .style('margin', '0 auto')
            .attr('viewBox', [-width / 2, -width / 2, width, width]) // coordinate (0, 0) is at center of svg viewBox

    const node = svg.append('g')
        .attr('font-family', 'sans-serif')
        .attr('font-size', 11)
      .selectAll('g')
      .data(root.leaves())
      .join('g')
        .attr('transform', d => `rotate(${d.x * 180 / Math.PI - 90}) translate(${d.y},0)`)
      .append('g')
        .attr('dy', '0.31em') // why?
        .attr('x', d => d.x < Math.PI ? 6 : -6)
        .attr('text-anchor', d => d.x < Math.PI ? 'start' : 'end')
        .attr('transform', d => d.x >= Math.PI ? 'rotate(180)' : null)
        .append('text')
          .style('cursor', d => isNodeClickable(d) ? 'pointer' : 'default')
          .attr('font-style', d => d.data.name.includes('<i>') ? 'italic' : null)
          .html(d => d.data.name.includes('<i>') ? d.data.name.replaceAll('<i>', '').replaceAll('</i>', '') : d.data.name)
          .each(function(d) { d.text = this; })
          .on('mouseover', handleTextMouseover)
          .on('mouseout', handleTextMouseout)
          .on('click', handleTextClick)
        ;

    ;

    const link = svg.append('g')
        .attr('stroke', '#ccc')
        .attr('fill', 'none')
      .selectAll('path')
      .data(links)
      .join('path')
        .style('mix-blend-mode', 'multiply')
        .attr('d', (d) => line(d.subj.path(d.obj)))
        .each(function(d) { d.path = this })
    ;

    function handleTextMouseover(event, d) {
      link.style('mix-blend-mode', null)
      d3.select(this).attr('font-weight', 'bold');
      d3.selectAll(d.objLinks.map(d => d.path)).attr('stroke', colorIn).raise();
      d3.selectAll(d.objLinks.map(d => d.subj.text)).attr('fill', colorIn).attr('font-weight', 'bold');
      d3.selectAll(d.subjLinks.map(d => d.path)).attr('stroke', colorOut).raise();
      d3.selectAll(d.subjLinks.map(d => d.obj.text)).attr('fill', colorOut).attr('font-weight', 'bold');
    }

    function handleTextMouseout(event, d) {
      link.style('mix-blend-mode', 'multiply');
      d3.select(this).attr('font-weight', null);
      d3.selectAll(d.objLinks.map(d => d.path)).attr('stroke', null);
      d3.selectAll(d.objLinks.map(d => d.subj.text)).attr('fill', null).attr('font-weight', null);
      d3.selectAll(d.subjLinks.map(d => d.path)).attr('stroke', null);
      d3.selectAll(d.subjLinks.map(d => d.obj.text)).attr('fill', null).attr('font-weight', null);
    }

    function handleTextClick(event, d) {
      if (isNodeClickable(d)) {
        window.location.href = d.data.searchPath;
      }
    }

    function isNodeClickable(d) {
      return allowClicks && !isNodePathCurPath(d);
    }

    function isNodePathCurPath(d) {
      return d.data.searchPath == (window.location.pathname + window.location.search);
    }
  }

  return exports;
})({});

