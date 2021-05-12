
# The Trait Schema

This document describes the Neo4j schema for Trait and affiliated
node types.  It expands on the contents of
[db/neo4j_schema.md](../db/neo4j_schema.md), incorporating additional
information provided by Jeremy Rice and other sources.  The schema is
exercised in the Rails `TraitBank` model in file
[trait_bank.rb](../app/models/trait_bank.rb), and it may be helpful to
consult that file in conjunction with this one.

I (JAR) have used this opportunity to experiment with rhetorical use/mention
separation.  I don't know whether this writing style is going to work
for everyone, so let me know if it's hard to understand and I'll fix it.

## About neo4j - in case you don't know all this already

Neo4j doesn't have a notion of schema, exactly, but in the general
sense of 'schema' meaning how the information at hand relates to what is
stored in the database, the following describes the schema for traits
and neighboring entities.

Instead of records or rows, Neo4j has 'nodes'.  Nodes can have typed
properties, with values that are scalars such as strings and numbers,
and typed links (sometimes called relationships, or arcs) to and from
other nodes.  Links have a 'source' or 'origin' and a 'target' or
'destination'.  Below we show link types in the section for each
origin node type, but neo4j has no particular source vs. target bias.

Properties and relationships can both be many to many.  Property
values are unique unless otherwise specified.

In the following there is a section for each node type, and in each
section a list of the properties of, and links from, nodes of that
type.

## Resource

A `Resource` node corresponds to a 'resource' defined here as a file
or set of files, imported from outside of the EOL project,
that provides specific measured or curated information about
taxa, such as habitat or average adult mass.  A resource comes
from some supplier of
biodiversity or trait information, in the form of a Darwin
Core Archive (DwCA).
Some of the information from resources is recorded in the
properties and links of `Trait` nodes.

* `resource_id` property - Each `Resource` node has a different
  `resource_id` property value.
  This value can be used as a key 
  in tables stored in one of the relational databases, where further
  information about the resource can be found.

## Page

A `Page` node is meant to correspond to a taxon for which there is a
'taxon concept' (published description of some kind).  (By 'taxon' is
meant the biological grouping that contains organisms or specimens, as
opposed to its description.)  The correspondence between
Pages and taxa will fail once in a while due to errors in the source
data, in taxon record matching (the harvester), or in what we believe
about nature.  These situations are errors and should be fixed when
detected.

The use of the word 'page' is a reference to the EOL user
interface, where each taxon known to EOL has its own web page.

* `page_id` property, a positive integer.
  Every `Page` has a different `page_id` value.  The page id is used as a key in
  the EOL relational databases (or ORM), which contain additional taxon
  information such as scientific name.
  Always present.
