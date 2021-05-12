// copied from/based on https://observablehq.com/@d3/parallel-sets"
window.Sankey = (function(exports) {
  exports.build = function($contain) {
    const width = 850
        , fullHeight = 520
        , shortHeight = fullHeight / 2
        , shortHeightCutoffNodes = 3
        ;

    var highlightLinks = [];

    $data = $contain.find('.js-sankey')
    const graph = {
        nodes: $data.data('nodes'),
        links: $data.data('links')
      }
    , numAxes = $data.data('axes')
    , maxAxisNodes = $data.data('maxAxisNodes')
    , height = maxAxisNodes > shortHeightCutoffNodes ? fullHeight : shortHeight
    ;

    const sankey = d3.sankey()
      .nodeWidth(15)
      .nodePadding(25)
      .extent([[0, 5], [width, height - 20]])
      .nodeId((d) => d.id);

    const svg = d3.select(".js-sankey")
      .append("svg")
      .attr("width", width)
      .style("width", width)
      .attr("height", height)
      .style("height", height)
      .style("margin", "0 auto")
      .style("display", "block")

    const {nodes, links} = sankey({
      nodes: graph.nodes.map(d => Object.assign({}, d)),
      links: graph.links.map(d => Object.assign({}, d))
    });

    const linkDataFn = d3.linkHorizontal()
      .source((d) => [d.source.x1, Math.min(d.source.y1 - (d.width / 2.0), d.y0)])
      .target((d) => [d.target.x0, Math.min(d.target.y1 - (d.width / 2.0), d.y1)]);

    var selectedNodes = {};

    const linkG = svg.append("g")
            .attr("fill", "none")
        , highlightLinkG = svg.append("g")
            .attr("fill", "none")
        ;
          
    joinLinks();

    const nodesG = svg.append("g");
    addNodes();

    function handleNodeClick(e, d) {
      if (d.clickable) {
        window.location = d.searchPath;
      }
    }

    function handleNodeMouseenter(e, d) {
      const connectedLinks = buildConnectedLinks(d);

      connectedLinks.forEach((l) => {
        const highlightLink = buildHighlightLink(l, d);

        if (highlightLink.width) {
          highlightLinks.push(highlightLink);
        }
      });

      updateHighlightNodeCounts(d);
      updateLinkColors();
      joinHighlightLinks();
    }

    function buildConnectedLinks(d) {
      const sourcePathLinks = buildSourcePathLinks(d)
          , targetPathLinks = buildTargetPathLinks(d)

      return sourcePathLinks.concat(targetPathLinks)
    }

    function buildSourcePathLinks(d) {
      return pathLinksHelper([d], 'source');
    }

    function buildTargetPathLinks(d) {
      return pathLinksHelper([d], 'target');
    }

    function pathLinksHelper(nodes, type) {
      const oppositeType = type == 'source' ? 'target' : 'source';
      const nodeLinks = links.filter((l) => {
        return nodes.includes(l[type])
      });
      let connectedLinks = [];

      if (nodeLinks.length) {
        connectedLinks = pathLinksHelper(nodeLinks.map((l) => l[oppositeType]), type);
      }

      return nodeLinks.concat(connectedLinks);
    }


    function buildHighlightLink(l, selectedNode) {
      const hlLink = {}
          , linkPageIds = new Set(l.pageIds)
          , selectedPageIds = new Set(selectedNode.pageIds)
          , intersectPageIds = setIntersection(linkPageIds, selectedPageIds);
          ;

      hlLink.id = l.id + "-hl"
      hlLink.source = l.source;
      hlLink.target = l.target;
      hlLink.width = (intersectPageIds.size / l.value) * l.width;


      hlLink.y0 = l.y0 + (l.width / 2.0) - (hlLink.width / 2.0);
      hlLink.y1 = l.y1 + (l.width / 2.0) - (hlLink.width / 2.0);
      hlLink.isHighlight = true;

      return hlLink;
    }

    function setIntersection(a, b) {
      const result = new Set();

      a.forEach((item) => {
        if (b.has(item)) {
          result.add(item);
        }
      });

      return result;
    }

    function handleNodeMouseleave() {
      highlightLinks = [];
      updateLinkColors();
      joinHighlightLinks();
      nodes.forEach((n) => {
        n.highlightValue = null;
      });
      updateNodeValues();
    }

    // all link uids for paths originating with node n
    function nodeTargetPathLinks(n) {
      return nodePathLinksHelper(new Set([n]), null, 'target');
    } 

    function nodeSourcePathLinks(n) {
      return nodePathLinksHelper(new Set([n]), null, 'source');
    }


    function nodePathLinksHelper(nodes, linkIds, type) {
      if (!linkIds) {
        linkIds = new Set();
      }

      if (!nodes.size) {
        return linkIds;
      }

      const linksKey = type + 'Links'
          , linkNodeKey = type == 'target' ? 'source' : 'target'
          , nextNodes = new Set()
          ;


      nodes.forEach((n) => {
        n[linksKey].forEach((l) => {
          linkIds.add(l.id); 
          nextNodes.add(l[linkNodeKey]);
        });
      });

      return nodePathLinksHelper(nextNodes, linkIds, type);
    }

    function updateHighlightNodeCounts(hoverNode) {
      const highlightNodes = new Set();

      highlightLinks.forEach((l) => {
        highlightNodes.add(l.source);
        highlightNodes.add(l.target);
      });

      highlightNodes.delete(hoverNode);

      highlightNodes.forEach((node) => {
        const size = setIntersection(new Set(node.pageIds), new Set(hoverNode.pageIds)).size;
        node.highlightValue = size;
      });

      updateNodeValues();
    }

    function setSelectedNode(node) {
      if (selectedNodes[node.axisId] == node) {
        // unset
        selectedNodes[node.axisId] = null;
      } else {
        //set
        selectedNodes[node.axisId] = node;
      }
    }

    function linkColor(d) {
      if (highlightLinks.length && !d.isHighlight) {
        return "#eee";
      } else {
        return "#89c783";
      }
    }

    function joinLinks() {
      joinLinksHelper(linkG, links)
    }

    function joinHighlightLinks() {
      joinLinksHelper(highlightLinkG, highlightLinks);
    }

    function joinLinksHelper(g, data) {
      const link = g.selectAll('g')
        .data(data)
        .join('g');

      const gradient = link.append('linearGradient')
        .attr("id", d => d.id)
        .attr('gradientUnits', 'userSpaceOnUse')
        .attr('x1', d => d.source.x1)
        .attr('x2', d => d.target.x0)

      gradient.append('stop')
        .attr('offset', '0%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);

      gradient.append('stop')
        .attr('offset', '10%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);

      gradient.append('stop')
        .attr('offset', '30%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', .5);

      gradient.append('stop')
        .attr('offset', '70%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', .5);

      gradient.append('stop')
        .attr('offset', '90%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);

      gradient.append('stop')
        .attr('offset', '100%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);
        
      link.append('path') 
        .attr("d", linkDataFn)
        .attr("stroke", d => `url(#${d.id})`)
        .attr("stroke-width", d => Math.max(1, d.width));

      link.append("title")
        .text(d => d.names ? `${d.names.join(" → ")}\n${d.value.toLocaleString()}` : "")
    }

    function updateLinkColors() {
      linkG.selectAll('stop')
        .attr('stop-color', linkColor);
    }

    function addNodes() {
      const nodeG = nodesG.selectAll("g")
        .data(nodes)
        .join("g")
        .on('click', handleNodeClick)
        .on('mouseenter', handleNodeMouseenter)
        .on('mouseleave', handleNodeMouseleave);

      nodeG.append("title")
          .text(d => d.clickable ? d.promptText : null)

      nodeG.append("rect")
          .attr("x", d => d.x0)
          .attr("y", d => d.y0)
          .attr("height", d => d.y1 - d.y0)
          .attr("width", d => d.x1 - d.x0)
          .attr('fill', nodeFillColor)
          .attr('stroke', nodeStrokeColor)
          .attr('stroke-width', nodeStrokeWidth)
          .style('cursor', nodeCursor)
        ;

      nodeG.append("text")
        .style("font", "10px sans-serif")
        .attr("x", d => d.x0 < width / 2 ? d.x1 : d.x0)
        .attr("y", d => d.y1 + 10)
        .attr("dy", "0.35em")
        .attr("text-anchor", d => d.x0 < width / 2 ? "start" : "end")
        .text(d => d.name)
        .style('cursor', nodeCursor)
        .append("tspan")
          .attr('class', 'node-value')
          .attr("fill-opacity", 0.7)

      updateNodeValues();
    }

    function updateNodeValues() {
      nodesG.selectAll('.node-value')
        .text(d => { 
          if (d.highlightValue) {
            return ` ${I18n.t('i18n_js.traits.data_viz.sankey.m_of_n', { m: d.highlightValue, n: d.value })}`
          } else {
            return ` ${d.value.toLocaleString()}`;
          }
        });
    }

    function nodeCursor(d) {
      return d.clickable ? 'pointer' : 'normal';
    }

    function nodeFillColor(d) {
      return '#000';
    }

    function nodeStrokeColor(d) {
      return null;
    }

    function nodeStrokeWidth(d) {
      return 0;
    }
  }
  return exports;
})({});
