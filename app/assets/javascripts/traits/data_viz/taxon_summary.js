window.TaxonSummaryViz = (function(exports) {
  const width = 800
      , height = 800
      , pad = 3
      , bgColor = '#fff' //'rgb(163, 245, 207)'
      , outerCircColor = 'rgb(185, 233, 240)'
      , innerCircColor = '#fff'
      , labelTspanOffset = 13
      ;

  let view;
  let root;
  let focus;
  let node;
  let label;
  let svg;
  let filterText

  function build($contain) {
    const $viz = $contain.find('.js-taxon-summary')
        , data = $viz.data('json')
        ;

    filterText = $viz.data('prompt');
    root = pack(data);
    focus = root;

    d3.select($viz[0])
      .style('width', `${width}px`)
      .style('height', `${height}px`)
      .style('position', 'relative')
      .style('margin', '0 auto')
      ;

    svg = d3.select($viz[0])
      .append('svg')
      .attr('viewBox', `-${width / 2} -${height / 2} ${width} ${height}`)
      .attr('width', width)
      .style('width', width)
      .attr('height', height)
      .style('height', height)
      .style('margin', '0 auto')
      .style('display', 'block')
      .style('background', bgColor)
      .style('cursor', 'pointer')
      .on('click', (e, d) => zoom(root))
      ;

    node = svg.append('g')
      .selectAll('circle')
      .data(root.descendants().slice(1))
      .join('circle')
        .attr('fill', d => d.children ? outerCircColor : innerCircColor)
        .on('click', handleNodeClick)
        ;

    label = svg.append('g')
      .style('font',  '12px sans-serif')
      .attr('fill', '#222')
      .attr('text-anchor', 'middle')
      .attr('pointer-events', 'none')
      .selectAll('text')
      .data(root.descendants().slice(1))
      .join('text')
        .attr('id', labelId)
        .style('fill-opacity', d => d.children ? 1 : 0)
        .style('mix-blend-mode', 'multiply')
        .style('display', labelDisplay)

    label.append('tspan')
      .attr('font-style', d => d.data.name.includes('<i>') ? 'italic' : null)
      .text(d => d.data.name.includes('<i>') ? d.data.name.replaceAll('<i>', '').replaceAll('</i>', '') : d.data.name);

    label.append('tspan')
      .attr('x', 0)
      .attr('dy', -labelTspanOffset)
      .text(d => `(${d.data.count})`);

    outerFilterPrompt = d3.select($viz[0])
      .append('button')
      .style('position', 'absolute')
      .style('top', '5px')
      .style('right', '5px')
      .style('text-anchor', 'end')
      .style('padding', '2px 4px')
      .style('font', 'bold 14px sans-serif')
      .style('display', 'none')
      .style('cursor', 'pointer');

    zoomTo([root.x, root.y, root.r * 2]);
  }
  exports.build = build;

  function pack(data) {
    return d3.pack()
        .size([width, height])
        .padding(pad)
      (d3.hierarchy(data)
        .sum(d => d.count)
        .sort((a, b) => b.count - a.count))
  }

  function zoom(d) {
    focus = d;

    if (focus !== root && focus.children) {
      outerFilterPrompt.html(focus.data.promptText);
      outerFilterPrompt.style('display', 'block');
      outerFilterPrompt.on('click', () => window.location = d.data.searchPath);
    } else {
      outerFilterPrompt.style('display', 'none');
    }

    const transition = svg.transition()
        .duration(750)
        .tween("zoom", d => {
          const i = d3.interpolateZoom(view, [focus.x, focus.y, focus.r * 2]);
          return t => zoomTo(i(t));
        });

    label
      .filter(function(d) { return d.parent === focus || this.style.display === "inline"; })
      .style('fill-opacity', d => d.parent === focus ? 1 : 0)
      .style('display', d => d.parent === focus ? 'inline' : 'none')
  }

  function zoomTo(v) {
    const k = width / v[2];

    view = v;

    label.attr("transform", (d) => nodeTransform(d, v, k));
    node.attr("transform", (d) => nodeTransform(d, v, k));
    node.attr("r", d => d.r * k);
    node
      .attr('pointer-events', d => d.parent && d.parent === focus ? null : 'none')
      .on('mouseover', handleNodeMouseover)
      .on('mouseout', handleNodeMouseout)
      ;
  }

  function handleNodeClick(e, d) {
    if (d !== focus) {
      if (d.children) {
        zoom(d); 
      } else {
        window.location = d.data.searchPath;
      }

      e.stopPropagation();
    }
  }

  function handleNodeMouseover(e, d) {
    d3.select(this).attr('stroke', '#000');

    if (!d.children) {
      label.style('fill-opacity', '.5');

      d3.select(`#${labelId(d)}`)
        .style('fill-opacity', 1)
        .style('font-weight', 'bold')
        .append('tspan')
          .attr('class', 'click-prompt')
          .attr('x', 0)
          .attr('dy', 2 * labelTspanOffset)
          .text('click to filter');
    }
  }

  function handleNodeMouseout(e, d) {
    d3.select(this).attr('stroke', null)

    if (!d.children) {
      label
        .style('fill-opacity', 1)
        .style('font-weight', 'normal');

      d3.select(`#${labelId(d)}`)
        .select('.click-prompt')
        .remove();
    }
  }

  function labelId(d) {
    return `label-${d.data.pageId}`;
  }

  function labelDisplay(d) {
    return d.parent === focus ? 'inline' : 'none';
  }

  function nodeTransform(d, v, k) {
    // layout is better with child nodes rotated 90 deg. about center of parent circle
    if (!d.children) {
      parentX = transformCoord(d.parent.x, v[0], k);
      parentY = transformCoord(d.parent.y, v[1], k);

      xNew = transformCoord(d.x, v[0], k);
      yNew = transformCoord(d.y, v[1], k);

      x = yNew - parentY + parentX;
      y = xNew - parentX + parentY;
    } else {
      x = transformCoord(d.x, v[0], k);
      y = transformCoord(d.y, v[1], k);
    }

    return `translate(${x},${y})`;
  } 

  function transformCoord(nVal, vVal, k) {
    return (nVal - vVal) * k; 
  }

  return exports;
})({});