* `canonical` property, a string.
  Each page should have its own scientific name, represented here in its
  canonical form (e.g.: "*Procyon lotor*" and NOT "*P. lotor* (Linnaeus,
  1758)").
  *Should* always be present, but this value is *denormalized* and may therefore
  be "stale" or missing in rare cases. For the most trustworthy value, it is
  advised to check the EOL page (https://eol.org/pages/PAGE_ID/names).
* `rank` property, a string (e.g. `"family"`).
  This gives the corresponding taxon's designated rank, if any.  The rank
  comes from the dynamic hierarchy (see denormalization remark above), which 
  in turn gets it from various taxonomic sources.

Relationships:

* `parent` link (to another `Page` node): taxonomic subsumption; the
  target is [intended to be] the `Page` node for the smallest taxon in
  the dynamic hierarchy that contains, but is different from, the one
  for this `Page`.  The `parent` link is unique, if present, and is
  only absent for the root of the dynamic hierarchy and for Page nodes
  that don't belong to the dynamic hierarchy.
* `trait` link (to a `Trait` node): the target node gives categorical or
  quantitative information
  about the taxon.  Many `Trait`s (or no
  `Trait`s) can be `trait`-linked from a given `Page`.
* `inferred_trait` link: same as `trait`, but the applicability of the
  `Trait` to the `Page` is inferred.  The `Page` is a descendant of
  the `Page` that the `Trait` belongs to.  Many `Page`s can be related
  by `inferred_trait` to a single `Trait`.

## Trait

A `Trait` node corresponds to some kind of statement about a taxon (or
its members).  As usual a statement can be true or false.
These `Trait` statements are intended to be true, but as with any
information recorded in a database, they will not always be so.

The statement expressed by a `Trait` node, like most statements, has a subject,
a verb (or predicate), and an object (or value).  The subject is the taxon that
the `Page` node is about (i.e. the taxon for the `Page` node that
links to this `Trait` node via a `trait` link).  The verb is
given by the `predicate` link, and the object is given by one of the
`Trait` node properties or links, as described below.

`Trait` nodes have many properties and links, which are organized
below into groups.

### General information about the statement

* `eol_pk` property: an uninterpreted string that is different
  for every `Trait` node.  Always present.
* `resource_pk` property: a key for the statement within the resource;
  that is, each statement obtained from a given resource has a different `resource_pk`
  value.  Always present.  The value originates from a `measurementOrFactID` or
  `associationID` field in the resource DwCA.
* `citation` property: bibliographic citation (see http://purl.org/dc/terms/bibliographicCitation)
* `source` property: Value copied from a DwCA. Meant to describe the original source
  of the `Trait` information (since the resource is itself an aggregator).  
  Free text. Often quite long. Semantics unclear.

Relationships:

* `supplier` link: links to the Resource node for the resource from which 
  this statement is drawn.
* `metadata` link: information (statements!) about this statement; see below.
  The node may be `metadata`-linked to any number of `MetaData` nodes.
  A `MetaData` node may be linked from any number of `Trait` nodes.

### Subject and predicate

* `scientific_name` property: the name that the resource provided for the
  subject taxon; not necessarily the same as the `canonical` property or
  EOL's name for the taxon 
  (which is the name associated in the RDB with the `page_id` for the 
  subject's `Page`). 

Relationships:

* a `Trait` node is the target of `trait` or `inferred_trait` link,
  see above.  Each `Trait` node is `trait` related to exactly one `Page`.
* `predicate` link: links to a `Term` node, usually one for an ontology
  term; see below for `Term`.  Always present.

### Object (or value) of the statement

The 'object' or value of the statement is given by the
`object_page`, `object_term`, `normal_measurement`, or `literal`,
as determined by the nature of the `predicate`.

* `object_term` link: to a `Term` node for the object of the statement,
  usually an ontology term for some qualitative choice (e.g. habitat type).
  The predicate's type will be 'measurement' [check on this].
* `object_page` link: to a `Page` node that is the object of the statement for Traits with predicate type `association`.
* `normal_measurement` property: this value is the value of the statement,
  indicating a quantity in normalized units.
  The predicate's type will be 'measurement' [check on this].
* `normal_units_term` link: when `normal_measurement` is present, the
  target is a `Term` node (usually
  for an ontology term) that gives the units in which `normal_measurement` is given.
* `normal_units` property: textual description of the units
* `measurement` property: redundant with `normal_measurement`, but the value is given
  as it occurs in the resource rather than normalized to EOL-favored units
* `units_term` link: when `measurement` is present, the target is a `Term` node (usually
  for an ontology term) describing the units of `measurement` as the value
  is provided by the resource.
* `literal` property: a string coming from an uncontrolled vocabulary such as
  is found in certain Darwin Core attributes.
  (This property seems to be redundant, in that it is the `uri` of the
  `object_term` when there is one?)

### Qualifiers

The statement might not necessarily apply to everything in the taxon, but
only to some subset.

The following properties provide such scope qualifiers.  The property
values are text for the web site to use; the text is derived from
ontology terms that are not stored.  Those terms can be found in
`MetaData` nodes that repeat the expression of this qualifying
information.

* `method` property: measurement method (see http://rs.tdwg.org/dwc/terms/measurementMethod)
* `remarks` property: measurement remarks (see http://rs.tdwg.org/dwc/terms/measurementRemarks)
* `sample_size` property: sample size (see http://eol.org/schema/terms/SampleSize)
* `statistical_method` property [more documentation needed]
* `statistical_method_term` link
* `sex_term` link
* `lifestage_term` link

Sometimes (always?) these qualifying properties and links are
redundant with `MetaData` nodes for this `Trait` node.  E.g. it
appears that if there is a `sex_term` link then there is also a
`MetaData` node that has a `sex` property.  Similarly for
`lifestage_term` and the `life stage` MetaData property.

## Metadata

A `MetaData` node expresses something we know or believe, either
about the `Trait` node's statement, the way the statement was
determined, or the way in which the statement is expressed in the `Trait` node.

Some `MetaData` nodes are a more rigorous expression of information in
the `Trait` node, providing an ontology term rather than free text.

* `eol_pk` property:     always present - unique to this `MetaData` node
* `predicate` link (to a `Term`):      Example: the target could be an ontology term
      indicating that the measurement value gives the sample size.  Always present
* `object_term` link (to a `Term`): either this link, or a `measurement`
     or `literal` property, is present, similarly to `Trait` nodes
* `measurement` property:      e.g. the sample size
* `units_term` link (to a `Term` node): units that apply to `measurement`, when it is present
* `literal` property: similar to same property on a `Trait`

## Term

`Term` nodes correspond (usually?) to ontology terms defined in some
origin document such as an OWL ontology or controlled vocabulary.  Terms
are written as URLs (URIs) and the origin provides them with a name,
description, and other information such as type and subsumption
relationships.

Terms are copied from EOL harvesting database to the graph database.
They are *not* used in EOL's relational publishing database.

* `uri` property:    always present - the standard URI (URL) for this property
* `name` property:   an English word or phrase, chosen by EOL curators, but
  usually the same as the canonical name as provided by the origin ontology.  Always present
* `name_<locale>` (e.g., name\_fr) property: translated name for locale \<locale\>. May be the same as `name`; may not be present.
* `type` property: for type checking.
  Possible values as of this writing are `"measurement"`, `"association"`, `"value"`,
  and `"metadata"` reflecting how the term is used in EOL.  Always present
* `definition` property:   from the ontology
* `comment` property:      EOL curator note
* `attribution` property:  string, e.g. might say that term's source is a particular OBO ontology
* `section_ids` property:  string with comma separated fields giving the
   sections of the TOC in which the term occurs.  The exact
   syntax and semantics are hairy; see RDB documentation for details.
* `is_hidden_from_overview` property: hidden from the trait overview on a web page
* `is_hidden_from_glossary` property
* `position` property:  an integer assigned only to this term, related to the
  ordering of this `Trait` information in the summary on the web page
* `trait_row_count` property: a periodically calculated (offline) count of all (:Trait)-[:\<reltype\>]->(:Term)-[:parent\_term|:synonym\_of\*0..]->(term) paths where term is the Term in question. reltype is object\_term for Terms with type = 'value' and predicate for Terms with type in ['measurement', 'association']. This is a statistic used for query optimization. May not be present.
* `distinct_page_count` property: same as above, except it is a count of the distinct pages in (page:Page)-[:trait]->(:Trait)... matches.


* `parent_term` link: the Terms form a hierarchy, this gives the term's parent term
* `synonym_of` link: a parent Term that this one is equivalent or approximately equivalent to. 
* `inverse_of` link: Reserved for type 'association' Terms, that is, predicates for association Traits. If a given Term `t` has relationship `(t)-[:inverse_of]->(other:Term)`, `t` should not be used directly in Trait queries as it isn't attached to any Traits. Instead, use its inverse in the opposite direction. For example, `MATCH (p:Page)-[:trait|inferred_trait]->(trait:Trait)-[:predicate]->(t)` becomes `MATCH (trait:Trait)-[:object_page]->(p), (trait)-[:predicate]->(other:Term)<-[:inverse_of]-(t)`. 
* `object_for_predicate` link: a periodically-refreshed convenience relationship linking obj and pred terms where there exists (pred:Term)<-[:parent\_term|:synonym\_of\*0..]-(:Term)<-[:predicate]-(:Trait)-[:object\_term]->(:Term)-[:parent\_term|:synonym\_of\*0..]->(obj:Term).
